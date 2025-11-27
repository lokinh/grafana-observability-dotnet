## Step 7 – Kiểm thử tổng thể & bàn giao Phase 1

### 1. Checklist kỹ thuật
| Hạng mục | Cách kiểm tra |
| --- | --- |
| Collector fan-out | `docker logs ssidx-otel-collector` không báo lỗi, Tempo & Aspire đều thấy trace. |
| Trace completeness | Tempo query `service.name="ssidx-nginx"` → chọn 20 trace ngẫu nhiên, xác nhận có span tới DB (Npgsql). |
| TPS accuracy | So sánh panel TPS với số order thực tế trong DB (đếm `orders` trong Trading DB). Sai số < 5%. |
| Queue delay | Làm chậm consumer (tạm dừng service Assets) → panel Queue Delay tăng. Khôi phục service → delay về mức bình thường. |
| Bottleneck | Giả lập truy vấn DB chậm bằng `pg_sleep` (hoặc tắt index) → trace waterfall highlight span `db.postgresql`. |

### 2. Kiểm thử tự động/ bán tự động
1. Chạy script load (ví dụ `Testcases/Load/order-load.http`) gửi 1k lệnh.
2. Thu thập traceId slow > 1s để đưa vào báo cáo.
3. Dùng Grafana “Explore → Tempo” lọc theo `orderId` để chứng minh trace bám ID nghiệp vụ.

### 3. Bàn giao & tài liệu
- Cập nhật `docker-compose/grafana/pharse1/GUIDE.md` + các step file (đã có).
- Viết `RUNBOOK_phase1.md` (ở thư mục này) mô tả quy trình:
  1. Restart Collector.
  2. Thêm service mới.
  3. Debug trace thất lạc.
- Tạo ticket/README ghi rõ cách chuyển dịch vụ sang Collector (tham chiếu Step 2).

### 4. Tiêu chí hoàn thành Phase 1
- 95% request có trace đầy đủ (Gateway → Producer → Kafka → Consumer → DB).
- Dashboard Phase 1 hoạt động, hiển thị TPS/queue delay/bottleneck.
- Đội dev biết cách bật tracing cho service mới (tài liệu step-by-step).
- Aspire Dashboard vẫn chạy, không mất dữ liệu.

Hoàn thành checklist trên đồng nghĩa Phase 1 (Tracing-first) đã bàn giao 100%.

