## Step 5 – Consumer & queue delay (Assets, Settlement, Statistic…)

### 1. Context
- `SSIDX.Services.Kafka` đã hỗ trợ `Confluent.Kafka.Extensions.OpenTelemetry`.
- Consumer logic (ví dụ `Assets/SSIDX.Engines.Assets/Consumers/AssetSubscriber.cs`) đang đọc `TraceContext` để tạo Activity mới.
- Cần chuẩn hoá việc đo queue delay và gắn tag bottleneck.

### 2. Extract trace context
```csharp
var carrier = new PropagationContext(ActivityContext.Parse(traceparent), Baggage.Current);
using var span = _tracer.StartActiveSpan("asset.consume", SpanKind.Consumer, carrier.ActivityContext);
span.SetAttribute("topic", context.Topic);
span.SetAttribute("partition", context.Partition);
span.SetAttribute("offset", context.Offset.Value);
```

### 3. Tính queue delay & processing latency
- Khi producer gửi message, lưu `EventPublished` (UTC ticks) vào payload (đã tồn tại trong nhiều DTO).
- Ở consumer:
```csharp
var queueDelay = DateTime.UtcNow - message.EventPublished;
span.SetAttribute("queue_delay_ms", queueDelay.TotalMilliseconds);
```
- Các bước xử lý nội bộ (validation, DB, publish event mới) nên có child span:
```csharp
using var processSpan = _tracer.StartActiveSpan("asset.process_balance", SpanKind.Internal);
processSpan.SetAttribute("orderId", message.OrderId);
```

### 4. Xử lý DLQ/Retry
- Khi push vào Dead Letter Queue: `span.RecordException(ex); span.SetAttribute("dlq_topic", "asset-dlq");`
- Nếu có retry: thêm event `span.AddEvent("retry", new("attempt", retryCount));`.

### 5. Kiểm tra bằng Tempo
1. Truy vấn TraceQL:
```
{ service.name = "SSIDX.Engines.Assets" && span.name = "asset.consume" }
```
2. Xem attribute `queue_delay_ms`.
3. So sánh `queue_delay_ms` với chênh lệch `startTime(producer)` để đảm bảo logic đúng.

### 6. Kết quả Step 5
- Consumer span đầy đủ metadata (topic, partition, offset, queue delay).
- Bottleneck (delay cao) hiển thị được ở dashboard.

