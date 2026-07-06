USE DataFrontiers_Review;

-- ==============================================================================
-- 06_triggers_events.sql - DataFrontiers Review Quarterly
-- Phiên bản: Final
-- Mô tả: Định nghĩa các Triggers và Event Scheduler
-- Môi trường: MySQL 8+, InnoDB
-- ==============================================================================

-- ==============================================================================
-- 1. TRIGGERS
-- ==============================================================================

DELIMITER //

-- 1.1 TRIGGER: Trg_Prevent_Page_Overlap_Insert
-- Ngăn chặn xếp trang đè lên nhau khi INSERT
DROP TRIGGER IF EXISTS Trg_Prevent_Page_Overlap_Insert //
CREATE TRIGGER Trg_Prevent_Page_Overlap_Insert
BEFORE INSERT ON MANUSCRIPT
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT;
    IF NEW.issue_id IS NOT NULL AND NEW.start_page IS NOT NULL AND NEW.page_count IS NOT NULL THEN
        SELECT COUNT(*) INTO overlap_count
        FROM MANUSCRIPT
        WHERE issue_id = NEW.issue_id
          AND (
              (NEW.start_page BETWEEN start_page AND (start_page + page_count - 1))
              OR ((NEW.start_page + NEW.page_count - 1) BETWEEN start_page AND (start_page + page_count - 1))
              OR (start_page BETWEEN NEW.start_page AND (NEW.start_page + NEW.page_count - 1))
          );
        IF overlap_count > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi Nghiệp Vụ: Xung đột dải số trang, khoảng trang bị đè lên bài viết khác.';
        END IF;
    END IF;
END //

-- 1.2 TRIGGER: Trg_Prevent_Page_Overlap_Update
-- Ngăn chặn xếp trang đè lên nhau khi UPDATE
DROP TRIGGER IF EXISTS Trg_Prevent_Page_Overlap_Update //
CREATE TRIGGER Trg_Prevent_Page_Overlap_Update
BEFORE UPDATE ON MANUSCRIPT
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT;
    IF NEW.issue_id IS NOT NULL AND NEW.start_page IS NOT NULL AND NEW.page_count IS NOT NULL THEN
        SELECT COUNT(*) INTO overlap_count
        FROM MANUSCRIPT
        WHERE issue_id = NEW.issue_id
          AND manuscript_id != NEW.manuscript_id
          AND (
              (NEW.start_page BETWEEN start_page AND (start_page + page_count - 1))
              OR ((NEW.start_page + NEW.page_count - 1) BETWEEN start_page AND (start_page + page_count - 1))
              OR (start_page BETWEEN NEW.start_page AND (NEW.start_page + NEW.page_count - 1))
          );
        IF overlap_count > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi Nghiệp Vụ: Xung đột dải số trang, khoảng trang bị đè lên bài viết khác.';
        END IF;
    END IF;
END //

-- 1.3 TRIGGER: trg_check_publication_date
-- Kiểm tra publication_date của Issue không được trước ngày nhận bài đầu tiên
DROP TRIGGER IF EXISTS trg_check_publication_date //
CREATE TRIGGER trg_check_publication_date
BEFORE UPDATE ON ISSUE
FOR EACH ROW
BEGIN
    DECLARE min_received TIMESTAMP;
    IF NEW.publication_date IS NOT NULL THEN
        SELECT MIN(received_date) INTO min_received FROM MANUSCRIPT WHERE issue_id = NEW.issue_id;
        IF min_received IS NOT NULL AND NEW.publication_date < min_received THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi Logic: Số báo không thể xuất bản trước khi nhận bài đầu tiên.';
        END IF;
    END IF;
END //

-- 1.4 TRIGGER: trg_audit_manuscript_status
-- Tự động ghi nhật ký khi trạng thái bài thay đổi
DROP TRIGGER IF EXISTS trg_audit_manuscript_status //
CREATE TRIGGER trg_audit_manuscript_status
AFTER UPDATE ON MANUSCRIPT
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO MANUSCRIPT_AUDIT (manuscript_id, old_status, new_status, changed_date)
        VALUES (NEW.manuscript_id, OLD.status, NEW.status, CURRENT_TIMESTAMP);
    END IF;
