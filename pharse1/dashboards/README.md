# SSIDX Observability Dashboards

Dashboard suite được thiết kế theo best practices của DevOps senior cho event-driven architecture.

## 🎯 Dashboard Overview

### 1. **RED Metrics (Golden Signals)** - `01-red-metrics.json`
**Purpose**: High-level service health monitoring
- **R**ate: Request throughput (RPS/TPS) 
- **E**rrors: Error rate và success rate
- **D**uration: Latency percentiles (P50/P95/P99)

**Key Features**:
- Real-time RPS từ traces (không dùng HTTP metrics)
- Error rate tracking với color-coded thresholds
- Latency distribution heatmap
- Current stats vs historical trends

**When to use**: 
- Daily health checks
- SLA monitoring
- Capacity planning
- Performance baseline

---

### 2. **Distributed Tracing** - `02-distributed-tracing.json`
**Purpose**: Deep-dive vào request flows qua services

**Key Features**:
- Slow traces table (configurable threshold: 10ms-5s)
- Failed traces với error details
- Click-through to Tempo explorer
- Trace volume và complexity metrics

**When to use**:
- Troubleshooting slow requests
- Investigating errors
- Understanding service dependencies
- Root cause analysis

---

### 3. **Error Analysis & Troubleshooting** - `03-error-analysis.json`
**Purpose**: Error-focused monitoring và triage

**Key Features**:
- Error rate trends by service
- Top erroring operations (pie chart)
- Error breakdown by service & operation
- Direct link to failed traces
- Success rate SLO tracking

**When to use**:
- Incident response
- Error pattern analysis
- Post-mortem investigations
- Service reliability tracking

---

### 4. **Logs & Correlation** - `04-logs-correlation.json`
**Purpose**: Log analysis với trace correlation

**Key Features**:
- Log volume trends
- Error/Warning log streams
- Log level distribution
- Search by Trace ID (correlate logs ↔ traces)
- Customizable log filters

**When to use**:
- Debugging specific traces
- Log pattern analysis
- Correlating logs with metrics/traces
- Finding root cause from trace ID

---

### 5. **Service Overview & Dependencies** - `05-service-overview.json`
**Purpose**: System-wide visibility và service health comparison

**Key Features**:
- Service health matrix (RPS, Errors, Latency)
- Top operations by traffic
- Slowest operations ranking
- Traffic distribution visualization
- Span kind analysis (client/server/internal)

**When to use**:
- System overview dashboards
- Comparing service performance
- Identifying bottlenecks
- Architecture optimization

---

### 6. **Service Dependencies & Data Flow** - `06-service-dependency-graph.json`
**Purpose**: Visualize service interactions và data flow patterns

**Key Features**:
- Service call flow graph
- Kafka topic producers và consumers
- Redis operations by service
- PostgreSQL operations breakdown
- MongoDB operations tracking
- Message throughput metrics

**When to use**:
- Understanding system architecture
- Identifying communication bottlenecks
- Kafka topic analysis
- Database load distribution
- Event-driven flow debugging

---

### 7. **Business & Trading Metrics** - `07-business-metrics.json`
**Purpose**: Business-level KPIs và trading performance

**Key Features**:
- Order TPS (transactions per second)
- Trade execution rate
- Balance updates tracking
- Notification throughput
- End-to-end order latency (P50/P95/P99)
- Trading pairs distribution
- Database transaction rate
- Kafka message throughput
- Average spans per trace (complexity)
- Active services count

**When to use**:
- Business performance monitoring
- Trading volume analysis
- System capacity planning
- Order-to-trade conversion tracking
- Settlement performance

---

## 📊 Data Sources

### Metrics từ Traces (Event-Driven)
Tất cả metrics được generate từ **OpenTelemetry Traces** qua **spanmetrics connector**:

```yaml
# OTel Collector Config
connectors:
  spanmetrics:
    histogram:
      buckets: [2ms, 5ms, 10ms, 25ms, 50ms, 100ms, 200ms, 500ms, 1s, 2s, 5s, 10s]
```

