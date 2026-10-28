# Distributions: core vs contrib vs vendor builds

"OpenTelemetry Collector" is not one binary. It's a **build system** (`ocb`, the
collector builder) that compiles a chosen set of components into one binary.

## The three you'll encounter

| Distro | What's in it | When it fits |
|---|---|---|
| `otelcol-core` | Only stable, "core" components (OTLP receiver, batch, basic exporters) | Lean, security-sensitive footprints |
| `otelcol-contrib` | Everything the contrib repo ships (100+ components) | Default general-purpose choice; what this lab uses |
| Vendor distros | Curated subset, possibly custom components | SigNoz, Grafana Agent, Datadog, etc. |

SigNoz's `signoz-otel-collector` is a **vendor distribution** — mostly contrib
components plus their own ClickHouse exporter and config presets (the `base` /
`k8s` / `k8s-logs` presets in their chart). Practically: any config key you'd write
for contrib 0.154 applies, but a few components (e.g. `clickhouse` exporter) only
exist in their build.

## Why this matters for upgrades

Because distros are **compiled subsets**, upgrading is not a version bump — it's a
component-set change:

- A component can be **renamed** (`logging` -> `debug` exporter, 0.86)
- A component can be **removed** from a distro between releases
- Defaults drift (e.g. receiver endpoint binding defaults, the `$(VAR)` vs
  `${env:VAR}` env expansion syntax change)

The homelab corollary: the SigNoz chart pins the collector version. When you tune
agent config (like the `hostmetrics` scrapers), you're editing a ConfigMap that the
chart regenerates — chart upgrades can silently reset hand-edits. Anything you want
durable belongs in the chart values, in Git.

## Checking what's actually in a binary

```bash
docker run --rm otel/opentelemetry-collector-contrib:0.154.0 components
# prints: receivers, processors, exporters, extensions, connectors + build info
```

Run this against ANY collector binary (including SigNoz's) before writing config
for it — it's the ground truth for "does this distro support the component I want".

## Building your own

`ocb` takes a manifest listing exactly the components you want and emits a binary.
That's the endgame of understanding the collector: when you realize the config file
is just wiring, and the binary is just a container of parts, "which collector
should I run" becomes "which parts do I need".
