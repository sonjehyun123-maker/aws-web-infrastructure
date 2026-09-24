# AWS 리소스 정리 체크리스트 (Cleanup Checklist)

실습 종료 후 불필요한 과금을 방지하기 위하여 아래 리소스 정리 절차를 수행하고 삭제 여부를 확인합니다.

| 리소스 구분 | 항목 / ID | 삭제/해제 확인 | 삭제 순서 / 주의사항 |
| :--- | :--- | :---: | :--- |
| **EC2 인스턴스** | Instance ID (`i-xxxxxxxx`) | [ ] 완료 | 인스턴스 **Terminate(종료)** 처리 (Shutdown이 아님) |
| **EBS 볼륨** | Volume ID (`vol-xxxxxxxx`) | [ ] 완료 | EC2 종료 시 자동 삭제 여부 확인, 남아있다면 수동 삭제 |
| **Elastic IP** | Allocation ID (`eipalloc-xxx`) | [ ] 완료 | EC2에서 Disassociate 후 **Release(릴리스)** 필수 |
| **Security Group**| SG ID (`sg-xxxxxxxx`) | [ ] 완료 | EC2 삭제 후 보안 그룹 삭제 |
| **Internet Gateway**| IGW ID (`igw-xxxxxxxx`) | [ ] 완료 | VPC에서 Detach 후 IGW 삭제 |
| **Subnet & Route Table**| Subnet / RT ID | [ ] 완료 | Subnet 삭제 및 사용자 지정 Route Table 삭제 |
| **VPC** | VPC ID (`vpc-xxxxxxxx`) | [ ] 완료 | 리소스 해제 후 최종 VPC 삭제 |
| **IAM** | IAM User / Role | [ ] 완료 | 실습용 IAM 계정/역할 및 Access Key 삭제 또는 비활성화 |

---

### Billing 확인 (권장)
- [ ] AWS Console -> **Billing & Cost Management Dashboard**에 접속하여 예상 과금 항목이 $0.00인지 확인 스크린샷 첨부.
