SHELL := /bin/sh

# -------- Config --------
PROJECT      := $(notdir $(CURDIR))
TMP_DIR      ?= /tmp
DATE         := $(shell date "+%Y%m%d_%H%M%S")

# Share isolado (apenas o zip fica aqui)
SHARE_DIR    := $(TMP_DIR)/$(PROJECT)-share-$(DATE)
ZIP_BASENAME := $(PROJECT)-stack-$(DATE).zip
ZIP_FILE     := $(SHARE_DIR)/$(ZIP_BASENAME)
PID_FILE     := $(SHARE_DIR)/zip-http.pid
PORT_FILE    := $(SHARE_DIR)/zip-http.port
LOG_FILE     := $(SHARE_DIR)/zip-http.log

# Porta / tempo
PORT_FIRST   ?= 8000
PORT_LAST    ?= 8020
PORT         ?= auto
DURATION     ?= 300
BIND_ADDR    ?= 127.0.0.1   # mude para 0.0.0.0 se quiser expor na rede

# Excludes
EXCLUDES_FILE := $(TMP_DIR)/$(PROJECT)-zip-excludes.txt
ZIP_FLAGS     := -rqX       # -X remove attrs extras → zip mais reproduzível
TOK_MAX_SIZE  ?= 1000000    # 1MB: limite p/ contar linhas/tokens com performance

# -------- Helpers --------
_write_excludes:
	@{ \
	  printf "%s\n" "*/node_modules/*" "node_modules/*"; \
	  printf "%s\n" "*/dist/*" "dist/*" "*/build/*" "build/*" "*/.next/*" ".next/*"; \
	  printf "%s\n" "*/.output/*" ".output/*" "*/.vercel/*" ".vercel/*" "*/.turbo/*" ".turbo/*"; \
	  printf "%s\n" "*/.cache/*" ".cache/*" "*/coverage/*" "coverage/*" "*/.pnpm-store/*" ".pnpm-store/*"; \
	  printf "%s\n" "*/.vscode/*" ".vscode/*" "*/.idea/*" ".idea/*" "*/tmp/*" "tmp/*"; \
	  printf "%s\n" "*/.yarn/*" ".yarn/*" "*/.npm/*" ".npm/*" "*/.parcel-cache/*" ".parcel-cache/*"; \
	  printf "%s\n" "*/.eslintcache/*" ".eslintcache/*" "*/.nyc_output/*" ".nyc_output/*" "*/.pytest_cache/*" ".pytest_cache/*"; \
	  printf "%s\n" "*/.DS_Store" ".DS_Store" "*.log" "yarn-error.log*" "npm-debug.log*"; \
	  printf "%s\n" "yarn.lock" "package-lock.json" "pnpm-lock.yaml" ".env*" "ecosystem.config.js" "*.tgz" "*.tar.gz" "*.zip"; \
	} > "$(EXCLUDES_FILE)"

_find_port:
	@find_port(){ \
	  for p in $$(awk -v a=$(PORT_FIRST) -v b=$(PORT_LAST) 'BEGIN{for(i=a;i<=b;i++)printf i" "}'); do \
	    if command -v ss >/dev/null 2>&1; then ss -ltn 2>/dev/null | awk '{print $$4}' | grep -q ":$$p$$" && busy=1 || busy=0; \
	    elif command -v netstat >/dev/null 2>&1; then netstat -an 2>/dev/null | grep -q "[\.\:]$$p[[:space:]]" && busy=1 || busy=0; \
	    elif command -v lsof >/dev/null 2>&1; then lsof -iTCP:$$p -sTCP:LISTEN >/dev/null 2>&1 && busy=1 || busy=0; \
	    else busy=0; fi; \
	    [ $$busy -eq 0 ] && { echo $$p; exit 0; }; \
	  done; exit 1; \
	}; find_port

