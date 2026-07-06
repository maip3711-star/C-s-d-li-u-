-- ==============================================================================
-- 09_tests.sql - DataFrontiers Review Quarterly
-- Phiên bản: Final (Đã fix lỗi "reviewer đã được phân công")
-- Mô tả: Bộ test Positive và Negative cho toàn bộ hệ thống
-- Môi trường: MySQL 8+, InnoDB
-- ==============================================================================

USE DataFrontiers_Review;

-- ==============================================================================
-- 0. XÓA CÁC PROCEDURE TEST CŨ (nếu có)
-- ==============================================================================
DROP PROCEDURE IF EXISTS test_unique_email;
DROP PROCEDURE IF EXISTS test_score_check;
DROP PROCEDURE IF EXISTS test_page_overlap;
DROP PROCEDURE IF EXISTS test_pubdate;
DROP PROCEDURE IF EXISTS test_short_comment;
DROP PROCEDURE IF EXISTS test_assign_reviewer_success;
DROP PROCEDURE IF EXISTS test_assign_reviewer_duplicate;
DROP PROCEDURE IF EXISTS test_assign_reviewer_author;

-- ==============================================================================
-- 1. POSITIVE TESTS
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- TEST P01: Gán reviewer cho bài MF-26-004 (chưa có assignment) - dùng reviewer 12 (chưa có)
-- -----------------------------------------------------------------------------
SELECT '=== Test P01: sp_assign_reviewer (hợp lệ - bài mới) ===' AS '';

START TRANSACTION;

-- Lưu trạng thái cũ
SET @old_status = (SELECT status FROM MANUSCRIPT WHERE manuscript_id = 'MF-26-004');
SET @old_count = (SELECT COUNT(*) FROM REVIEW_ASSIGNMENT WHERE manuscript_id = 'MF-26-004');

-- Gọi procedure với bài MF-26-004 và reviewer 12 (chưa có assignment)
CALL sp_assign_reviewer('MF-26-004', 12, '2026-07-15 23:59:59');

-- Kiểm tra kết quả: số assignment tăng lên 1, status vẫn 'received'
SELECT 
    'P01' AS test_id,
    'Gán reviewer 12 cho MF-26-004' AS description,
    (SELECT status FROM MANUSCRIPT WHERE manuscript_id = 'MF-26-004') AS actual_status,
    'received' AS expected_status,
    CASE 
        WHEN (SELECT COUNT(*) FROM REVIEW_ASSIGNMENT WHERE manuscript_id = 'MF-26-004') = @old_count + 1 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS result;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- TEST P02: Xuất bản Issue 2 (rollback)
-- -----------------------------------------------------------------------------
SELECT '=== Test P02: sp_publish_issue (hợp lệ) ===' AS '';

START TRANSACTION;

SET @old_issue_status = (SELECT issue_status FROM ISSUE WHERE issue_id = 2);

CALL sp_publish_issue(2);

SELECT 
    'P02' AS test_id,
    'Xuất bản Issue 2' AS description,
    (SELECT issue_status FROM ISSUE WHERE issue_id = 2) AS actual_status,
    'published' AS expected_status,
    CASE 
        WHEN (SELECT issue_status FROM ISSUE WHERE issue_id = 2) = 'published' 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS result;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- TEST P03: Test Function fn_get_avg_score
-- -----------------------------------------------------------------------------
SELECT '=== Test P03: fn_get_avg_score ===' AS '';

SELECT 
    'P03' AS test_id,
    'Điểm trung bình của MF-26-001' AS description,
    fn_get_avg_score('MF-26-001') AS actual_score,
    '~8.8' AS expected,
    CASE 
        WHEN ABS(fn_get_avg_score('MF-26-001') - 8.75) < 0.1 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS result;

-- -----------------------------------------------------------------------------
-- TEST P04: Test View vw_manuscript_review_summary
-- -----------------------------------------------------------------------------
SELECT '=== Test P04: vw_manuscript_review_summary ===' AS '';

SELECT 
    'P04' AS test_id,
    'View có dữ liệu cho MF-26-001' AS description,
    COUNT(*) AS row_count,
    '>0' AS expected,
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS' 
        ELSE 'FAIL' 
    END AS result
FROM vw_manuscript_review_summary
WHERE manuscript_id = 'MF-26-001';

-- -----------------------------------------------------------------------------
-- TEST P05: Trigger Audit - cập nhật status
-- -----------------------------------------------------------------------------
SELECT '=== Test P05: Trigger Audit (ghi log) ===' AS '';

START TRANSACTION;

