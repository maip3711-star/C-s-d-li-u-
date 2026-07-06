-- ==============================================================================
-- 03_queries.sql - DataFrontiers Review Quarterly
-- Phiên bản: Final
-- Mô tả: 8 truy vấn nghiệp vụ (Q01 - Q08) đáp ứng yêu cầu của giảng viên
-- Môi trường: MySQL 8+, InnoDB
-- ==============================================================================

USE DataFrontiers_Review;

-- ==============================================================================
-- Q01 (Filter + Order): Danh sách bài nộp trong năm 2026, sắp xếp theo ngày nhận mới nhất.
-- Business question: Biên tập viên muốn xem tất cả bài đã nhận trong năm để theo dõi tiến độ.
-- ==============================================================================
SELECT manuscript_id, title, status, received_date
FROM MANUSCRIPT
WHERE YEAR(received_date) = 2026
ORDER BY received_date DESC;

-- ==============================================================================
-- Q02 (INNER JOIN 3+ tables): Danh sách tác giả và tên bài đã vượt qua vòng phản biện.
-- Business question: Ban biên tập muốn thống kê các tác giả có bài được chấp nhận hoặc xuất bản.
-- ==============================================================================
SELECT p.full_name AS author_name, m.title, m.status
FROM AUTHOR a
INNER JOIN PERSON p ON a.person_id = p.person_id
INNER JOIN MANUSCRIPT_AUTHOR ma ON a.person_id = ma.person_id
INNER JOIN MANUSCRIPT m ON ma.manuscript_id = m.manuscript_id
WHERE m.status IN ('accepted', 'scheduled', 'published');

-- ==============================================================================
-- Q03 (LEFT JOIN / tìm dữ liệu thiếu): Các Reviewer chưa từng được phân công bài nào.
-- Business question: Tòa soạn muốn tìm các chuyên gia mới hoặc chưa hoạt động để mời phản biện.
-- ==============================================================================
SELECT p.person_id, p.full_name, p.email
FROM REVIEWER r
INNER JOIN PERSON p ON r.person_id = p.person_id
LEFT JOIN REVIEW_ASSIGNMENT ra ON r.person_id = ra.reviewer_id
WHERE ra.assignment_id IS NULL;

-- ==============================================================================
-- Q04 (GROUP BY + HAVING): Số bài phản biện của mỗi Reviewer trong năm 2026 (> 0 bài).
-- Business question: Đánh giá khối lượng công việc của từng reviewer để phân công hợp lý.
-- ==============================================================================
SELECT p.full_name AS reviewer_name, COUNT(ra.assignment_id) AS total_assignments
FROM REVIEWER r
INNER JOIN PERSON p ON r.person_id = p.person_id
INNER JOIN REVIEW_ASSIGNMENT ra ON r.person_id = ra.reviewer_id
WHERE YEAR(ra.date_sent) = 2026
GROUP BY p.person_id, p.full_name
HAVING COUNT(ra.assignment_id) > 0
ORDER BY total_assignments DESC;

-- ==============================================================================
-- Q05 (Subquery / EXISTS): Bài nộp đã phân công đủ 3 Reviewer nhưng CHƯA nhận đủ 3 phản hồi.
-- Business question: Cảnh báo các bài đang bị trễ tiến độ phản biện (đã gửi đủ reviewer nhưng chưa có feedback).
-- ==============================================================================
SELECT m.manuscript_id, m.title
FROM MANUSCRIPT m
WHERE 
    (SELECT COUNT(*) FROM REVIEW_ASSIGNMENT ra WHERE ra.manuscript_id = m.manuscript_id) >= 3
    AND 
    (SELECT COUNT(*) FROM REVIEW r 
     INNER JOIN REVIEW_ASSIGNMENT ra ON r.assignment_id = ra.assignment_id 
     WHERE ra.manuscript_id = m.manuscript_id) < 3;

-- ==============================================================================
-- Q06 (CTE / Derived Table): Tính điểm trung bình của từng bài, xếp hạng từ cao xuống thấp.
-- Business question: Xác định các bài có chất lượng cao nhất để ưu tiên xuất bản.
-- ==============================================================================
WITH AvgScores AS (
    SELECT ra.manuscript_id, AVG(rs.score) AS avg_score
    FROM REVIEW_SCORE rs
    INNER JOIN REVIEW r ON rs.review_id = r.review_id
    INNER JOIN REVIEW_ASSIGNMENT ra ON r.assignment_id = ra.assignment_id
    GROUP BY ra.manuscript_id
)
SELECT m.manuscript_id, m.title, a.avg_score
FROM AvgScores a
INNER JOIN MANUSCRIPT m ON a.manuscript_id = m.manuscript_id
ORDER BY a.avg_score DESC;

-- ==============================================================================
-- Q07 (Date Functions): Thống kê số bài được nhận theo từng tháng trong năm 2026.
-- Business question: Phân tích xu hướng gửi bài theo thời gian để điều chỉnh chính sách.
-- ==============================================================================
SELECT MONTH(received_date) AS receive_month, COUNT(manuscript_id) AS total_received
FROM MANUSCRIPT
WHERE YEAR(received_date) = 2026
GROUP BY MONTH(received_date)
ORDER BY receive_month ASC;

-- ==============================================================================
-- Q08 (Query dùng View): Đánh giá tiến độ và chất lượng của các bài đang phản biện.
-- LƯU Ý: Yêu cầu View 'vw_manuscript_review_summary' đã được định nghĩa trong file 04_views.sql.
-- Business question: Tổng quan nhanh về các bài đang trong quy trình phản biện để ưu tiên xử lý.
-- ==============================================================================
SELECT 
    manuscript_id, 
    title, 
    total_assigned_reviewers, 
    total_completed_reviews, 
    average_score
FROM vw_manuscript_review_summary
WHERE status = 'under_review'
ORDER BY average_score DESC;