# AWS 웹 서비스 인프라 구축 프로젝트

본 프로젝트는 AWS 프리티어 환경에서 VPC, Subnet, Internet Gateway, Security Group 및 EC2(Nginx) 기반의 기본 웹 인프라를 구축하고 외부 접속을 검증한 결과를 담고 있습니다.

## 1. 외부 접속 증빙
- **접속 검증 방식**: (A) 브라우저 접속 / (B) GET /health 호출 중 선택
- **접속 URL / 퍼블릭 IP**: `http://<퍼블릭IP>`
- **접속 결과 예시**:
  - 응답 코드: 200 OK
  - 서비스 응답 내용: Nginx Welcome 페이지 또는 "OK"

> **스크린샷 증빙**: 아래에 브라우저/curl 접속 결과 스크린샷 첨부 예정
> ![외부 접속 검증 스크린샷](./docs/proof.png)

## 2. 제출 문서 목록
- [아키텍처 다이어그램](./docs/architecture.pdf) (또는 `architecture.png`)
- [트러블슈팅 보고서](./docs/troubleshooting.md)
- [리소스 정리 체크리스트](./docs/cleanup-checklist.md)
