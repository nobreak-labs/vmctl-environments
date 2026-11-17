#!/usr/bin/env bash

set -euo pipefail

GRUB_TIMEOUT_SEC="${GRUB_TIMEOUT_SEC:-5}"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: root 권한으로 실행하세요."
  echo "예: sudo $0"
  exit 1
fi

KERNEL="$(uname -r)"
INITRAMFS="/boot/initramfs-${KERNEL}.img"
KERNEL_IMAGE="/lib/modules/${KERNEL}/vmlinuz"
MODDIR="/usr/lib/dracut/modules.d/98dracut-systemd"
SOURCE_FILE="${MODDIR}/dracut-emergency.sh"   # 정확한 경로로 고정 (백업 파일 오인 방지)
BACKUP="${SOURCE_FILE}.rhcsa-original"
RESCUE_HOOK="/usr/lib/kernel/install.d/51-dracut-rescue.install"
BLS_DIR="/boot/loader/entries"
LAB_SHELL='exec /bin/sh -i -l'

# 이미지마다 /etc/machine-id 와 BLS 항목 이름의 machine-id가 다를 수 있으므로
# 현재 커널의 BLS 항목에서 machine-id를 가져온다.
ENTRY="$(ls "${BLS_DIR}"/*-"${KERNEL}".conf 2>/dev/null | head -n1 || true)"
if [[ -z "$ENTRY" ]]; then
  echo "ERROR: ${KERNEL} 의 BLS 항목을 ${BLS_DIR} 에서 찾을 수 없습니다."
  exit 1
fi
ENTRY_MID="$(basename "$ENTRY" "-${KERNEL}.conf")"
RESCUE_ENTRY="${BLS_DIR}/${ENTRY_MID}-0-rescue.conf"
RESCUE_KERNEL="/boot/vmlinuz-0-rescue-${ENTRY_MID}"
RESCUE_INITRAMFS="/boot/initramfs-0-rescue-${ENTRY_MID}.img"

echo "kernel        : ${KERNEL}"
echo "BLS entry     : ${ENTRY}"
echo "dracut source : ${SOURCE_FILE}"

echo "[1/8] dracut-config-rescue 설치 확인"
if ! rpm -q dracut-config-rescue >/dev/null 2>&1; then
  dnf install -y -q dracut-config-rescue
fi

echo "[2/8] dracut-emergency 원본 확보"
if [[ -f "$BACKUP" ]]; then
  # 이전 실행에서 남은 백업으로 원본 복구
  grep -q 'exec sulogin' "$BACKUP" || { echo "ERROR: 백업 파일이 원본이 아닙니다: $BACKUP"; exit 1; }
  cp -a "$BACKUP" "$SOURCE_FILE"
else
  grep -q 'exec sulogin' "$SOURCE_FILE" || { echo "ERROR: 원본에 'exec sulogin'이 없습니다: $SOURCE_FILE"; exit 1; }
  cp -a "$SOURCE_FILE" "$BACKUP"
fi
# 이전 버전 스크립트가 남긴 찌꺼기 정리 (*.rhcsa-original.rhcsa-original, *.lab)
rm -f "${BACKUP}".* "${SOURCE_FILE}.lab"

echo "[3/8] 랜덤 root 패스워드 설정"
TEMP_ROOT_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
echo "root:${TEMP_ROOT_PASSWORD}" | chpasswd
unset TEMP_ROOT_PASSWORD

echo "[4/8] 실습용 emergency shell 적용 (임시)"
# 이후 단계에서 실패해도 원본 파일은 반드시 복구
trap 'cp -a "$BACKUP" "$SOURCE_FILE"' EXIT

PATCHED="$(mktemp)"
sed '/^[[:space:]]*if getargbool 0 SYSTEMD_SULOGIN_FORCE;/,/^[[:space:]]*fi$/c\
    '"$LAB_SHELL" "$BACKUP" > "$PATCHED"
sh -n "$PATCHED"
if grep -q 'sulogin' "$PATCHED" || ! grep -qF "$LAB_SHELL" "$PATCHED"; then
  rm -f "$PATCHED"
  echo "ERROR: dracut-emergency 패치 실패 (dracut 버전이 바뀌었는지 확인)"
  exit 1
fi
cat "$PATCHED" > "$SOURCE_FILE"   # 권한/SELinux 컨텍스트 유지
rm -f "$PATCHED"

echo "[5/8] 정상 initramfs 재생성"
dracut -f "$INITRAMFS" "$KERNEL"

echo "[6/8] rescue 이미지/부팅 항목 재생성"
rm -f "$RESCUE_ENTRY" "$RESCUE_KERNEL" "$RESCUE_INITRAMFS" "/boot/.vmlinuz-0-rescue-${ENTRY_MID}.hmac"
# 3번째 인자의 상위 디렉터리가 존재하지 않아야 /boot 아래 BLS 방식으로 생성됨
KERNEL_INSTALL_MACHINE_ID="$ENTRY_MID" \
  "$RESCUE_HOOK" add "$KERNEL" "/boot/${ENTRY_MID}/${KERNEL}" "$KERNEL_IMAGE"

echo "[7/8] dracut 원본 파일 복구 + GRUB 메뉴 대기 시간 ${GRUB_TIMEOUT_SEC}초"
cp -a "$BACKUP" "$SOURCE_FILE"
trap - EXIT
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=${GRUB_TIMEOUT_SEC}/" /etc/default/grub
grub2-editenv - unset menu_auto_hide
grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1

echo "[8/8] 결과 확인"
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
  echo "  FAIL rescue 부팅 항목 없음"
  fail=1
fi

if grep -q 'sulogin' "$SOURCE_FILE"; then
  echo "  OK   ${SOURCE_FILE} 원본 상태"
else
  echo "  FAIL ${SOURCE_FILE} 원본 복구 안 됨"
  fail=1
fi

echo
if [[ $fail -eq 0 ]]; then
  echo "OK: rd.break 실습 환경 준비 완료"
else
  echo "ERROR: 일부 항목 실패"
  exit 1
fi
