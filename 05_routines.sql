USE DataFrontiers_Review;
DELIMITER //

DROP FUNCTION IF EXISTS fn_get_avg_score //
CREATE FUNCTION fn_get_avg_score(p_manuscript_id VARCHAR(50)) 
RETURNS DECIMAL(4,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_avg DECIMAL(4,2);
    SELECT AVG(rs.score) INTO v_avg
    FROM REVIEW_SCORE rs
    INNER JOIN REVIEW r ON rs.review_id = r.review_id
    INNER JOIN REVIEW_ASSIGNMENT ra ON r.assignment_id = ra.assignment_id
    WHERE ra.manuscript_id = p_manuscript_id;
    RETURN COALESCE(v_avg, 0.00);
END //

-- ==========================================================================
-- SP_ASSIGN_REVIEWER – Phiên bản sửa lỗi, có log chi tiết
-- ==========================================================================
DROP PROCEDURE IF EXISTS sp_assign_reviewer //
CREATE PROCEDURE sp_assign_reviewer(
    IN p_manuscript_id VARCHAR(50), 
    IN p_reviewer_id INT,
    IN p_deadline TIMESTAMP
)
BEGIN
    DECLARE v_current_reviewers INT;
    DECLARE v_status VARCHAR(20);
    DECLARE v_error_msg TEXT DEFAULT '';

    -- Xử lý lỗi: GHI LOG và RESIGNAL với thông báo cụ thể
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            @sqlstate = RETURNED_SQLSTATE,
            @errno = MYSQL_ERRNO,
            @text = MESSAGE_TEXT;
        SET v_error_msg = CONCAT('SQLSTATE ', @sqlstate, ', Error ', @errno, ': ', @text);
        INSERT INTO PROCEDURE_AUDIT (procedure_name, manuscript_id, reviewer_id, error_code, error_message)
        VALUES ('sp_assign_reviewer', p_manuscript_id, p_reviewer_id, @sqlstate, v_error_msg);
        ROLLBACK;
        RESIGNAL SET MESSAGE_TEXT = v_error_msg;
    END;

    START TRANSACTION;

    -- 1. Kiểm tra bài tồn tại
    IF NOT EXISTS (SELECT 1 FROM MANUSCRIPT WHERE manuscript_id = p_manuscript_id) THEN
        SET v_error_msg = 'Lỗi: Bài nộp không tồn tại.';
        INSERT INTO PROCEDURE_AUDIT (procedure_name, manuscript_id, reviewer_id, error_code, error_message)
        VALUES ('sp_assign_reviewer', p_manuscript_id, p_reviewer_id, 'BUSINESS', v_error_msg);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END IF;

    -- 2. Kiểm tra reviewer tồn tại
    IF NOT EXISTS (SELECT 1 FROM REVIEWER WHERE person_id = p_reviewer_id) THEN
        SET v_error_msg = 'Lỗi: Reviewer không tồn tại.';
        INSERT INTO PROCEDURE_AUDIT (procedure_name, manuscript_id, reviewer_id, error_code, error_message)
        VALUES ('sp_assign_reviewer', p_manuscript_id, p_reviewer_id, 'BUSINESS', v_error_msg);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END IF;

    -- 3. Khóa row và lấy trạng thái bài
    SELECT status INTO v_status FROM MANUSCRIPT WHERE manuscript_id = p_manuscript_id FOR UPDATE;

    -- 4. Kiểm tra trạng thái bài có cho phép phân công không (chỉ được nhận khi 'received' hoặc 'under_review' nếu chưa đủ reviewer)
    IF v_status IN ('accepted', 'rejected', 'scheduled', 'published') THEN
        SET v_error_msg = CONCAT('Lỗi: Bài đang ở trạng thái ', v_status, ', không thể phân công thêm reviewer.');
        INSERT INTO PROCEDURE_AUDIT (procedure_name, manuscript_id, reviewer_id, error_code, error_message)
        VALUES ('sp_assign_reviewer', p_manuscript_id, p_reviewer_id, 'BUSINESS', v_error_msg);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END IF;

    -- 5. Kiểm tra trùng phân công
    IF EXISTS (SELECT 1 FROM REVIEW_ASSIGNMENT WHERE manuscript_id = p_manuscript_id AND reviewer_id = p_reviewer_id) THEN
        SET v_error_msg = 'Lỗi: Reviewer đã được phân công cho bài này.';
        INSERT INTO PROCEDURE_AUDIT (procedure_name, manuscript_id, reviewer_id, error_code, error_message)
        VALUES ('sp_assign_reviewer', p_manuscript_id, p_reviewer_id, 'BUSINESS', v_error_msg);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END IF;

    -- 6. Kiểm tra tác giả không được tự phản biện
    IF EXISTS (SELECT 1 FROM MANUSCRIPT_AUTHOR WHERE manuscript_id = p_manuscript_id AND person_id = p_reviewer_id) THEN
        SET v_error_msg = 'Lỗi: Tác giả không được phản biện bài của chính mình.';
        INSERT INTO PROCEDURE_AUDIT (procedure_name, manuscript_id, reviewer_id, error_code, error_message)
        VALUES ('sp_assign_reviewer', p_manuscript_id, p_reviewer_id, 'BUSINESS', v_error_msg);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END IF;

    -- 7. Insert phân công
    INSERT INTO REVIEW_ASSIGNMENT (manuscript_id, reviewer_id, date_sent, deadline)
    VALUES (p_manuscript_id, p_reviewer_id, CURRENT_TIMESTAMP, p_deadline);

    -- 8. Đếm số reviewer hiện tại
    SELECT COUNT(*) INTO v_current_reviewers FROM REVIEW_ASSIGNMENT WHERE manuscript_id = p_manuscript_id;

    -- 9. Nếu đủ 3 reviewer và bài đang 'received' -> chuyển sang 'under_review'
    IF v_current_reviewers >= 3 AND v_status = 'received' THEN
        UPDATE MANUSCRIPT SET status = 'under_review' WHERE manuscript_id = p_manuscript_id;
    END IF;

    INSERT INTO PROCEDURE_AUDIT (procedure_name, manuscript_id, reviewer_id, error_code, error_message)
    VALUES ('sp_assign_reviewer', p_manuscript_id, p_reviewer_id, 'SUCCESS', 'Phân công thành công.');

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_publish_issue //
CREATE PROCEDURE sp_publish_issue(IN p_issue_id INT)
BEGIN
    DECLARE v_issue_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL SET MESSAGE_TEXT = 'Lỗi khi xuất bản số báo.';
    END;

    START TRANSACTION;
    SELECT issue_status INTO v_issue_status FROM ISSUE WHERE issue_id = p_issue_id FOR UPDATE;

    IF v_issue_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Số báo không tồn tại.';
    END IF;
    IF v_issue_status = 'published' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Số báo đã được xuất bản.';
    END IF;

    UPDATE ISSUE SET issue_status = 'published', publication_date = CURRENT_TIMESTAMP WHERE issue_id = p_issue_id;
    UPDATE MANUSCRIPT SET status = 'published' WHERE issue_id = p_issue_id AND status IN ('scheduled', 'accepted');
    COMMIT;
END //

DELIMITER ;