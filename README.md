# DataFrontiers Review Quarterly — Báo cáo cuối kỳ (Nhóm 5 — Đề 4)

Hệ thống quản lý bài nộp, phản biện độc lập và xuất bản tạp chí học thuật quý **DataFrontiers Review Quarterly**.

---

## 📌 Giới thiệu đề tài

DataFrontiers Review Quarterly là một ấn phẩm học thuật trực tuyến chuyên công bố các bài nghiên cứu trong lĩnh vực Khoa học dữ liệu, Hệ thống thông tin và Phân tích kinh doanh. Hệ thống vận hành theo mô hình phản biện kín (peer-review) với tỷ lệ chấp nhận bài thấp, đòi hỏi theo dõi chặt chẽ vòng đời mỗi bài nộp.

**Các chức năng chính:**
- Quản lý vòng đời bài nộp: `received → under_review → accepted/rejected → scheduled → published`
- Quản lý tác giả, chuyên gia phản biện, biên tập viên
- Quản lý phản biện theo 4 tiêu chí (Relevance, Clarity, Methodology, Contribution)
- Quản lý số phát hành theo quý (Spring, Summer, Fall, Winter)

---

## ⚙️ Yêu cầu môi trường

- **MySQL** 8.0+ (đã test tương thích với 8.0/8.4)
- **Storage engine:** InnoDB
- **Charset/Collation:** utf8mb4 / utf8mb4_0900_ai_ci
- **Môi trường:** Lab/local — không chạy trên server dùng chung

---

## 📂 Danh sách file trong repository

| File | Mô tả |
| :--- | :--- |
| `01_schema.sql` | Tạo database, 15 bảng, constraints, trigger |
| `02_seed_data.sql` | Dữ liệu mẫu (12 người dùng, 7 bài, 15 phân công) |
| `03_queries.sql` | 8 truy vấn nghiệp vụ Q01 – Q08 |
| `04_views.sql` | 3 views + test SELECT |
| `05_routines.sql` | 1 function + 2 procedures |
| `06_triggers_events.sql` | 7 triggers + 1 event (disabled) |
| `07_indexes_explain.sql` | 2 indexes + EXPLAIN |
| `08_admin_backup.sql` | Phân quyền (Role/User), backup/restore plan |
| `09_tests.sql` | 12 test cases (positive & negative) |
| `ERD.png` | Sơ đồ Crow's Foot ERD |
| `report.pdf` | Báo cáo cuối kỳ đầy đủ |

---

## 🚀 Thứ tự chạy script

**Lưu ý quan trọng:** Các script có dependency lẫn nhau, cần chạy đúng thứ tự:

```bash
mysql -u root -p < 01_schema.sql
mysql -u root -p < 02_seed_data.sql
mysql -u root -p < 04_views.sql
mysql -u root -p < 05_routines.sql
mysql -u root -p < 06_triggers_events.sql
mysql -u root -p < 07_indexes_explain.sql
mysql -u root -p < 03_queries.sql
mysql -u root -p < 09_tests.sql
