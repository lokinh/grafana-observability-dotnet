## Hướng dẫn chi tiết hoàn thành Phase 1 – Tracing First

Tài liệu này liệt kê từng bước và trỏ tới hướng dẫn con tương ứng. Thực hiện lần lượt từ Step 1 → Step 7 để đạt 100% mục tiêu Phase 1.

| Step | Nội dung | Link chi tiết |
| --- | --- | --- |
| 1 | Dựng Grafana + Tempo + OTel Collector fan-out Aspire | [STEP1_INFRASTRUCTURE](./STEP1_INFRASTRUCTURE.md) |
| 2 | Đồng bộ biến môi trường .NET để trỏ vào Collector mới | [STEP2_SERVICE_WIRING](./STEP2_SERVICE_WIRING.md) |
| 3 | Gateway/Nginx & trace propagation đầu vào | [STEP3_GATEWAY_AND_HEADERS](./STEP3_GATEWAY_AND_HEADERS.md) |
| 4 | Producer span (CoreAPI, Matcher, Asset, Trade) | [STEP4_PRODUCER_TRACE](./STEP4_PRODUCER_TRACE.md) |
| 5 | Consumer span + queue delay (Asset, Settlement, Statistic…) | [STEP5_CONSUMER_TRACE](./STEP5_CONSUMER_TRACE.md) |
| 6 | Dashboard Grafana (TPS, queue delay, bottleneck) | [STEP6_GRAFANA_DASHBOARD](./STEP6_GRAFANA_DASHBOARD.md) |
| 7 | Kiểm thử & bàn giao Phase 1 | [STEP7_VALIDATION](./STEP7_VALIDATION.md) |

### Chuẩn hóa cấu hình chung cho dự án SSIDX
- Không cần viết thêm `tracing-config.yaml` vì `.NET` đã gom trong `SSIDX.Shared.Extensions.ConfigureOpenTelemetry`.
- Chỉ cần thống nhất biến môi trường (đặt trong `.env` và CI/CD):
  ```bash
  OPENTELEMETRY_IS_ENABLE=true
  OTEL_EXPORTER_OTLP_PROTOCOL=grpc
  # Docker Desktop/WSL: host.docker.internal; môi trường khác: IP/host máy chạy Collector
  OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317
  OTEL_RESOURCE_ATTRIBUTES=deployment.environment=staging
  ```
- Các service Kafka sử dụng `SSIDX.Helpers.OTELHelper` → đảm bảo luôn set/đọc `TraceContext` khi publish/consume.

### Tiêu chí hoàn thành Phase 1
- 95% request phát trace nối liền Gateway → DB (Tempo search kiểm chứng).
- Dashboard “Tracing Phase 1” hiển thị TPS & queue delay dựa trên trace.
- Có checklist propagation Kafka/HTTP, hướng dẫn onboarding service mới.
- Runbook xử lý bottleneck được lưu cùng folder `pharse1/`.

Tham chiếu hướng dẫn chi tiết từng step trước khi chuyển sang Phase 2.