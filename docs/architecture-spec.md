# AWS 웹 서비스 시스템 아키텍처 상세 분석서

본 문서는 AWS(Amazon Web Services) 환경에 구축된 웹 인프라 시스템 아키텍처 다이어그램을 기반으로, 각 네트워크 리소스의 역할, 보안 경계 설정, 컴퓨팅 스펙, 그리고 외부 요청 패킷이 전달되는 전체 이동 경로를 종합적으로 분석하고 기술한 상세 설명서입니다.

---

## 1. 아키텍처 전체 구성 개요

본 인프라는 외부 인터넷 망과 격리된 사용자 전용 가상 네트워크(VPC)를 기반으로, 외부 접속이 필요한 웹 서비스 리소스만을 선택적으로 공개하는 서브넷 및 방화벽 구조로 설계되었습니다.

![아키텍처 다이어그램](./images/architecture.png)

---

## 2. 외부 트래픽 및 네트워크 관문 (External Traffic & Network Boundary)
### 2.1 외부 사용자 및 트래픽 (Internet Users / Clients)
- **접속 목적**: 전 세계 인터넷 사용자가 서비스 이용을 위해 웹 서비스(HTTP 80번 포트)에 접속하거나, 인프라 관리자가 서버 유지보수를 위해 SSH(22번 포트) 원격 접속을 시도합니다.
- **통신 프로토콜**: TCP/IP 기반의 HTTP(80) 및 SSH(22) 프로토콜을 사용합니다.

### 2.2 독립 가상 네트워크 (Mission-VPC)
- **VPC 식별자**: `vpc-00dc9a5671c96f5c5` (이름: `Mission-VPC`)
- **배치 리전**: AWS 한국 서울 리전 (`ap-northeast-2`)
- **IP 대역 (CIDR)**: `10.0.0.0/16` (총 65,536개의 사설 IP 주소 공간 확보)
- **역할**: 클라우드 상에서 다른 사용자의 네트워크와 물리적·논리적으로 완전하게 분리된 독립 가상 네트워크 통신 공간을 제공합니다.
### 2.3 인터넷 관문 (Internet Gateway, IGW)
- **IGW 식별자**: `igw-08725917d1b9eb4b0` (이름: `Mission-IGW`)
- **연결 상태**: `Mission-VPC`에 결합(Attached) 완료
- **역할**: VPC 내부의 사설 IP 주소와 외부 인터넷 IPv4 주소 간의 네트워크 주소 변환(NAT) 및 트래픽 통로 역할을 수행하여, 내부 리소스가 외부 인터넷과 아웃바운드/인바운드 통신을 가능하게 만듭니다.
### 2.4 라우팅 테이블 (Route Table)
- **Route Table 식별자**: `rtb-04591059288768592` (이름: `Mission-RouteTable`)
- **라우팅 규칙 (Routes)**:
  - `10.0.0.0/16` -> `local` (VPC 내부 리소스 간 사설 통신)
  - `0.0.0.0/0` -> `igw-08725917d1b9eb4b0` (모든 외부 인터넷 향 트래픽을 IGW로 전달)
- **역할**: 서브넷 내부에서 발생하는 트래픽 중 외부 인터넷망(`0.0.0.0/0`)으로 향하는 모든 요청을 Internet Gateway로 정확히 이정표(Next Hop)를 제시해 줌으로써 해당 서브넷에 'Public Subnet'의 속성을 부여합니다.

---

## 3. 서브넷 및 보안 격리 (Subnet & Security Isolation)
### 3.1 퍼블릭 서브넷 (Public Subnet)
- **Subnet 식별자**: `subnet-0a319c0f06c2b88cc` (이름: `Mission-Public-Subnet`)
- **가용 영역 (AZ)**: `ap-northeast-2a` (서울 리전 2a 가용 영역)
- **IP 대역 (CIDR)**: `10.0.1.0/24` (총 256개의 사설 IP 주소 공간)
- **속성**: 퍼블릭 IPv4 자동 할당 기능(`map-public-ip-on-launch`)이 활성화되어 있어, 인스턴스 배치 시 전 세계에서 접근 가능한 고유 퍼블릭 IP가 자동으로 부여됩니다.
### 3.2 보안 그룹 (Security Group - 가상 방화벽)
- **SG 식별자**: `sg-046612d8c8902fcae` (이름: `Mission-Web-SG`)
- **역할**: EC2 인스턴스 바로 앞단에서 상태 유지(Stateful) 인바운드 및 아웃바운드 패킷 흐름을 검증하는 L4 인프라 방화벽입니다.
#### 인바운드 접근 제어 규칙 (Inbound Rules)
1. **HTTP 서비스 포트 (TCP 80)**:
   - **허용 소스 (Source)**: `0.0.0.0/0` (전 세계 모든 IP 대역)
   - **설정 목적**: 웹 서비스를 누구나 이용할 수 있도록 불특정 다수에게 80번 웹 포트를 전체 개방합니다.
2. **SSH 관리 포트 (TCP 22)**:
   - **허용 소스 (Source)**: `211.209.211.121/32` (관리자 고유 IP 주소 한정)
   - **설정 목적**: 무차별 대입 공격(Brute Force)이나 해킹 시도를 차단하기 위하여 오직 지정된 관리자의 단일 IP 주소에서만 터미널 접속이 가능하도록 엄격한 최소 권한을 적용합니다.
#### 아웃바운드 규칙 (Outbound Rules)
- **허용 트래픽**: `0.0.0.0/0` (모든 목적지 및 모든 프로토콜 허용)
- **설정 목적**: EC2 서버 내부에서 패키지 업데이트(`apt-get update`) 및 외부 API 연동 통신이 가능하도록 아웃바운드 트래픽을 전체 개방합니다.

