# vmctl Environments

[vmctl](https://github.com/nobreak-labs/vmctl)로 관리하는 개발/실습용 VM 환경 모음입니다.
[vagrant-environments](https://github.com/nobreak-labs/vagrant-environments)의 vmctl 버전입니다.

## 사전 준비

- vmctl 설치: [docs/vmctl-install.md](docs/vmctl-install.md) (이 저장소의 vmfile은 네트워크 `mode`/CIDR 표기를 쓰므로 **vmctl 0.6.0 이상** 필요)
- 명령어 요약: [docs/vmctl-cheat-sheet.md](docs/vmctl-cheat-sheet.md)
- 새 vmfile.yaml 작성: [templates/README.md](templates/README.md)

## 이미지

- Ubuntu 24.04: `nobreak-labs/ubuntu-24.04`
- Ubuntu 26.04: `nobreak-labs/ubuntu-26.04`
- Rocky Linux 9: `nobreak-labs/rockylinux-9`
- Rocky Linux 10: `nobreak-labs/rockylinux-10`

> vmctl은 이미지 이름을 `owner/name` 형식으로 사용합니다 (`vmctl image pull <name>[:<version>]`).

## 환경 목록

| 파일 | 설명 |
|------|------|
| [vmfile_ubuntu.yaml](vmfile_ubuntu.yaml) | Ubuntu 24.04 단일 VM |
| [vmfile_rocky.yaml](vmfile_rocky.yaml) | Rocky Linux 10 단일 VM |
| [vmfile_docker.yaml](vmfile_docker.yaml) | Docker 설치된 단일 VM |
| [vmfile_ansible.yaml](vmfile_ansible.yaml) | Ansible 실습용 control + node 2대 |
| [vmfile_frr.yaml](vmfile_frr.yaml) | FRRouting(RIP) 라우터 VM |
| [vmfile_jenkins_cicd.yaml](vmfile_jenkins_cicd.yaml) | Jenkins CI/CD 파이프라인 실습용 다중 VM |
| [vmfile_kubespray.yaml](vmfile_kubespray.yaml) | Kubespray로 구성하는 Kubernetes 클러스터 (control 1 + node 3) |
| [vmfile_kubespray_cilium_bgp.yaml](vmfile_kubespray_cilium_bgp.yaml) | Kubespray + Cilium BGP 실습용 클러스터 + FRR 라우터 |

> **참고**: vagrant-environments의 `Vagrantfile_openstack_aio`는 bridged 네트워크가 0.6.0에서 지원되었지만,
> nested virtualization과 커스텀 디스크 컨트롤러 설정은 아직 `vmfile.yaml`로 표현할 수 없어 제외했습니다.

## 네트워크

vmctl 0.6.0부터 추가 NIC에 `type: bridge`와 주소 설정 방식 `mode`(`static` / `dhcp` / `none`), CIDR 표기를 쓸 수 있습니다.
관리용 NAT(`ethernet0`)는 그대로 유지되므로 기존 SSH 접속 경로는 바뀌지 않습니다.

```yaml
networks:
  - type: hostonly            # VM ↔ VM, 호스트 ↔ VM 통신
    mode: static
    ip: 192.168.153.11/24
  - type: hostonly
    mode: dhcp                # VMware DHCP에서 주소 수신
    subnet: 192.168.154.0/24
  - type: bridge
    mode: dhcp                # 호스트가 붙어 있는 외부 LAN에 연결
```

이 저장소의 `vmfile_*.yaml`은 모두 `hostonly` + `mode: static` + CIDR 표기를 사용합니다.
필드별 설명은 [templates/README.md](templates/README.md), 명령/설정 요약은 [docs/vmctl-cheat-sheet.md](docs/vmctl-cheat-sheet.md)를 참고하세요.

## 사용법

각 `vmfile_*.yaml`은 그대로 `-f` 옵션으로 실행하거나, `vmfile.yaml`로 복사해서 사용합니다.

```bash
# 방법 1: -f 옵션으로 직접 지정
vmctl -f vmfile_docker.yaml up

# 방법 2: vmfile.yaml로 복사 후 사용
cp vmfile_docker.yaml vmfile.yaml
vmctl up
```

프로비저닝 스크립트를 `path`로 참조하는 vmfile은 리포지토리 루트(`scripts/` 디렉터리 기준 상대 경로)에서 실행해야 합니다.
