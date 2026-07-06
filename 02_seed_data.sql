-- ==============================================================================
-- 02_seed_data.sql - DataFrontiers Review Quarterly
-- Phiên bản: Final
-- Mô tả: Dữ liệu mẫu cho toàn bộ hệ thống
-- Môi trường: MySQL 8+, InnoDB
-- ==============================================================================

USE DataFrontiers_Review;

-- ==============================================================================
-- 0. LÀM SẠCH DỮ LIỆU CŨ (ĐẢM BẢO TÍNH IDEMPOTENT)
-- ==============================================================================
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE REVIEW_SCORE;
TRUNCATE TABLE REVIEW;
TRUNCATE TABLE REVIEW_ASSIGNMENT;
TRUNCATE TABLE MANUSCRIPT_AUTHOR;
TRUNCATE TABLE REVIEWER_EXPERTISE;
TRUNCATE TABLE MANUSCRIPT_AUDIT;
TRUNCATE TABLE MANUSCRIPT;
TRUNCATE TABLE ISSUE;
TRUNCATE TABLE CRITERION;
TRUNCATE TABLE EXPERTISE_AREA;
TRUNCATE TABLE AUTHOR;
TRUNCATE TABLE REVIEWER;
TRUNCATE TABLE EDITOR;
TRUNCATE TABLE PERSON;

SET FOREIGN_KEY_CHECKS = 1;

-- ==============================================================================
-- 1. NHÓM NGƯỜI DÙNG (PERSON & ROLES)
-- ==============================================================================

-- 1.1 PERSON – Người dùng chung
INSERT INTO PERSON (person_id, full_name, email, affiliation) VALUES 
(1, 'Nguyễn Tuấn Anh', 'tuananh.editor@datafrontiers.org', 'DataFrontiers Institute'),
(2, 'Trần Hoàng Tuấn', 'hoang.tuan@vnu.edu.vn', 'Đại học Quốc gia Hà Nội'),
(3, 'Ngô Thị Quỳnh', 'quynh.ngo@makeup-art.com', 'Tmore Academy'),
(4, 'Trần Văn Thắng', 'thang.tran@tmore.edu.vn', 'Tmore Academy'), 
(5, 'Lê Anh Khoa', 'lekhoa.ds@hust.edu.vn', 'Đại học Bách Khoa Hà Nội'),
(6, 'Phạm Ngọc Mai', 'maipn@isvnu.edu.vn', 'Trường Quốc tế VNU'),
(7, 'Nguyễn Thị Hồng Nhung', 'nhungnth@isvnu.edu.vn', 'Trường Quốc tế VNU'),
(8, 'Trần Minh Đức', 'duc.tranm@fpt.edu.vn', 'Đại học FPT'),
(9, 'Lê Hải Yến', 'yen.lehai@rmit.edu.vn', 'RMIT Vietnam'),
(10, 'Vũ Đức Minh', 'minh.vu@isvnu.edu.vn', 'Trường Quốc tế VNU'),
(11, 'Trần Thanh Hằng', 'hang.tt@isvnu.edu.vn', 'Trường Quốc tế VNU'), -- Author mới chưa có bài
(12, 'Phạm Văn Hùng', 'hung.pv@hust.edu.vn', 'Đại học Bách Khoa Hà Nội'); -- Reviewer mới chưa nhận bài

-- 1.2 EDITOR – Biên tập viên (3 người)
INSERT INTO EDITOR (person_id) VALUES (1), (2), (10);

-- 1.3 REVIEWER – Chuyên gia phản biện (6 người + 1 người mới)
INSERT INTO REVIEWER (person_id) VALUES (3), (4), (5), (8), (9), (10), (12);

-- 1.4 AUTHOR – Tác giả (4 người + 1 người mới chưa có bài)
INSERT INTO AUTHOR (person_id, mailing_address) VALUES 
(4, 'Tòa nhà Tmore, Lê Hồng Phong, Thanh Hóa'),
(6, 'Ký túc xá VNU, Mỹ Đình, Hà Nội'),
(7, 'Trường Quốc tế, Làng Đại học, Hà Nội'),
(8, 'Khu công nghệ cao Hòa Lạc, Hà Nội'),
(11, 'Trường Quốc tế, Làng Đại học, Hà Nội');

-- ==============================================================================
-- 2. DANH MỤC CỐ ĐỊNH (CLOSED SETS)
-- ==============================================================================

