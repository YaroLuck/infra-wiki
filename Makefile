SHELL := /bin/bash
SERVICES := reverse-proxy docmost
NET := web
BACKUP_DIR := backups

.PHONY: help
help:
	@echo "Server: infra-wiki"
	@echo "Targets:"
	@echo "  ensure-net       - создать внешнюю сеть '$(NET)' если нет"
	@echo "  up dir=<svc>     - поднять сервис (reverse-proxy|docmost)"
	@echo "  down dir=<svc>   - остановить сервис"
	@echo "  up-all           - поднять все"
	@echo "  down-all         - остановить все"
	@echo "  pull-all         - обновить образы"
	@echo "  ps-all           - показать статусы"
	@echo "  backup-db/files  - сделать бэкапы DocMost"

define need_dir
	@if [ -z "$(dir)" ]; then echo "Укажи: make <target> dir=docmost|reverse-proxy"; exit 1; fi
endef

# --- Single service ---
up:
	$(call need_dir)
	cd $(dir) && docker compose up -d

down:
	$(call need_dir)
	cd $(dir) && docker compose down

# --- All services ---
ensure-net:
	@docker network inspect $(NET) >/dev/null 2>&1 || docker network create $(NET)

up-all: ensure-net
	@set -e; for s in $(SERVICES); do echo ">>> UP $$s"; cd $$s && docker compose up -d; cd - >/dev/null; done

down-all:
	@set -e; for s in $(SERVICES); do echo ">>> DOWN $$s"; cd $$s && docker compose down; cd - >/dev/null; done

pull-all:
	@set -e; for s in $(SERVICES); do echo ">>> PULL $$s"; cd $$s && docker compose pull; cd - >/dev/null; done

ps-all:
	@set -e; for s in $(SERVICES); do echo ">>> PS $$s"; cd $$s && docker compose ps; cd - >/dev/null; done

# --- Backups ---
backup-db:
	@mkdir -p $(BACKUP_DIR)
	@ts=$$(date +'%Y%m%d_%H%M%S'); \
	cont=$$(docker ps --format '{{.Names}}' | grep -E '^docmost_db$$' || true); \
	if [ -z "$$cont" ]; then echo "Контейнер docmost_db не найден"; exit 1; fi; \
	docker exec $$cont sh -lc 'pg_dump -U "$$POSTGRES_USER" "$$POSTGRES_DB"' > $(BACKUP_DIR)/docmost_db_$$ts.sql && \
	echo "OK -> $(BACKUP_DIR)/docmost_db_$$ts.sql"

backup-files:
	@mkdir -p $(BACKUP_DIR)
	@ts=$$(date +'%Y%m%d_%H%M%S'); \
	vol=$$(docker volume ls --format '{{.Name}}' | grep -E '^docmost_docmost_data$$' || true); \
	if [ -z "$$vol" ]; then echo "Том docmost_docmost_data не найден"; exit 1; fi; \
	docker run --rm -v $$vol:/data -v $$(pwd)/$(BACKUP_DIR):/backup alpine sh -c "cd / && tar czf /backup/docmost_files_$$ts.tgz data" && \
	echo "OK -> $(BACKUP_DIR)/docmost_files_$$ts.tgz"