SET @initial_audit_count = (SELECT COUNT(*) FROM MANUSCRIPT_AUDIT WHERE manuscript_id = 'MF-26-004');

UPDATE MANUSCRIPT SET status = 'under_review' WHERE manuscript_id = 'MF-26-004';

SELECT 
    'P05' AS test_id,
    'Update status MF-26-004' AS description,
    (SELECT COUNT(*) FROM MANUSCRIPT_AUDIT WHERE manuscript_id = 'MF-26-004') AS actual_logs,
    @initial_audit_count + 1 AS expected_logs,
    CASE 
        WHEN (SELECT COUNT(*) FROM MANUSCRIPT_AUDIT WHERE manuscript_id = 'MF-26-004') > @initial_audit_count 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS result;

ROLLBACK;

-- ==============================================================================
-- 2. NEGATIVE TESTS
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- TEST N01: UNIQUE email
-- -----------------------------------------------------------------------------
SELECT '=== Test N01: Vi phạm UNIQUE email ===' AS '';

DELIMITER //
DROP PROCEDURE IF EXISTS test_unique_email //
CREATE PROCEDURE test_unique_email()
BEGIN
    DECLARE EXIT HANDLER FOR SQLSTATE '23000' 
    BEGIN
        SELECT 'N01' AS test_id, 'INSERT email trùng' AS description, 
               'PASS' AS result, 'UNIQUE constraint violated' AS caught_error;
    END;
    INSERT INTO PERSON (full_name, email, affiliation) 
    VALUES ('Hacker', 'tuananh.editor@datafrontiers.org', 'Hack Organization');
    SELECT 'N01' AS test_id, 'INSERT email trùng' AS description, 
           'FAIL' AS result, 'Expected UNIQUE error but no error' AS caught_error;
END //
DELIMITER ;

CALL test_unique_email();
DROP PROCEDURE test_unique_email;

-- -----------------------------------------------------------------------------
-- TEST N02: CHECK score >10
-- -----------------------------------------------------------------------------
SELECT '=== Test N02: Vi phạm CHECK score ===' AS '';

DELIMITER //
DROP PROCEDURE IF EXISTS test_score_check //
CREATE PROCEDURE test_score_check()
BEGIN
    DECLARE EXIT HANDLER FOR SQLSTATE 'HY000' 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errno = MYSQL_ERRNO;
        IF @errno = 3819 THEN
            SELECT 'N02' AS test_id, 'INSERT score > 10' AS description, 
                   'PASS' AS result, 'CHECK constraint violated' AS caught_error;
        ELSE
            RESIGNAL;
        END IF;
    END;
    INSERT INTO REVIEW_SCORE (review_id, criterion_id, score) VALUES (1, 1, 11.0);
    SELECT 'N02' AS test_id, 'INSERT score > 10' AS description, 
           'FAIL' AS result, 'Expected CHECK error but no error' AS caught_error;
END //
DELIMITER ;

CALL test_score_check();
DROP PROCEDURE test_score_check;

-- -----------------------------------------------------------------------------
-- TEST N03: Trigger chống đè trang
-- -----------------------------------------------------------------------------
SELECT '=== Test N03: Trigger chống đè trang ===' AS '';

DELIMITER //
DROP PROCEDURE IF EXISTS test_page_overlap //
CREATE PROCEDURE test_page_overlap()
BEGIN
    DECLARE EXIT HANDLER FOR SQLSTATE '45000' 
    BEGIN
        SELECT 'N03' AS test_id, 'INSERT trang bị đè' AS description, 
               'PASS' AS result, 'Trigger prevented page overlap' AS caught_error;
    END;
    INSERT INTO MANUSCRIPT (manuscript_id, title, received_date, status, page_count, order_in_issue, start_page, editor_id, issue_id) 
    VALUES ('MF-FAIL-001','Bài đè trang', CURRENT_TIMESTAMP, 'scheduled', 5, 3, 12, 1, 1);
    SELECT 'N03' AS test_id, 'INSERT trang bị đè' AS description, 
           'FAIL' AS result, 'Expected page overlap error but no error' AS caught_error;
END //
DELIMITER ;

CALL test_page_overlap();
DROP PROCEDURE test_page_overlap;

-- -----------------------------------------------------------------------------
-- TEST N04: publication_date sai
-- -----------------------------------------------------------------------------
SELECT '=== Test N04: Publication date trước ngày nhận bài ===' AS '';

