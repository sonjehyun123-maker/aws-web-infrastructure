# 트러블슈팅 보고서 (Troubleshooting Report)

본 보고서는 AWS 클라우드 웹 인프라 구축 실습 중 실제로 경험한 2가지 기술적 문제 상황에 대해 원인을 파악하고 해결한 과정을 6단계 정식 프레임워크에 맞춰 작성한 문서입니다.

---

## 사례 1. AWS IAM 및 상위 계정 조직 정책(SCP) 권한 거부 오류
### 1. 증상 (Problem Statement)
- AWS CLI를 이용하여 VPC(`create-vpc`), 태그 생성(`create-tags`), 이미지 조회(`describe-images`) 명령어를 실행하였으나 `UnauthorizedOperation` 및 `explicit deny in a service control policy` 오류 메시지가 반환되며 작성이 차단됨.
```text
An error occurred (UnauthorizedOperation) when calling the CreateVpc operation: You are not authorized to perform this operation. User: arn:aws:iam::952376465187:user/son-admin is not authorized to perform: ec2:CreateVpc with an explicit deny in a service control policy: arn:aws:organizations::.../policy/service_control_policy/p-4fisx83d
```
### 2. 원인 가설 (Hypothesis)
- 실습에 처음 사용한 계정(`952376465187`)이 특정 기관/기업의 AWS Organization에 소속되어 있으며, 상위 관리자가 서비스 제어 정책(SCP: Service Control Policy)을 통해 일반 IAM 사용자의 신규 VPC 및 EC2 관련 생성 권한을 명시적으로 거부(Explicit Deny)해 놓은 상태임.
### 3. 검증 방법 (Verification)
- `aws sts get-caller-identity` 명령을 실행하여 소속 IAM ARN과 계정 ID를 조회함.
- `aws ec2 describe-vpcs` 명령을 실행하여 명시적 거부(Explicit Deny) 응답을 수신하고 IAM 권한 추가만으로는 해결할 수 없는 상위 SCP 차단 정책임을 검증함.
### 4. 조치 내용 (Remediation)
- 상위 조직 정책의 영향을 받지 않는 독립된 개인 AWS 프리티어 계정(`751479507314`, IAM 사용자 `SON-6-1`)으로 전환함.
- `AmazonEC2FullAccess` 정책이 부여된 새로운 계정의 Access Key ID 및 Secret Access Key를 발급받아 `aws configure`에 재등록함.

### 5. 결과 (Outcome)
- `aws sts get-caller-identity` 결과가 신규 계정으로 변경되었으며, `Mission-VPC`, `Mission-Public-Subnet`, `Mission-IGW`, `Mission-RouteTable`, `Mission-Web-SG` 및 EC2 인스턴스가 아무런 오류 없이 100% 정상 생성됨.
### 6. 재발 방지 (Prevention)
- 새로운 AWS 계정에서 실습을 진행하기 전, 상위 SCP 제한 여부를 확인하는 자격 증명 사정 점검(Pre-flight Check) 절차를 구축 가이드에 포함함.

---

## 사례 2. EC2 부팅 직후 패키지 락으로 인한 Nginx 웹 서버 접속 지연 오류

### 1. 증상 (Problem Statement)
- EC2 인스턴스(`i-0760f0f6d6352c5ed`) 생성이 완료되어 상태가 `running`이고 보안 그룹 80번 포트가 개방되어 있음에도, 퍼블릭 IP `http://3.34.42.120`으로 HTTP 요청 시 접속이 수 분간 타임아웃되거나 응답을 받지 못함.
### 2. 원인 가설 (Hypothesis)
- Ubuntu 22.04 LTS 최신 AMI의 초기 부팅 시 시스템 자동 업데이트 프로세스(`unattended-upgrades`)가 백그라운드에서 백그라운드 락(`/var/lib/dpkg/lock-frontend`)을 점유함에 따라 UserData로 전달된 `apt-get install -y nginx` 명령어 실행이 지연되었을 가능성.
### 3. 검증 방법 (Verification)
- 발급된 SSH 키(`mission-key.pem`)를 활용하여 인스턴스에 직접 접속함: `ssh -i mission-key.pem ubuntu@3.34.42.120`
- Nginx 서비스 작동 상태 조회: `sudo systemctl status nginx` ➔ `Unit nginx.service could not be found` 확인.
- 부팅 실행 로그 점검: `/var/log/cloud-init-output.log` 파일의 하단 로그를 조회하여 패키지 설치 대기 상태를 확인함.
### 4. 조치 내용 (Remediation)
- SSH 세션에서 Nginx 패키지를 수동으로 설치하고 웹 서버 서비스를 활성화함:
  ```bash
  sudo apt-get update -y && sudo apt-get install -y nginx
  sudo systemctl restart nginx
  echo "OK" | sudo tee /var/www/html/health
  echo "<h1>Welcome to AWS Web Infrastructure Mission!</h1><p>Status: 200 OK</p>" | sudo tee /var/www/html/index.html
  ```

### 5. 결과 (Outcome)
- 로컬 및 외부 웹 브라우저 접속 검증:
  - `http://3.34.42.120` ➔ `HTTP 200 OK` 정상 응답 수신.
  - `http://3.34.42.120/health` ➔ `OK` (HTTP 200 OK) 헬스 체크 정상 응답 수신.
### 6. 재발 방지 (Prevention)
- EC2 인스턴스 자동화 배포 시 UserData 스크립트 시작 부분에 부팅 시 패키지 락 대기를 방지하는 사전 처리 명령을 추가하거나 배포 후 서비스 헬스 체크 루틴을 의무화함.

---

## 외부 접속 장애 점검 순서

외부 HTTP 접속에 문제가 발생한 경우 다음 순서로 확인하여 네트워크 문제와 서버 문제를 구분합니다.

### 1. Route Table

```powershell
aws ec2 describe-route-tables --route-table-ids <RT_ID> --region ap-northeast-2
```

확인할 내용:
- `0.0.0.0/0 → IGW` 경로 존재 여부
- 해당 Route Table과 Public Subnet의 연결 여부

### 2. Security Group

```powershell
aws ec2 describe-security-groups --group-ids <SG_ID> --region ap-northeast-2
```

확인할 내용:
- TCP 80 인바운드 허용 여부
- SSH 22가 현재 관리자 IP를 허용하는지 여부

### 3. Public IP / Public Subnet

```powershell
aws ec2 describe-instances --instance-ids <INSTANCE_ID> `
  --query "Reservations[0].Instances[0].PublicIpAddress" `
  --output text --region ap-northeast-2
```

```powershell
aws ec2 describe-subnets --subnet-ids <SUBNET_ID> `
  --query "Subnets[0].MapPublicIpOnLaunch" `
  --region ap-northeast-2
```

### 4. 서버 내부

```bash
sudo systemctl status nginx
sudo ss -lntp | grep :80
curl -i http://localhost/health
```

### 5. 외부 응답

```bash
curl -i http://<PUBLIC_IP>
curl -i http://<PUBLIC_IP>/health
```

최종적으로 `Route → Security Group → Public IP → Server → HTTP Response` 순서로 확인하여 장애 범위를 좁힙니다.

## 원본 로그 기록 기준

장애 기록은 설명만 남기지 않고 실행한 명령과 핵심 출력 결과를 함께 남깁니다.

```bash
sudo systemctl status nginx
```

```text
Unit nginx.service could not be found
```

또는:

```bash
curl -i http://localhost/health
```

```text
HTTP/1.1 200 OK

OK
```

이처럼 `가설 → 실행 명령 → 실제 출력 → 판단 → 조치`의 관계가 드러나도록 기록합니다.
