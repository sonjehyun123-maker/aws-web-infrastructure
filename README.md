# AWS 웹 서비스 인프라 구축 및 외부 서비스 제공 프로젝트

본 프로젝트는 AWS 환경에서 VPC 기반 네트워크를 직접 구성하고, Public Subnet의 EC2 인스턴스에 Nginx 웹 서버를 배포하여 외부 인터넷에서 접근 가능한 웹 서비스를 구축·검증한 과제 수행 기록입니다.

## 1. 개요 및 구성 목적

본 과제에서는 다음 구조를 직접 구성했습니다.

- `Mission-VPC` : `10.0.0.0/16`
- `Mission-Public-Subnet` : `10.0.1.0/24`
- `Mission-IGW`
- `Mission-RouteTable`
- `Mission-Web-SG`
- `Mission-Web-Server` : `t3.micro`, Ubuntu 22.04 LTS, Nginx

외부 요청은 다음 경로로 전달됩니다.

> Internet Client → Internet Gateway → Route Table → Public Subnet → Security Group → EC2/Nginx

Public Subnet에는 퍼블릭 IPv4 자동 할당 옵션을 적용하고, Route Table에는 `0.0.0.0/0 → IGW` 경로를 설정했습니다. 웹 서비스는 HTTP 80번 포트를 외부에 공개하고, 관리용 SSH 22번 포트는 특정 관리자 IP(`/32`)로 제한했습니다.

## 2. 외부 접속 검증

### 웹 서비스

브라우저에서 다음 주소로 접속하여 Nginx 응답을 확인했습니다.

```text
http://3.34.42.120
```

확인 결과:

```text
HTTP 200 OK
```

### Health Check

```text
http://3.34.42.120/health
```

확인 결과:

```text
HTTP 200 OK
OK
```

CLI에서도 다음과 같이 원본 응답을 확인할 수 있습니다.

```bash
curl -i http://3.34.42.120
curl -i http://3.34.42.120/health
```

SSH 접속 확인:

```bash
ssh -i mission-key.pem ubuntu@3.34.42.120
```

> 실제 제출본에서는 브라우저 접속 화면과 SSH 성공 터미널 화면을 함께 첨부하면 구성 검증 과정을 한눈에 확인할 수 있습니다.

## 3. 구축된 AWS 인프라

| 구분 | 리소스 | 주요 설정 |
|---|---|---|
| VPC | `Mission-VPC` | `10.0.0.0/16` |
| Public Subnet | `Mission-Public-Subnet` | `10.0.1.0/24`, Public IPv4 자동 할당 |
| Internet Gateway | `Mission-IGW` | `Mission-VPC`에 연결 |
| Route Table | `Mission-RouteTable` | `0.0.0.0/0 → IGW` |
| Security Group | `Mission-Web-SG` | HTTP 80 공개, SSH 22 관리자 IP 제한 |
| EC2 | `Mission-Web-Server` | `t3.micro`, Ubuntu 22.04 LTS |
| Web Server | Nginx | TCP 80 |

### 리소스 연결 관계

```text
Mission-VPC
└── Mission-Public-Subnet
    ├── Route Table: 0.0.0.0/0 → Mission-IGW
    └── Mission-Web-Server
        └── Mission-Web-SG
            ├── TCP 80  ← 0.0.0.0/0
            └── TCP 22  ← 관리자 IP /32
```

라우팅과 서브넷의 연결 상태를 함께 확인해야 실제 Public Subnet 구성이 완성되었는지 판단할 수 있습니다.

## 4. 보안 및 접근 제어

### Security Group

| 방향 | 포트 | 소스/대상 | 목적 |
|---|---:|---|---|
| Inbound | 80 | `0.0.0.0/0` | 웹 서비스 |
| Inbound | 22 | 관리자 IP `/32` | SSH 관리 |
| Outbound | 전체 | `0.0.0.0/0` | 패키지 업데이트 및 외부 통신 |

HTTP 80은 외부 사용자가 웹 서비스를 이용해야 하므로 공개했습니다. 반면 SSH는 서비스 이용에 필요하지 않기 때문에 관리자 IP 한 곳으로 제한했습니다.

현재 실습의 Outbound 전체 허용은 패키지 설치와 업데이트를 단순하게 수행하기 위한 설정입니다. 운영 환경에서는 필요한 목적지와 포트만 허용하는 egress 정책으로 축소할 수 있습니다.