# -------- Alvo principal --------
makezip: _write_excludes ## zipa com exclusões, sobe HTTP 5min, mostra Top10s e limpa tudo
	@set -eu; \
	# 0) Checagens mínimas
	for b in zip python3 find xargs sort head wc tr awk; do command -v $$b >/dev/null 2>&1 || { echo "falta: $$b"; exit 1; }; done; \
	# 1) Preparar share isolado
	rm -rf "$(SHARE_DIR)"; mkdir -p "$(SHARE_DIR)"; \
	# 2) Gerar ZIP com exclusões via arquivo (evita argv gigante)
	printf "gerando: %s\n" "$(ZIP_FILE)"; \
	zip $(ZIP_FLAGS) "$(ZIP_FILE)" . -x@"$(EXCLUDES_FILE)" || { echo "falha ao zipar"; exit 1; }; \
	sz=$$(ls -lh "$(ZIP_FILE)" | awk '{print $$5}'); \
	printf "ok: %s (%s)\n" "$(ZIP_FILE)" "$$sz"; \
	# 3) Análises Top10 (tamanho, linhas, tokens≈palavras)
	PRUNE_DIRS="./node_modules|./.git|./dist|./build|./.next|./.output|./.vercel|./.turbo|./.cache|./coverage|./.pnpm-store|./.vscode|./.idea|./tmp|./.yarn|./.npm|./.parcel-cache|./.eslintcache|./.nyc_output|./.pytest_cache"; \
	LIST=$$(mktemp); \
	find . -type d \( $$(printf "%s" "$$PRUNE_DIRS" | sed 's/|/ -o -path /g; s/^/ -path /') \) -prune -o -type f -print0 > "$$LIST"; \
	printf "\n== Top 10 por tamanho (KB) ==\n"; \
	xargs -0 du -ak < "$$LIST" 2>/dev/null | sort -nr | head -n 10 | awk '{printf "%8s KB  %s\n", $$1, $$2}'; \
	printf "\n== Top 10 por linhas (<= %d bytes) ==\n" $(TOK_MAX_SIZE); \
	xargs -0 -I{} sh -c 'f="$$1"; sz=$$(wc -c < "$$f" 2>/dev/null || echo 0); if [ "$$sz" -le $(TOK_MAX_SIZE) ]; then ln=$$(wc -l < "$$f" 2>/dev/null || echo 0); printf "%8s  %s\n" "$$ln" "$$f"; fi' _ {} < "$$LIST" | sort -nr | head -n 10; \
	printf "\n== Top 10 por tokens≈palavras (<= %d bytes) ==\n" $(TOK_MAX_SIZE); \
	xargs -0 -I{} sh -c 'f="$$1"; sz=$$(wc -c < "$$f" 2>/dev/null || echo 0); if [ "$$sz" -le $(TOK_MAX_SIZE) ]; then tk=$$(tr -cd "[:alnum:]_[:space:]" < "$$f" | wc -w | tr -d "[:space:]"); printf "%8s  %s\n" "$$tk" "$$f"; fi' _ {} < "$$LIST" | sort -nr | head -n 10; \
	rm -f "$$LIST"; \
	# 4) Subir HTTP server (apenas este diretório) e publicar link
	if [ "$(PORT)" = "auto" ]; then PORT_SEL=$$($(MAKE) -s _find_port) || { echo "sem porta livre $(PORT_FIRST)-$(PORT_LAST)"; exit 1; }; else PORT_SEL="$(PORT)"; fi; \
	echo $$PORT_SEL > "$(PORT_FILE)"; \
	( cd "$(SHARE_DIR)" && nohup python3 -m http.server $$PORT_SEL --bind "$(BIND_ADDR)" >> "$(LOG_FILE)" 2>&1 & echo $$! > "$(PID_FILE)" ); \
	if [ "$$(
	  uname -s 2>/dev/null
	)" = "Darwin" ]; then IP=$$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || printf "$(BIND_ADDR)"); \
	else IP=$$(hostname -I 2>/dev/null | awk '{print $$1}'); [ -n "$$IP" ] || IP="$(BIND_ADDR)"; fi; \
	base=$$(basename "$(ZIP_FILE)"); \
	printf "\nservindo %s por %ss — pid=%s porta=%s bind=%s\n" "$$base" "$(DURATION)" "$$(cat '$(PID_FILE)')" "$$PORT_SEL" "$(BIND_ADDR)"; \
	printf "link: http://%s:%s/%s\n\n" "$$IP" "$$PORT_SEL" "$$base"; \
	# 5) Auto-stop + limpeza total
	( sleep $(DURATION); kill $$(cat "$(PID_FILE)") 2>/dev/null || true; rm -rf "$(SHARE_DIR)" ) >/dev/null 2>&1 &

.PHONY: _write_excludes _find_port makezip
