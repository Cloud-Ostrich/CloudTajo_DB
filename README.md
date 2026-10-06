# CloudTajo_DB
Database schema and test SQL for CloudTajo

# CloudTajo Database

영수증 OCR 기반 회비·지출 정산 관리 서비스의 MySQL 데이터베이스 설계 및 테스트 SQL입니다.

사용자, 영수증, 첨부 파일, OCR 결과, 처리 이력, 정산 기록, 중복 후보 정보를 관리합니다.

## 개발 환경

- DB: MySQL
- 로컬 검증 환경: MySQL 9.4.0
- 사용 도구: MySQL Workbench
- 팀 서비스 적용 예정: Naver Cloud DB for MySQL

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| schema.sql | 테이블, 기본값, 기본키·외래키 및 제약조건 생성 |
| test.sql | 데이터 저장 및 제약조건 확인을 위한 수동 테스트 |

## 테이블 구성

| 테이블 | 용도 |
| --- | --- |
| users | 사용자 정보 및 권한 |
| categories | 지출 카테고리 |
| receipts | 영수증 정보 및 처리 상태 |
| receipt_files | 영수증 첨부 파일 정보 |
| ocr_results | 영수증 OCR 인식 결과 |
| settlements | 정산 완료 기록 |
| receipt_histories | 영수증 처리 이력 |
| duplicate_candidates | 중복·유사 영수증 비교 후보 |

## 주요 제약조건

- 사용자 이메일과 카테고리 이름은 중복 등록할 수 없습니다.
- 사용자 역할은 USER 또는 ADMIN으로 제한합니다.
- 영수증 상태는 지정된 목록으로 제한합니다.
- 외래키로 테이블 간 연결 관계를 관리합니다.
- 영수증 한 건당 첨부 파일과 정산 기록은 각각 최대 한 개입니다.
- 영수증 한 건에 OCR 결과와 처리 이력을 여러 개 저장할 수 있습니다.
- 시스템 작업의 처리 이력은 처리자(actor_id)가 NULL일 수 있습니다. why? 사람이 아니라 프로그램이 자동으로 수행한 작업도 이력에 남기때문
- 중복 후보는 자기 자신과의 비교 및 동일한 순서의 영수증 조합 재등록을 차단합니다.

## 로컬 실행 방법

MySQL Workbench에서 테스트용 데이터베이스를 생성하고 선택합니다.

```sql
CREATE DATABASE IF NOT EXISTS cloudtajo_test
    DEFAULT CHARACTER SET utf8mb4;

USE cloudtajo_test;
```

선택한 데이터베이스에 `schema.sql`을 실행하여 테이블을 생성합니다.

이후 같은 연결에서 `test.sql`을 번호 순서대로 구간별로 실행합니다.

## 테스트 실행 시 참고사항

- 테스트 데이터가 없는 상태에서 처음 실행하는 것을 기준으로 작성했습니다.
- 중복 등록, 잘못된 외래키, 허용되지 않은 값 입력 등 일부 테스트는 오류 발생이 정상 결과입니다.
- 의도적으로 오류를 발생시키는 구간이 있으므로 전체를 한 번에 실행하지 않고 구간별로 확인합니다.
- test.sql은 로컬 테스트용이며 실제 서비스 DB에 실행하지 않습니다.

## 현재 작업 상태

- 8개 테이블 생성 SQL 작성
- 로컬 MySQL에서 테이블 생성 및 제약조건 테스트 진행
- 팀 서비스 DB 적용 및 백엔드 연동 예정