---

## 4. 애플리케이션 컴퓨팅 및 웹 서버 (Application Computing & Web Server)
### 4.1 EC2 인스턴스 (Mission-Web-Server)
- **Instance 식별자**: `i-0760f0f6d6352c5ed` (이름: `Mission-Web-Server`)
- **인스턴스 스펙**: `t3.micro` (vCPU 2코어, 1GiB 메모리 - 프리티어 대상)
- **운영체제 (OS)**: Ubuntu 22.04 LTS (Amazon Machine Image: `ami-0621cf8f7a0902253`)
- **네트워크 주소 정보**:
  - **퍼블릭 IP (Public IP)**: `3.34.42.120` (외부 사용자가 접속 시 사용하는 공인 IP)
  - **프라이빗 IP (Private IP)**: `10.0.1.172` (VPC 내부에서 리소스 간 통신에 사용하는 사설 IP)
### 4.2 웹 서버 및 응답 상태 (Nginx Application)
- **구동 웹 서버**: Nginx (Engine X - HTTP 80번 포트 리스닝)
- **서비스 상태**: `systemctl status nginx` ➔ `active (running)` 정상 작동 중
- **헬스 체크 엔드포인트**: `http://3.34.42.120/health`
- **상태 검사 결과**: `HTTP 200 OK` 응답 코드와 함께 `"OK"` 텍스트 반환을 검증하여 외부 인프라 통신 및 애플리케이션이 모두 정상 상공하였음을 입증합니다.

---

## 5. 종합 패킷 이동 시나리오 (Traffic Flow Scenario)

외부 클라이언트가 웹사이트에 접속할 때 수신 패킷이 통과하는 단계별 이동 시나리오는 다음과 같습니다.
1. **[요청 전송]** 외부 사용자가 브라우저 주소창에 `http://3.34.42.120`을 입력하여 HTTP GET 요청을 전송합니다.
2. **[관문 수신]** 패킷이 AWS 서울 리전의 VPC 경계에 위치한 Internet Gateway(`igw-08725917d1b9eb4b0`)에 수신됩니다.
3. **[경로 탐색]** 라우팅 테이블(`rtb-04591059288768592`)이 외부 트래픽(`0.0.0.0/0`)을 서브넷(`subnet-0a319c0f06c2b88cc`)으로 전달합니다.
4. **[방화벽 검증]** 보안 그룹(`sg-046612d8c8902fcae`)이 수신된 패킷의 목적지 포트(80번)와 출발지 IP(`0.0.0.0/0`)가 인바운드 허용 규칙에 일치하는지 통과시킵니다.
5. **[서버 처리]** EC2 인스턴스 내부의 Nginx 웹 서버가 80번 포트로 요청을 수신하여 `HTTP/1.1 200 OK` 응답 페이지를 생성하고 클라이언트에 반환합니다.

---

## 추가 운영 및 관리 기준

### 리소스 연결 상태 확인

외부 접속이 정상적으로 이루어지기 위해 다음 연결 상태를 함께 확인합니다.

```text
Mission-VPC
    ↓
Mission-Public-Subnet
    ↓
Mission-RouteTable
    ↓
0.0.0.0/0 → Mission-IGW
    ↓
Mission-Web-Server
    ↓
Mission-Web-SG
    ├── TCP 80 → 0.0.0.0/0
    └── TCP 22 → 관리자 IP /32
```

Route Table과 Public Subnet의 연결 상태는 Route Table의 Subnet associations와 Routes를 함께 확인하여 검증합니다.

```powershell
aws ec2 describe-route-tables --route-table-ids rtb-04591059288768592 `
  --query "RouteTables[0].{Routes:Routes,Associations:Associations}" `
  --region ap-northeast-2
```

### HTTP 공개 및 Outbound 관리

HTTP 80은 외부 웹 서비스 제공을 위해 `0.0.0.0/0`으로 공개되어 있습니다. 인터넷 전체 공개는 포트 스캔이나 웹 서버 취약점 공격에 노출될 가능성이 있으므로 실제 운영 환경에서는 HTTPS, WAF 등의 추가 보안 설정을 고려할 수 있습니다.

현재 Outbound 전체 허용은 패키지 업데이트와 외부 통신을 위한 실습 설정입니다. 운영 환경에서는 필요한 목적지와 포트만 허용하는 egress 정책으로 축소할 수 있습니다.

### 관리자 IP 변경

관리자 IP가 변경되면 현재 공인 IP를 확인하고 기존 SSH 허용 규칙을 새 `/32` 주소로 변경합니다.

```powershell
$MY_IP = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim() + "/32"
```

이전 IP를 계속 누적하기보다 사용하지 않는 규칙을 제거하여 관리 접근 범위를 최소화합니다.

### 확장 기준

단일 EC2 구조의 병목 여부는 CPU 사용률, 메모리 사용량, 네트워크 트래픽, 동시 접속량, Nginx 응답 지연 및 HTTP 5xx 발생량 등을 기준으로 확인할 수 있습니다.

여러 EC2로 확장할 필요가 생기면 다음과 같이 ALB를 추가할 수 있습니다.

```text
Internet
   ↓
ALB
   ↓
Target Group
 ├── EC2
 ├── EC2
 └── EC2
```

### 태그 및 네이밍

추가 리소스는 기존 `Mission-*` 형식을 유지하고 다음과 같은 태그 기준을 사용할 수 있습니다.

```text
Project     = AWS-Web-Infrastructure
Environment = Practice
Owner       = sonjehyun
Purpose     = Web-Server
```
