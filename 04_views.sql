-- ==============================================================================
-- 04_views.sql - DataFrontiers Review Quarterly
-- Phiên bản: Final
-- Mô tả: Định nghĩa các View cho báo cáo và tra cứu dữ liệu
-- Môi trường: MySQL 8+, InnoDB
-- ==============================================================================

USE DataFrontiers_Review;

-- ==============================================================================
-- VIEW 1: vw_manuscript_review_summary
-- Mô tả: Tổng quan quá trình phản biện của từng bài (số lượng reviewer, số review đã hoàn thành, điểm trung bình)
-- Sử dụng: Theo dõi tiến độ phản biện, lọc bài under_review, đánh giá chất lượng bài
-- ==============================================================================
CREATE OR REPLACE VIEW vw_manuscript_review_summary AS
SELECT 
    m.manuscript_id,
    m.title,
    m.status,
    m.issue_id,
    COUNT(DISTINCT ra.assignment_id) AS total_assigned_reviewers,
    COUNT(DISTINCT r.review_id) AS total_completed_reviews,
    IFNULL(ROUND(AVG(rs.score), 2), 0.00) AS average_score,
    -- Thêm cột xếp hạng để dễ sử dụng trong báo cáo
    CASE 
        WHEN COUNT(DISTINCT r.review_id) >= 3 AND IFNULL(AVG(rs.score), 0) >= 8.0 THEN 'Excellent'
        WHEN COUNT(DISTINCT r.review_id) >= 3 AND IFNULL(AVG(rs.score), 0) >= 6.5 THEN 'Good'
        WHEN COUNT(DISTINCT r.review_id) >= 3 THEN 'Fair'
        ELSE 'Pending'
    END AS quality_rating
FROM MANUSCRIPT m
LEFT JOIN REVIEW_ASSIGNMENT ra ON m.manuscript_id = ra.manuscript_id
LEFT JOIN REVIEW r ON ra.assignment_id = r.assignment_id
LEFT JOIN REVIEW_SCORE rs ON r.review_id = rs.review_id
WHERE ra.assignment_id IS NOT NULL  -- Chỉ lấy bài đã có ít nhất 1 phân công
GROUP BY m.manuscript_id, m.title, m.status, m.issue_id;

-- ==============================================================================
-- VIEW 2: vw_issue_table_of_contents
-- Mô tả: Mục lục các số báo đã xuất bản, hiển thị tác giả chính và số trang
-- Sử dụng: Tạo bảng mục lục cho từng số báo, tra cứu nội dung
-- ==============================================================================
CREATE OR REPLACE VIEW vw_issue_table_of_contents AS
SELECT 
    i.issue_id,
    i.season,
    i.year,
    i.volume,
    i.issue_number,
    i.publication_date,
    m.order_in_issue,
    m.start_page,
    m.page_count,
    m.title,
    p.full_name AS primary_author,
    p.email AS author_email
FROM ISSUE i
INNER JOIN MANUSCRIPT m ON i.issue_id = m.issue_id
INNER JOIN MANUSCRIPT_AUTHOR ma ON m.manuscript_id = ma.manuscript_id
INNER JOIN PERSON p ON ma.person_id = p.person_id
WHERE i.issue_status = 'published' 
  AND ma.author_order = 1  -- Chỉ lấy tác giả chính
ORDER BY i.year DESC, i.issue_number ASC, m.order_in_issue ASC;

-- ==============================================================================
-- VIEW 3: vw_reviewer_performance (Bonus)
-- Mô tả: Đánh giá hiệu suất của từng reviewer (số bài đã nhận, số bài đã phản hồi, điểm trung bình)
-- Sử dụng: Quản lý chất lượng reviewer, thống kê cho ban biên tập
-- ==============================================================================
CREATE OR REPLACE VIEW vw_reviewer_performance AS
SELECT 
    p.person_id,
    p.full_name,
    p.email,
    p.affiliation,
    COUNT(DISTINCT ra.assignment_id) AS total_assigned,
    COUNT(DISTINCT r.review_id) AS total_completed,
    ROUND(
        IFNULL(COUNT(DISTINCT r.review_id) * 100.0 / NULLIF(COUNT(DISTINCT ra.assignment_id), 0), 0), 
        2
    ) AS completion_rate_percent,
    IFNULL(ROUND(AVG(rs.score), 2), 0.00) AS avg_score_given,
    -- Thời gian phản hồi trung bình (ngày)
    ROUND(
        IFNULL(AVG(DATEDIFF(r.response_date, ra.date_sent)), 0), 
        0
    ) AS avg_response_days
FROM REVIEWER rev
INNER JOIN PERSON p ON rev.person_id = p.person_id
LEFT JOIN REVIEW_ASSIGNMENT ra ON rev.person_id = ra.reviewer_id
LEFT JOIN REVIEW r ON ra.assignment_id = r.assignment_id
LEFT JOIN REVIEW_SCORE rs ON r.review_id = rs.review_id
GROUP BY p.person_id, p.full_name, p.email, p.affiliation
HAVING total_assigned > 0  -- Chỉ hiển thị reviewer đã nhận bài
ORDER BY avg_score_given DESC, completion_rate_percent DESC;

-- ==============================================================================
-- TEST QUERIES (Kiểm thử các View)
-- ==============================================================================

-- Test View 1: Danh sách bài đang phản biện (under_review) có điểm trung bình
SELECT '=== TEST VIEW 1: vw_manuscript_review_summary ===' AS Message;
SELECT manuscript_id, title, status, total_assigned_reviewers, total_completed_reviews, average_score, quality_rating
FROM vw_manuscript_review_summary
WHERE status = 'under_review'
ORDER BY average_score DESC;

-- Test View 2: Mục lục số báo Spring 2026
SELECT '=== TEST VIEW 2: vw_issue_table_of_contents ===' AS Message;
SELECT * FROM vw_issue_table_of_contents
WHERE season = 'Spring' AND year = 2026
ORDER BY order_in_issue;

-- Test View 3: Top 3 Reviewer có điểm trung bình cao nhất
SELECT '=== TEST VIEW 3: vw_reviewer_performance ===' AS Message;
SELECT full_name, total_assigned, total_completed, completion_rate_percent, avg_score_given, avg_response_days
FROM vw_reviewer_performance
ORDER BY avg_score_given DESC
LIMIT 3;

-- ==============================================================================
-- KẾT THÚC FILE
-- ==============================================================================
SELECT 'All views created and tested successfully!' AS Status;