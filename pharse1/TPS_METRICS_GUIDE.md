# TPS Metrics Guide - Event-Driven System

## Vấn đề với công thức cũ

### ❌ Công thức sai:
```promql
# Quá chung chung, match nhiều spans không liên quan
sum(rate(traces_spanmetrics_calls_total{span_name=~"POST.*Order/trade"}[1m]))

# Chỉ đếm Kafka publish events, không phản ánh throughput thực
sum(rate(traces_spanmetrics_calls_total{span_name=~"trades\\..* publish"}[1m]))
```

**Lý do sai:**
1. Không filter theo `service` → đếm trùng lặp spans từ nhiều services
2. Regex quá rộng → match cả spans không liên quan (health checks, monitoring, etc.)
3. Chỉ đếm events chứ không đếm business transactions
4. Trong event-driven system, 1 order có thể tạo ra nhiều events (publish, process, notify)

## ✅ Công thức đúng cho Event-Driven Architecture

### 1. Order Submission TPS
Đếm số orders được submit từ Exchange API:

```promql
sum(rate(traces_spanmetrics_calls_total{
  service="ssidx-exchange",
  span_name=~"POST.*Order.*"
}[1m]))
```

**Ý nghĩa:** Số orders mà users submit qua API mỗi giây

### 2. Order to Matcher TPS
Đếm orders được gửi tới Matching Engine:

```promql
sum(rate(traces_spanmetrics_calls_total{
  service="ssidx-submission",
  span_name=~"orders.*publish"
}[1m]))
```

**Ý nghĩa:** Số orders được validate và forward tới matcher

### 3. Order Matching TPS
Đếm orders được xử lý bởi Matching Engine:

```promql
sum(rate(traces_spanmetrics_calls_total{
  service="ssidx-matcher",
  span_name=~"orders.*process"
}[1m]))
```

**Ý nghĩa:** Throughput thực của matching engine

### 4. Trade Execution TPS
Đếm trades được tạo ra sau khi match thành công:

```promql
sum(rate(traces_spanmetrics_calls_total{
  service="ssidx-matcher",
  span_name=~"trades.*publish"
}[1m]))
```

**Ý nghĩa:** Số trades thực sự được execute (matching thành công)

### 5. Trade Settlement TPS
Đếm trades được settle (cập nhật balance):

```promql
sum(rate(traces_spanmetrics_calls_total{
  service="ssidx-settlement",
  span_name=~"trades.*process"
}[1m]))
```

**Ý nghĩa:** Số trades đã hoàn tất settlement

### 6. Balance Update TPS
Đếm số lần cập nhật balance:

```promql
sum(rate(traces_spanmetrics_calls_total{
  service="ssidx-assets",
  span_name="balance.change process"
}[1m]))
```

**Ý nghĩa:** Throughput của Asset Engine khi xử lý balance changes

## Kiến trúc Pipeline & Metrics

```
User Request → Exchange API → Submission → Matcher → Settlement → Assets
     │              │             │           │          │           │
     │              │             │           │          │           │
  Order         Order         Orders      Trades     Trades    Balance
Submission    Accepted       Queued     Generated   Settled    Updated
   TPS           TPS           TPS         TPS        TPS        TPS
```

### Span Names trong hệ thống:

**ssidx-exchange (API Gateway):**
- `POST api/v{version:apiVersion}/Order/trade` - Order submission endpoint

**ssidx-submission (Order Validation):**
- `orders-submission.{pair} process` - Validate order
- `orders.{pair} publish` - Forward to matcher
- `insert OrderEntity` - Persist to DB

**ssidx-matcher (Matching Engine):**
- `orders.{pair} process` - Match order
- `trades.{pair} publish` - Publish matched trades

**ssidx-settlement (Settlement):**
- `trades.{pair} process` - Process trade settlement
- `balance.change publish` - Publish balance changes
- `update OrderOpen` / `findAndModify OrderOpen` - Update order status
- `insert OrderWait` - Create filled orders

**ssidx-assets (Asset Management):**
- `balance.change process` - Apply balance changes
- `asset.notify publish` - Notify about asset changes
- `notify.private publish` - Send user notifications

## Labels trong Prometheus

Tất cả metrics có format:
```
traces_spanmetrics_calls_total{
  service="<service-name>",      # Tên service (ssidx-exchange, ssidx-matcher, etc.)
  span_name="<operation>",       # Tên operation cụ thể
  span_kind="SPAN_KIND_*",       # CONSUMER, PRODUCER, CLIENT, SERVER
  cluster="docker-compose",
  source="tempo"
}
```

## Best Practices

### ✅ DO:
1. Luôn filter theo `service` để tránh đếm trùng
2. Dùng exact match cho span_name khi có thể
3. Dùng regex cẩn thận, test trước khi deploy
4. Monitor từng stage của pipeline riêng biệt
5. So sánh TPS giữa các stages để tìm bottleneck

### ❌ DON'T:
1. Không dùng regex quá rộng như `.*Order.*`
2. Không skip service filter
3. Không chỉ nhìn vào publish events mà bỏ qua process events
4. Không aggregate tất cả services lại thành 1 metric duy nhất

## Troubleshooting

### Không có data?
```bash
# Kiểm tra metrics có tồn tại không
curl "http://localhost:9090/api/v1/query?query=traces_spanmetrics_calls_total"

# List tất cả span names
curl "http://localhost:9090/api/v1/query?query=count%20by%20(service,span_name)%20(traces_spanmetrics_calls_total)"
```

### TPS = 0?
- Kiểm tra service name đúng chưa (ssidx-*, không phải ssid-*)
- Kiểm tra span_name có match với actual spans không
- Verify time range trong Grafana
- Kiểm tra OTel Collector và Tempo đang chạy

### TPS cao bất thường?
- Có thể đang đếm spans từ nhiều services (thiếu service filter)
- Regex match quá nhiều spans (quá rộng)
- Có retry/duplicate requests

## Tham khảo thêm

- [OpenTelemetry Span Metrics](https://opentelemetry.io/docs/specs/otel/metrics/semantic_conventions/span-metrics/)
- [Prometheus Rate Function](https://prometheus.io/docs/prometheus/latest/querying/functions/#rate)
- [Grafana TraceQL](https://grafana.com/docs/tempo/latest/traceql/)