**Available Metrics**:
- `traces_spanmetrics_calls_total` - Total requests/events
- `traces_spanmetrics_latency_bucket` - Latency histogram
- `traces_spanmetrics_latency_sum` - Total latency
- `traces_spanmetrics_latency_count` - Request count

**Labels**:
- `service_name` - Service name từ resource attributes
- `span_name` - Operation/method name
- `span_kind` - SPAN_KIND_SERVER/CLIENT/INTERNAL/...
- `status_code` - STATUS_CODE_OK/ERROR/UNSET

### Why Not HTTP Metrics?
Event-driven systems communicate qua:
- Kafka messages
- Redis pub/sub  
- Database operations
- Internal function calls

HTTP metrics chỉ capture một phần nhỏ của traffic. **Traces capture ALL operations**.

---

## 🚀 Quick Start

### 1. Access Dashboards
```bash
# Grafana URL
http://localhost:3000

# Dashboards location
Tracing folder > Select dashboard
```

### 2. Common Workflows

#### 🔍 Investigating Slow Response
1. Open **RED Metrics** → Check P95/P99 latency spike
2. Open **Distributed Tracing** → Filter slow traces (>500ms)
3. Click trace ID → View full waterfall in Tempo
4. Open **Logs & Correlation** → Enter Trace ID → See related logs

#### 🚨 Responding to Errors
1. Open **Error Analysis** → Check error rate spike
2. View **Top Erroring Operations** pie chart
3. Click failed trace in table → Investigate in Tempo
4. Open **Logs & Correlation** → Check error logs from same service

#### 📈 Performance Review
1. Open **Service Overview** → Compare all services
2. Identify services with high latency/error rate
3. Drill down to **RED Metrics** for specific service
4. Check **Distributed Tracing** for slow operations

---

## ⚙️ Configuration

### Dashboard Variables

#### Service Selection
```
Variable: $service
Type: Query from Prometheus
Query: label_values(traces_spanmetrics_calls_total, service_name)
```

#### Duration Threshold (Distributed Tracing)
```
Variable: $min_duration
Options: 10ms, 50ms, 100ms, 200ms, 500ms, 1s, 2s, 5s
```

#### Trace ID (Logs Correlation)
```
Variable: $trace_id
Type: Textbox
Usage: Filter logs by specific trace
```

### Time Ranges
- **RED Metrics**: Last 15m (refresh 5s)
- **Distributed Tracing**: Last 1h (refresh 10s)  
- **Error Analysis**: Last 1h (refresh 10s)
- **Logs**: Last 1h (refresh 10s)
- **Service Overview**: Last 15m (refresh 10s)

---

## 🎨 Dashboard Design Principles

### 1. Top-Down Approach
- Start broad (Service Overview)
- Narrow down (RED Metrics per service)
- Deep dive (Individual traces)

### 2. Actionable Metrics
- Color-coded thresholds (green/yellow/orange/red)
- Direct links to investigation tools (Tempo, Loki)
- Click-through drill-downs

### 3. Context Preservation
- Variables preserved across dashboards
- Time range synced
- Related dashboards linked

### 4. Event-Driven Focus
- Metrics from traces (not HTTP)
- Captures Kafka, Redis, DB operations
- Internal service calls visible

---

## 📌 Best Practices

### SLO Thresholds (Recommended)
```
Latency:
  - P50: < 50ms (good), < 100ms (acceptable), > 100ms (slow)
  - P95: < 200ms (good), < 500ms (acceptable), > 500ms (slow)
  - P99: < 500ms (good), < 1s (acceptable), > 1s (critical)

Error Rate:
  - < 1% (good)
  - 1-5% (warning)
  - 5-10% (critical)
  - > 10% (incident)

Success Rate:
  - > 99% (excellent)
  - 95-99% (good)
  - 90-95% (degraded)
  - < 90% (critical)
```

### Dashboard Usage
1. **Daily**: Service Overview → Quick health check
2. **Alerts**: Error Analysis → Triage và root cause
3. **Performance**: RED Metrics → Identify degradation
4. **Debugging**: Distributed Tracing + Logs → Full context

