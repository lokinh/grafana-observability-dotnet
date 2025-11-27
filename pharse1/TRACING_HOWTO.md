# Cách Xem Distributed Tracing Waterfall

## Giống như Aspire Dashboard

Để xem trace waterfall như trong Aspire Dashboard (các microservices liên tục nhau), làm theo các bước sau:

---

## Phương pháp 1: Grafana Explore (Khuyên dùng)

### Bước 1: Mở Grafana Explore
```
http://localhost:3000/explore
```

### Bước 2: Chọn Tempo Datasource
- Trong dropdown "Datasource" ở góc trên, chọn **Tempo**

### Bước 3: Query Traces
Có 3 cách query:

#### A. Search by Service Name
1. Query type: **Search**
2. Service Name: chọn service (vd: `ssidx-assets`, `ssidx-exchange`)
3. Click **Run query**
4. Sẽ thấy list các traces gần đây

#### B. TraceQL Query
```traceql
{resource.service.name="ssidx-assets"} | duration > 100ms
```
Hoặc:
```traceql
{resource.service.name="ssidx-nginx"} && span.http.method="GET"
```

#### C. Search by Trace ID
- Nếu bạn có Trace ID (từ logs hoặc dashboard), paste trực tiếp vào ô query

### Bước 4: Xem Trace Details
1. Click vào bất kỳ Trace ID nào trong results
2. Sẽ thấy **Waterfall view** với:
   - **Timeline**: Thời gian của từng span
   - **Service hierarchy**: Cấu trúc call chain
   - **Span details**: Attributes, events, logs
   - **Duration**: Thời gian mỗi operation

---

## Phương pháp 2: Từ Dashboard

### Bước 1: Mở Dashboard
```
http://localhost:3000/d/ssidx-tracing-phase1/ssidx-tracing-phase-1
```

### Bước 2: Tìm Slow Traces
- Scroll xuống panel **"Top Slow Traces (>100ms)"**
- Sẽ thấy table với các trace chậm nhất

### Bước 3: Click Trace ID
- Click vào cột **"Trace ID"**
- Sẽ tự động mở Explore view với trace waterfall đầy đủ

---

## Phương pháp 3: Service Graph (Tempo 2.x)

Tempo 2.9.0 hỗ trợ Service Graph để visualize service dependencies:

### Bước 1: Mở Explore
```
http://localhost:3000/explore?left={"datasource":"tempo","queries":[{"queryType":"serviceMap"}]}
```

### Bước 2: Query type = Service Graph
- Chọn **Service Graph** trong Query type dropdown
- Sẽ thấy diagram các services và connections

---

## Đọc Trace Waterfall

### Cấu trúc của một Trace:

```
webfrontend: GET /weather                    [20.88ms] ──────────────────────┐
├─ webfrontend → Browser Link: GET           [718µs]   ─┐                    │
├─ webfrontend → cache: DATA redis GET       [982µs]    ├─ Parallel calls   │
├─ webfrontend → GET                         [1.44ms]  ─┘                    │
│  └─ apiservice → GET /weatherforecast      [108µs]   ← Backend call       │
└─ webfrontend → cache: DATA redis SETEX     [1.15ms]   ← Cache write       │
                                                                              │
Total Duration: 20.88ms                      ────────────────────────────────┘
```

### Cách đọc:
1. **Depth (Độ sâu)**: Số lượng services trong chain
2. **Total spans**: Tổng số operations
3. **Critical path** (đường màu đậm): Longest path quyết định total duration
4. **Parallel operations**: Các spans cùng level chạy đồng thời

---

## So sánh Aspire vs Grafana Tempo

| Tính năng | Aspire Dashboard | Grafana Tempo |
|-----------|------------------|---------------|
| **Trace Waterfall** | ✅ Có | ✅ Có |
| **Service dependencies** | ✅ Có | ✅ Có (Service Graph) |
| **Span attributes** | ✅ Có | ✅ Có (chi tiết hơn) |
| **TraceQL query** | ❌ Không | ✅ Có |
| **Correlation with logs** | ❌ Không | ✅ Có (Loki) |
| **Correlation with metrics** | ✅ Basic | ✅ Advanced (Exemplars) |
| **Custom dashboards** | ❌ Không | ✅ Có |
| **Data retention** | ❌ In-memory only | ✅ Persistent |

