# vmctl 치트 시트

## 일반적인 작업 순서

1. 프로젝트 디렉터리 생성
2. 해당 디렉터리에 `vmfile.yaml` 작성 (또는 이 저장소의 `vmfile_*.yaml` 사용)
3. `vmctl` 명령으로 VM 관리

## 초기화

- `vmctl init`: 현재 디렉터리에 주석이 포함된 `vmfile.yaml` 템플릿 생성
- `vmctl validate`: `vmfile.yaml` 문법/필드 검증
- `vmctl doctor`: 호스트 환경 점검 (VMware 바이너리, VM 디렉터리, DHCP lease 접근, 디스크 공간, 이미지 캐시, 네트워크). 하나라도 실패하면 종료 코드 1

## VM 정보 확인

- `vmctl list` (`ls`): 현재 프로젝트 VM 목록
- `vmctl show [name...]`: VM 상세 정보 (이름 생략 시 전체 VM)

## 프로젝트 관리

- `vmctl project list` (`ls`): vmctl이 아는 전체 프로젝트와 VM 목록
- `vmctl project prune [--yes] [--force]`: `vmfile.yaml`이 사라진 프로젝트의 state 항목 삭제 (`--force`는 VM이 남은 항목도 삭제하며, VM 자체는 호스트에 그대로 남음)

## VM 시작/재시작

- `vmctl up [name...]`: VM 기동 (이미지 다운로드 → import → SSH 설정 → provision을 자동 수행, provision은 최초 1회만 실행)
- `vmctl up --gui [name...]`: GUI로 시작 (VMware만)
- `vmctl create [name...]`: 생성만 하고 시작하지 않음
- `vmctl restart [name...]`: 재시작
- `vmctl restart --force [name...]`: 강제 종료 후 재시작
- `vmctl provision [name...]`: provision 재실행
- `vmctl provision --name <step>`: 특정 provision 스텝만 실행
- `vmctl provision list [name...]` (`ls`): provision 스텝 목록

## VM 중지/삭제

- `vmctl down [name...]`: 정상 종료
- `vmctl down --force`: 강제 종료
- `vmctl destroy [name...] [--yes]`: 삭제 (`--yes`, `-y`는 확인 프롬프트 생략)
- `vmctl destroy [name...] --force`: 확인 없이 + 에러 무시하고 state까지 강제 제거

## SSH / 파일 전송

- `vmctl ssh [name]`: 인터랙티브 SSH (세션 자동 로깅, VM이 하나뿐이면 이름 생략 가능)
- `vmctl ssh [name] --no-log`: 로깅 없이 접속
- `vmctl ssh-config [name]`: `~/.ssh/config` 블록 출력 (VM이 하나뿐이면 이름 생략 가능)
- `vmctl exec <name> -- <cmd>`: 단일 명령 실행
- `vmctl cp ./local.txt <name>:/remote`: 파일 업로드
- `vmctl cp <name>:/remote ./local.txt`: 파일 다운로드 (원격 경로는 홈 디렉터리 기준 상대 경로 또는 절대 경로)

## 세션 로그

SSH 접속 시 터미널 I/O가 `logs/{날짜}/{vmname}/{시간}.log`에 자동 기록됩니다.

- `vmctl log list [name]` (`ls`): 세션 목록
- `vmctl log show <id>`: 세션 내용 출력
- `vmctl log compress [name]`: 완료된 세션 zip 압축 (원본 유지, 진행 중인 세션은 제외)
- `vmctl log prune [name] [--before YYYY-MM-DD] [--yes]`: 로그/zip 삭제

## 이미지 관리

- `vmctl image list` (`ls`): 로컬 캐시 목록
- `vmctl image pull <name>[:<ver>]`: 이미지 다운로드
- `vmctl image add <path> <name>[:<ver>]`: 로컬 이미지 아카이브(`.tar.gz`/`.box`)를 캐시에 추가
- `vmctl image remove [name[:<ver>]]` (`rm`): 이미지 삭제 (버전이 여러 개면 버전 지정 필요, `--all`은 전체 삭제)
- `vmctl image prune`: 어떤 VM도 참조하지 않는 이미지 삭제
- `vmctl image update`: 최신 버전 확인 및 업데이트

`image remove`, `image prune`, `image update`는 `--yes`(`-y`)로 확인 프롬프트를 생략합니다.

## 네트워크

- `vmctl network list` (`ls`): VMware 네트워크 목록 + VM 사용 현황 (DHCP 열은 VMware 서비스의 on/off, bridge는 `external` 표시)
- `vmctl network prune [--yes]`: VM이 없는 네트워크 삭제 (vmctl이 만든 네트워크만 대상)
- `vmctl network restart`: 호스트의 VMware 네트워크 서비스 재시작 (기존 설정 유지). 호스트의 모든 VM이 DHCP/NAT 연결을 잠시 잃을 수 있고, macOS/Linux는 sudo, Windows는 관리자 승인이 필요하며, 이후 게스트 DHCP 갱신이 필요할 수 있음

### vmfile.yaml 네트워크 설정

`ethernet0`은 관리용 NAT로 고정되어 SSH·인터넷 경로로 쓰이고, `networks[]`는 선언 순서대로
`ethernet1`부터 붙는 추가 NIC입니다. `nat`은 `networks`에 쓸 수 없습니다.

| 필드 | 설명 |
|------|------|
| `type` | 필수. `hostonly` 또는 `bridge` |
| `mode` | `static`, `dhcp`, `none`. 생략 시 `ip`가 있으면 `static`, 없으면 `dhcp` |
| `ip` | `static`에서 필수. IPv4 주소 또는 CIDR |
| `netmask` | 기존 표기 호환용. CIDR가 없으면 기본 `/24` |
| `subnet` | `hostonly`의 `dhcp`/`none`에서 필수. 네트워크 CIDR |

```yaml
networks:
  - type: hostonly
    mode: static
    ip: 192.168.153.11/24      # CIDR 또는 IP + netmask
  - type: hostonly
    mode: dhcp                 # VMware DHCP에서 주소 수신
    subnet: 192.168.154.0/24
  - type: hostonly
    mode: none                 # 링크만 활성화, 자동 주소 설정 없음
    subnet: 192.168.155.0/24
  - type: bridge
    mode: dhcp                 # 외부 LAN DHCP
```

- 추가 NIC은 기본 경로와 DNS를 바꾸지 않고 관리 NAT에 그대로 둡니다.
- 네트워크 설정을 바꾼 뒤에는 `vmctl restart <VM>`으로 반영합니다.
- hostonly DHCP는 VMware DHCP 풀과 고정 IP 대역이 겹치면 오류가 납니다.
- DHCP 주소 수신은 비동기이므로 `vmctl exec <VM> -- ip -4 addr`로 확인합니다.

## 기타

- `vmctl version`: 버전 정보 출력
- `vmctl completion <bash|zsh|fish|powershell>`: 셸 자동완성 스크립트 생성 ([설치 문서](vmctl-install.md#셸-자동완성-선택) 참고)

## 전역 플래그

| 플래그 | 설명 |
|--------|------|
| `--file, -f` | `vmfile.yaml` 경로 지정 |
| `--debug` | vmrun 명령 전체 출력 |
| `--quiet` | 에러만 출력 |