---

## 🔧 Troubleshooting

### No Data in Dashboards?

#### Check 1: OTel Collector Running
```bash
docker logs otelcollector --tail 50
# Should see: "Starting spanmetrics connector"
```

#### Check 2: Spanmetrics Metrics Available
```bash
docker exec prometheus wget -qO- \
  "http://localhost:9090/api/v1/query?query=traces_spanmetrics_calls_total"
```

#### Check 3: Services Sending Traces
```bash
docker logs tempo --tail 50
# Should see traces being ingested
```

#### Check 4: Prometheus Scraping OTel
```bash
# Check Prometheus targets
http://localhost:9090/targets
# Look for: otelcollector endpoint
```

### Dashboard Shows Old Data?

1. Check time range (top-right corner)
2. Adjust refresh rate (5s-1m recommended)
3. Clear browser cache
4. Restart Grafana: `docker restart grafana`

---

## 📚 Related Documentation

- [STEP4_PRODUCER_TRACE.md](../STEP4_PRODUCER_TRACE.md) - How to instrument services
- [STEP6_GRAFANA_DASHBOARD.md](../STEP6_GRAFANA_DASHBOARD.md) - Dashboard setup guide
- [DASHBOARD_GUIDE.md](../DASHBOARD_GUIDE.md) - Detailed dashboard usage

---

## 🎯 Real-World Trace Example

Based on actual production trace data, here's what a **complete trade execution** looks like:

```
POST /api/v1/Order/trade (566ms total, 61 spans)
  ├─ ssidx-exchange (8 spans)
  │  ├─ Redis: GET cache:instrument (34ms)
  │  ├─ Redis: GET cache:ticker:BU2U (10ms)
  │  ├─ Redis: GET cache:ticker:BUVNC (23ms)
  │  ├─ PostgreSQL: SELECT count Order (12ms)
  │  ├─ PostgreSQL: INSERT Order (15ms)
  │  └─ Kafka: balance.change publish (274ms)
  │
  ├─ ssidx-assets (46 spans)
  │  ├─ Kafka: balance.change consume (32ms)
  │  ├─ Redis: EXISTS/SET txhash locks (8-16ms each)
  │  ├─ MongoDB: insert TransactionCollection (11-18ms each)
  │  ├─ PostgreSQL: CALL sp_commit_batch (249ms)
  │  └─ Kafka: asset.notify + notify.private publish
  │
  ├─ ssidx-submission (3 spans)
  │  ├─ Kafka: orders-submission consume (44ms)
  │  └─ Kafka: orders publish (27ms)
  │
  ├─ ssidx-matcher (2 spans)
  │  ├─ Kafka: orders consume (18ms)
  │  └─ Kafka: trades publish (19ms)
  │
  └─ ssidx-settlement (7 spans)
     ├─ Kafka: trades consume
     ├─ MongoDB: find OrderOpen (25-21ms)
     ├─ MongoDB: findAndModify OrderOpen (32ms)
     └─ MongoDB: insert OrderWait (16ms)
```

**Key Insights:**
- **61 spans** across **5 services**
- **12 Kafka messages** (publish/consume)
- **14 Redis operations** (cache + locks)
- **3 PostgreSQL queries** (including batch commit)
- **7 MongoDB operations** (order state + transactions)
- **End-to-end latency**: 566ms (P95 target: <500ms)

This level of detail helps identify:
- Bottlenecks (PostgreSQL batch commit: 249ms)
- Cascade delays (balance changes trigger multiple services)
- Database hotspots (MongoDB order state operations)

---

## 🎯 Roadmap

### Phase 2 (Planned)
- [x] Service dependency graph ✅
- [x] Business metrics dashboard ✅
- [ ] Alert rules integration (Prometheus Alertmanager)
- [ ] SLO compliance dashboard
- [ ] Cost/performance optimization dashboard
- [ ] Anomaly detection (ML-based)

---

**Maintained by**: DevOps Team  
**Last Updated**: 2025-11-20  
**Version**: Phase 1 - Event-Driven Observability

