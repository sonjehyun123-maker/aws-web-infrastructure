# AWS 클라우드 및 웹 인프라 구축 학습 가이드

본 문서는 AWS(Amazon Web Services) 환경에서 VPC 네트워크 기반 구조를 설계하고 가상 서버(EC2)에 웹 서비스를 배포하는 과정에서 필요한 핵심 개념, 트래픽 흐름, 보안 원칙, 구축 절차 및 트러블슈팅 방법을 설명하는 학습 가이드입니다.

---

## 1. 학습 목표 및 핵심 검증 항목

본 실습을 마친 학습자는 아래 5가지 질문에 대해 기술적으로 명확하게 설명할 수 있어야 합니다.

1. **네트워크 기본 구성요소의 역할과 패킷 흐름**
   - VPC, Subnet, Route Table, Internet Gateway가 각각 어떤 역할을 수행하며, 외부 인터넷 사용자의 요청이 EC2 인스턴스의 Nginx 웹 서버까지 도달하는 통신 경로를 설명할 수 있는가?
2. **보안 그룹(Security Group)과 IAM의 차이점 및 최소 권한 원칙**
   - 인프라 수준의 방화벽인 보안 그룹과 계정/API 수준의 권한 관리 도구인 IAM의 차이를 설명하고, 왜 SSH(22번 포트)는 특정 IP로 제한해야 하고 IAM 권한은 필요한 최소 범위로 제약해야 하는지 설명할 수 있는가?
3. **외부 접속 허용을 위한 3대 필요조건**
   - 외부 요청이 서버에 도달하기 위해 필요한 퍼블릭 IP 할당, 라우팅 테이블의 IGW 경로 설정, 보안 그룹의 인바운드 허용 규칙 간의 상호 관계를 설명할 수 있는가?
4. **체계적인 트러블슈팅 절차**
   - 장애 발생 시 수집된 로그와 오류 증상을 기반으로 원인을 가설화하고, 단계별로 검증 및 조치하는 트러블슈팅 프레임워크(증상 → 가설 → 검증 → 조치 → 결과 → 재발방지)를 적용할 수 있는가?
5. **클라우드 자원 관리 및 과금 방지 리소스 정리**
   - 클라우드에서 비용이 발생하는 대표적 요인을 이해하고, 리소스 간 의존성 관계에 맞춰 안전하게 자원을 삭제하는 순서와 이유를 설명할 수 있는가?

---

## 2. 네트워크 및 보안 아키텍처 이론

### 2.1 네트워크 핵심 리소스
- **VPC (Virtual Private Cloud)**
  - AWS 계정 내에서 논리적으로 완전하게 격리된 사용자 전용 가상 네트워크 공간입니다. 본 실습에서는 `10.0.0.0/16` CIDR 대역을 할당하여 구축하였습니다.
- **Public Subnet (공용 서브넷)**
  - VPC 내부에서 외부 인터넷과의 직접적인 통신이 가능하도록 배치된 서브넷 영역입니다. EC2 생성 시 외부 접속용 퍼블릭 IPv4 주소를 자동으로 할당받도록 설정합니다. 본 실습 대역은 `10.0.1.0/24`입니다.
- **Internet Gateway (IGW)**
  - VPC 내부의 리소스와 외부 인터넷 망을 연결하는 수평 확장형 관문입니다. VPC에 결합(Attach)되어 수신 및 발신 트래픽의 NAT 및 라우팅 주소 변환을 담당합니다.
- **Route Table (라우팅 테이블)**
  - 서브넷에서 발생하는 네트워크 트래픽이 이동할 다음 목적지(Next Hop)를 지정하는 테이블입니다. 외부 인터넷으로 향하는 모든 트래픽(`0.0.0.0/0`)의 타겟을 Internet Gateway로 지정하여 Public Subnet의 속성을 부여합니다.

### 2.2 트래픽 이동 경로 (Network Packet Flow)

외부 사용자가 브라우저를 통해 웹 서비스에 접속할 때 발생 패킷 이동 순서는 다음과 같습니다.

1. **클라이언트 요청 발생**: 외부 사용자가 HTTP 프로토콜을 통해 `http://3.34.42.120:80` 주소로 TCP 접속 요청을 전송합니다.
2. **Internet Gateway 수신**: 요청 패킷이 AWS 계정의 VPC 경계에 도착하여 Internet Gateway(`igw-08725917d1b9eb4b0`)를 통과합니다.
3. **Route Table 검증**: 서브넷에 연동된 라우팅 테이블이 아웃바운드 및 응답 트래픽 경로(`0.0.0.0/0 -> IGW`)를 확인하고 패킷을 해당 Public Subnet으로 전달합니다.
4. **Security Group 필터링**: EC2 인스턴스에 적용된 보안 그룹(`sg-046612d8c8902fcae`)에서 출발지 IP와 목적지 포트(80번)가 인바운드 규칙에 맞는지 검증합니다.
5. **EC2 웹 서버 처리**: 인스턴스 내부의 커널을 지나 80번 포트를 바인딩하고 있는 Nginx 웹 서버 프로세스에 패킷이 전달되어 `200 OK` 응답을 생성 및 반환합니다.

### 2.3 Security Group과 IAM의 비교 분석

