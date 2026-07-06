# vmfile.yaml Template Guide

이 템플릿은 멀티 VM 환경을 쉽고 유연하게 구성하기 위해 설계되었습니다. `defaults`로 공통값을 지정하고, `vms` 배열의 각 항목에서 필요한 값만 덮어씁니다.

## 시작하기

1. `templates/vmfile_template.yaml` 파일을 프로젝트 디렉터리로 복사합니다.
   ```bash
   cp templates/vmfile_template.yaml vmfile.yaml
   ```
2. `vmfile.yaml`을 열어 원하는 구성을 설정합니다.
3. `vmctl validate`로 검증한 뒤 `vmctl up` 명령어로 VM을 생성합니다.

`vmctl init` 명령으로도 주석이 포함된 동일한 형태의 템플릿을 생성할 수 있습니다.

---

## 설정 가이드

### 1. 전역 설정 (defaults)

모든 VM에 기본으로 적용될 이미지와 리소스를 정의합니다.

```yaml
defaults:
  image: nobreak-labs/rocky-10
  cpus: 2
  memory: 2048
```

### 2. VM 구성 (vms)

`vms` 배열에 생성할 VM들을 정의합니다. 각 VM은 `name`이 필수이며, 나머지 값은 생략 시 `defaults`를 따릅니다.

#### 지원 옵션

| 옵션 | 설명 | 기본값 | 예시 |
|------|------|--------|------|
| `image` | Vagrant Cloud 이미지 이름 (`owner/name`) | `defaults.image` | `nobreak-labs/ubuntu-24.04` |
| `image_version` | 이미지 버전 고정 | 최신 버전 | `"10.1"` |
| `cpus` | CPU 코어 수 | `defaults.cpus` | `4` |
| `memory` | 메모리 크기 (MB) | `defaults.memory` | `4096` |
| `networks` | hostonly 네트워크 목록 (`type`, `ip`, `netmask`) | - | `[{type: hostonly, ip: 192.168.153.10}]` |
| `disks` | 추가 디스크 목록 (`name`, `size`) | - | `[{name: data, size: 10GB}]` |
| `provision` | 프로비저닝 스텝 목록 (`name`, `inline` 또는 `path`, `on_error`) | - | 아래 예시 참고 |
| `ssh` | VM별 SSH 설정 (`user`, `timeout`, `extra_public_keys`) | 전역 `ssh` | - |

> **참고**: 네트워크 타입은 현재 `hostonly`만 지원합니다. `netmask`를 생략하면 `255.255.255.0`이 적용됩니다.
> **참고**: `provision`의 `inline`과 `path`는 동시에 사용할 수 없습니다.

---

## 구성 예제

```yaml
defaults:
  image: nobreak-labs/rocky-10
  cpus: 2
  memory: 2048

vms:
  # 1. 기본 설정 (네트워크만 지정)
  - name: web-server
    networks:
      - type: hostonly
        ip: 192.168.153.10

  # 2. 리소스 커스터마이징
  - name: db-server
    cpus: 4
    memory: 4096
    networks:
      - type: hostonly
        ip: 192.168.153.20

  # 3. 다른 이미지 및 추가 디스크
  - name: storage-node
    image: nobreak-labs/ubuntu-24.04
    networks:
      - type: hostonly
        ip: 192.168.153.30
    disks:
      - name: data
        size: 50GB

  # 4. 풀 옵션 (provision 포함)
  - name: k8s-master
    cpus: 2
    memory: 4096
    networks:
      - type: hostonly
        ip: 192.168.153.40
    disks:
      - name: data
        size: 20GB
    provision:
      - name: install-docker
        path: ./scripts/ubuntu/install-docker.sh
```
