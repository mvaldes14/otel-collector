CONFIG ?= configs/01-minimal.yaml
COMPOSE := docker compose

.PHONY: up down logs push-telemetry switch-config ps

## up: start the collector with $(CONFIG)
up:
	$(COMPOSE) up -d
	@echo "collector up. config: $(CONFIG). health: curl localhost:13133"

## down: stop everything
down:
	$(COMPOSE) down -v

## logs: follow collector output (this is where the debug exporter prints)
logs:
	$(COMPOSE) logs -f collector

## push-telemetry: fire one synthetic trace + log at OTLP/HTTP
push-telemetry:
	@bash scripts/generate-telemetry.sh

## switch-config: CONFIG=configs/02-pipelines.yaml make switch-config
switch-config:
	sed -i 's#\./configs/[0-9a-z-]*\.yaml#$(CONFIG)#' docker-compose.yml
	$(COMPOSE) up -d --force-recreate collector
	@echo "now running: $(CONFIG)"

## ps: what's running
ps:
	$(COMPOSE) ps
