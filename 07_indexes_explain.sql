USE DataFrontiers_Review;

-- ==============================================================================
-- 07_indexes_explain.sql
-- Mục tiêu: Phân tích hiệu năng, tạo index và so sánh EXPLAIN trước/sau
-- ==============================================================================

-- ==============================================================================
-- 0. HIỂN THỊ INDEX HIỆN TẠI (để so sánh sau khi tạo)
-- ==============================================================================
SELECT '=== INDEX HIỆN TẠI TRÊN BẢNG MANUSCRIPT ===' AS '';
SHOW INDEX FROM MANUSCRIPT;

SELECT '=== INDEX HIỆN TẠI TRÊN BẢNG REVIEW_ASSIGNMENT ===' AS '';
SHOW INDEX FROM REVIEW_ASSIGNMENT;

-- ==============================================================================
-- 1. KIỂM TRA HIỆU NĂNG TRƯỚC KHI TẠO INDEX
-- ==============================================================================

-- 1.1 Query lọc theo status + received_date (Q01 mở rộng)
-- Lưu ý: Sử dụng BETWEEN thay vì YEAR() để tận dụng index
EXPLAIN SELECT manuscript_id, title, status, received_date 
FROM MANUSCRIPT 
WHERE status = 'under_review' 
  AND received_date BETWEEN '2026-01-01' AND '2026-12-31';

-- 1.2 Query JOIN giữa REVIEWER, PERSON, REVIEW_ASSIGNMENT (Q04)
EXPLAIN SELECT p.full_name, COUNT(ra.assignment_id) 
FROM REVIEWER r
INNER JOIN PERSON p ON r.person_id = p.person_id
INNER JOIN REVIEW_ASSIGNMENT ra ON r.person_id = ra.reviewer_id
GROUP BY p.person_id, p.full_name;

-- ==============================================================================
-- 2. TẠO INDEX TỐI ƯU HÓA HIỆU NĂNG
-- ==============================================================================

-- 2.1 Index 1: Hỗ trợ lọc theo status và received_date
-- Cần thiết khi dữ liệu lớn (hàng nghìn bài)
CREATE INDEX idx_status_received ON MANUSCRIPT (status, received_date);

-- 2.2 Index 2: Hỗ trợ JOIN giữa REVIEW_ASSIGNMENT và REVIEWER/MANUSCRIPT
-- Giảm table scan khi thống kê số bài của reviewer
CREATE INDEX idx_manuscript_reviewer ON REVIEW_ASSIGNMENT (manuscript_id, reviewer_id);

-- ==============================================================================
-- 3. KIỂM TRA LẠI HIỆU NĂNG SAU KHI CÓ INDEX (so sánh với bước 1)
-- ==============================================================================

-- 3.1 Chạy lại query 1 và xem sự thay đổi
-- Kỳ vọng: type chuyển từ ALL hoặc index sang ref/range, possible_keys hiển thị idx_status_received
EXPLAIN SELECT manuscript_id, title, status, received_date 
FROM MANUSCRIPT 
WHERE status = 'under_review' 
  AND received_date BETWEEN '2026-01-01' AND '2026-12-31';

-- 3.2 Chạy lại query 2
-- Kỳ vọng: possible_keys hiển thị idx_manuscript_reviewer, type là ref hoặc index
EXPLAIN SELECT p.full_name, COUNT(ra.assignment_id) 
FROM REVIEWER r
INNER JOIN PERSON p ON r.person_id = p.person_id
INNER JOIN REVIEW_ASSIGNMENT ra ON r.person_id = ra.reviewer_id
GROUP BY p.person_id, p.full_name;

-- ==============================================================================
-- 4. HIỂN THỊ LẠI INDEX SAU KHI TẠO (để kiểm tra)
-- ==============================================================================
SELECT '=== INDEX SAU KHI TẠO (MANUSCRIPT) ===' AS '';
SHOW INDEX FROM MANUSCRIPT;

SELECT '=== INDEX SAU KHI TẠO (REVIEW_ASSIGNMENT) ===' AS '';
SHOW INDEX FROM REVIEW_ASSIGNMENT;

-- ==============================================================================
-- 5. (TÙY CHỌN) Dùng FORCE INDEX để minh họa sử dụng index
-- ==============================================================================
-- Trong thực tế, MySQL optimizer tự chọn index tốt nhất, nhưng có thể dùng FORCE INDEX để ép
EXPLAIN SELECT manuscript_id, title, status, received_date 
FROM MANUSCRIPT FORCE INDEX (idx_status_received)
WHERE status = 'under_review' 
  AND received_date BETWEEN '2026-01-01' AND '2026-12-31';

-- ==============================================================================
-- 6. GIẢI THÍCH NGẮN
-- ==============================================================================
-- Dự kiến kết quả trước khi tạo index:
-- - Query 1: type = ALL (table scan), rows ≈ tổng số dòng trong MANUSCRIPT (khoảng 7), Extra = Using where
-- - Query 2: type = ALL (table scan), rows ≈ số dòng trong REVIEW_ASSIGNMENT
-- 
-- Dự kiến kết quả sau khi tạo index:
-- - Query 1: type = ref (hoặc range), possible_keys = idx_status_received, key = idx_status_received, rows nhỏ hơn nhiều
-- - Query 2: type = ref, possible_keys = idx_manuscript_reviewer, key = idx_manuscript_reviewer
-- 
-- Lưu ý: Với dữ liệu nhỏ (7 bài), MySQL optimizer có thể vẫn chọn table scan. 
-- Tuy nhiên, với dữ liệu thực tế (hàng trăm bài), index sẽ giúp giảm rows từ vài trăm xuống còn vài dòng.
-- ==============================================================================