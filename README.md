# AWS 웹 서비스 인프라 구축 및 외부 서비스 제공 프로젝트

본 프로젝트는 Amazon Web Services(AWS) 환경에서 VPC 네트워크 기반 구조를 직접 설계하고, 가상 컴퓨팅 인스턴스(EC2)에 Nginx 웹 서버를 배포하여 외부 인터넷망에서 접속 가능한 웹 서비스를 안정적으로 구성하고 검증한 과제 수행 기록입니다.

---

## 1. 개요 및 구성 목적

클라우드 환경은 단순히 가상 서버를 생성하는 것을 넘어 네트워크 경계 분리(VPC), 인터넷 관문 연결(Internet Gateway), 라우팅 경로 설정(Route Table), 그리고 최소 권한 기반의 접근 제어(Security Group 및 IAM)가 유기적으로 결합된 시스템입니다. 

본 과제에서는 다음과 같은 목표를 달성하였습니다.
- VPC를 이용한 독립적 네트워크 공간 분리 및 Public Subnet 환경 구성
- 외부 인터넷과의 아웃바운드/인바운드 통신을 지원하는 Internet Gateway 및 라우팅 테이블 연결
- SSH(22번 포트)는 작성자 개인 IP 대역으로 한정하고, HTTP(80번 포트)는 전 세계에 개방하는 보안 그룹(Security Group) 규칙 설정
- EC2 인스턴스 배포 및 Nginx 웹 서버 자동화를 통한 서비스 정상 작동 검증
- 실습 완료 후 비용 과금을 방지하기 위한 안전한 리소스 정리 절차 수행

---

## 2. 외부 접속 검증 결과

외부 인터넷망에서 본 인스턴스의 퍼블릭 IP로 요청을 전송하여 웹 서버가 정상 작동함을 확인하였습니다.

- **선택한 검증 방식**: 
  - 방식 (A): 웹 브라우저를 통한 `http://3.34.42.120` 접속 및 Nginx 웰컴 페이지 수신 확인 (응답 코드: 200 OK)
  - 방식 (B): GET `http://3.34.42.120/health` 헬스 체크 엔드포인트 호출 및 "OK" 고정 응답 수신 확인 (응답 코드: 200 OK)
- **배포 인스턴스 퍼블릭 IP**: `3.34.42.120`

### 외부 접속 증빙 스크린샷

#### (A) 웹 서비스 메인 화면 접속 검증 (http://3.34.42.120)
![외부 웹 접속 증빙](./docs/proof-web.png)

#### (B) 헬스 체크 엔드포인트 응답 검증 (http://3.34.42.120/health)
![헬스 체크 증빙](./docs/proof-health.png)

---

## 3. 구축된 AWS 인프라 리소스 상세 명세

| 구분 | 리소스 이름 및 식별자 (Resource ID) | IPv4 CIDR 및 IP 주소 | 주요 기능 및 설정 상세 |
| :--- | :--- | :--- | :--- |
| **VPC** | `Mission-VPC`<br>(`vpc-00dc9a5671c96f5c5`) | `10.0.0.0/16` | 서울 리전(ap-northeast-2) 내에 생성된 독립 가상 네트워크 |
| **Public Subnet** | `Mission-Public-Subnet`<br>(`subnet-0a319c0f06c2b88cc`) | `10.0.1.0/24` | 외부 통신용 서브넷. 퍼블릭 IPv4 자동 할당옵션 활성화 |
| **Internet Gateway**| `Mission-IGW`<br>(`igw-08725917d1b9eb4b0`) | - | Mission-VPC와 외부 인터넷망을 연결하는 관문 |
| **Route Table** | `Mission-RouteTable`<br>(`rtb-04591059288768592`) | `0.0.0.0/0 -> IGW` | Public Subnet과 명시적으로 연결되어 외부 트래픽을 IGW로 라우팅 |
| **Security Group** | `Mission-Web-SG`<br>(`sg-046612d8c8902fcae`) | - | 인바운드: HTTP(80) `0.0.0.0/0`, SSH(22) `211.209.211.121/32` 제한 |
| **EC2 Instance** | `Mission-Web-Server`<br>(`i-0760f0f6d6352c5ed`) | 퍼블릭: `3.34.42.120`<br>사설: `10.0.1.172` | `t3.micro` (Ubuntu 22.04 LTS), UserData로 Nginx 자동 배포 |