`0.0.0.0/0`에 대한 HTTP 공개는 인터넷상의 스캔과 웹 서버 취약점 공격에 노출될 수 있습니다. 따라서 HTTP 공개가 필요한 서비스라도 실제 운영에서는 HTTPS, WAF, 애플리케이션 보안 설정 등을 함께 고려해야 합니다.

### 관리자 IP 변경

관리자 네트워크가 변경되면 기존 SSH 규칙을 그대로 유지하지 않고 현재 공인 IP를 확인한 후 `/32` 규칙을 수정합니다.

```powershell
$MY_IP = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim() + "/32"
```

기존 SSH 규칙을 제거한 뒤 현재 IP를 추가하는 방식으로 관리합니다.

```powershell
aws ec2 revoke-security-group-ingress --group-id <SG_ID> --protocol tcp --port 22 --cidr <OLD_IP>/32
aws ec2 authorize-security-group-ingress --group-id <SG_ID> --protocol tcp --port 22 --cidr $MY_IP
```

## 5. IAM 최소 권한

Security Group은 네트워크 접근을 제어하고 IAM은 AWS 리소스에 대한 API 작업 권한을 제어합니다.

실습에서 EC2 관련 작업을 수행하는 계정은 필요한 작업 범위에 맞는 권한을 사용해야 하며, 장기적으로는 `AdministratorAccess` 같은 광범위한 권한 대신 작업별 최소 권한 정책을 사용하는 것이 적절합니다.

예를 들어 VPC/EC2 실습용 역할을 별도로 만든다면 필요한 작업만 다음과 같이 제한할 수 있습니다.

```text
ec2:Describe*
ec2:CreateVpc
ec2:CreateSubnet
ec2:CreateRoute
ec2:RunInstances
ec2:TerminateInstances
```

권한을 추가할 때는 실제 작업에 필요한 API 호출을 확인하고, CloudTrail 등의 감사 기록을 검토하여 불필요한 권한이 남지 않았는지 확인합니다.

## 6. 리소스 이름 및 태그 규칙

리소스 이름은 `Mission-<Resource>` 형식으로 통일합니다.

| 항목 | 규칙 | 예시 |
|---|---|---|
| 프로젝트 | `Mission` | `Mission` |
| VPC | `Mission-VPC` | `Mission-VPC` |
| Subnet | `Mission-Public-Subnet` | `Mission-Public-Subnet` |
| IGW | `Mission-IGW` | `Mission-IGW` |
| Route Table | `Mission-RouteTable` | `Mission-RouteTable` |
| Security Group | `Mission-Web-SG` | `Mission-Web-SG` |
| EC2 | `Mission-Web-Server` | `Mission-Web-Server` |

태그는 다음 기준으로 관리합니다.

```text
Project = AWS-Web-Infrastructure
Environment = Practice
Owner = sonjehyun
Purpose = Web-Server
```

리소스를 생성할 때 이름과 태그를 함께 지정하면 AWS 콘솔과 CLI에서 리소스를 식별하고 정리하기 쉽습니다.

## 7. 장애 발생 시 점검 순서

외부에서 웹 서비스에 접근하지 못할 경우 아래 순서로 범위를 좁혀갑니다.

### 1단계 — Route Table

```powershell
aws ec2 describe-route-tables --route-table-ids <RT_ID> --region ap-northeast-2
```

확인:

- `0.0.0.0/0 → IGW` 존재 여부
- 해당 Route Table이 Public Subnet에 연결되어 있는지

### 2단계 — Security Group

```powershell
aws ec2 describe-security-groups --group-ids <SG_ID> --region ap-northeast-2
```

확인:

- TCP 80 인바운드 허용 여부
- SSH 22가 현재 관리자 IP를 허용하는지

### 3단계 — Public IP

```powershell
aws ec2 describe-instances --instance-ids <INSTANCE_ID> `
  --query "Reservations[0].Instances[0].PublicIpAddress" `
  --output text --region ap-northeast-2
```

확인:

- EC2가 Public Subnet에 존재하는지
- 퍼블릭 IP가 실제 접속 주소와 일치하는지
- 서브넷의 `map-public-ip-on-launch` 설정 여부

### 4단계 — 서버 내부

```bash
sudo systemctl status nginx
sudo ss -lntp | grep :80
curl -i http://localhost
curl -i http://localhost/health
```

