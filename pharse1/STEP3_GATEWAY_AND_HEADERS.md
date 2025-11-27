## Step 3 – Gateway & Propagation chuẩn với context .NET hiện tại

### 1. Mục tiêu
- Đảm bảo trace root bắt đầu từ Nginx/API Gateway và xuyên suốt tới Kafka.
- Khớp với thực tế: Gateway hiện là Nginx (xem `docker-compose/services/nginx`) đứng trước các service ASP.NET.

### 2. Instrument Nginx với `nginx:1.25-otel`
Image `nginx:1.25-otel` đã có sẵn module `ngx_otel_module.so` được compile sẵn, không cần build phức tạp.

1. **Dockerfile** (`docker-compose/services/nginx/Dockerfile`):
   ```dockerfile
   FROM nginx:1.25-otel
   
   COPY nginx.conf /etc/nginx/nginx.conf
   ```

2. **nginx.conf** cấu hình theo format chuẩn:
   ```nginx
   load_module modules/ngx_otel_module.so;

   events {
       worker_connections 1024;
   }

   http {
       otel_exporter {
           endpoint http://host.docker.internal:4317;
       }

       otel_service_name "ssidx-nginx";
       otel_trace on;

       server {
           listen 80;

           location /market/ {
               otel_trace_context propagate;
               proxy_pass http://market_backend/;
               proxy_set_header traceparent $otel_trace_id;
               proxy_set_header tracestate $otel_trace_state;
               ...
           }
       }
   }
   ```
   - `load_module` phải đặt ở **top-level** (ngoài block `http`).
   - `otel_exporter.endpoint` trỏ tới Collector gRPC port `4317` (hoặc HTTP `4318/v1/traces`).
   - `otel_trace_context propagate` trong location blocks để tự động propagate trace context.
   - `proxy_set_header traceparent/tracestate` forward context xuống backend.

3. **Build & restart**:
   ```powershell
   cd docker-compose/services/nginx
   docker compose up -d --build ssidx-nginx
   docker logs ssidx-nginx  # Kiểm tra không có lỗi module
   ```

**Lưu ý**: Nếu Nginx báo lỗi `host not found in upstream`, đảm bảo các backend service (ssidx-assets-engine, ssidx-exchange-endpoint) đã chạy và cùng network `ssidx-network`.

### 3. ASP.NET Gateway/Endpoints
- Các API trong `Endpoints/SSIDX.Endpoints.*` đã tự động tạo span qua `AddServiceDefaults()`.
- Đảm bảo middleware không xoá header `traceparent`.
- Với các outbound call (HTTP/Kafka):
  - HTTP: `HttpClient` đã được `AddHttpClientInstrumentation`.
  - Kafka: dùng `SSIDX.Services.Kafka` + `OTELHelper` để ghi `TraceContext` vào payload (vd `Assets/SSIDX.Engines.Assets.Libs/Models/ChangeBalanceCommand.cs`).

### 4. Kiểm thử propagation
1. **Test endpoint đơn giản** (không cần backend):
   ```powershell
   curl http://localhost:18000/health
   # Response: "OK" + trace được gửi tới Collector
   ```

2. **Gửi request qua Nginx tới backend**:
   ```powershell
   curl http://localhost:18000/market/api/v1/orders -H "x-user: demo"
   ```

3. **Kiểm tra Collector nhận span từ Nginx**:
   ```powershell
   docker logs ssidx-otel-collector | Select-String "ssidx-nginx"
   # Hoặc xem log với verbosity: detailed để thấy span details
   ```

4. **Trên Tempo/Grafana**, truy vấn:
   - `service.name="ssidx-nginx"` → xem span root.
   - `TraceID` → bảo đảm có span `SSIDX.Endpoints.Exchange` (child span).

5. **Kafka propagation**:
   - Bật log `Confluent.Kafka` (đặt `Logging:LogLevel:Confluent.Kafka=Debug`) để thấy header `traceparent` trong message.

### 5. Checklist hoàn thành Step 3
- ✅ Nginx build thành công với `nginx:1.25-otel` và module load được.
- ✅ Nginx sinh span `ssidx-nginx` khi có request.
- ✅ Trace root có attribute `client.ip`, `http.target`.
- ✅ Header `traceparent` xuất hiện tại controller .NET (kiểm tra `Activity.Current.TraceId` trong log).
- ✅ Collector nhận được span từ Nginx (kiểm tra log hoặc Tempo search).
- ✅ Aspire Dashboard vẫn xem được trace vì Collector forward.

### 6. Troubleshooting
- **Nginx không start**: Kiểm tra `docker logs ssidx-nginx` → thường do `load_module` đặt sai vị trí hoặc upstream host không resolve được.
- **Không thấy trace**: Kiểm tra Collector endpoint có reachable từ Nginx container (`docker exec ssidx-nginx ping host.docker.internal`).
- **Trace disconnected**: Đảm bảo `otel_trace_context propagate` và `proxy_set_header traceparent` đã được set đúng trong location blocks.

### Tham khảo
- [Monitor NGINX with OpenTelemetry Tracing](https://last9.io/blog/monitor-nginx-with-opentelemetry-tracing/)
