-- DB 구조·제약 조건 테스트
-- 로컬 테스트 DB 전용
-- 각 테스트 구간을 선택해서 개별 실행
-- 중복·허용값 위반 테스트는 오류가 발생해야 정상

USE cloudtajo_test;


-- 1. 사용자 저장 및 자동 ID·기본 역할 확인
INSERT INTO users (
    name, email, password_hash, created_at, updated_at
)
VALUES (
    'DB 테스트 사용자',
    'dbtest@example.com',
    'test_hash_not_for_login',
    NOW(),
    NOW()
);

SELECT id, name, email, role
FROM users
WHERE email = 'dbtest@example.com';


-- 2. 이메일 중복 등록 차단 확인
-- 예상 결과: 오류 1062 (uq_users_email)
INSERT INTO users (
    name, email, password_hash, created_at, updated_at
)
VALUES (
    '중복 테스트 사용자',
    'dbtest@example.com',
    'test_hash_not_for_login',
    NOW(),
    NOW()
);


-- 3. 카테고리 저장 및 active 기본값 확인
INSERT INTO categories (
    name, description
)
VALUES (
    'DB 테스트 카테고리',
    'DB 검증용 임시 데이터'
);

SELECT id, name, active
FROM categories
WHERE name = 'DB 테스트 카테고리';


-- 4. 영수증 저장 및 기본 상태 확인
SET @test_user_id = (
    SELECT id FROM users
    WHERE email = 'dbtest@example.com'
);

SET @test_category_id = (
    SELECT id FROM categories
    WHERE name = 'DB 테스트 카테고리'
);

INSERT INTO receipts (
    purpose, merchant_name, paid_at, amount,
    submitted_at, updated_at, submitter_id, category_id
)
VALUES (
    'DB 테스트용 지출',
    '테스트 상점',
    '2026-10-06',
    10000,
    NOW(),
    NOW(),
    @test_user_id,
    @test_category_id
);

SET @test_receipt_id = LAST_INSERT_ID();

SELECT id, purpose, status, amount, submitter_id, category_id
FROM receipts
WHERE id = @test_receipt_id;


-- 5. 존재하지 않는 사용자 연결 차단 확인
-- 예상 결과: 오류 1452 (fk_receipts_submitter)
INSERT INTO receipts (
    purpose, submitted_at, updated_at,
    submitter_id, category_id
)
VALUES (
    'FK 차단 테스트',
    NOW(),
    NOW(),
    -1,
    @test_category_id
);


-- 6. 영수증 파일 저장 및 1:1 제약 확인
-- 첫 번째 입력: 저장 성공
INSERT INTO receipt_files (
    object_key, original_filename, content_type,
    file_size, uploaded_at, receipt_id
)
VALUES (
    'db-test/receipt-1.png',
    'test-receipt.png',
    'image/png',
    1024,
    NOW(),
    @test_receipt_id
);

-- 두 번째 입력: 오류 1062 (uq_receipt_files_receipt)
INSERT INTO receipt_files (
    object_key, original_filename, content_type,
    file_size, uploaded_at, receipt_id
)
VALUES (
    'db-test/receipt-1-second.png',
    'test-receipt-second.png',
    'image/png',
    2048,
    NOW(),
    @test_receipt_id
);


-- 7. OCR 결과 1:N 관계 및 selected 기본값 확인
INSERT INTO ocr_results (
    provider, merchant_name_raw, amount_raw,
    created_at, receipt_id
)
VALUES
    (
        'CLOVA_OCR', '테스트 상점', 10000,
        NOW(), @test_receipt_id
    ),
    (
        'CLOVA_OCR', '테스트 상점 재인식', 10000,
        NOW(), @test_receipt_id
    );

SELECT id, receipt_id, merchant_name_raw, amount_raw, selected
FROM ocr_results
WHERE receipt_id = @test_receipt_id
ORDER BY id;


-- 8. 처리 이력 1:N 관계 및 actor_id NULL 허용 확인
-- 이력만 저장하며 receipts의 실제 상태는 변경하지 않음
INSERT INTO receipt_histories (
    action, from_status, to_status,
    reason, created_at, receipt_id, actor_id
)
VALUES
    (
        'OCR_REQUEST', 'SUBMITTED', 'OCR_PENDING',
        'DB 테스트용 OCR 요청 기록',
        NOW(), @test_receipt_id, NULL
    ),
    (
        'OCR_COMPLETE', 'OCR_PENDING', 'OCR_DONE',
        'DB 테스트용 OCR 완료 기록',
        NOW(), @test_receipt_id, NULL
    );

