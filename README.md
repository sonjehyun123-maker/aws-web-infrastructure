# AWS 웹 서비스 인프라 구축 프로젝트

본 프로젝트는 AWS 프리티어 환경에서 VPC, Subnet, Internet Gateway, Security Group 및 EC2(Nginx) 기반의 기본 웹 인프라를 구축하고 외부 접속을 검증한 결과를 담고 있습니다.

## 1. 외부 접속 증빙
- **접속 검증 방식**: (A) 브라우저 접속 (`http://3.34.42.120`) 및 (B) GET /health 호출 (`http://3.34.42.120/health`)
- **접속 URL / 퍼블릭 IP**: `http://3.34.42.120`
- **접속 결과 확인**:
  - `GET http://3.34.42.120` ➔ `200 OK` (`<h1>Welcome to AWS Web Infrastructure Mission!</h1><p>Status: 200 OK</p>`)
  - `GET http://3.34.42.120/health` ➔ `200 OK` (`OK`)

> **스크린샷 증빙**:
> 브라우저 및 AWS 콘솔 캡처 이미지를 `docs/` 디렉토리에 추가하여 과제물로 제출합니다.

## 2. 제출 문서 목록
- [학습 가이드 문서](./LEARNING_GUIDE.md)
- [아키텍처 다이어그램](./docs/architecture.pdf) (또는 `architecture.png`)
- [트러블슈팅 보고서](./docs/troubleshooting.md)
- [리소스 정리 체크리스트](./docs/cleanup-checklist.md)
