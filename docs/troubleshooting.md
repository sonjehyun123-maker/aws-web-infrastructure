# 트러블슈팅 보고서 (Troubleshooting Report)

## Case 1. SSH 접속 불가 또는 외부 HTTP 요청 타임아웃 오류 (예시)

### 1. 증상 (Problem Statement)
- 퍼블릭 IP를 통해 인스턴스 SSH 접속(port 22) 또는 HTTP(port 80) 요청 시 `Connection timed out` 오류 발생.

### 2. 원인 가설 (Hypothesis)
- 보안 그룹(Security Group) 인바운드 규칙에 SSH(22) 또는 HTTP(80) 포트가 허용되어 있지 않거나,
- Subnet의 Route Table에 Internet Gateway(0.0.0.0/0 -> igw-xxx) 경로가 누락되었을 가능성.

### 3. 검증 방법 (Verification)
- AWS Console -> Security Groups -> Inbound Rules 조회.
- Route Table -> Routes 탭에서 `0.0.0.0/0` 타겟이 IGW로 등록되어 있는지 확인.

### 4. 조치 내용 (Remediation)
- Security Group 인바운드 규칙 추가:
  - HTTP (Port 80) : `0.0.0.0/0`
  - SSH (Port 22) : `<학습자_개인_IP>/32`
- Route Table에 `0.0.0.0/0` -> `igw-xxxxxx` 라우팅 경로 지정.

### 5. 결과 (Outcome)
- `curl -I http://<퍼블릭IP>` 실행 시 `HTTP/1.1 200 OK` 정상 응답 수신 확인.
- SSH 접속 정상 연결 완료.

### 6. 재발 방지 (Prevention)
- 인프라 생성 절차 체크리스트 작성 (VPC -> IGW -> Route Table 연결 -> SG 포트 제한 확인 -> EC2 생성 순서 엄수).
