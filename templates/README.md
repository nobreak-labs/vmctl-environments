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
  image: nobreak-labs/rockylinux-10
  cpus: 2
  memory: 2048
```

### 2. VM 구성 (vms)

`vms` 배열에 생성할 VM들을 정의합니다. 각 VM은 `name`이 필수이며, 나머지 값은 생략 시 `defaults`를 따릅니다.

#### 지원 옵션

| 옵션 | 설명 | 기본값 | 예시 |
|------|------|--------|------|
| `image` | 이미지 이름 (`owner/name`) | `defaults.image` | `nobreak-labs/ubuntu-24.04` |
| `image_version` | 이미지 버전 고정 | 최신 버전 | `"10.1"` |
| `cpus` | CPU 코어 수 | `defaults.cpus` | `4` |
| `memory` | 메모리 크기 (MB) | `defaults.memory` | `4096` |
| `networks` | 추가 NIC 목록 (`type`, `mode`, `ip`, `subnet`, `netmask`) | - | `[{type: hostonly, mode: static, ip: 192.168.153.10/24}]` |
| `disks` | 추가 디스크 목록 (`name`, `size`) | - | `[{name: data, size: 10GB}]` |
| `provision` | 프로비저닝 스텝 목록 (`name`, `inline` 또는 `path`, `on_error`) | - | 아래 예시 참고 |
| `ssh` | VM별 SSH 설정 (`user`, `timeout`, `extra_public_keys`) | 전역 `ssh` | - |

> **참고**: `provision`의 `inline`과 `path`는 동시에 사용할 수 없습니다.

---

### 3. 네트워크 (networks)

`ethernet0`은 관리용 NAT로 고정되며 SSH·인터넷 경로로 사용합니다. `networks`에는 `nat`을 쓸 수 없고,
선언한 순서대로 `ethernet1`부터 추가 NIC이 붙습니다.

| 필드 | 설명 |
|------|------|
| `type` | 필수. `hostonly` 또는 `bridge` |
| `mode` | `static`, `dhcp`, `none`. 생략 시 `ip`가 있으면 `static`, 없으면 `dhcp` |
| `ip` | `static`에서 필수. IPv4 주소 또는 CIDR (`192.168.153.10/24`) |
| `netmask` | 기존 표기 호환용. CIDR가 없으면 기본 `/24` |
| `subnet` | `hostonly`의 `dhcp`/`none`에서 필수. 네트워크 CIDR (`192.168.154.0/24`) |

- `static`: 지정한 IPv4 주소를 적용하고 DHCP를 끕니다.
- `dhcp`: `bridge`는 외부 LAN에서, `hostonly`는 VMware DHCP에서 주소를 받습니다.
- `none`: 링크만 올리고 IPv4/IPv6 자동 주소 설정을 모두 끕니다. provision이나 게스트 안에서 직접 주소를 정할 때 사용합니다.

```yaml
networks:
  - type: hostonly          # VM ↔ VM, 호스트 ↔ VM 통신
    mode: static
    ip: 192.168.153.10/24

  - type: hostonly
    mode: dhcp
    subnet: 192.168.154.0/24

  - type: hostonly
    mode: none
    subnet: 192.168.155.0/24

  - type: bridge            # 호스트가 붙어 있는 외부 LAN에 연결
    mode: dhcp
```

> **참고**: `bridge`에는 `subnet`을 쓰지 않고, `hostonly` static은 `ip`에서 서브넷을 계산하므로 `subnet`이 필요 없습니다.
> CIDR와 `netmask`를 함께 지정하면 값이 일치해야 합니다.
> **참고**: 추가 NIC은 기본 경로와 DNS를 바꾸지 않고 관리 NAT에 그대로 둡니다. 게이트웨이/DNS 옵션은 제공하지 않습니다.
> **참고**: 네트워크 설정을 바꾼 뒤에는 `vmctl restart <VM>`으로 반영합니다.

---

### 4. 프로비저닝 (provision)

`provision`에 필요한 작업을 스텝별로 나열하고, 각 스텝의 `inline: |` 아래에 셸 스크립트를 작성합니다. 별도 스크립트 파일 없이 YAML 파일 하나에 설치와 설정 작업을 담을 수 있습니다.

#### 여러 명령과 설정 파일 작성

다음은 Ubuntu VM에서 패키지를 설치한 뒤 설정 파일을 만드는 예시입니다.

```yaml
provision:
  - name: install-packages
    inline: |
      #!/bin/bash
      set -e

      apt-get update
      apt-get install -y curl git
  - name: write-config
    inline: |
      #!/bin/bash
      set -e

      install -d -m 0755 /opt/example
      cat <<'EOF' > /opt/example/app.conf
      APP_ENV=development
      LOG_LEVEL=info
      EOF
    # on_error: continue   # 실패해도 다음 스텝 진행. 기본값: stop
