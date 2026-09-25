# AWS 리소스 정리 체크리스트 (Cleanup Checklist)

본 체크리스트는 실습 종료 후 불필요한 비용 과금을 방지하기 위해 생성된 모든 AWS 리소스를 안전하게 삭제/릴리스하는 절차 문서입니다.

---

## 📋 1. 생성된 리소스 추적 및 정리 체크리스트

| 리소스 구분 | 생성된 Resource ID | 삭제/해제 상태 | 삭제 순서 / 주의사항 |
| :--- | :--- | :---: | :--- |
| **EC2 인스턴스** | `i-0760f0f6d6352c5ed` | [ ] 대기 / [ ] 완료 | 인스턴스 **Terminate(종료)** 처리 (Shutdown이 아닌 Terminate 필수) |
| **EBS 볼륨** | `vol-0xxxxxxxxxxxx` | [ ] 완료 | EC2 Terminate 시 `DeleteOnTermination`에 의해 자동 삭제 확인 |
| **Key Pair** | `mission-key` | [ ] 대기 / [ ] 완료 | AWS Console 또는 CLI로 Key Pair 삭제 (`aws ec2 delete-key-pair`) |
| **Security Group**| `sg-046612d8c8902fcae` | [ ] 대기 / [ ] 완료 | EC2 종결 후 보안 그룹 삭제 (`aws ec2 delete-security-group`) |
| **Subnet & Route Table**| `subnet-0a319c0f06c2b88cc`<br>`rtb-04591059288768592` | [ ] 대기 / [ ] 완료 | Subnet 삭제 및 사용자 지정 Route Table 삭제 |
| **Internet Gateway**| `igw-08725917d1b9eb4b0` | [ ] 대기 / [ ] 완료 | VPC에서 Detach 후 IGW 삭제 |
| **VPC** | `vpc-00dc9a5671c96f5c5` | [ ] 대기 / [ ] 완료 | 모든 하위 리소스 해제 후 최종 VPC 삭제 |

---

## 🗑️ 2. CLI 기반 한 번에 리소스 정리 명령어 (실습 완료 후 실행)

```powershell
# 1. EC2 인스턴스 종료
aws ec2 terminate-instances --instance-ids i-0760f0f6d6352c5ed --region ap-northeast-2
aws ec2 wait instance-terminated --instance-ids i-0760f0f6d6352c5ed --region ap-northeast-2

# 2. Key Pair 삭제
aws ec2 delete-key-pair --key-name mission-key --region ap-northeast-2

# 3. Security Group 삭제
aws ec2 delete-security-group --group-id sg-046612d8c8902fcae --region ap-northeast-2

# 4. Route Table 및 Internet Gateway Detach & 삭제
aws ec2 delete-route-table --route-table-id rtb-04591059288768592 --region ap-northeast-2
aws ec2 detach-internet-gateway --internet-gateway-id igw-08725917d1b9eb4b0 --vpc-id vpc-00dc9a5671c96f5c5 --region ap-northeast-2
aws ec2 delete-internet-gateway --internet-gateway-id igw-08725917d1b9eb4b0 --region ap-northeast-2

# 5. Subnet 및 VPC 삭제
aws ec2 delete-subnet --subnet-id subnet-0a319c0f06c2b88cc --region ap-northeast-2
aws ec2 delete-vpc --vpc-id vpc-00dc9a5671c96f5c5 --region ap-northeast-2
```

---

## 💰 3. Billing (과금) 최종 확인
- [ ] AWS Console ➔ **Billing & Cost Management Dashboard** 접속
- [ ] 예상 과금 금액이 `$0.00` 유지되는지 최종 점검 완료
