#!/usr/bin/env bash

set -euo pipefail

GRUB_TIMEOUT_SEC="${GRUB_TIMEOUT_SEC:-5}"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  echo "Example: sudo $0"
  exit 1
fi

KERNEL="$(uname -r)"
INITRAMFS="/boot/initramfs-${KERNEL}.img"
KERNEL_IMAGE="/lib/modules/${KERNEL}/vmlinuz"
MODDIR="/usr/lib/dracut/modules.d/98dracut-systemd"
SOURCE_FILE="${MODDIR}/dracut-emergency.sh"   # Fixed path (avoids picking up backup files by mistake)
BACKUP="${SOURCE_FILE}.rhcsa-original"
RESCUE_HOOK="/usr/lib/kernel/install.d/51-dracut-rescue.install"
BLS_DIR="/boot/loader/entries"
LAB_SHELL='exec /bin/sh -i -l'

# The machine-id in /etc/machine-id may differ from the one in the BLS entry name
# depending on the image, so take the machine-id from the current kernel's BLS entry.
ENTRY="$(ls "${BLS_DIR}"/*-"${KERNEL}".conf 2>/dev/null | head -n1 || true)"
if [[ -z "$ENTRY" ]]; then
  echo "ERROR: BLS entry for ${KERNEL} not found in ${BLS_DIR}."
  exit 1
fi
ENTRY_MID="$(basename "$ENTRY" "-${KERNEL}.conf")"
RESCUE_ENTRY="${BLS_DIR}/${ENTRY_MID}-0-rescue.conf"
RESCUE_KERNEL="/boot/vmlinuz-0-rescue-${ENTRY_MID}"
RESCUE_INITRAMFS="/boot/initramfs-0-rescue-${ENTRY_MID}.img"

echo "kernel        : ${KERNEL}"
echo "BLS entry     : ${ENTRY}"
echo "dracut source : ${SOURCE_FILE}"

echo "[1/8] Checking dracut-config-rescue package"
if ! rpm -q dracut-config-rescue >/dev/null 2>&1; then
  dnf install -y -q dracut-config-rescue
fi

echo "[2/8] Securing original dracut-emergency script"
if [[ -f "$BACKUP" ]]; then
  # Restore the original from a backup left by a previous run
  grep -q 'exec sulogin' "$BACKUP" || { echo "ERROR: Backup file is not the original: $BACKUP"; exit 1; }
  cp -a "$BACKUP" "$SOURCE_FILE"
else
  grep -q 'exec sulogin' "$SOURCE_FILE" || { echo "ERROR: 'exec sulogin' not found in original: $SOURCE_FILE"; exit 1; }
  cp -a "$SOURCE_FILE" "$BACKUP"
fi
# Clean up leftovers from older versions of this script (*.rhcsa-original.rhcsa-original, *.lab)
rm -f "${BACKUP}".* "${SOURCE_FILE}.lab"

echo "[3/8] Setting random root password"
TEMP_ROOT_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
echo "root:${TEMP_ROOT_PASSWORD}" | chpasswd
unset TEMP_ROOT_PASSWORD

echo "[4/8] Applying lab emergency shell (temporary)"
# Always restore the original file, even if a later step fails
trap 'cp -a "$BACKUP" "$SOURCE_FILE"' EXIT

PATCHED="$(mktemp)"
sed '/^[[:space:]]*if getargbool 0 SYSTEMD_SULOGIN_FORCE;/,/^[[:space:]]*fi$/c\
    '"$LAB_SHELL" "$BACKUP" > "$PATCHED"
sh -n "$PATCHED"
if grep -q 'sulogin' "$PATCHED" || ! grep -qF "$LAB_SHELL" "$PATCHED"; then
  rm -f "$PATCHED"
  echo "ERROR: Failed to patch dracut-emergency (check whether the dracut version has changed)"
  exit 1
fi
cat "$PATCHED" > "$SOURCE_FILE"   # Preserve permissions and SELinux context
rm -f "$PATCHED"

echo "[5/8] Regenerating default initramfs"
dracut -f "$INITRAMFS" "$KERNEL"

echo "[6/8] Regenerating rescue image and boot entry"
rm -f "$RESCUE_ENTRY" "$RESCUE_KERNEL" "$RESCUE_INITRAMFS" "/boot/.vmlinuz-0-rescue-${ENTRY_MID}.hmac"
# The parent directory of the 3rd argument must not exist so the hook creates a BLS entry under /boot
KERNEL_INSTALL_MACHINE_ID="$ENTRY_MID" \
  "$RESCUE_HOOK" add "$KERNEL" "/boot/${ENTRY_MID}/${KERNEL}" "$KERNEL_IMAGE"

echo "[7/8] Restoring original dracut file + setting GRUB menu timeout to ${GRUB_TIMEOUT_SEC}s"
cp -a "$BACKUP" "$SOURCE_FILE"
trap - EXIT
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=${GRUB_TIMEOUT_SEC}/" /etc/default/grub
grub2-editenv - unset menu_auto_hide
grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1

echo "[8/8] Verifying results"
fail=0
check_initrd() {
  local img="$1" tmp
  tmp="$(mktemp -d)"
  ( cd "$tmp" && lsinitrd --unpack "$img" >/dev/null 2>&1 )
  if grep -qF "$LAB_SHELL" "$tmp/usr/bin/dracut-emergency" \
     && ! grep -q 'sulogin' "$tmp/usr/bin/dracut-emergency"; then
    echo "  OK   $img"
  else
    echo "  FAIL $img"
    fail=1
  fi
  rm -rf "$tmp"
}
check_initrd "$INITRAMFS"
check_initrd "$RESCUE_INITRAMFS"

if [[ -f "$RESCUE_ENTRY" && -f "$RESCUE_KERNEL" ]]; then
  echo "  OK   $RESCUE_ENTRY ($(sed -n 's/^title //p' "$RESCUE_ENTRY"))"
else
  echo "  FAIL Rescue boot entry not found"
  fail=1
fi

if grep -q 'sulogin' "$SOURCE_FILE"; then
  echo "  OK   ${SOURCE_FILE} is in original state"
else
  echo "  FAIL ${SOURCE_FILE} was not restored"
  fail=1
fi

echo
if [[ $fail -eq 0 ]]; then
  echo "OK: rd.break lab environment is ready"
else
  echo "ERROR: Some checks failed"
  exit 1
fi
