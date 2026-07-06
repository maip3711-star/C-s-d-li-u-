-- ==============================================================================
-- 01_schema.sql - DataFrontiers Review Quarterly
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS DataFrontiers_Review;
USE DataFrontiers_Review;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS PROCEDURE_AUDIT;
DROP TABLE IF EXISTS REVIEW_SCORE;
DROP TABLE IF EXISTS REVIEW;
DROP TABLE IF EXISTS REVIEW_ASSIGNMENT;
DROP TABLE IF EXISTS MANUSCRIPT_AUTHOR;
DROP TABLE IF EXISTS REVIEWER_EXPERTISE;
DROP TABLE IF EXISTS MANUSCRIPT_AUDIT;
DROP TABLE IF EXISTS MANUSCRIPT;
DROP TABLE IF EXISTS ISSUE;
DROP TABLE IF EXISTS CRITERION;
DROP TABLE IF EXISTS EXPERTISE_AREA;
DROP TABLE IF EXISTS EDITOR;
DROP TABLE IF EXISTS REVIEWER;
DROP TABLE IF EXISTS AUTHOR;
DROP TABLE IF EXISTS PERSON;

SET FOREIGN_KEY_CHECKS = 1;

-- 1. NHÓM NGƯỜI DÙNG
CREATE TABLE PERSON (
    person_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    affiliation VARCHAR(255) NOT NULL,
    CONSTRAINT chk_person_email CHECK (
        email REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'
    )
);

CREATE TABLE AUTHOR (
    person_id INT PRIMARY KEY,
    mailing_address VARCHAR(500) NOT NULL,
    CONSTRAINT fk_author_person FOREIGN KEY (person_id) REFERENCES PERSON(person_id) ON DELETE CASCADE
);

CREATE TABLE REVIEWER (
    person_id INT PRIMARY KEY,
    CONSTRAINT fk_reviewer_person FOREIGN KEY (person_id) REFERENCES PERSON(person_id) ON DELETE CASCADE
);

CREATE TABLE EDITOR (
    person_id INT PRIMARY KEY,
    CONSTRAINT fk_editor_person FOREIGN KEY (person_id) REFERENCES PERSON(person_id) ON DELETE CASCADE
);

-- 2. DANH MỤC
CREATE TABLE EXPERTISE_AREA (
    expertise_id INT AUTO_INCREMENT PRIMARY KEY,
    expertise_code VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL
);

CREATE TABLE CRITERION (
    criterion_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL
);

-- 3. DỮ LIỆU TRUNG TÂM
CREATE TABLE ISSUE (
    issue_id INT AUTO_INCREMENT PRIMARY KEY,
    season ENUM('Spring', 'Summer', 'Fall', 'Winter') NOT NULL,
    year INT NOT NULL,
    volume INT UNSIGNED NOT NULL,
    issue_number INT UNSIGNED NOT NULL,
    issue_status ENUM('draft', 'published') NOT NULL,
    publication_date TIMESTAMP NULL,
    CONSTRAINT uq_issue UNIQUE (season, year, volume, issue_number),
    CONSTRAINT chk_issue_pubdate CHECK (
        (issue_status = 'published' AND publication_date IS NOT NULL) OR
        (issue_status = 'draft' AND publication_date IS NULL)
    ),
    CONSTRAINT chk_issue_year CHECK (year >= 2000 AND year <= 2030)
);

CREATE TABLE MANUSCRIPT (
    manuscript_id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    received_date TIMESTAMP NOT NULL,
    status ENUM('received','rejected','under_review','accepted','scheduled','published') NOT NULL,
    acceptance_date TIMESTAMP NULL,
    page_count INT NULL,
    order_in_issue INT NULL,
    start_page INT NULL,
    editor_id INT NOT NULL,
    issue_id INT NULL,
    CONSTRAINT fk_manu_editor FOREIGN KEY (editor_id) REFERENCES EDITOR(person_id),
    CONSTRAINT fk_manu_issue FOREIGN KEY (issue_id) REFERENCES ISSUE(issue_id),
    CONSTRAINT chk_title_meaningful CHECK (LENGTH(TRIM(title)) > 5),
    CONSTRAINT chk_acceptance_date CHECK (status NOT IN ('accepted', 'scheduled', 'published') OR acceptance_date IS NOT NULL),
    CONSTRAINT chk_issue_data CHECK (status NOT IN ('scheduled', 'published') OR (issue_id IS NOT NULL AND order_in_issue IS NOT NULL AND start_page IS NOT NULL AND page_count IS NOT NULL)),
    CONSTRAINT chk_valid_numbers CHECK (page_count > 0 AND page_count <= 100 AND start_page >= 1 AND order_in_issue >= 1),
    CONSTRAINT chk_dates_logic CHECK (acceptance_date IS NULL OR received_date <= acceptance_date),
    CONSTRAINT uq_issue_order UNIQUE (issue_id, order_in_issue),
    CONSTRAINT uq_issue_start UNIQUE (issue_id, start_page)
);

CREATE TABLE MANUSCRIPT_AUDIT (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    manuscript_id VARCHAR(50) NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100) DEFAULT 'System_Trigger',
    CONSTRAINT fk_audit_manu FOREIGN KEY (manuscript_id) REFERENCES MANUSCRIPT(manuscript_id) ON DELETE CASCADE
);

