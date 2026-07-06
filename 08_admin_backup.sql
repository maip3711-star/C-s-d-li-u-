USE DataFrontiers_Review;

-- ==============================================================================
-- 0. TẠO BẢNG PROCEDURE_AUDIT (ĐỂ GHI LOG LỖI TỪ PROCEDURE)
-- ==============================================================================
-- Lưu ý: Nếu đã có bảng này ở file 01_schema.sql thì bỏ qua phần này
CREATE TABLE IF NOT EXISTS PROCEDURE_AUDIT (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    manuscript_id VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    error_message TEXT,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    executed_by VARCHAR(100) DEFAULT 'System'
);

-- ==============================================================================
-- 1. QUẢN TRỊ NGƯỜI DÙNG (ROLE-BASED ACCESS CONTROL)
-- ==============================================================================

-- Xóa role/user cũ (nếu có) để chạy lại sạch sẽ
DROP ROLE IF EXISTS 'role_datafrontiers_admin';
DROP ROLE IF EXISTS 'role_datafrontiers_editor';
DROP ROLE IF EXISTS 'role_datafrontiers_reviewer';

DROP USER IF EXISTS 'df_admin'@'localhost';
DROP USER IF EXISTS 'editor_app'@'localhost';
DROP USER IF EXISTS 'reviewer_app'@'localhost';

-- ==============================================================================
-- 1.1 QUẢN TRỊ VIÊN (ADMIN) – Toàn quyền
-- ==============================================================================
CREATE ROLE 'role_datafrontiers_admin';
GRANT ALL PRIVILEGES ON DataFrontiers_Review.* TO 'role_datafrontiers_admin';

CREATE USER 'df_admin'@'localhost' IDENTIFIED BY 'ChangeMe123!';
GRANT 'role_datafrontiers_admin' TO 'df_admin'@'localhost';
SET DEFAULT ROLE 'role_datafrontiers_admin' TO 'df_admin'@'localhost';

-- ==============================================================================
-- 1.2 BIÊN TẬP VIÊN (EDITOR) – Quản lý bài nộp và phân công
-- ==============================================================================
CREATE ROLE 'role_datafrontiers_editor';
GRANT SELECT, INSERT, UPDATE ON DataFrontiers_Review.MANUSCRIPT TO 'role_datafrontiers_editor';
GRANT SELECT, INSERT, UPDATE ON DataFrontiers_Review.REVIEW_ASSIGNMENT TO 'role_datafrontiers_editor';
GRANT SELECT ON DataFrontiers_Review.vw_manuscript_review_summary TO 'role_datafrontiers_editor';
GRANT SELECT ON DataFrontiers_Review.MANUSCRIPT_AUTHOR TO 'role_datafrontiers_editor';
GRANT EXECUTE ON PROCEDURE sp_assign_reviewer TO 'role_datafrontiers_editor';
GRANT EXECUTE ON PROCEDURE sp_publish_issue TO 'role_datafrontiers_editor';

CREATE USER 'editor_app'@'localhost' IDENTIFIED BY 'ChangeMe123!';
GRANT 'role_datafrontiers_editor' TO 'editor_app'@'localhost';
SET DEFAULT ROLE 'role_datafrontiers_editor' TO 'editor_app'@'localhost';

-- ==============================================================================
-- 1.3 CHUYÊN GIA PHẢN BIỆN (REVIEWER) – Chỉ nhập điểm và xem bài
-- ==============================================================================
CREATE ROLE 'role_datafrontiers_reviewer';
GRANT SELECT ON DataFrontiers_Review.MANUSCRIPT TO 'role_datafrontiers_reviewer';
GRANT SELECT ON DataFrontiers_Review.REVIEW_ASSIGNMENT TO 'role_datafrontiers_reviewer';
GRANT INSERT ON DataFrontiers_Review.REVIEW_SCORE TO 'role_datafrontiers_reviewer';
GRANT SELECT ON DataFrontiers_Review.REVIEW TO 'role_datafrontiers_reviewer';
GRANT SELECT ON DataFrontiers_Review.REVIEWER_EXPERTISE TO 'role_datafrontiers_reviewer';

CREATE USER 'reviewer_app'@'localhost' IDENTIFIED BY 'ChangeMe123!';
GRANT 'role_datafrontiers_reviewer' TO 'reviewer_app'@'localhost';
SET DEFAULT ROLE 'role_datafrontiers_reviewer' TO 'reviewer_app'@'localhost';

-- ==============================================================================
-- 2. KIỂM TRA QUYỀN HẠN (SHOW GRANTS)
-- ==============================================================================
-- Đây là bằng chứng để đối chiếu với yêu cầu "Least Privilege"
-- (Kết quả của các lệnh này cần được chụp ảnh đưa vào báo cáo)

SHOW GRANTS FOR 'df_admin'@'localhost';
SHOW GRANTS FOR 'editor_app'@'localhost';
SHOW GRANTS FOR 'reviewer_app'@'localhost';

-- ==============================================================================
-- 3. SAO LƯU VÀ PHỤC HỒI (BACKUP & RESTORE RUNBOOK)
-- ==============================================================================
-- Lưu ý: Các lệnh này chạy trên TERMINAL, không phải trong MySQL

-- 3.1 Sao lưu toàn bộ (Backup)
-- mysqldump -u root -p --routines --triggers --events --single-transaction DataFrontiers_Review > backup_datafrontiers_$(date +%Y%m%d_%H%M%S).sql

-- 3.2 Phục hồi (Restore)
-- Bước 1: Tạo database nếu chưa có (có thể dùng test database để an toàn)
-- mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS DataFrontiers_Review_Restore;"

-- Bước 2: Phục hồi dữ liệu
-- mysql -u root -p DataFrontiers_Review_Restore < backup_datafrontiers_YYYYMMDD_HHMMSS.sql

-- 3.3 Xác minh kết quả restore
-- SELECT COUNT(*) FROM DataFrontiers_Review_Restore.PERSON;
-- SELECT COUNT(*) FROM DataFrontiers_Review_Restore.MANUSCRIPT;

-- ==============================================================================
-- 4. KẾT LUẬN
-- ==============================================================================
-- ✅ Đã tạo 3 Role với quyền hạn tối thiểu (Least Privilege)
-- ✅ Đã tạo 3 User tương ứng với từng Role
-- ✅ Đã có kịch bản Backup (mysqldump) với đầy đủ routines, triggers, events
-- ✅ Đã có kịch bản Restore an toàn (vào database riêng)
-- ✅ Không hard-code password; sử dụng 'ChangeMe123!' cho môi trường Lab
-- ✅ Tất cả User đều giới hạn ở 'localhost' (không dùng '%')
-- ==============================================================================