-- 2.1 CRITERION – 4 tiêu chí đánh giá
INSERT INTO CRITERION (criterion_id, name, description) VALUES 
(1, 'Relevance', 'Mức độ phù hợp với phạm vi của ấn phẩm'),
(2, 'Clarity', 'Độ rõ ràng, mạch lạc và văn phong học thuật'),
(3, 'Methodology', 'Tính đúng đắn và phù hợp của phương pháp nghiên cứu'),
(4, 'Contribution', 'Đóng góp mới cho lĩnh vực nghiên cứu');

-- 2.2 EXPERTISE_AREA – Lĩnh vực chuyên môn
INSERT INTO EXPERTISE_AREA (expertise_id, expertise_code, description) VALUES 
(1, 'DS101', 'Predictive Analytics'),
(2, 'IS203', 'Database Modeling & Design'),
(3, 'BA305', 'Business Process Automation'),
(4, 'ML404', 'Machine Learning Algorithms'),
(5, 'DS205', 'Big Data Processing'),        -- Lĩnh vực mới chưa có reviewer
(6, 'IS107', 'Information Systems Strategy'); -- Lĩnh vực mới chưa có reviewer

-- 2.3 REVIEWER_EXPERTISE – Gán lĩnh vực cho reviewer
-- Reviewer 3: DS101, BA305
INSERT INTO REVIEWER_EXPERTISE (person_id, expertise_id) VALUES 
(3, 1), (3, 3),
-- Reviewer 4: IS203, BA305
(4, 2), (4, 3),
-- Reviewer 5: DS101, IS203
(5, 1), (5, 2),
-- Reviewer 8: ML404
(8, 4),
-- Reviewer 9: IS203, ML404
(9, 2), (9, 4),
-- Reviewer 10: DS101, IS203, BA305, ML404
(10, 1), (10, 2), (10, 3), (10, 4),
-- Reviewer 12: ML404, DS205 (reviewer mới)
(12, 4), (12, 5);

-- ==============================================================================
-- 3. SỐ PHÁT HÀNH (ISSUE)
-- ==============================================================================
INSERT INTO ISSUE (issue_id, season, year, volume, issue_number, issue_status, publication_date) VALUES 
(1, 'Spring', 2026, 10, 1, 'published', '2026-04-15 08:00:00'),  -- Đã xuất bản
(2, 'Summer', 2026, 10, 2, 'draft', NULL),                        -- Chưa xuất bản, đã có bài
(3, 'Fall', 2026, 10, 3, 'draft', NULL),                          -- Chưa xuất bản, chưa có bài (test BR16)
(4, 'Winter', 2026, 10, 4, 'draft', NULL);                        -- Chưa xuất bản, chưa có bài

-- ==============================================================================
-- 4. BÀI NỘP (MANUSCRIPT) – Đủ các trạng thái
-- ==============================================================================
INSERT INTO MANUSCRIPT (
    manuscript_id, title, received_date, status, acceptance_date, 
    page_count, order_in_issue, start_page, editor_id, issue_id
) VALUES 
-- Bài đã xuất bản (published)
('MF-26-001', 'Tối ưu hóa Database Modeling với kỹ thuật Machine Learning', 
 '2026-01-10 10:00:00', 'published', '2026-02-20 14:00:00', 12, 1, 10, 1, 1),

-- Bài đã xếp lịch (scheduled)
('MF-26-002', 'Mô hình tự động hóa quy trình nghiệp vụ sử dụng RPA', 
 '2026-03-01 08:00:00', 'scheduled', '2026-04-10 09:00:00', 15, 2, 22, 2, 1), 

-- Bài đang phản biện (under_review)
('MF-26-003', 'Phân tích dữ liệu kinh doanh chuỗi F&B trong thời đại số', 
 '2026-05-01 09:30:00', 'under_review', NULL, NULL, NULL, NULL, 10, NULL),

-- Bài mới nhận (received)
('MF-26-004', 'Ứng dụng Predictive Analytics trong dự báo tài chính', 
 '2026-05-15 11:15:00', 'received', NULL, NULL, NULL, NULL, 1, NULL),

-- Bài bị từ chối (rejected)
('MF-26-005', 'Phân tích thị trường chứng khoán Việt Nam 2025', 
 '2026-05-20 09:00:00', 'rejected', NULL, NULL, NULL, NULL, 1, NULL),

