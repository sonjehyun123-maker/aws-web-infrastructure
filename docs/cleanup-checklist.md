# AWS 리소스 정리 체크리스트 (Cleanup Checklist)

본 문서는 과제 실습 완료 후 불필요한 클라우드 비용 과금을 방지하기 위하여, 생성되었던 모든 AWS 인프라 리소스에 대해 안전하게 삭제 작업을 수행하고 검증한 체크리스트 보고서입니다.

---

## 1. 생성 리소스 추적 및 정리 이력 관리표

| 리소스 구분 | 생성된 Resource ID | 정리 상태 | 삭제 수행 방법 및 비고 |
| :--- | :--- | :---: | :--- |
| **EC2 인스턴스** | `i-0760f0f6d6352c5ed` | 완료 | EC2 인스턴스 Terminate(종료) 완료 |
| **EBS 볼륨** | `vol-0xxxxxxxxxxxx` | 완료 | EC2 인스턴스 종료 시 DeleteOnTermination에 의해 자동 삭제 |
| **Key Pair** | `mission-key` | 완료 | SSH 키 페어 삭제 완료 (`aws ec2 delete-key-pair`) |
| **Security Group**| `sg-046612d8c8902fcae` | 완료 | EC2 인스턴스 종료 후 보안 그룹 삭제 완료 |
| **Route Table** | `rtb-04591059288768592` | 완료 | Subnet 라우팅 연결 해제 후 Route Table 삭제 완료 |
| **Internet Gateway**| `igw-08725917d1b9eb4b0` | 완료 | VPC에서 Detach 후 IGW 삭제 완료 |
| **Public Subnet** | `subnet-0a319c0f06c2b88cc` | 완료 | Subnet 삭제 완료 |
| **VPC** | `vpc-00dc9a5671c96f5c5` | 완료 | 하위 리소스 해제 후 VPC 최종 삭제 완료 (`Vpcs: []` 확인) |

---

## 2. CLI 기반 리소스 정리 수행 스크립트 (실행 내역)

자원 간 의존성을 고려하여 아래 순서대로 삭제를 진행하였습니다.

```powershell
# 1. EC2 인스턴스 종료 (Terminate) 및 완료 대기
aws ec2 terminate-instances --instance-ids i-0760f0f6d6352c5ed --region ap-northeast-2
aws ec2 wait instance-terminated --instance-ids i-0760f0f6d6352c5ed --region ap-northeast-2

# 2. Key Pair 및 Security Group 삭제
aws ec2 delete-key-pair --key-name mission-key --region ap-northeast-2
aws ec2 delete-security-group --group-id sg-046612d8c8902fcae --region ap-northeast-2

# 3. Route Table 연동 해제 및 삭제
$ASSOC_ID = (aws ec2 describe-route-tables --route-table-ids rtb-04591059288768592 --query 'RouteTables[0].Associations[0].RouteTableAssociationId' --output text --region ap-northeast-2)
aws ec2 disassociate-route-table --association-id $ASSOC_ID --region ap-northeast-2
aws ec2 delete-route-table --route-table-id rtb-04591059288768592 --region ap-northeast-2

# 4. Internet Gateway Detach 및 삭제
aws ec2 detach-internet-gateway --internet-gateway-id igw-08725917d1b9eb4b0 --vpc-id vpc-00dc9a5671c96f5c5 --region ap-northeast-2
aws ec2 delete-internet-gateway --internet-gateway-id igw-08725917d1b9eb4b0 --region ap-northeast-2

# 5. Subnet 및 VPC 최종 삭제
aws ec2 delete-subnet --subnet-id subnet-0a319c0f06c2b88cc --region ap-northeast-2
aws ec2 delete-vpc --vpc-id vpc-00dc9a5671c96f5c5 --region ap-northeast-2
```

---

## 3. 과금(Billing) 최종 검증
- AWS Management Console ➔ **Billing & Cost Management Dashboard**에 접속하여 예상 청구 금액이 `$0.00`로 유지되고 미사용 자원이 잔존하지 않음을 최종 검증하였습니다.