```

- `|`는 스크립트의 줄바꿈을 유지합니다. 본문은 `inline`보다 더 깊게, 일정하게 들여씁니다.
- 각 스텝은 별도 스크립트로 작성합니다. 다른 스텝에서도 필요한 셸 변수는 해당 스텝에서 다시 정의합니다.
- 각 스크립트에 `set -e`를 넣으면 명령 실패 시 해당 스텝이 중단됩니다. `on_error`는 스텝 실패 후 처리를 정합니다.
- heredoc의 종료 구분자 `EOF`는 위 예시처럼 `cat`과 같은 깊이로 들여씁니다. YAML이 공통 들여쓰기를 제거하면 셸이 올바르게 인식합니다.
- `<<'EOF'`는 본문의 `$변수`와 `$(명령)`을 그대로 기록합니다. 값을 확장하려면 `<<EOF`를 사용합니다.
- 패키지 설치 명령은 VM 이미지에 맞춰 작성합니다. Ubuntu는 `apt-get`, Rocky Linux는 `dnf`를 사용합니다.

#### 반복 스크립트를 앵커와 별칭으로 재사용

첫 번째 `inline`에 `&prepare_workspace`로 앵커를 선언하고, 다른 VM에서는 `*prepare_workspace`로 같은 스크립트를 참조합니다.

```yaml
defaults:
  image: nobreak-labs/ubuntu-24.04
  cpus: 2
  memory: 2048

vms:
  - name: app1
    provision:
      - name: prepare-workspace
        inline: &prepare_workspace |
          #!/bin/bash
          set -e

          install -d -m 0755 /opt/example

  - name: app2
    provision:
      - name: prepare-workspace
        inline: *prepare_workspace
      - name: write-node-config
        inline: |
          #!/bin/bash
          set -e

          echo 'NODE_NAME=app2' > /opt/example/node.conf
```

앵커는 참조보다 먼저 선언해야 하며, 같은 YAML 파일 안에서만 사용할 수 있습니다. 별칭은 스크립트 전체를 재사용하므로 VM별로 다른 작업은 별도 스텝에 작성합니다. 각 VM에서 스크립트가 실행될 때 `$(uname -m)` 같은 셸 표현식이 평가됩니다.

실제 구성은 루트의 [vmfile_jenkins_cicd.yaml](../vmfile_jenkins_cicd.yaml)과 [vmfile_kubespray.yaml](../vmfile_kubespray.yaml)을 참고하세요.

---

## 구성 예제

```yaml
defaults:
  image: nobreak-labs/rockylinux-10
  cpus: 2
  memory: 2048

vms:
  # 1. 기본 설정 (hostonly 고정 IP)
  - name: web-server
    networks:
      - type: hostonly
        mode: static
        ip: 192.168.153.10/24

  # 2. 리소스 커스터마이징
  - name: db-server
    cpus: 4
    memory: 4096
    networks:
      - type: hostonly
        mode: static
        ip: 192.168.153.20/24

  # 3. 다른 이미지 및 추가 디스크
  - name: storage-node
    image: nobreak-labs/ubuntu-24.04
    networks:
      - type: hostonly
        mode: static
        ip: 192.168.153.30/24
    disks:
      - name: data
        size: 50GB

  # 4. 외부 LAN 연결 (bridge) + hostonly DHCP
  - name: edge-node
    networks:
      - type: hostonly
        mode: dhcp
        subnet: 192.168.154.0/24
      - type: bridge
        mode: dhcp

  # 5. 풀 옵션 (provision 포함)
  - name: k8s-master
    image: nobreak-labs/ubuntu-24.04
    cpus: 2
    memory: 4096
    networks:
      - type: hostonly
        mode: static
        ip: 192.168.153.40/24
    disks:
      - name: data
        size: 20GB
    provision:
      - name: install-packages
        inline: |
          #!/bin/bash
          set -e

          apt-get update
          apt-get install -y curl git
```
