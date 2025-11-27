## Step 2 – Đảm bảo tất cả dịch vụ .NET trỏ về Collector mới

### 1. Biết mình đang dùng gì
- Toàn bộ microservice dùng chung extension `SSIDX.Shared.Extensions.ConfigureOpenTelemetry`.
- Việc bật/tắt tracing phụ thuộc biến môi trường:
  - `OPENTELEMETRY_IS_ENABLE=true`
  - `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`
  - `OTEL_EXPORTER_OTLP_ENDPOINT=<url>`
- Các compose con (Exchange, Assets, Matching, Settlement, Submission, Backoffice, Websocket…) đã khai báo 3 biến trên trong phần `environment`.

### 2. Checklist cập nhật `.env`
Trong `docker-compose/env.example` (đã được cập nhật ở Step 1) và `.env` thực tế:
```env
OTEL_PROTOCOL=grpc
# Docker Desktop/WSL: host.docker.internal
# Cluster khác: thay IP/hostname máy chạy Grafana stack
OTEL_ENDPOINT=http://host.docker.internal:4317
```
Sau khi chỉnh:
```powershell
cp docker-compose/env.example docker-compose/.env   # nếu chưa có
# sửa bằng editor rồi reload từng service (để nhận env mới):
$services = @(
  "matching-engine",
  "assets",
  "settlement",
  "submission",
  "statistic",
  "exchange",
  "backoffice",
  "websocket"
)
foreach ($svc in $services) {
  docker compose --env-file docker-compose/.env -f docker-compose/services/$svc/docker-compose.yml up -d
}
```

### 3. Kiểm tra cấu hình trong code
| Dịch vụ | File xác nhận |
| --- | --- |
| Exchange Endpoint | `Endpoints/SSIDX.Endpoints.Exchange/Program.cs` → `builder.AddServiceDefaults()` |
| Matching Engine | `Matching/SSIDX.Engines.Matching/Program.cs` → `services.ConfigureOpenTelemetry(configuration);` |
| Asset Engine | `Assets/SSIDX.Engines.Assets/Program.cs` (tương tự) |
| Settlement / Submission / Statistic / Backoffice | đều gọi `ConfigureOpenTelemetry` trong DI bootstrap |

Không cần thêm code mới – chỉ cần đảm bảo biến môi trường chính xác.

### 4. Xác thực dịch vụ đã kết nối Collector
1. Chạy `docker logs <service>` (VD `ssidx-matching-engine`) và kiểm tra:
   - Không có lỗi `Failed to export spans`.
   - Có log `Exporter connected otlp` của OpenTelemetry.
2. Trên Collector:
   ```powershell
   docker logs ssidx-otel-collector | Select-String "service\.name"
   ```
   → thấy các `resource service.name` như `SSIDX.MatchingEngine`, `SSIDX.ExchangeEndpoint`.
3. Vào Grafana → Tempo → Search → `service.name="SSIDX.Engines.Matching"` hoặc dùng Explore Traces plugin để chắc chắn trace đã tới.

### 5. Lưu ý cho chạy local (dotnet run)
- Khi chạy trực tiếp (không qua Docker), set env:
  ```powershell
  $env:OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
  $env:OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317" # hoặc IP máy chạy Collector
  $env:OPENTELEMETRY_IS_ENABLE="true"
  dotnet run --project Matching/SSIDX.Engines.Matching
  ```
- Nếu không muốn ảnh hưởng Aspire, dùng Collector local forward tới Tempo và Aspire tương tự file `otel-collector.yaml`.

### 6. Kết quả Step 2
- `.env` và mọi compose con đã trỏ `OTEL_ENDPOINT` về Collector mới (qua host IP).
- Tempo bắt đầu nhận dữ liệu → có thể tra cứu trace theo `service.name`.
- Aspire tiếp tục có dữ liệu nhờ collector fan-out (không ảnh hưởng dashboard cũ).