-- *** BỔ SUNG: Bảng log lỗi cho procedure ***
CREATE TABLE PROCEDURE_AUDIT (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    procedure_name VARCHAR(100) NOT NULL,
    manuscript_id VARCHAR(50) NULL,
    reviewer_id INT NULL,
    error_code VARCHAR(20),
    error_message TEXT,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. NHÓM LIÊN KẾT
CREATE TABLE MANUSCRIPT_AUTHOR (
    manuscript_id VARCHAR(50) NOT NULL,
    person_id INT NOT NULL,
    author_order INT NOT NULL,
    PRIMARY KEY (manuscript_id, person_id),
    CONSTRAINT fk_ma_manu FOREIGN KEY (manuscript_id) REFERENCES MANUSCRIPT(manuscript_id) ON DELETE CASCADE,
    CONSTRAINT fk_ma_author FOREIGN KEY (person_id) REFERENCES AUTHOR(person_id) ON DELETE RESTRICT,
    CONSTRAINT uq_manu_order UNIQUE (manuscript_id, author_order)
);

CREATE TABLE REVIEWER_EXPERTISE (
    person_id INT NOT NULL,
    expertise_id INT NOT NULL,
    PRIMARY KEY (person_id, expertise_id),
    CONSTRAINT fk_re_rev FOREIGN KEY (person_id) REFERENCES REVIEWER(person_id) ON DELETE CASCADE,
    CONSTRAINT fk_re_exp FOREIGN KEY (expertise_id) REFERENCES EXPERTISE_AREA(expertise_id) ON DELETE RESTRICT
);

CREATE TABLE REVIEW_ASSIGNMENT (
    assignment_id INT AUTO_INCREMENT PRIMARY KEY,
    manuscript_id VARCHAR(50) NOT NULL,
    reviewer_id INT NOT NULL,
    date_sent TIMESTAMP NOT NULL,
    deadline TIMESTAMP NULL,
    CONSTRAINT fk_ra_manu FOREIGN KEY (manuscript_id) REFERENCES MANUSCRIPT(manuscript_id) ON DELETE CASCADE,
    CONSTRAINT fk_ra_rev FOREIGN KEY (reviewer_id) REFERENCES REVIEWER(person_id) ON DELETE RESTRICT,
    CONSTRAINT uq_manu_rev UNIQUE (manuscript_id, reviewer_id)
);

CREATE TABLE REVIEW (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    assignment_id INT NOT NULL UNIQUE,
    deadline_date TIMESTAMP NOT NULL,
    response_date TIMESTAMP NOT NULL,
    recommendation ENUM('accept','reject') NOT NULL,
    comments TEXT NOT NULL,
    CONSTRAINT fk_review_assign FOREIGN KEY (assignment_id) REFERENCES REVIEW_ASSIGNMENT(assignment_id) ON DELETE RESTRICT,
    CONSTRAINT chk_comments_length CHECK (LENGTH(TRIM(comments)) >= 20)
);

CREATE TABLE REVIEW_SCORE (
    review_id INT NOT NULL,
    criterion_id INT NOT NULL,
    score DECIMAL(4,2) NOT NULL,
    PRIMARY KEY (review_id, criterion_id),
    CONSTRAINT fk_rs_review FOREIGN KEY (review_id) REFERENCES REVIEW(review_id) ON DELETE CASCADE,
    CONSTRAINT fk_rs_crit FOREIGN KEY (criterion_id) REFERENCES CRITERION(criterion_id) ON DELETE RESTRICT,
    CONSTRAINT chk_score CHECK (score BETWEEN 0 AND 10)
);

-- 5. TRIGGERS (đã sửa trigger delete score – không báo lỗi khi xóa điểm)
DELIMITER //

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
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Xung đột dải số trang.';
        END IF;
    END IF;
END //

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
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Xung đột dải số trang.';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_check_publication_date
BEFORE UPDATE ON ISSUE
FOR EACH ROW
BEGIN
    DECLARE min_received TIMESTAMP;
    IF NEW.publication_date IS NOT NULL THEN
        SELECT MIN(received_date) INTO min_received FROM MANUSCRIPT WHERE issue_id = NEW.issue_id;
        IF min_received IS NOT NULL AND NEW.publication_date < min_received THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Số báo không thể xuất bản trước ngày nhận bài đầu tiên.';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_audit_manuscript_status
AFTER UPDATE ON MANUSCRIPT
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO MANUSCRIPT_AUDIT (manuscript_id, old_status, new_status, changed_date)
        VALUES (NEW.manuscript_id, OLD.status, NEW.status, CURRENT_TIMESTAMP);
    END IF;
END //

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

-- *** SỬA: Trigger DELETE không báo lỗi nếu số điểm <4 (cho phép xóa để sửa) ***
CREATE TRIGGER trg_check_review_scores_delete
AFTER DELETE ON REVIEW_SCORE
FOR EACH ROW
BEGIN
    -- Không làm gì, chỉ để giữ cấu trúc
    -- Thực tế, logic này sẽ được kiểm soát ở tầng ứng dụng
END //

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