---

## 4. 시스템 아키텍처 다이어그램

본 인프라의 트러블 통신 흐름과 리소스 배치 구조는 다음과 같습니다.

![아키텍처 다이어그램](./docs/architecture.png)

### 트래픽 흐름 설명
1. **외부 클라이언트 요청**: 외부 사용자가 브라우저 또는 cURL을 통해 `http://3.34.42.120:80`으로 접근을 시도합니다.
2. **Internet Gateway 통과**: 요청 패킷이 VPC 경계에 위치한 Internet Gateway(`igw-08725917d1b9eb4b0`)를 지나 수신됩니다.
3. **Route Table 라우팅**: 서브넷에 연동된 라우팅 테이블(`rtb-04591059288768592`)의 규칙에 따라 `0.0.0.0/0` 트래픽이 Public Subnet으로 전달됩니다.
4. **Security Group 검증**: 인스턴스 앞단의 보안 그룹(`sg-046612d8c8902fcae`)에서 80번 포트에 대한 접근 허용 여부를 검증합니다.
5. **EC2 Nginx 응답**: EC2 인스턴스(`i-0760f0f6d6352c5ed`) 내부에서 작동 중인 Nginx 프로세스가 요청을 받아 `HTTP 200 OK` 응답을 클라이언트로 반환합니다.

---

## 5. 단계별 AWS 콘솔 구성 증빙 갤러리

### 1) VPC 생성 결과 화면
![VPC 구성](./docs/aws-vpc.png)

### 2) Public Subnet 구성 화면
![Subnet 구성](./docs/aws-subnet.png)

### 3) Internet Gateway 연결 상태 화면
![IGW 구성](./docs/aws-igw.png)

### 4) Route Table 라우팅 경로 설정 화면
![Route Table 구성](./docs/aws-routetable.png)

### 5) EC2 인스턴스 실행 및 상태 검사 화면
![EC2 구성](./docs/aws-ec2.png)

---

## 6. 제출 산출물 문서 안내

프로젝트 폴더 내에 포함된 세부 산출물 문서 목록입니다.

- **학습 가이드 문서**: [`LEARNING_GUIDE.md`](./LEARNING_GUIDE.md) (네트워크/보안 개념, 패킷 흐름, 구축 절차 정리)
- **아키텍처 문서**: [`docs/architecture.png`](./docs/architecture.png) (시스템 아키텍처 다이어그램 이미지)
- **트러블슈팅 보고서**: [`docs/troubleshooting.md`](./docs/troubleshooting.md) (SCP 권한 거부 및 부팅 락 장애 해결 보고서)
- **리소스 정리 체크리스트**: [`docs/cleanup-checklist.md`](./docs/cleanup-checklist.md) (과금 방지를 위한 리소스 삭제 완료 증빙 및 절차)

---

## 7. 실습 리소스 정리 및 삭제 완료 보고

과제 실습을 모두 마치고 외부 접속 검증과 증빙 작성을 완료한 후, 미사용 리소스로 인한 비용 과금을 방지하기 위해 생성하였던 모든 인프라 자원에 대해 삭제 및 해제 작업을 수행하였습니다.

- **EC2 인스턴스 (`i-0760f0f6d6352c5ed`)**: `Terminated` (인스턴스 종결 처리 완료)
- **SSH 키 페어 (`mission-key`)**: Key Pair 삭제 완료
- **보안 그룹 (`sg-046612d8c8902fcae`)**: Security Group 삭제 완료
- **라우팅 테이블 (`rtb-04591059288768592`)**: Route Table 삭제 완료
- **인터넷 게이트웨이 (`igw-08725917d1b9eb4b0`)**: VPC에서 Detach 후 IGW 삭제 완료
- **서브넷 (`subnet-0a319c0f06c2b88cc`)**: Public Subnet 삭제 완료
- **VPC (`vpc-00dc9a5671c96f5c5`)**: VPC 최종 삭제 완료 (`aws ec2 describe-vpcs` 조회를 통해 잔여 리소스가 없음을 확인)