-- Bài đã accepted nhưng chưa xếp lịch (accepted)
('MF-26-006', 'Big Data Processing trong lĩnh vực y tế công cộng', 
 '2026-06-01 14:00:00', 'accepted', '2026-06-20 10:00:00', 20, NULL, NULL, 2, NULL),

-- Bài được xếp vào số 2 (scheduled)
('MF-26-007', 'Phân tích dữ liệu xã hội bằng Machine Learning', 
 '2026-06-10 08:00:00', 'scheduled', '2026-07-01 09:00:00', 18, 1, 35, 10, 2);

-- ==============================================================================
-- 5. MANUSCRIPT_AUTHOR – Gán tác giả cho bài
-- ==============================================================================
INSERT INTO MANUSCRIPT_AUTHOR (manuscript_id, person_id, author_order) VALUES 
('MF-26-001', 6, 1), ('MF-26-001', 7, 2),   -- Bài 1: 2 tác giả
('MF-26-002', 4, 1),                         -- Bài 2: 1 tác giả
('MF-26-003', 8, 1), ('MF-26-003', 6, 2),   -- Bài 3: 2 tác giả
('MF-26-004', 7, 1),                         -- Bài 4: 1 tác giả
('MF-26-005', 7, 1), ('MF-26-005', 11, 2),  -- Bài 5: 2 tác giả
('MF-26-006', 8, 1), ('MF-26-006', 11, 2),  -- Bài 6: 2 tác giả
('MF-26-007', 6, 1), ('MF-26-007', 7, 2), ('MF-26-007', 11, 3); -- Bài 7: 3 tác giả

-- ==============================================================================
-- 6. PHÂN CÔNG PHẢN BIỆN (REVIEW_ASSIGNMENT)
-- ==============================================================================
INSERT INTO REVIEW_ASSIGNMENT (assignment_id, manuscript_id, reviewer_id, date_sent, deadline) VALUES 
-- Bài MF-26-001: 3 reviewer
(1, 'MF-26-001', 3, '2026-01-15 08:00:00', '2026-02-15 08:00:00'),
(2, 'MF-26-001', 4, '2026-01-15 08:30:00', '2026-02-15 08:30:00'),
(3, 'MF-26-001', 5, '2026-01-15 09:00:00', '2026-02-15 09:00:00'),

-- Bài MF-26-002: 3 reviewer
(4, 'MF-26-002', 8, '2026-03-05 10:00:00', '2026-04-05 10:00:00'),
(5, 'MF-26-002', 9, '2026-03-05 10:05:00', '2026-04-05 10:05:00'),
(6, 'MF-26-002', 10, '2026-03-05 10:15:00', '2026-04-05 10:15:00'),

-- Bài MF-26-003: 3 reviewer (đang phản biện)
(7, 'MF-26-003', 3, '2026-05-05 10:00:00', '2026-06-05 10:00:00'),
(8, 'MF-26-003', 5, '2026-05-05 10:15:00', '2026-06-05 10:15:00'),
(9, 'MF-26-003', 9, '2026-05-05 10:30:00', '2026-06-05 10:30:00'),

-- Bài MF-26-006: 3 reviewer (đã accepted)
(10, 'MF-26-006', 4, '2026-06-05 10:00:00', '2026-07-05 10:00:00'),
(11, 'MF-26-006', 8, '2026-06-05 10:10:00', '2026-07-05 10:10:00'),
(12, 'MF-26-006', 10, '2026-06-05 10:20:00', '2026-07-05 10:20:00'),

-- Bài MF-26-007: 3 reviewer (đã scheduled)
(13, 'MF-26-007', 5, '2026-06-15 08:00:00', '2026-07-15 08:00:00'),
(14, 'MF-26-007', 8, '2026-06-15 08:10:00', '2026-07-15 08:10:00'),
(15, 'MF-26-007', 9, '2026-06-15 08:20:00', '2026-07-15 08:20:00');

-- ==============================================================================
-- 7. PHẢN HỒI (REVIEW) & ĐIỂM SỐ (REVIEW_SCORE)
-- ==============================================================================