---

## TraceQL Queries Hữu Ích

### 1. Tìm slow traces
```traceql
{duration > 500ms}
```

### 2. Traces với errors
```traceql
{status = error}
```

### 3. Traces theo HTTP route
```traceql
{span.http.route = "/api/v1/Account/balance"}
```

### 4. Traces từ specific service
```traceql
{resource.service.name = "ssidx-assets"}
```

### 5. Traces với database calls
```traceql
{span.db.system = "postgresql"}
```

### 6. Combined query
```traceql
{resource.service.name = "ssidx-exchange" && span.http.method = "GET"} | duration > 100ms
```

---

## Troubleshooting

### Không thấy traces trong Grafana

1. **Kiểm tra Tempo có traces không**:
```bash
curl http://localhost:3200/api/search?limit=10
```

2. **Kiểm tra OTel Collector logs**:
```bash
docker logs otelcollector --tail 50 | grep -i trace
```

3. **Verify time range**:
- Mặc định Grafana query "Last 1 hour"
- Nếu services mới start, thay đổi thành "Last 15 minutes"

### Traces không liên tục giữa các services

1. **Kiểm tra trace context propagation**:
- Verify HTTP headers có `traceparent`
- Verify Kafka headers có trace context

2. **Kiểm tra service names**:
```bash
# Lấy danh sách services trong Tempo
curl "http://localhost:3200/api/search/tag/service.name/values"
```

### Dashboard panel trống

1. **Verify Prometheus có metrics**:
```bash
curl "http://localhost:9090/api/v1/query?query=up"
```

2. **Check datasource health**:
- Vào Grafana → Configuration → Data sources
- Test connection cho Tempo, Prometheus, Loki

---

## Tips & Best Practices

### 1. Sử dụng Trace ID trong logs
Trong code .NET:
```csharp
var traceId = Activity.Current?.TraceId.ToString();
_logger.LogInformation("Processing order {OrderId} [TraceId: {TraceId}]", orderId, traceId);
```

Sau đó trong Grafana Explore:
- Query logs từ Loki với TraceId
- Click vào TraceId → Jump to trace

### 2. Thêm Custom Attributes
```csharp
Activity.Current?.SetTag("orderId", order.Id);
Activity.Current?.SetTag("symbol", order.Symbol);
Activity.Current?.SetTag("userId", order.UserId);
```

Attributes này sẽ xuất hiện trong trace details và có thể query bằng TraceQL.

### 3. Measure Queue Delay
```csharp
var queueDelay = DateTime.UtcNow - message.Timestamp;
Activity.Current?.SetTag("queue_delay_ms", queueDelay.TotalMilliseconds);
```

### 4. Mark Critical Spans
```csharp
Activity.Current?.SetTag("span.kind", "critical");
Activity.Current?.SetTag("business_operation", "settlement");
```

---

## Shortcuts

- **Grafana Explore với Tempo**:
  ```
  http://localhost:3000/explore?left={"datasource":"tempo"}
  ```

- **Dashboard Phase 1**:
  ```
  http://localhost:3000/d/ssidx-tracing-phase1/ssidx-tracing-phase-1
  ```

- **Tempo API Search**:
  ```
  http://localhost:3200/api/search?limit=20
  ```

- **Aspire Dashboard** (nếu vẫn chạy):
  ```
  http://localhost:18888
  ```

---

## Next Steps

1. **Enable Exemplars**: Link metrics → traces
2. **Service Graph**: Visualize service dependencies
3. **Alerting**: Alert on high latency/error rates
4. **Custom dashboards**: Per-service dashboards
5. **APM-style views**: RED metrics (Rate, Errors, Duration)