필요한 경우:

```bash
sudo tail -n 50 /var/log/cloud-init-output.log
```

이 순서로 네트워크 경로 → 접근 제어 → 주소 → 서버 프로세스 순으로 확인하면 문제 발생 지점을 빠르게 좁힐 수 있습니다.

## 8. 아키텍처 확장 및 비용 관리

현재 구성은 단일 EC2 기반의 실습용 웹 서비스입니다. 사용량이 증가하거나 단일 인스턴스가 병목이 되는 경우 다음과 같이 확장할 수 있습니다.

### 병목 확인

다음 지표를 먼저 확인합니다.

- EC2 CPU 사용률
- 메모리 사용량
- 네트워크 트래픽
- Nginx 응답 지연
- HTTP 4xx/5xx 발생량
- 동시 접속량

CloudWatch에서 CPU 및 네트워크 지표를 확인하고, Nginx 로그에서 응답 시간과 오류 발생 여부를 함께 확인합니다.

### ALB 도입 기준

다음 상황에서는 Application Load Balancer(ALB)를 고려할 수 있습니다.

```text
단일 EC2의 처리량 부족
        ↓
EC2 여러 대로 확장
        ↓
ALB가 외부 요청 분산
        ↓
Target Group Health Check
        ↓
정상 인스턴스로 요청 전달
```

ALB를 도입하면 여러 EC2에 요청을 분산하고 비정상 인스턴스를 대상에서 제외하는 구조로 확장할 수 있습니다.

### 비용 추적

실습 종료 후에는 사용하지 않는 EC2, EBS, Elastic IP 등의 잔여 리소스를 확인합니다.

```text
AWS Billing & Cost Management
        ↓
Cost / Bills 확인
        ↓
미사용 리소스 확인
        ↓
EC2 / EBS / EIP / 기타 리소스 정리
```

특히 Elastic IP를 별도로 할당한 경우에는 인스턴스 종료와 별개로 주소가 남아 있는지 확인하고, 미사용 Elastic IP는 반드시 Release합니다.

## 9. 트러블슈팅

실제 구축 과정에서 다음 문제를 확인하고 해결했습니다.

### IAM/SCP 권한 거부

`UnauthorizedOperation` 및 상위 SCP의 `explicit deny`가 발생하여 VPC 생성이 차단되었습니다.

```bash
aws sts get-caller-identity
aws ec2 describe-vpcs
```

현재 계정의 IAM 자격 증명과 상위 조직 정책의 영향을 확인한 뒤 독립된 실습 계정으로 전환하여 구축을 진행했습니다.

### EC2 초기 부팅 및 Nginx 설치 지연

EC2가 `running` 상태이고 HTTP 80이 허용되어 있었지만 외부 접속이 되지 않는 문제가 발생했습니다.

```bash
sudo systemctl status nginx
tail -n 50 /var/log/cloud-init-output.log
```

Nginx가 설치되지 않은 것을 확인하고 패키지 락으로 인한 UserData 지연 가능성을 확인했습니다.

```bash
sudo apt-get update -y
sudo apt-get install -y nginx
sudo systemctl restart nginx
```

이후 `/health` 및 메인 페이지에서 HTTP 200 응답을 확인했습니다.

## 10. 리소스 정리

실습 종료 후 다음 순서로 리소스를 정리합니다.

```text
EC2 종료
  ↓
Key Pair / Security Group 확인 및 정리
  ↓
Route Table 연결 해제 및 삭제
  ↓
Internet Gateway Detach / 삭제
  ↓
Public Subnet 삭제
  ↓
VPC 삭제
  ↓
EIP 사용 여부 확인 및 미사용 EIP Release
  ↓
Billing / Cost 확인
```

현재 실습에서는 별도의 Elastic IP를 사용하지 않은 경우에도 마지막 단계에서 EIP 목록을 확인하여 잔여 주소가 없는지 검증합니다.

## 11. 제출 산출물

- `README.md` — 전체 구성 및 검증 결과
- `LEARNING_GUIDE.md` — AWS 네트워크/보안 학습 가이드
- `docs/architecture-spec.md` — 아키텍처 상세 분석
- `docs/troubleshooting.md` — 실제 장애 해결 과정
- `docs/cleanup-checklist.md` — 리소스 삭제 및 비용 확인
- `docs/images/architecture.png` — 시스템 아키텍처 다이어그램