-- 7.1 Bài MF-26-001 (published) – 3 review đều Accept
INSERT INTO REVIEW (review_id, assignment_id, deadline_date, response_date, recommendation, comments) VALUES 
(1, 1, '2026-02-15 08:00:00', '2026-02-10 14:00:00', 'accept', 
 'Bài viết xuất sắc, cấu trúc rõ ràng, tính ứng dụng thực tế cao. Tác giả đã trình bày vấn đề một cách logic và có hệ thống.'),
(2, 2, '2026-02-15 08:30:00', '2026-02-12 09:00:00', 'accept', 
 'Phương pháp nghiên cứu được thiết kế phù hợp, dữ liệu minh chứng đầy đủ. Phần kết luận đưa ra các gợi ý có giá trị.'),
(3, 3, '2026-02-15 09:00:00', '2026-02-14 16:30:00', 'accept', 
 'Đóng góp tốt cho mảng Database Modeling, các thực nghiệm được mô tả chi tiết. Đề xuất hướng phát triển trong tương lai rõ ràng.');

INSERT INTO REVIEW_SCORE (review_id, criterion_id, score) VALUES 
(1, 1, 9.0), (1, 2, 8.5), (1, 3, 9.0), (1, 4, 8.0),
(2, 1, 8.5), (2, 2, 8.0), (2, 3, 8.5), (2, 4, 9.0),
(3, 1, 9.5), (3, 2, 9.0), (3, 3, 8.5), (3, 4, 8.5);

-- 7.2 Bài MF-26-002 (scheduled) – 3 review đều Accept
INSERT INTO REVIEW (review_id, assignment_id, deadline_date, response_date, recommendation, comments) VALUES 
(4, 4, '2026-04-05 10:00:00', '2026-03-25 10:00:00', 'accept', 
 'Bài viết đáp ứng tốt các yêu cầu học thuật. Phần nghiên cứu tình huống được phân tích sâu sắc.'),
(5, 5, '2026-04-05 10:05:00', '2026-03-26 10:00:00', 'accept', 
 'Nội dung rất thực tế, gắn với nhu cầu của doanh nghiệp. Phương pháp nghiên cứu được trình bày mạch lạc.'),
(6, 6, '2026-04-05 10:15:00', '2026-03-27 10:00:00', 'accept', 
 'Cấu trúc bài viết hợp lý, lập luận chặt chẽ. Đề xuất các giải pháp tự động hóa có tính khả thi cao.');

INSERT INTO REVIEW_SCORE (review_id, criterion_id, score) VALUES 
(4, 1, 8.0), (4, 2, 8.0), (4, 3, 7.5), (4, 4, 8.0),
(5, 1, 8.5), (5, 2, 8.5), (5, 3, 8.0), (5, 4, 8.5),
(6, 1, 8.0), (6, 2, 7.5), (6, 3, 8.0), (6, 4, 8.0);

-- 7.3 Bài MF-26-003 (under_review) – 2 Accept, 1 Reject
INSERT INTO REVIEW (review_id, assignment_id, deadline_date, response_date, recommendation, comments) VALUES 
(7, 7, '2026-06-05 10:00:00', '2026-05-25 09:30:00', 'accept', 
 'Bài viết tiềm năng, cần bổ sung thêm tài liệu tham khảo và làm rõ phần thu thập dữ liệu.'),
(8, 8, '2026-06-05 10:15:00', '2026-05-26 09:30:00', 'accept', 
 'Kết quả thực nghiệm thuyết phục, đáng được khuyến khích. Phân tích dữ liệu được thực hiện cẩn thận.'),
(9, 9, '2026-06-05 10:30:00', '2026-05-27 10:00:00', 'reject', 
 'Dữ liệu thu thập chưa đầy đủ và chưa đại diện cho tổng thể. Kết luận còn khiên cưỡng, chưa thuyết phục được người đọc.');

INSERT INTO REVIEW_SCORE (review_id, criterion_id, score) VALUES 
(7, 1, 7.0), (7, 2, 8.0), (7, 3, 7.0), (7, 4, 7.5),
(8, 1, 8.0), (8, 2, 7.5), (8, 3, 8.0), (8, 4, 8.0),
(9, 1, 5.0), (9, 2, 6.0), (9, 3, 5.0), (9, 4, 5.0);