DELIMITER //
DROP PROCEDURE IF EXISTS test_pubdate //
CREATE PROCEDURE test_pubdate()
BEGIN
    DECLARE EXIT HANDLER FOR SQLSTATE '45000' 
    BEGIN
        SELECT 'N04' AS test_id, 'UPDATE publication_date sớm' AS description, 
               'PASS' AS result, 'Trigger prevented invalid pub date' AS caught_error;
    END;
    UPDATE ISSUE SET publication_date = '2025-01-01', issue_status = 'published' WHERE issue_id = 1;
    SELECT 'N04' AS test_id, 'UPDATE publication_date sớm' AS description, 
           'FAIL' AS result, 'Expected pub date error but no error' AS caught_error;
END //
DELIMITER ;

CALL test_pubdate();
DROP PROCEDURE test_pubdate;

-- -----------------------------------------------------------------------------
-- TEST N05: Comments quá ngắn
-- -----------------------------------------------------------------------------
SELECT '=== Test N05: Comments quá ngắn ===' AS '';

DELIMITER //
DROP PROCEDURE IF EXISTS test_short_comment //
CREATE PROCEDURE test_short_comment()
BEGIN
    DECLARE EXIT HANDLER FOR SQLSTATE 'HY000' 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errno = MYSQL_ERRNO;
        IF @errno = 3819 THEN
            SELECT 'N05' AS test_id, 'INSERT comment ngắn' AS description, 
                   'PASS' AS result, 'CHECK constraint violated' AS caught_error;
        ELSE
            RESIGNAL;
        END IF;
    END;
    INSERT INTO REVIEW (assignment_id, deadline_date, response_date, recommendation, comments) 
    VALUES (1, '2026-12-31', '2026-12-30', 'accept', 'Ngắn');
    SELECT 'N05' AS test_id, 'INSERT comment ngắn' AS description, 
           'FAIL' AS result, 'Expected CHECK error but no error' AS caught_error;
END //
DELIMITER ;

CALL test_short_comment();
DROP PROCEDURE test_short_comment;

-- -----------------------------------------------------------------------------
-- TEST N06: Gán trùng reviewer
-- -----------------------------------------------------------------------------
SELECT '=== Test N06: Gán trùng reviewer ===' AS '';

DELIMITER //
DROP PROCEDURE IF EXISTS test_assign_reviewer_duplicate //
CREATE PROCEDURE test_assign_reviewer_duplicate()
BEGIN
    DECLARE EXIT HANDLER FOR SQLSTATE '45000' 
    BEGIN
        SELECT 'N06' AS test_id, 'Gán trùng reviewer' AS description, 
               'PASS' AS result, 'Business rule prevented duplicate' AS caught_error;
    END;
    -- Gán lại reviewer 3 cho MF-26-001 (đã có)
    CALL sp_assign_reviewer('MF-26-001', 3, '2026-12-31');
    SELECT 'N06' AS test_id, 'Gán trùng reviewer' AS description, 
           'FAIL' AS result, 'Expected duplicate error but no error' AS caught_error;
END //
DELIMITER ;

CALL test_assign_reviewer_duplicate();
DROP PROCEDURE test_assign_reviewer_duplicate;

-- -----------------------------------------------------------------------------
-- TEST N07: Tác giả tự phản biện
-- -----------------------------------------------------------------------------
SELECT '=== Test N07: Tác giả tự phản biện ===' AS '';

DELIMITER //
DROP PROCEDURE IF EXISTS test_assign_reviewer_author //
CREATE PROCEDURE test_assign_reviewer_author()
BEGIN
    DECLARE EXIT HANDLER FOR SQLSTATE '45000' 
    BEGIN
        SELECT 'N07' AS test_id, 'Tác giả tự phản biện' AS description, 
               'PASS' AS result, 'Business rule prevented self-review' AS caught_error;
    END;
    -- Gán person_id = 6 (tác giả) làm reviewer cho MF-26-001
    CALL sp_assign_reviewer('MF-26-001', 6, '2026-12-31');
    SELECT 'N07' AS test_id, 'Tác giả tự phản biện' AS description, 
           'FAIL' AS result, 'Expected self-review error but no error' AS caught_error;
END //
DELIMITER ;

CALL test_assign_reviewer_author();
DROP PROCEDURE test_assign_reviewer_author;

-- ==============================================================================
-- 3. TỔNG KẾT
-- ==============================================================================
SELECT '=== KẾT THÚC KIỂM THỬ ===' AS '';
SELECT 'Vui lòng kiểm tra từng kết quả PASS/FAIL ở trên.' AS Note;

-- ==============================================================================
-- 4. DỌN DẸP
-- ==============================================================================
-- Các test đều rollback, dữ liệu mẫu giữ nguyên.
-- ==============================================================================