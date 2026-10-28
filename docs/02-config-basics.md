# Reading a collector config, section by section

Annotated against `configs/02-pipelines.yaml` — open it side by side.

## Top-level keys (only three matter)

```yaml
receivers:   # declare available inputs
processors:  # declare available transforms
exporters:   # declare available outputs
extensions:  # sidecar capabilities (health_check, file_storage, ...)
service:     # THE wiring: pipelines + which extensions run + own telemetry
```

Anything outside `service` is a **declaration**. Nothing runs until `service`
references it. A declared-but-unwired component is the #1 silent misconfiguration.

## The `service.pipelines` contract

```yaml
service:
  pipelines:
    traces:                    # pipeline NAME = signal type
      receivers: [otlp]        # may list several -> fan-in
      processors: [a, b, c]    # ORDER IS EXECUTION ORDER
      exporters: [x]           # may list several -> fan-out (each gets a copy)
```

Rules worth memorizing:

1. Processor order = execution order. `memory_limiter` goes **first** so it
   sheds load before any expensive transform runs. `batch` goes **last**.
2. Multiple exporters = broadcast. Each exporter gets its own copy of the data.
3. Pipelines of different signals don't share processors unless the processor
   is stateless-and-cheap (a shared `batch` is a separate instance per pipeline).

## Processor anatomy: they're all list-of-action shaped

```yaml
attributes/scrub:
  actions:
    - key: http.request.header.authorization
      action: delete
```

- `insert` — only if key absent
- `update` — only if key present
- `upsert` — insert or update (the "just make it true" choice)
- `delete` — remove

The `attributes` processor touches **span/log attributes**; the `resource`
processor touches **Resource attributes** (service.name, host.name...). They look
identical and operate on different layers — a very common source of "why didn't
my attribute change show up".

## The `service.telemetry` block

The collector emits metrics about **itself** on `:8888`. The ones that matter
when debugging throughput/loss:

- `otelcol_receiver_accepted_*` / `otelcol_exporter_sent_*` — compare sent vs
  accepted per signal: a divergence = data lost or queued inside the collector
- `otelcol_exporter_queue_size` / `_capacity` — sending_queue fill level
- `otelcol_process_memory_rss` — actual memory vs memory_limiter limits
- `otelcol_exporter_send_failed_*` — retries exhausted / hard failures

## Validation without running

```bash
docker run --rm -v "$PWD/configs:/cfg" \
  otel/opentelemetry-collector-contrib:0.154.0 \
  validate --config=/cfg/02-pipelines.yaml
```

`validate` checks schema + component wiring without opening ports. Use it in CI —
an invalid config fails at startup and drops **all** telemetry until fixed.