| 구분 | Security Group (보안 그룹) | IAM (Identity & Access Management) |
| :--- | :--- | :--- |
| **적용 범위** | 네트워크 인터페이스 (ENI), EC2 인스턴스 | 사용자 계정, 그룹, 역할(Role), AWS API 호출 |
| **작동 방식** | Stateful 방식의 방화벽 (인바운드 허용 시 반환 패킷 자동 허용) | Policy(JSON 문서) 기반의 명시적 Allow/Deny 평가 |
| **최소 권한 제어** | 필요한 포트 및 소스 IP 대역만 개방<br>(HTTP 80: 0.0.0.0/0, SSH 22: 특정 IP) | 과도한 권한(`AdministratorAccess`)을 배제하고 작업에 필요한 정책(`AmazonEC2FullAccess`)만 부여 |

---

## 3. AWS CLI를 활용한 Step-by-Step 구축 가이드

### 1단계: 퍼블릭 IP 확인 및 VPC / Subnet 생성
```powershell
# 1. 학습자 현재 컴퓨터의 외부 퍼블릭 IP 확인
$MY_IP = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim() + "/32"

# 2. VPC 생성 (CIDR: 10.0.0.0/16)
$VPC_ID = (aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region ap-northeast-2 --query 'Vpc.VpcId' --output text)

# 3. Public Subnet 생성 (CIDR: 10.0.1.0/24)
$SUBNET_ID = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ap-northeast-2a --region ap-northeast-2 --query 'Subnet.SubnetId' --output text)

# 4. 서브넷 생성 시 퍼블릭 IP 자동 할당 설정 활성화
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region ap-northeast-2
```

### 2단계: Internet Gateway 연결 및 라우팅 테이블 구성
```powershell
# 1. Internet Gateway 생성 및 VPC 결합
$IGW_ID = (aws ec2 create-internet-gateway --region ap-northeast-2 --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region ap-northeast-2

# 2. Route Table 생성
$RT_ID = (aws ec2 create-route-table --vpc-id $VPC_ID --region ap-northeast-2 --query 'RouteTable.RouteTableId' --output text)

# 3. 0.0.0.0/0 -> IGW 라우팅 규칙 추가
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region ap-northeast-2

# 4. Subnet에 Route Table 연결
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID --region ap-northeast-2
```

### 3단계: 보안 그룹 설정 및 EC2 인스턴스 배포
```powershell
# 1. Security Group 생성
$SG_ID = (aws ec2 create-security-group --group-name Mission-Web-SG --description "SG for Web Server" --vpc-id $VPC_ID --region ap-northeast-2 --query 'GroupId' --output text)

# 2. 인바운드 규칙 설정 (HTTP 80 전세계 허용, SSH 22 내 IP 제한)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region ap-northeast-2
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $MY_IP --region ap-northeast-2

# 3. UserData 스크립트 작성 및 EC2 인스턴스 실행
aws ec2 run-instances --image-id ami-0621cf8f7a0902253 --count 1 --instance-type t3.micro --key-name mission-key --security-group-ids $SG_ID --subnet-id $SUBNET_ID --user-data fileb://user-data.sh --region ap-northeast-2
```

---

## 4. 트러블슈팅 분석 사례 및 보고서 작성법

장애 또는 오류가 발생한 경우 다음과 같은 6단계 가설-검증 프레임워크를 적용하여 해결 과정을 기록합니다.

### 케이스 예시: EC2 부팅 시 패키지 매니저 백그라운드 락으로 인한 웹 서버 미작동
- **증상 (Symptom)**: 인스턴스가 `running` 상태이고 80번 포트 보안 그룹이 허용되어 있으나 `http://<퍼블릭IP>` 접속 시 연결 실패 발생.
- **원인 가설 (Hypothesis)**: Ubuntu 최신 AMI의 초기 부팅 과정에서 `unattended-upgrades` 프로세스가 작동하여 `apt-get` 락을 점유함에 따라 UserData의 Nginx 설치 과정이 대기 상태에 빠짐.
- **검증 방법 (Verification)**: SSH 접속 후 `/var/log/cloud-init-output.log` 로그 파일 및 `sudo systemctl status nginx` 상태 조회.
- **조치 내용 (Remediation)**: SSH 명령을 통해 Nginx 패키지를 수동으로 즉시 설치 및 재시작(`sudo systemctl restart nginx`).
- **결과 (Outcome)**: `http://<퍼블릭IP>` 및 `/health` 엔드포인트에서 `200 OK` 정상 응답 수신 확인.
- **재발 방지 (Prevention)**: 배포 스크립트에 패키지 설치 완료 여부를 검증하는 루틴을 포함시킴.

---

## 5. 자원 의존성에 따른 리소스 정리 절차

클라우드 자원은 상위 자원과 하위 자원 간에 의존성(Dependency)이 존재합니다. 따라서 삭제 시 반드시 아래 순서를 준수해야 오류(`DependencyViolation`) 없이 깔끔하게 정리할 수 있습니다.

1. **EC2 인스턴스 종결 (Terminate)**: 네트워크 인터페이스(ENI)를 사용 중인 컴퓨트 자원을 가장 먼저 종료해야 합니다.
2. **보안 그룹(Security Group) 및 키 페어 삭제**: EC2 종결이 완료된 후 연결된 보안 그룹을 삭제합니다.
3. **라우팅 테이블 및 인터넷 게이트웨이 분리/삭제**: 서브넷 연결을 해제하고 IGW를 VPC에서 Detach 한 후 삭제합니다.
4. **서브넷 및 VPC 삭제**: 내부의 모든 하위 자원이 제거되었음을 확인한 후 서브넷과 최종 VPC를 삭제합니다.
