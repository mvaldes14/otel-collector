# Collector architecture — the four things to internalize

## 1. Components are typed and wired, never invented

There are exactly five component types:

| Type | Role | Examples |
|---|---|---|
| Receiver | how data enters | `otlp`, `filelog`, `hostmetrics`, `kubeletstats` |
| Processor | transform in-place, per pipeline, in declared order | `batch`, `memory_limiter`, `tail_sampling`, `attributes` |
| Exporter | how data leaves | `otlp`, `debug`, `clickhouse` |
| Extension | sidecar capabilities, not on pipelines | `health_check`, `file_storage`, `pprof` |
| Connector | joins two pipelines (producer + consumer) | `routing`, `spanmetrics` |

A component must be **declared in its section AND referenced from a pipeline**.
Declaring a receiver but never wiring it = silent no-op. This bites everyone once.

## 2. Pipelines are the unit of deployment

`service.pipelines.<signal>` — one per signal type (`traces`, `metrics`, `logs`).
Each is an independent conveyor: its own receivers, its own ordered processors,
its own exporters. Two pipelines can share a receiver; data is then **fanned out**
to both. There is no global processing order across pipelines.

## 3. The collector is a set of bounded queues

Mental model that pays off when debugging backpressure:

```
receiver -> (in-memory pipeline buffer) -> processors -> exporter queue -> network
```

- `memory_limiter` guards the pipeline buffer (sheds when above limit)
- `sending_queue` guards the exporter (holds batches during backend outage)
- `batch` reduces network round-trips, costs added latency (its `timeout`)

If telemetry is "missing", walk that chain: was data received (receiver metrics),
dropped by memory_limiter (`otelcol_processor_accepted_*`), queued (queue size),
or rejected by the backend (exporter errors)?

## 4. Agent vs gateway — the deployment topology question

- **Agent**: DaemonSet, one per node. Cheap, close to the source, no tail_sampling
  (spans of one trace live on many nodes).
- **Gateway**: Deployment, few replicas. Expensive per-instance, sees whole traces
  (so tail_sampling lives here), one place for credentials and egress control.
- The homelab runs both: `signoz-k8s-helm-k8s-infra-otel-agent` (DaemonSet, 6 replicas,
  one per node) feeding `signoz-signoz-helm-otel-collector` (gateway) feeding ClickHouse.

Almost every "why is my trace weird" question is answered by knowing which of these
a given pipeline ran on.

## Honest limitations to know up front

- The in-memory queue is lost on restart. True durability = `file_storage` extension.
- `batch` is not delivery guarantee; it's grouping. At-least-once comes from
  retry + queue; exactly-once doesn't exist (duplicates are possible after retry).
- Component versions move fast. Always diff against the changelog of the version
  you actually deploy — see `03-distributions.md`.
