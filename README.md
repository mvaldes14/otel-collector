# otel-collector learning lab

A hands-on playground for understanding OpenTelemetry Collector internals — config,
pipelines, processors, and how data flows. Everything here is runnable locally with
Docker, and every concept maps to a real collector already running in the homelab.

## The mental model in one paragraph

The Collector is a **telemetry router and pipeline engine**. It has no opinions about
your data. You declare **receivers** (how data gets in), **processors** (what happens
to it in order), **exporters** (where it goes), and wire them into **pipelines** — one
per signal type (traces, metrics, logs). Every pipeline is
`receivers -> processors -> exporters`, applied in the declared order. Everything else
(extensions, service telemetry) is supporting infrastructure.

## Layout

```
configs/
  01-minimal.yaml        one receiver, one exporter, one pipeline — the smallest legal config
  02-pipelines.yaml      all three signals + batch + memory_limiter, attributes processor
  03-production.yaml     retry/backoff, sending_queue, resourcedetection, health_check
  04-sampling.yaml       tail_sampling: keep all errors, sample the rest
docs/
  01-architecture.md     components, pipelines, the collector as four queues
  02-config-basics.yaml  annotated walkthrough of a config file, section by section
  03-distributions.md    core vs contrib vs vendor distros (SigNoz's is a distro)
  04-homelab-map.md      every collector running in the k3s cluster, and what it does
docker-compose.yml      collector + a tiny OTLP generator, wires to configs/01
scripts/
  generate-telemetry.sh  push a hand-built OTLP/JSON trace+log straight at :4318
Makefile                up / down / logs / validate / push-telemetry
```

## Quick start

```bash
make up                 # starts collector with configs/01-minimal.yaml
make push-telemetry     # generates one trace + one log via OTLP/HTTP
make logs               # watch the debug exporter print them
```

Then swap the compose file's config mount to `02-pipelines.yaml`, `03-...`, and read
`docs/01-architecture.md` alongside each step-up.

## Which version?

Examples target `opentelemetry-collector-contrib` **0.154.0** — deliberately the same
major the homelab runs (`clickhouse/ck-collector-collector`), so what you learn here
transfers 1:1. Config syntax changes between versions (e.g. `logging` exporter was
renamed to `debug` in 0.86; the batch processor keys are stable but verify against the
version you deploy).
