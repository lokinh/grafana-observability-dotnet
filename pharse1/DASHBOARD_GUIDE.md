# Grafana Dashboard - Phase 1 Tracing Guide

## Truy cập Dashboard

1. Mở trình duyệt: http://localhost:3000
2. Dashboard tự động load (anonymous authentication enabled)
3. Tìm dashboard: **SSIDX Tracing Phase 1** (trong folder "Tracing" hoặc search)

## Các Panel trong Dashboard

### 1. Request Rate (TPS) by Service
- **Loại**: Time series
- **Nguồn**: Prometheus
- **Metric**: `rate(http_server_request_duration_seconds_count[1m])`
- **Mục đích**: Hiển thị số request/giây theo từng service và route
- **Cách dùng**: 
  - Chọn service trong dropdown ở trên
  - Xem TPS theo thời gian
  - So sánh TPS giữa các routes

### 2. P95 Latency by Service
- **Loại**: Bar gauge
- **Nguồn**: Prometheus
- **Metric**: `histogram_quantile(0.95, ...)`
- **Mục đích**: Hiển thị độ trễ P95 của từng service
- **Cảnh báo**:
  - Xanh: < 100ms
  - Vàng: 100-500ms
  - Đỏ: > 500ms

### 3. Top Slow Traces (>100ms)
- **Loại**: Table
- **Nguồn**: Tempo
- **TraceQL**: `{resource.service.name="$service"} | duration > 100ms`
- **Mục đích**: Liệt kê các traces chậm nhất
- **Tính năng**:
  - Click vào "Trace ID" để xem chi tiết trace trong Explore
  - Sắp xếp theo Duration để tìm bottleneck
  - Hiển thị top 20 traces chậm nhất

### 4. Service Logs
- **Loại**: Logs panel
- **Nguồn**: Loki
- **Query**: `{service_name="$service"}`
- **Mục đích**: Xem logs của service được chọn
- **Tính năng**:
  - Auto-refresh mỗi 5s
  - Filter logs theo time range
  - Correlation với traces (via trace ID trong logs)

### 5. Request Duration Percentiles
- **Loại**: Time series
- **Nguồn**: Prometheus
- **Metrics**: P50, P95, P99
- **Mục đích**: So sánh các percentile latency
- **Cách đọc**:
  - P50 (median): Phần lớn requests
  - P95: Trường hợp xấu
  - P99: Edge cases
  - Nếu P95/P99 cao hơn P50 nhiều → có bottleneck

### 6. Total Request Rate
- **Loại**: Gauge
- **Nguồn**: Prometheus
- **Metric**: `sum(rate(...))`
- **Mục đích**: Tổng TPS của service hiện tại
- **Threshold**:
  - Xanh: < 100 rps
  - Vàng: 100-1000 rps
  - Đỏ: > 1000 rps

## Template Variables

### $service
- **Nguồn**: Prometheus `label_values(service_name)`
- **Mục đích**: Filter data theo service
- **Giá trị mẫu**:
  - ssidx-assets-engine
  - ssidx-exchange
  - ssidx-matcher
  - ssidx-settlement
  - ssidx-nginx

## Use Cases

### Case 1: Tìm Bottleneck
1. Vào panel "Top Slow Traces"
2. Click vào Trace ID của trace chậm nhất
3. Xem waterfall trong Explore
4. Identify span nào consume nhiều thời gian nhất

### Case 2: Phân tích TPS Drop
1. Xem panel "Request Rate (TPS) by Service"
2. Identify thời điểm TPS giảm
3. Check panel "Service Logs" cùng time range
4. Tìm errors/exceptions trong logs

### Case 3: So sánh Performance giữa các Service
1. Xem panel "P95 Latency by Service"
2. Identify service nào có latency cao nhất
3. Vào "Top Slow Traces" của service đó
4. Analyze root cause

### Case 4: Monitor Real-time
1. Set refresh rate = 5s (ở góc trên)
2. Set time range = Last 15 minutes
3. Quan sát TPS và latency realtime
4. Trigger alerts nếu vượt threshold

## Validation

### Test Dashboard hoạt động đúng:

1. **Generate Traffic**:
```bash
# Gọi API nhiều lần
for i in {1..100}; do
  curl -X GET "http://localhost:10000/api/v1/Account/balance?clnId=1"
done
```

2. **Kiểm tra Panels**:
   - TPS panel phải tăng
   - Traces xuất hiện trong "Top Slow Traces"
   - Logs hiển thị requests
   - Latency metrics update

3. **Test Trace Correlation**:
   - Click vào một Trace ID
   - Verify mở Explore với trace details
   - Xem các spans linked với nhau

## Troubleshooting

### Dashboard không hiển thị data

1. **Kiểm tra datasources**:
```bash
# Grafana logs
docker logs grafana --tail 50

# Verify datasources
curl http://localhost:3000/api/datasources
```

2. **Kiểm tra Prometheus có metrics**:
```bash
# Query Prometheus
curl "http://localhost:9090/api/v1/query?query=up"
```

3. **Kiểm tra Tempo có traces**:
```bash
# Query Tempo
curl "http://localhost:3200/api/search?limit=10"
```

4. **Kiểm tra Loki có logs**:
```bash
# Query Loki
curl "http://localhost:3100/loki/api/v1/query_range?query={job=\"varlogs\"}"
```

### Tempo queries trả về empty

- Verify service đang gửi traces:
```bash
docker logs otelcollector --tail 20 | grep -i "trace"
```

- Check OTEL_ENABLE environment variable:
```bash
docker exec ssidx-assets-engine printenv | grep OTEL
```

### Loki không có logs

- Verify OTLP receiver trong OTel Collector:
```bash
docker logs otelcollector --tail 20 | grep -i "log"
```

- Check Loki config:
```bash
docker exec loki cat /etc/loki/local-config.yaml
```

## Next Steps - Phase 2

1. **Span Metrics**: Enable span-metrics processor trong OTel Collector
2. **Exemplars**: Link metrics → traces
3. **Queue Delay Dashboard**: Thêm panel đo queue delay từ Kafka timestamp
4. **Alerting**: Tạo alerts cho high latency, low TPS, error rate
5. **Custom Attributes**: Thêm business attributes (orderId, symbol, userId)

## Dashboard Maintenance

### Backup Dashboard
```bash
# Export dashboard JSON
curl -H "Content-Type: application/json" \
  http://localhost:3000/api/dashboards/uid/ssidx-tracing-phase1 > backup.json
```

### Update Dashboard
1. Edit trong Grafana UI
2. Save changes
3. Export JSON: Settings → JSON Model → Copy
4. Update `docker-compose/grafana/pharse1/dashboards/tracing-phase1.json`
5. Commit to git

### Version Control
- Dashboard JSON được lưu trong repo
- Mọi thay đổi phải commit
- Tag version khi có breaking changes