END //

-- 1.5 TRIGGER: trg_check_review_scores_insert
-- Đảm bảo mỗi REVIEW có đúng 4 điểm (INSERT)
DROP TRIGGER IF EXISTS trg_check_review_scores_insert //
CREATE TRIGGER trg_check_review_scores_insert
AFTER INSERT ON REVIEW_SCORE
FOR EACH ROW
BEGIN
    DECLARE score_count INT;
    SELECT COUNT(*) INTO score_count FROM REVIEW_SCORE WHERE review_id = NEW.review_id;
    IF score_count > 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Một review không được có quá 4 tiêu chí điểm.';
    END IF;
END //

-- 1.6 TRIGGER: trg_check_review_scores_delete
-- Đảm bảo mỗi REVIEW có đúng 4 điểm (DELETE)
DROP TRIGGER IF EXISTS trg_check_review_scores_delete //
CREATE TRIGGER trg_check_review_scores_delete
AFTER DELETE ON REVIEW_SCORE
FOR EACH ROW
BEGIN
    DECLARE score_count INT;
    SELECT COUNT(*) INTO score_count FROM REVIEW_SCORE WHERE review_id = OLD.review_id;
    IF score_count < 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Mỗi review phải có đủ 4 tiêu chí điểm.';
    END IF;
END //

-- 1.7 TRIGGER: trg_check_review_response_date
-- Đảm bảo response_date không nhỏ hơn date_sent
DROP TRIGGER IF EXISTS trg_check_review_response_date //
CREATE TRIGGER trg_check_review_response_date
BEFORE INSERT ON REVIEW
FOR EACH ROW
BEGIN
    DECLARE sent_date TIMESTAMP;
    SELECT date_sent INTO sent_date FROM REVIEW_ASSIGNMENT WHERE assignment_id = NEW.assignment_id;
    IF NEW.response_date < sent_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Ngày phản hồi không thể trước ngày gửi bài.';
    END IF;
END //

DELIMITER ;

-- ==============================================================================
-- 2. EVENT SCHEDULER
-- ==============================================================================

-- Bật Event Scheduler (chỉ cho môi trường Lab/Test)
SET GLOBAL event_scheduler = ON;

-- 2.1 Event: evt_cleanup_old_audit_logs
-- Dọn dẹp MANUSCRIPT_AUDIT (xóa log cũ hơn 1 năm)
-- Trạng thái: DISABLE (mặc định tắt để tránh thực thi ngoài ý muốn)

DROP EVENT IF EXISTS evt_cleanup_old_audit_logs;

DELIMITER //
CREATE EVENT evt_cleanup_old_audit_logs
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP
DISABLE  -- Tắt mặc định, muốn chạy thì ENABLE
DO
BEGIN
    DELETE FROM MANUSCRIPT_AUDIT 
    WHERE changed_date < DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 YEAR);
END //
DELIMITER ;

-- ==============================================================================
-- 3. TEST & KIỂM TRA
-- ==============================================================================

-- Kiểm tra danh sách các Trigger
SHOW TRIGGERS WHERE `Table` IN ('MANUSCRIPT', 'ISSUE', 'REVIEW_SCORE', 'REVIEW');

-- Kiểm tra trạng thái Event
SHOW EVENTS WHERE Db = 'DataFrontiers_Review';

-- Xem trạng thái Event Scheduler
SHOW STATUS LIKE 'event_scheduler%';

-- ==============================================================================
-- 4. HƯỚNG DẪN THỰC THI (Optional)
-- ==============================================================================
-- Để kích hoạt Event chạy tự động (chỉ trong Lab):
-- ALTER EVENT evt_cleanup_old_audit_logs ENABLE;
--
-- Để tạm dừng:
-- ALTER EVENT evt_cleanup_old_audit_logs DISABLE;
-- ==============================================================================
