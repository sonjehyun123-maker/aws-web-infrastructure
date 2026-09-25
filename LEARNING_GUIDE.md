# AWS 클라우드 및 AI API 기초: 웹 인프라 구축 학습 가이드

본 가이드는 AWS 프리티어 환경에서 VPC, Subnet, Internet Gateway, Security Group, EC2 인스턴스를 구축하고 Nginx 웹 서버를 외부로 제공하는 과정을 체계적으로 정리한 학습 문서입니다.

---

## 📌 1. 학습 목표 및 질문 (Checklist)
본 실습을 마친 후 학습자는 다음 5가지 질문에 논리적으로 답변할 수 있어야 합니다.

1. **VPC, Subnet, Route Table, Internet Gateway**가 각각 어떤 역할을 하며 external traffic이 EC2까지 도달하는 전체 패킷 흐름은 무엇인가?
2. **Security Group(인프라 방화벽)**과 **IAM(API 권한 제어)**의 역할 차이는 무엇이며, 최소 권한 원칙(Least Privilege)을 왜/어떻게 적용해야 하는가?
3. 외부 요청이 EC2의 웹 서버까지 도달하기 위해 필요한 3가지 핵심 설정(라우팅, 퍼블릭 IP, 보안 그룹)의 관계는 무엇인가?
4. 오류 발생 시 로그/증상을 근거로 원인을 가설화하고 조치하는 **트러블슈팅 6단계 절차**는 어떻게 진행되는가?
5. 클라우드 과금이 발생하는 대표 요인은 무엇이며, **리소스 정리 의존성 순서**와 이유는 무엇인가?

---

## 🏗️ 2. 네트워크 및 보안 아키텍처 이론

### 2.1 네트워크 구성 요소의 역할
- **VPC (Virtual Private Cloud)**: AWS 계정 내 논리적으로 격리된 가상 네트워크 공간 (`10.0.0.0/16`)
- **Public Subnet**: 인터넷 접속이 가능한 서브넷 공간 (`10.0.1.0/24`). EC2 생성 시 퍼블릭 IP(Public IP) 자동 할당 설정 필수.
- **Internet Gateway (IGW)**: VPC와 전 세계 인터넷망 간의 트래픽 통로 역할을 수행하는 게이트웨이 리소스.
- **Route Table (라우팅 테이블)**: 서브넷에서 외부로 나가는 트래픽의 이정표. `0.0.0.0/0`(모든 외부 IP) 경로의 Target을 `IGW`로 등록하여 Public Subnet의 라우팅을 완성.

### 2.2 패킷 이동 흐름 (Traffic Flow)
```text
외부 사용자 (Browser / curl)
    │
    ▼ (http://3.34.42.120:80)
[Internet Gateway (igw-08725917d1b9eb4b0)]
    │
    ▼ (Route Table: 0.0.0.0/0 -> IGW)
[Public Subnet (10.0.1.0/24)]
    │
    ▼ (Security Group: Inbound Port 80 Allow)
[EC2 Instance (Mission-Web-Server)]
    │
    ▼ (Nginx Web Server)
응답 반환: 200 OK / "OK"
```

### 2.3 Security Group vs IAM 비교
| 구분 | Security Group (보안 그룹) | IAM (Identity & Access Management) |
| :--- | :--- | :--- |
| **적용 대상** | 네트워크 패킷 / 인스턴스 (EC2, RDS 등) | 사용자(User), 그룹(Group), 역할(Role), API 호출 |
| **주요 역할** | Stateful 방화벽 (포트 및 IP 대역 단위 허용) | AWS 리소스 생성/조회/수정/삭제 권한 Control |
| **최소 권한 설정**| HTTP(80) 0.0.0.0/0 허용, SSH(22) 내 IP만 허용 | AdministratorAccess 금지, `AmazonEC2FullAccess` 한정 |

---

## 💻 3. AWS CLI 구축 스크립트 가이드

```powershell
# 1. 퍼블릭 IP 확인
$MY_IP = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim() + "/32"

# 2. VPC 생성 (10.0.0.0/16)
$VPC_ID = (aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region ap-northeast-2 --query 'Vpc.VpcId' --output text)

# 3. Public Subnet 생성 및 퍼블릭 IP 자동할당 켜기
$SUBNET_ID = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ap-northeast-2a --region ap-northeast-2 --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region ap-northeast-2

# 4. Internet Gateway 생성 및 VPC 연결
$IGW_ID = (aws ec2 create-internet-gateway --region ap-northeast-2 --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region ap-northeast-2

# 5. Route Table 생성 및 0.0.0.0/0 -> IGW 경로 등록 후 Subnet 연결
$RT_ID = (aws ec2 create-route-table --vpc-id $VPC_ID --region ap-northeast-2 --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region ap-northeast-2
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID --region ap-northeast-2

# 6. Security Group 생성 (HTTP 80 전세계 / SSH 22 내 IP)
$SG_ID = (aws ec2 create-security-group --group-name Mission-Web-SG --description "SG for Web Server" --vpc-id $VPC_ID --region ap-northeast-2 --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region ap-northeast-2
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $MY_IP --region ap-northeast-2

# 7. EC2 인스턴스 (t3.micro, Ubuntu 22.04 LTS) 실행
aws ec2 run-instances --image-id ami-0621cf8f7a0902253 --count 1 --instance-type t3.micro --key-name mission-key --security-group-ids $SG_ID --subnet-id $SUBNET_ID --user-data fileb://user-data.sh --region ap-northeast-2
```

---

## 🛠️ 4. 트러블슈팅 프레임워크 (6단계)

실습 중 발생한 모든 문제는 다음 6단계 프레임워크에 따라 문서화하고 분석합니다:
1. **증상 (Symptom)**: 문제 발생 현상 (예: SSH 접속 불가, HTTP 타임아웃, SCP 권한 오류 등)
2. **원인 가설 (Hypothesis)**: 보안 그룹 포트 미개방, IGW 라우팅 누락, 부팅 백그라운드 락 등 추정
3. **검증 방법 (Verification)**: CLI `describe` 명령, SSH 접속 후 systemctl 및 `/var/log/cloud-init-output.log` 로그 확인
4. **조치 내용 (Remediation)**: 보안 그룹 수정, 라우팅 추가, Nginx 재시작 등 실행
5. **결과 (Outcome)**: `200 OK` 또는 접속 성공 확인
6. **재발 방지 (Prevention)**: 체크리스트 반영 및 자동화 스크립트 보완

---

## 🧹 5. 자원 의존성에 따른 리소스 정리 절차 (Cleanup)

리소스 삭제 시 **의존성 (Dependency Violation)** 오류를 방지하기 위해 다음 순서로 삭제해야 합니다:

1. **EC2 Instance Terminate**: 인스턴스를 먼저 종료해야 연결된 Elastic IP/보안그룹 해제 가능.
2. **Security Group & Key Pair 삭제**: EC2 종료 완료 후 삭제 가능.
3. **Route Table & Internet Gateway Detach/삭제**: IGW를 VPC에서 Detach해야 VPC 삭제 가능.
4. **Subnet & VPC 삭제**: VPC 내부의 Subnet이 모두 제거된 후 최종 VPC 삭제 가능.
