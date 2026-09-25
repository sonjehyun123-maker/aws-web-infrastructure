# AWS 웹 서비스 인프라 구축 프로젝트

본 프로젝트는 AWS 프리티어 환경에서 VPC, Subnet, Internet Gateway, Security Group 및 EC2(Nginx) 기반의 기본 웹 인프라를 구축하고 외부 접속을 검증한 결과를 담고 있습니다.

## 1. 외부 접속 증빙
- **접속 검증 방식**:
  - (A) 브라우저 접속: `http://3.34.42.120` ➔ `200 OK`
  - (B) GET /health 호출: `http://3.34.42.120/health` ➔ `OK` (200 OK)
- **접속 URL / 퍼블릭 IP**: `http://3.34.42.120`

### 📸 접속 증빙 스크린샷
#### (A) 웹 서비스 메인 접속 (`http://3.34.42.120`)
![외부 웹 접속 증빙](./docs/proof-web.png)

#### (B) 헬스 체크 응답 (`http://3.34.42.120/health`)
![헬스 체크 증빙](./docs/proof-health.png)

---

## 2. 제출 문서 목록
- 📘 [학습 가이드 문서](./LEARNING_GUIDE.md)
- 📐 [아키텍처 다이어그램](./docs/architecture.html)
- 🛠️ [트러블슈팅 보고서](./docs/troubleshooting.md)
- 🧹 [리소스 정리 체크리스트](./docs/cleanup-checklist.md)

---

## 🏗️ 3. AWS 구성 요소 요약

| 구성 요소 | Resource ID | IPv4 CIDR / IP | 주요 설정 |
| :--- | :--- | :--- | :--- |
| **VPC** | `vpc-00dc9a5671c96f5c5` | `10.0.0.0/16` | Mission-VPC (서울 리전 `ap-northeast-2`) |
| **Public Subnet** | `subnet-0a319c0f06c2b88cc` | `10.0.1.0/24` | 퍼블릭 IP 자동 할당 활성화 |
| **Internet Gateway**| `igw-08725917d1b9eb4b0` | - | Mission-VPC에 Attached |
| **Route Table** | `rtb-04591059288768592` | `0.0.0.0/0 -> IGW` | Public Subnet과 연결 완료 |
| **Security Group** | `sg-046612d8c8902fcae` | - | Inbound: HTTP(80) `0.0.0.0/0`, SSH(22) `211.209.211.121/32` |
| **EC2 Instance** | `i-0760f0f6d6352c5ed` | `3.34.42.120` | `t3.micro` (Ubuntu 22.04 LTS), Nginx Web Server |

---

## 📸 4. AWS 구축 증빙 스크린샷 갤러리

### 1) VPC 생성 증빙 (`Mission-VPC`)
![VPC 구성](./docs/aws-vpc.png)

### 2) Public Subnet 증빙 (`Mission-Public-Subnet`)
![Subnet 구성](./docs/aws-subnet.png)

### 3) Internet Gateway 연결 증빙 (`Mission-IGW`)
![IGW 구성](./docs/aws-igw.png)

### 4) Route Table 0.0.0.0/0 라우팅 증빙 (`Mission-RouteTable`)
![Route Table 구성](./docs/aws-routetable.png)

### 5) EC2 인스턴스 실행 증빙 (`Mission-Web-Server`)
![EC2 구성](./docs/aws-ec2.png)
