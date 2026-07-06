# vmctl 설치

## 사전 요구사항

- macOS: [VMware Fusion](https://www.vmware.com/products/fusion.html)
- Windows: [VMware Workstation](https://www.vmware.com/products/workstation-pro.html)

## vmctl 설치

- [vmctl-releases](https://github.com/nobreak-labs/vmctl-releases)

**macOS**

```bash
curl -fsSL https://raw.githubusercontent.com/nobreak-labs/vmctl-releases/main/install.sh | bash
```

`~/.local/bin/vmctl`에 설치되고, PATH에 없으면 사용 중인 셸의 rc 파일(`.zshrc` 등)에 자동으로 등록됩니다. 새 터미널을 열거나 `source ~/.zshrc`로 반영하세요.

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/nobreak-labs/vmctl-releases/main/install.ps1 | iex
```

`%LOCALAPPDATA%\vmctl\vmctl.exe`에 설치되고 사용자 PATH에 자동 등록됩니다.

## 설치 확인

```bash
vmctl version
```

## 셸 자동완성 (선택)

**zsh (macOS)**

```bash
vmctl completion zsh > $(brew --prefix)/share/zsh/site-functions/_vmctl
```

**powershell (Windows)**

```powershell
if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
vmctl completion powershell >> $PROFILE
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

셸별 상세 안내는 `vmctl completion <shell> --help` 참고.
