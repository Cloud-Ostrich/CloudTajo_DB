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
    CONSTRAINT uq_users_email UNIQUE (email),
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
    CONSTRAINT uq_categories_name UNIQUE (name)
) ENGINE=InnoDB;


-- 3. receipts: 영수증 제출·정산 요청
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
            'OCR_PENDING',
            'OCR_DONE',
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
-- 영수증 한 건에 파일 기록 최대 한 개
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


-- 5. ocr_results: OCR 결과
-- 영수증 한 건에 OCR 결과 여러 개 보존 가능
-- 최대 한 개만 selected = TRUE로 선택하는 규칙은 백엔드에서 처리
CREATE TABLE ocr_results (
    id BIGINT NOT NULL AUTO_INCREMENT,
    provider VARCHAR(30) NOT NULL,
    merchant_name_raw VARCHAR(200) NULL,
    paid_at_raw DATE NULL,
    amount_raw DECIMAL(15,0) NULL,
    confidence DECIMAL(7,6) NULL,
    raw_payload JSON NULL,
    selected BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL,
    receipt_id BIGINT NOT NULL,

    PRIMARY KEY (id),

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