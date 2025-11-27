## Step 4 – Producer (CoreAPI, Matcher, Asset, Trade) bám sát implementation

### 1. Thực trạng
- Các service .NET đã dùng `Activity`/`OTELHelper` để nhúng trace context vào message.
- Ví dụ:
  - `Assets/SSIDX.Engines.Assets.Libs/Models/ChangeBalanceCommand.cs` chứa trường `TraceContext`.
  - `CoreLibs/SSIDX.Shared/Utilities/OTELHelper.cs` hỗ trợ `GetTraceContext()` và `RestoreCurrentContext`.
- Cần xác nhận mọi luồng publish Kafka đều gọi helper này và set attribute chuẩn để tính TPS/queue delay.

### 2. Checklist triển khai
| Service | Vị trí publish | Việc cần làm |
| --- | --- | --- |
| Exchange Endpoint | `SSIDX.Services.Publishers` | Gọi `Activity.Current?.SetTag("orderId", ...)` trước khi push vào Kafka. |
| Matcher Engine | `Matching/SSIDX.Engines.Matching/Consumers/...` | Đảm bảo `ConfigureOpenTelemetry` active và `IKafkaService` set header `traceparent`. |
| Asset Engine | `Assets/SSIDX.Engines.Assets/Consumers/AssetSubscriber` | Đã có comment “Capture OpenTelemetry Activity context” – cần verify header ghi vào `ChangeBalanceCommand`. |
| Trade/Settlement | `Settlement/..` | Tương tự, gắn `TraceContext`. |

### 3. Tiêu chuẩn span producer
```csharp
using var activity = TracerProvider.Default.GetTracer("SSIDX.Matcher")
    .StartActivity("matcher.publish", ActivityKind.Producer);
activity?.SetTag("orderId", order.Id);
activity?.SetTag("symbol", order.Symbol);
activity?.SetTag("topic", topic);
activity?.SetTag("event_type", "OrderCreated");

var traceContext = OTELHelper.GetTraceContext();
message.Headers.Add("traceparent", Encoding.UTF8.GetBytes(traceContext));
```

### 4. Kiểm tra bằng thực tế
1. Bật `LogLevel: "Microsoft.AspNetCore.Hosting": "Information"` để dễ thấy ActivityId trong log.
2. Sau khi publish, kiểm tra Kafka message (dùng `kcat -C`) xem có header `traceparent`.
3. Trên Tempo, dùng truy vấn:
```
{ service.name = "SSIDX.Engines.Matching" && span.kind = "SPAN_KIND_PRODUCER" }
```
→ confirm attribute `orderId`, `symbol`.

### 5. Output Step 4
- Mọi producer span có metadata chuẩn.
- Header `traceparent` gắn vào message payload/headers, sẵn sàng cho consumer Step 5.

