-- 1. users: 사용자
CREATE TABLE users (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'USER',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT uq_users_email
        UNIQUE (email),

    CONSTRAINT chk_users_role
        CHECK (role IN ('USER', 'ADMIN'))
) ENGINE=InnoDB;


-- 2. categories: 지출 카테고리
CREATE TABLE categories (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    description VARCHAR(255) NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,

    PRIMARY KEY (id),

    CONSTRAINT uq_categories_name
        UNIQUE (name)
) ENGINE=InnoDB;


-- 3. receipts: 영수증 제출·정산 요청
-- 영수증의 제출·검토·승인·반려·정산 상태 관리
-- OCR 처리 상태는 ocr_results.status에서 별도로 관리
-- 관리자 확정값 저장 구조는 원본 그대로 유지
CREATE TABLE receipts (
    id BIGINT NOT NULL AUTO_INCREMENT,
    purpose VARCHAR(200) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED',
    merchant_name VARCHAR(200) NULL,
    paid_at DATE NULL,
    amount DECIMAL(15,0) NULL,
    memo TEXT NULL,
    submitted_at DATETIME NOT NULL,
    reviewed_at DATETIME NULL,
    updated_at DATETIME NOT NULL,
    submitter_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT chk_receipts_status
        CHECK (status IN (
            'SUBMITTED',
            'REVIEWING',
            'APPROVED',
            'REJECTED',
            'SETTLED'
        )),

    CONSTRAINT fk_receipts_submitter
        FOREIGN KEY (submitter_id) REFERENCES users (id),

    CONSTRAINT fk_receipts_category
        FOREIGN KEY (category_id) REFERENCES categories (id)
) ENGINE=InnoDB;


-- 4. receipt_files: 영수증 파일
-- 영수증 한 건에 파일 기록 최대 한 개: 원본 구조 유지
-- 재제출 시 기존 파일 기록을 새 이미지 정보로 갱신
-- Object Storage의 이전 이미지 삭제는 백엔드에서 별도 처리
CREATE TABLE receipt_files (
    id BIGINT NOT NULL AUTO_INCREMENT,
    object_key VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    file_size BIGINT NOT NULL,
    uploaded_at DATETIME NOT NULL,
    receipt_id BIGINT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT uq_receipt_files_receipt
        UNIQUE (receipt_id),

    CONSTRAINT fk_receipt_files_receipt
        FOREIGN KEY (receipt_id) REFERENCES receipts (id)
) ENGINE=InnoDB;


-- 5. ocr_results: OCR 처리 상태·결과
-- 영수증 한 건에 OCR 결과 여러 개 보존 가능: 원본 구조 유지
-- selected 컬럼 유지
-- 최대 한 개만 selected = TRUE로 선택하는 규칙은 백엔드에서 처리
-- 처리 중 또는 실패한 경우 추출값은 NULL일 수 있음
CREATE TABLE ocr_results (
    id BIGINT NOT NULL AUTO_INCREMENT,
    provider VARCHAR(30) NOT NULL,

    -- 추가: 영수증 업무 상태와 분리된 OCR 처리 상태
    status VARCHAR(30) NOT NULL DEFAULT 'OCR_PENDING',

    -- 기존 OCR 원본값: 그대로 유지
    merchant_name_raw VARCHAR(200) NULL,
    paid_at_raw DATE NULL,
    amount_raw DECIMAL(15,0) NULL,
    confidence DECIMAL(7,6) NULL,

    -- 기존: OCR 제공자가 반환한 원본 응답 JSON
    raw_payload JSON NULL,

    -- 추가: OCR이 인식한 전체 텍스트
    raw_text LONGTEXT NULL,

    -- 추가: 추출 후보·선택 근거 등 파싱 정보
    parsed_payload JSON NULL,

    -- 추가: 적용한 파싱 규칙의 버전
    parser_version VARCHAR(100) NULL,

    -- 추가: OCR 처리 실패 이유
    error_message TEXT NULL,

    -- 기존: 현재 사용할 OCR 결과 표시
    selected BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL,
    receipt_id BIGINT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT chk_ocr_results_status
        CHECK (status IN (
            'OCR_PENDING',
            'OCR_DONE',
            'OCR_FAILED'
        )),

    CONSTRAINT fk_ocr_results_receipt
        FOREIGN KEY (receipt_id) REFERENCES receipts (id)
) ENGINE=InnoDB;


-- 6. settlements: 정산 처리
-- 영수증 한 건에 정산 기록 최대 한 개
CREATE TABLE settlements (
    id BIGINT NOT NULL AUTO_INCREMENT,
    settled_at DATETIME NOT NULL,
    `comment` TEXT NULL,
    settled_by BIGINT NOT NULL,
    receipt_id BIGINT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT uq_settlements_receipt
        UNIQUE (receipt_id),

    CONSTRAINT fk_settlements_admin
        FOREIGN KEY (settled_by) REFERENCES users (id),

    CONSTRAINT fk_settlements_receipt
        FOREIGN KEY (receipt_id) REFERENCES receipts (id)
) ENGINE=InnoDB;


-- 7. receipt_histories: 영수증 처리 이력
-- 영수증 한 건에 이력 여러 개 저장 가능: receipt_id에 UNIQUE 없음
-- 시스템 작업이면 actor_id에 NULL 허용
-- from_status, to_status는 receipts.status의 업무 상태
-- OCR 처리 이력은 action, reason, snapshot으로 기록
CREATE TABLE receipt_histories (
    id BIGINT NOT NULL AUTO_INCREMENT,
    action VARCHAR(30) NOT NULL,
    from_status VARCHAR(30) NULL,
    to_status VARCHAR(30) NULL,
    reason TEXT NULL,
    snapshot JSON NULL,
    created_at DATETIME NOT NULL,
    receipt_id BIGINT NOT NULL,
    actor_id BIGINT NULL,

    PRIMARY KEY (id),

    CONSTRAINT fk_receipt_histories_receipt
        FOREIGN KEY (receipt_id) REFERENCES receipts (id),

    CONSTRAINT fk_receipt_histories_actor
        FOREIGN KEY (actor_id) REFERENCES users (id)
) ENGINE=InnoDB;


-- 8. duplicate_candidates: 중복·유사 영수증 후보
-- 동일한 방향의 영수증 ID 조합 중복 저장 금지
-- 자기 자신을 후보로 저장하는 것 금지
CREATE TABLE duplicate_candidates (
    id BIGINT NOT NULL AUTO_INCREMENT,
    match_reason VARCHAR(255) NOT NULL,
    score DECIMAL(7,6) NULL,
    created_at DATETIME NOT NULL,
    receipt_id BIGINT NOT NULL,
    candidate_receipt_id BIGINT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT uq_duplicate_candidates_pair
        UNIQUE (receipt_id, candidate_receipt_id),

    CONSTRAINT chk_duplicate_candidates_different
        CHECK (receipt_id <> candidate_receipt_id),

    CONSTRAINT fk_duplicate_candidates_receipt
        FOREIGN KEY (receipt_id) REFERENCES receipts (id),

    CONSTRAINT fk_duplicate_candidates_candidate
        FOREIGN KEY (candidate_receipt_id) REFERENCES receipts (id)
) ENGINE=InnoDB;
