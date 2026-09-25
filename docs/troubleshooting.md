# 트러블슈팅 보고서 (Troubleshooting Report)

본 보고서는 AWS 클라우드 웹 인프라 구축 과정에서 발생한 실제 오류 및 이슈에 대해 원인을 분석하고 해결한 과정을 기록한 문서입니다.

---

## Case 1. AWS IAM / Organization SCP (Service Control Policy) 권한 거부 오류

### 1. 증상 (Problem Statement)
- AWS CLI를 통한 VPC 및 EC2 생성 명령어 실행 시 `UnauthorizedOperation` 및 `explicit deny in a service control policy` 오류가 발생함.
```text
An error occurred (UnauthorizedOperation) when calling the CreateVpc operation: You are not authorized to perform this operation. User: arn:aws:iam::952376465187:user/son-admin is not authorized to perform: ec2:CreateVpc with an explicit deny in a service control policy: arn:aws:organizations::.../p-4fisx83d
```

### 2. 원인 가설 (Hypothesis)
- 실습 계정이 속한 상위 AWS Organization의 SCP(서비스 제어 정책)에서 IAM 사용자의 네트워크 리소스(`CreateVpc`, `CreateInternetGateway`, `CreateTags`) 생성을 차단하고 있음.

### 3. 검증 방법 (Verification)
- `aws sts get-caller-identity`로 현재 IAM 계정 및 조직 소속 계정 확인.
- `aws ec2 describe-vpcs` 실행 결과 조직 차원의 `explicit deny` 거부 응답 수신 확인.

### 4. 조치 내용 (Remediation)
- SCP 제약이 적용되지 않은 독립 개인 프리티어 계정(`751479507314`, IAM 사용자 `SON-6-1`)으로 교체.
- `aws configure`를 통해 새로운 계정의 Access Key ID 및 Secret Access Key 재설정 및 인증 완료.

### 5. 결과 (Outcome)
- `Mission-VPC`, `Mission-Public-Subnet`, `Mission-IGW`, `Mission-RouteTable`, `Mission-Web-SG` 및 EC2 인스턴스가 100% 정상 생성됨.

### 6. 재발 방지 (Prevention)
- AWS 실습 시 상위 계정의 SCP 정책 유무를 사전에 체크(`sts get-caller-identity` 및 pre-flight permission check)하는 절차를 체크리스트에 추가.

---

## Case 2. EC2 생성 직후 외부 HTTP (80) 접속 타임아웃 / 응답 실패

### 1. 증상 (Problem Statement)
- EC2 인스턴스(`i-0760f0f6d6352c5ed`)가 `running` 상태이고 보안 그룹 80 포트가 `0.0.0.0/0`으로 허용되어 있음에도, `curl http://3.34.42.120` 요청 시 접속 불가 또는 `WebCmdletWebResponseException` 발생.

### 2. 원인 가설 (Hypothesis)
- 가설 A: Nginx 서비스가 아직 설치/실행되지 않음 (Ubuntu boot 초기화 과정에서 `unattended-upgrades` 백그라운드 프로세스가 apt-get lock을 점유하여 UserData 스크립트 실행 지연).
- 가설 B: Subnet의 Route Table에 Internet Gateway(0.0.0.0/0 -> IGW) 경로 연결 누락.

### 3. 검증 방법 (Verification)
- SSH 키(`mission-key.pem`)를 이용해 인스턴스에 접속: `ssh -i mission-key.pem ubuntu@3.34.42.120`
- Nginx 상태 점검: `sudo systemctl status nginx` ➔ `Unit nginx.service could not be found` 확인.
- `cloud-init` 로그 점검: `/var/log/cloud-init-output.log` 확인 결과 apt 패키지 락 대기 상태 확인.

### 4. 조치 내용 (Remediation)
- SSH 접속을 통해 Nginx 패키지를 수동으로 즉시 설치 및 서비스 활성화:
  ```bash
  sudo apt-get update -y && sudo apt-get install -y nginx
  sudo systemctl restart nginx
  echo "OK" | sudo tee /var/www/html/health
  ```

### 5. 결과 (Outcome)
- `http://3.34.42.120` ➔ `200 OK` 정상 응답 수신.
- `http://3.34.42.120/health` ➔ `OK` 헬스체크 정상 응답 확인.

### 6. 재발 방지 (Prevention)
- EC2 UserData 작성 시 패키지 락 대기 방지 로직(`systemctl stop unattended-upgrades` 또는 수동 패키지 검증)을 배포 스크립트에 반영.