SELECT id, receipt_id, action, from_status, to_status, actor_id
FROM receipt_histories
WHERE receipt_id = @test_receipt_id
ORDER BY id;


-- 9. 정산 기록 저장 및 중복 정산 기록 차단 확인
-- DB 제약 테스트이며 실제 정산 업무 흐름을 재현하지 않음
INSERT INTO users (
    name, email, password_hash, role, created_at, updated_at
)
VALUES (
    'DB 테스트 관리자',
    'dbadmin@example.com',
    'test_hash_not_for_login',
    'ADMIN',
    NOW(),
    NOW()
);

SET @test_admin_id = LAST_INSERT_ID();

-- 첫 번째 정산 기록: 저장 성공
INSERT INTO settlements (
    settled_at, `comment`, settled_by, receipt_id
)
VALUES (
    NOW(),
    'DB 제약 검증용 정산 기록',
    @test_admin_id,
    @test_receipt_id
);

SELECT id, receipt_id, settled_by, settled_at
FROM settlements
WHERE receipt_id = @test_receipt_id;

-- 두 번째 정산 기록: 오류 1062 (uq_settlements_receipt)
INSERT INTO settlements (
    settled_at, `comment`, settled_by, receipt_id
)
VALUES (
    NOW(),
    '중복 정산 테스트',
    @test_admin_id,
    @test_receipt_id
);


-- 10. 중복 후보의 자기 자신 비교 차단 확인
-- 예상 결과: 오류 3819 (chk_duplicate_candidates_different)
INSERT INTO duplicate_candidates (
    match_reason, score, created_at,
    receipt_id, candidate_receipt_id
)
VALUES (
    '자기 자신 비교 차단 테스트',
    1.000000,
    NOW(),
    @test_receipt_id,
    @test_receipt_id
);


-- 11. 중복 후보 저장 및 동일 조합 중복 차단 확인
INSERT INTO receipts (
    purpose, submitted_at, updated_at,
    submitter_id, category_id
)
VALUES (
    '중복 후보 비교용 영수증',
    NOW(),
    NOW(),
    @test_user_id,
    @test_category_id
);

SET @candidate_id = LAST_INSERT_ID();

-- 첫 번째 후보 기록: 저장 성공
INSERT INTO duplicate_candidates (
    match_reason, score, created_at,
    receipt_id, candidate_receipt_id
)
VALUES (
    'DB 테스트용 유사 후보',
    0.950000,
    NOW(),
    @test_receipt_id,
    @candidate_id
);

SELECT id, receipt_id, candidate_receipt_id, score
FROM duplicate_candidates
WHERE receipt_id = @test_receipt_id
  AND candidate_receipt_id = @candidate_id;

-- 동일 조합 재등록: 오류 1062 (uq_duplicate_candidates_pair)
INSERT INTO duplicate_candidates (
    match_reason, score, created_at,
    receipt_id, candidate_receipt_id
)
VALUES (
    '동일 조합 중복 저장 테스트',
    0.950000,
    NOW(),
    @test_receipt_id,
    @candidate_id
);


-- 12. 허용되지 않은 사용자 역할 차단 확인
-- 예상 결과: 오류 3819 (chk_users_role)
INSERT INTO users (
    name, email, password_hash, role,
    created_at, updated_at
)
VALUES (
    '역할 제한 테스트',
    'roletest@example.com',
    'test_hash_not_for_login',
    'MANAGER',
    NOW(),
    NOW()
);


-- 13. 허용되지 않은 영수증 상태 차단 확인
-- 예상 결과: 오류 3819 (chk_receipts_status)
INSERT INTO receipts (
    purpose, status, submitted_at, updated_at,
    submitter_id, category_id
)
VALUES (
    '상태 제한 테스트',
    'INVALID_STATUS',
    NOW(),
    NOW(),
    @test_user_id,
    @test_category_id
);


-- 14. 카테고리 이름 중복 차단 확인
-- 예상 결과: 오류 1062 (uq_categories_name)
INSERT INTO categories (
    name, description
)
VALUES (
    'DB 테스트 카테고리',
    '카테고리 이름 중복 차단 테스트'
);