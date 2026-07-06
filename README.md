# vmctl Environments

[vmctl](https://github.com/nobreak-labs/vmctl)로 관리하는 개발/실습용 VM 환경 모음입니다.
[vagrant-environments](https://github.com/nobreak-labs/vagrant-environments)의 vmctl 버전입니다.

## 사전 준비

- vmctl 설치: [docs/vmctl-install.md](docs/vmctl-install.md)
- 명령어 요약: [docs/vmctl-cheat-sheet.md](docs/vmctl-cheat-sheet.md)
- 새 vmfile.yaml 작성: [templates/README.md](templates/README.md)

## 이미지

- Ubuntu 24.04: `nobreak-labs/ubuntu-24.04`
- Rocky Linux 10: `nobreak-labs/rocky-10`

이미지 검색: [Vagrant Cloud - nobreak-labs](https://portal.cloud.hashicorp.com/vagrant/discover/nobreak-labs)

> vmctl은 이미지 이름을 Vagrant Cloud의 `owner/name` 형식으로 사용합니다 (`vmctl image pull <name>[:<version>]`).

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

> **참고**: vagrant-environments의 `Vagrantfile_openstack_aio`(bridged 네트워크, nested virtualization, 커스텀 디스크 컨트롤러 필요)는
> vmctl의 현재 `vmfile.yaml` 스키마(`networks.type: hostonly`만 지원)로는 표현할 수 없어 제외했습니다.

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
