## Step 1 – Hạ tầng tracing bám sát stack hiện tại

### 1. Bối cảnh dự án
- Tất cả microservice .NET (Exchange, Assets, Matching, Settlement, Submission, Backoffice, WebSocket…) đã bật OpenTelemetry qua `SSIDX.Shared.Extensions.ConfigureOpenTelemetry`.
- Mặc định các service gửi OTLP trực tiếp tới Aspire Dashboard (`docker-compose/services/dashboard/docker-compose.yml`) thông qua biến `OTEL_ENDPOINT=http://ssidx-aspire-dashboard:18889`.
- Phase 1 cần bổ sung một OpenTelemetry Collector đặt cạnh Grafana để:
  1. Nhận OTLP từ các service (thay vì bắn thẳng Aspire).
  2. Forward trace sang Tempo cho dashboard tracing.
  3. Vẫn forward trace sang Aspire để bảo toàn monitoring hiện có.

### 2. Chuẩn bị thư mục và dữ liệu
```powershell
mkdir -Force docker-compose/grafana/data/grafana
mkdir -Force docker-compose/grafana/data/tempo
mkdir -Force docker-compose/grafana/configs
```
Stack Grafana dùng default network nội bộ (`grafana_default`) và publish port cho bên ngoài, không cần join `ssidx-network`. Các service khác có thể gọi IP/hostname của host này để gửi trace.

### 3. Cập nhật `docker-compose/grafana/compose.yaml`
Thêm service `tempo` và `otel-collector`, mount cấu hình từ `./configs` và dữ liệu vào `./data`:
```yaml
services:
  grafana:
    image: grafana/grafana:12.1.4
    container_name: grafana
    restart: unless-stopped
    ports:
      - 3000:3000
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ./data/grafana:/var/lib/grafana
    depends_on:
      - tempo
      - otel-collector

  tempo:
    image: grafana/tempo:2.6.0
    container_name: tempo
    restart: unless-stopped
    command: ["-config.file=/etc/tempo.yaml"]
    ports:
      - 3200:3200
    volumes:
      - ./configs/tempo.yaml:/etc/tempo.yaml
      - ./data/tempo:/var/tempo

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.104.0
    container_name: ssidx-otel-collector
    restart: unless-stopped
    command: ["--config=/etc/otel-collector.yaml"]
    ports:
      - 4317:4317
      - 4318:4318
    volumes:
      - ./configs/otel-collector.yaml:/etc/otel-collector.yaml
```

### 4. Tạo `tempo.yaml`
```yaml
server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
ingester:
  trace_idle_period: 10s
  max_block_duration: 5m
compactor:
  compaction:
    block_retention: 72h
storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces
```

### 5. Tạo `otel-collector.yaml`
Collector phải fan-out sang Tempo **và** Aspire:
```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  batch:
  attributes/addService:
    actions:
      - key: service.name
        action: insert
        value: unknown-service

exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true
  otlp/aspire:
    endpoint: ssidx-aspire-dashboard:18889
    tls:
      insecure: true
  logging:
    verbosity: normal

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [attributes/addService, batch]
      exporters: [otlp/tempo, otlp/aspire, logging]
```

### 6. Chạy stack
```powershell
cd docker-compose/grafana
docker compose up -d
```
Kiểm tra:
- `docker compose ps` → cả 3 service **Up**.
- `curl http://localhost:3200/ready` → Tempo ready.
- `docker logs ssidx-otel-collector` → không lỗi kết nối.
- Grafana đăng nhập bằng `admin/admin` (đổi password sau).

### 7. Cập nhật biến môi trường dịch vụ .NET
- Trong `docker-compose/env.example` đổi:
  ```
  # Nếu service chạy trong Docker Desktop/WSL trên cùng máy:
  OTEL_ENDPOINT=http://host.docker.internal:4317
  # Nếu chạy máy khác → đặt IP/hostname của máy chứa stack Grafana.
  ```
- Tất cả compose con đã mount `OTEL_EXPORTER_OTLP_PROTOCOL=${OTEL_PROTOCOL}` và `OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_ENDPOINT}` (ví dụ `docker-compose/services/matching-engine/docker-compose.yml`).
- Sau khi sửa `.env`, chạy `docker compose --env-file ../.env up -d <service>` để reload từng service hoặc dùng `run.sh`.
- Aspire Dashboard vẫn nhận trace vì Collector export song song.
- Khi tạo datasource Tempo trong Grafana, dùng `http://tempo:3200` (nếu cùng stack) hoặc `http://<host-ip>:3200` nếu datasource nằm ngoài compose.

### 8. Kết quả Step 1
- Hệ thống Grafana + Tempo + OTel Collector hoạt động độc lập nhưng publish port đầy đủ.
- `.NET` services chuẩn bị chuyển endpoint sang Collector mới.
- Sẵn sàng bước tiếp theo để xác nhận Gateway và các service đã gửi trace đúng Collector.

