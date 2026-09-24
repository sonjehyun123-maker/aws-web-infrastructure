# AWS 클라우드 및 AI API 기초: 웹 인프라 구축 학습 가이드

## 📌 1. 미션 개요 및 핵심 학습 목표
본 가이드는 AWS 환경에서 VPC, Subnet, Internet Gateway, Security Group, EC2 인스턴스를 CLI로 구축하고 Nginx 웹 서버를 외부로 제공하는 과정을 설명합니다.

### 학습자가 답할 수 있어야 하는 핵심 질문
1. **VPC, Subnet, Route Table, Internet Gateway**는 각각 어떤 역할을 하며 external traffic이 어떻게 EC2까지 도달하나요?
2. **Security Group(인프라 방화벽)**과 **IAM(권한 제어)**의 차이는 무엇이며, 최소 권한 원칙(Least Privilege)을 왜 적용해야 하나요?
3. 외부 접속(HTTP 80)에 필요한 라우팅 / 퍼블릭 IP / 보안그룹의 관계는 무엇인가요?
4. 오류 발생 시 원인을 가설화하고 조치하는 **트러블슈팅 절차**는 어떻게 진행되나요?
5. 클라우드 과금 발생 원인과 **안전한 리소스 정리 순서**는 무엇인가요?

---

## 🏗️ 2. 네트워크 및 보안 아키텍처 이론

### 2.1 네트워크 구성 요소
- **VPC (Virtual Private Cloud)**: AWS 내 독립된 가상 네트워크 (예: `10.0.0.0/16`)
- **Public Subnet**: 인터넷과 직접 통신이 가능한 서브넷 (예: `10.0.1.0/24`)
- **Internet Gateway (IGW)**: VPC와 인터넷 간의 통신 통로
- **Route Table**: 서브넷의 아웃바운드 트래픽 목적지 라우팅 규칙 (`0.0.0.0/0 -> IGW`)

### 2.2 Security Group vs IAM
| 구분 | Security Group (보안 그룹) | IAM (Identity & Access Management) |
| :--- | :--- | :--- |
| **대상** | 네트워크 / 인스턴스 (EC2, RDS 등) | 사용자, 그룹, 역할(Role), API 호출 |
| **역할** | Inbound/Outbound 패킷 포트 허용 (Stateful) | AWS 리소스 생성/조회/수정/삭제 권한 지정 |
| **원칙** | 필요 포트만 개방 (HTTP 80: 전체 / SSH 22: 내 IP) | 최소 권한 원칙 (AdministratorAccess 금지) |

---

## 💻 3. AWS CLI를 활용한 인프라 구축 실습

### 3.1 1단계: VPC 및 IGW 생성
```bash
# 1. VPC 생성 (10.0.0.0/16)
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region ap-northeast-2 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=My-Learning-VPC --region ap-northeast-2

# 2. Public Subnet 생성 (10.0.1.0/24)
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ap-northeast-2a --region ap-northeast-2 --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region ap-northeast-2

# 3. Internet Gateway 생성 및 VPC 연결
IGW_ID=$(aws ec2 create-internet-gateway --region ap-northeast-2 --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region ap-northeast-2
```

### 3.2 2단계: Route Table 생성 및 0.0.0.0/0 라우팅 지정
```bash
# 1. Route Table 생성
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region ap-northeast-2 --query 'RouteTable.RouteTableId' --output text)

# 2. 0.0.0.0/0 -> IGW 경로 추가
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region ap-northeast-2

# 3. Subnet에 Route Table 연결
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID --region ap-northeast-2
```

### 3.3 3단계: Security Group 생성 (최소 권한 포트 설정)
```bash
# 1. 내 퍼블릭 IP 확인
MY_IP=$(curl -s https://checkip.amazonaws.com)/32

# 2. Security Group 생성
SG_ID=$(aws ec2 create-security-group --group-name Web-SG --description "SG for Web Server" --vpc-id $VPC_ID --region ap-northeast-2 --query 'GroupId' --output text)

# 3. HTTP(80) 0.0.0.0/0 허용
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region ap-northeast-2

# 4. SSH(22) 내 IP만 허용
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $MY_IP --region ap-northeast-2
```

### 3.4 4단계: EC2 생성 및 Nginx 웹서버 자동 배포
```bash
# Ubuntu 22.04 LTS 최신 AMI 조회
AMI_ID=$(aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text --region ap-northeast-2)

# Nginx 자동 설치 script
cat << 'EOF' > user-data.sh
#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
echo "<h1>Welcome to My AWS Web Server</h1><p>Status: 200 OK</p>" > /var/www/html/index.html
EOF

# EC2 인스턴스 생성 (t2.micro 또는 t3.micro)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type t3.micro \
  --key-name MyKeyPair \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=My-Web-Server}]' \
  --region ap-northeast-2 \
  --query 'Instances[0].InstanceId' --output text)

# Public IP 조회
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region ap-northeast-2)
echo "Public IP: http://$PUBLIC_IP"
```

---

## 🛠️ 4. 트러블슈팅 케이스 연구

| 문제 상황 | 원인 | 검증 방법 | 해결 조치 |
| :--- | :--- | :--- | :--- |
| SSH 접속 타임아웃 (`Connection timed out`) | Security Group 22번 포트 미개방 또는 Route Table IGW 미연결 | `aws ec2 describe-security-groups`, `aws ec2 describe-route-tables` 확인 | SG에 내 IP 허용 추가, RT에 0.0.0.0/0 -> IGW 추가 |
| HTTP 80 타임아웃 / 접속 불가 | Nginx 서비스 미실행 또는 SG 80 포트 미허용 | SSH 접속 후 `systemctl status nginx`, SG 규칙 조회 | Nginx 재시작 (`sudo systemctl restart nginx`), SG 80 포트 개방 |
| EC2 외부 인터넷 안 됨 (curl 실패) | Subnet에 Public IP 자동 할당 비활성화 또는 Route Table 설정 오류 | 인스턴스 내부에서 `curl -I https://example.com` | Route Table IGW 라우팅 등록 |

---

## 🧹 5. 과금 방지를 위한 리소스 정리 순서

삭제는 **생성의 역순(의존성 순서)**으로 진행해야 오류가 발생하지 않습니다:

1. **EC2 Instance Termination**: `aws ec2 terminate-instances --instance-ids $INSTANCE_ID`
2. **Security Group Deletion**: `aws ec2 delete-security-group --group-id $SG_ID`
3. **Route Table & IGW Detach**: IGW 디태치 후 IGW 및 Route Table 삭제
4. **Subnet & VPC Deletion**: `aws ec2 delete-subnet`, `aws ec2 delete-vpc`
