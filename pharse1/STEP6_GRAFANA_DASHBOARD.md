## Step 6 – Dashboard Grafana (Tempo datasource)

### 1. Kết nối Tempo trong Grafana
1. Truy cập `http://localhost:3000` (hoặc host thực tế), đăng nhập admin.
2. `Connections → Data sources → Add new data source → Tempo`.
3. URL: `http://tempo:3200`. Bật tùy chọn `Trace to metrics` nếu dùng spanmetrics processor (có thể thêm sau).
4. Test & Save.

### 2. Dashboard “Tracing Phase 1”
Tạo dashboard mới gồm các panel:

| Panel | Datasource | Query | Ghi chú |
| --- | --- | --- | --- |
| TPS tổng | Tempo | `sum(rate(traces{}[1m])) by (service.name)` (cần bật spanmetrics) | Hoặc dùng `TraceQL` + transform Count. |
| TPS theo service | Tempo | Filter `service.name` = `SSIDX.Engines.Matching`, `SSIDX.Endpoints.Exchange` | So sánh match vs exchange. |
| Queue Delay | Tempo | `TraceQL`: `{ span.name = "asset.consume" } |> avg(queue_delay_ms)` | Hiển thị mean/P95. |
| Top slow traces | Tempo search | `duration > 500ms` + Table panel show traceId, duration, service | Link click mở trace. |
| Bottleneck waterfall | Tempo | Panel “Trace viewer” embedded, cho phép nhập traceId. |

### 3. Template variables
- `service`: `label_values(service.name)`
- `environment`: đọc từ `resource["deployment.environment"]` (đặt trong Step 2).
Sử dụng trong panel titles để chuyển đổi môi trường (dev/staging/prod).

### 4. Lưu dashboard vào repo
- Xuất JSON → lưu tại `docker-compose/grafana/pharse1/dashboards/tracing-phase1.json`.
- Có thể auto-provision:
```ini
[tracing-phase1]
path = /etc/grafana/provisioning/dashboards/tracing-phase1.json
```

### 5. Validation
- Khi gửi load test, biểu đồ TPS phải tăng tương ứng.
- Khi cố tình dừng consumer, panel Queue Delay tăng.
- Panel slow traces hiển thị traceId, click mở ra waterfall (Tempo UI).

### 6. Kết quả Step 6
- Dashboard phục vụ yêu cầu Phase 1: TPS, queue delay, bottleneck.
- JSON dashboard được version control trong repo.