-- 7.4 Bài MF-26-006 (accepted) – 3 review đều Accept
INSERT INTO REVIEW (review_id, assignment_id, deadline_date, response_date, recommendation, comments) VALUES 
(10, 10, '2026-07-05 10:00:00', '2026-06-25 09:00:00', 'accept', 
 'Bài viết có đóng góp quan trọng cho lĩnh vực y tế công cộng. Phương pháp xử lý dữ liệu lớn được trình bày chi tiết.'),
(11, 11, '2026-07-05 10:10:00', '2026-06-26 09:00:00', 'accept', 
 'Nghiên cứu được thiết kế bài bản, dữ liệu phân tích phong phú. Cần chỉnh sửa một số lỗi chính tả.'),
(12, 12, '2026-07-05 10:20:00', '2026-06-27 09:00:00', 'accept', 
 'Đóng góp mới, phù hợp với xu hướng hiện tại. Các khuyến nghị chính sách có giá trị thực tiễn cao.');

INSERT INTO REVIEW_SCORE (review_id, criterion_id, score) VALUES 
(10, 1, 8.5), (10, 2, 8.0), (10, 3, 8.5), (10, 4, 9.0),
(11, 1, 8.0), (11, 2, 7.5), (11, 3, 8.0), (11, 4, 8.5),
(12, 1, 8.5), (12, 2, 8.5), (12, 3, 8.0), (12, 4, 8.5);

-- 7.5 Bài MF-26-007 (scheduled) – 3 review đều Accept
INSERT INTO REVIEW (review_id, assignment_id, deadline_date, response_date, recommendation, comments) VALUES 
(13, 13, '2026-07-15 08:00:00', '2026-07-05 10:00:00', 'accept', 
 'Phân tích dữ liệu xã hội bằng ML là hướng tiếp cận mới, có tiềm năng ứng dụng cao.'),
(14, 14, '2026-07-15 08:10:00', '2026-07-06 10:00:00', 'accept', 
 'Bài viết có cấu trúc tốt, lập luận rõ ràng. Phần thực nghiệm minh họa đầy đủ.'),
(15, 15, '2026-07-15 08:20:00', '2026-07-07 10:00:00', 'accept', 
 'Nội dung phù hợp với định hướng của tạp chí. Tác giả cần bổ sung thêm thông tin về bộ dữ liệu sử dụng.');

INSERT INTO REVIEW_SCORE (review_id, criterion_id, score) VALUES 
(13, 1, 8.0), (13, 2, 8.5), (13, 3, 8.0), (13, 4, 8.0),
(14, 1, 8.5), (14, 2, 8.0), (14, 3, 8.5), (14, 4, 8.5),
(15, 1, 8.0), (15, 2, 8.0), (15, 3, 7.5), (15, 4, 8.0);

-- ==============================================================================
-- 8. KIỂM TRA DỮ LIỆU ĐÃ INSERT
-- ==============================================================================
SELECT '=== DỮ LIỆU ĐÃ INSERT THÀNH CÔNG ===' AS Status;
SELECT 'Số lượng PERSON: ' || COUNT(*) FROM PERSON AS INFO;
SELECT 'Số lượng MANUSCRIPT: ' || COUNT(*) FROM MANUSCRIPT AS INFO;
SELECT 'Số lượng REVIEW_ASSIGNMENT: ' || COUNT(*) FROM REVIEW_ASSIGNMENT AS INFO;
SELECT 'Số lượng REVIEW: ' || COUNT(*) FROM REVIEW AS INFO;
SELECT 'Số lượng REVIEW_SCORE: ' || COUNT(*) FROM REVIEW_SCORE AS INFO;

-- ==============================================================================
-- 9. CHÚ THÍCH KẾT THÚC
-- ==============================================================================
-- Dữ liệu đã được insert thành công.
-- Các tình huống nghiệp vụ đã có dữ liệu mẫu:
-- 1. Bài published: MF-26-001 (Issue 1, Spring 2026)
-- 2. Bài scheduled: MF-26-002 (Issue 1), MF-26-007 (Issue 2)
-- 3. Bài under_review: MF-26-003
-- 4. Bài received: MF-26-004
-- 5. Bài rejected: MF-26-005
-- 6. Bài accepted: MF-26-006
-- 7. Reviewer chưa nhận bài: person_id = 12
-- 8. Issue chưa có bài: Issue 3, Issue 4
-- 9. Lĩnh vực chưa có reviewer: DS205, IS107
-- 10. Author chưa có bài: person_id = 11
-- ==============================================================================