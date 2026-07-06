# vmctl 치트 시트

## 일반적인 작업 순서

1. 프로젝트 디렉터리 생성
2. 해당 디렉터리에 `vmfile.yaml` 작성 (또는 이 저장소의 `vmfile_*.yaml` 사용)
3. `vmctl` 명령으로 VM 관리

## 초기화

- `vmctl init`: 현재 디렉터리에 주석이 포함된 `vmfile.yaml` 템플릿 생성
- `vmctl validate`: `vmfile.yaml` 문법/필드 검증

## VM 정보 확인

- `vmctl list`: 현재 프로젝트 VM 목록
- `vmctl list --global`: 전체 프로젝트 VM 목록

## VM 시작/재시작

- `vmctl up [name...]`: VM 기동 (이미지 다운로드 → import → SSH 설정 → provision을 자동 수행, provision은 최초 1회만 실행)
- `vmctl create [name...]`: 생성만 하고 시작하지 않음
- `vmctl restart [name...]`: 재시작
- `vmctl provision [name...]`: provision 재실행
- `vmctl provision --name <step>`: 특정 provision 스텝만 실행
- `vmctl provision list [name...]`: provision 스텝 목록

## VM 중지/삭제

- `vmctl down [name...]`: 정상 종료
- `vmctl down --force`: 강제 종료
- `vmctl destroy [--force]`: 삭제 (`--force`는 확인 없이 + 에러 무시하고 state까지 강제 제거)

## SSH / 파일 전송

- `vmctl ssh <name>`: 인터랙티브 SSH (세션 자동 로깅)
- `vmctl ssh <name> --no-log`: 로깅 없이 접속
- `vmctl ssh-config <name>`: `~/.ssh/config` 블록 출력
- `vmctl exec <name> -- <cmd>`: 단일 명령 실행
- `vmctl cp ./local.txt <name>:/remote`: 파일 업로드
- `vmctl cp <name>:/remote ./local.txt`: 파일 다운로드

## 세션 로그

SSH 접속 시 터미널 I/O가 `logs/{날짜}/{vmname}/{시간}.log`에 자동 기록됩니다.

- `vmctl log list [name]`: 세션 목록
- `vmctl log show <id>`: 세션 내용 출력
- `vmctl log compress [name]`: 완료된 세션 zip 압축 (원본 유지)
- `vmctl log prune [--before YYYY-MM-DD] [--yes]`: 로그/zip 삭제

## 이미지 관리

- `vmctl image list`: 로컬 캐시 목록
- `vmctl image pull <name>[:<ver>]`: 이미지 다운로드
- `vmctl image remove <name>`: 이미지 삭제
- `vmctl image prune`: 미사용 이미지 삭제
- `vmctl image update`: 최신 버전 확인 및 업데이트

## 네트워크

- `vmctl network list`: VMware 네트워크 목록 + VM 사용 현황
- `vmctl network prune [--yes]`: VM이 없는 네트워크 삭제

## 전역 플래그

| 플래그 | 설명 |
|--------|------|
| `--file, -f` | `vmfile.yaml` 경로 지정 |
| `--debug` | vmrun 명령 전체 출력 |
| `--quiet` | 에러만 출력 |
