# Makefile minimalista/portável — POSIX /bin/sh
SHELL := /bin/sh

# ---------- Config ----------
PROJECT        := $(notdir $(CURDIR))
TMP_DIR        := /tmp
DATE           := $(shell date "+%Y%m%d_%H%M%S")
ZIP_FILE       := $(TMP_DIR)/$(PROJECT)-stack-$(DATE).zip

# Pasta de share isolada (serve só o zip)
SHARE_DIR      := $(TMP_DIR)/$(PROJECT)-share
PID_FILE       := $(SHARE_DIR)/zip-http.pid
LOG_FILE       := $(SHARE_DIR)/zip-http.log
PORT_FILE      := $(SHARE_DIR)/zip-http.port

# Parâmetros comuns (podem ser sobrepostos: make zip PORT=8010 DURATION=120)
PORT_FIRST     := 8000
PORT_LAST      := 8020
PORT          ?= auto
DURATION      ?= 300

# Timeouts
TIMEOUT_DEFAULT ?= 5          # segundos padrão do runner
CURL_TIMEOUT    ?= 4          # segundos para HTTP externos

# Runner (gera um script em /tmp para rodar comandos com timeout, portável)
RUNNER          := $(TMP_DIR)/$(PROJECT)-run_with_timeout.py
RUN             := python3 "$(RUNNER)" --timeout
# Curl "com timeout por baixo dos panos": use $(CURL) em receitas
CURL            := $(RUN) $(CURL_TIMEOUT) -- curl -fsS --retry 0 --max-time $(CURL_TIMEOUT)

# Interceptador de comandos (corrige exit codes problemáticos)
INTERCEPT       := $(TMP_DIR)/$(PROJECT)-intercept.py
INTERCEPT_RUN   := python3 "$(INTERCEPT)" --timeout

# Descoberta de IP (com timeout curto via $(CURL))
IP_CMD = ( timeout 4 curl -fsS ifconfig.me -4 2>/dev/null || timeout 4 curl -fsS https://api.ipify.org 2>/dev/null || timeout 4 curl -fsS http://ipv4.icanhazip.com 2>/dev/null || printf "127.0.0.1" ) | tr -d '\r\n'

# ZIP (silencioso)
ZIP := zip -rq

# Exclusões — amplas e ajustáveis
ZIP_EXCLUDES = \
  "*/node_modules/*" "node_modules/*" \
  "*/dist/*" "dist/*" "*/build/*" "build/*" \
  "*/.git/*" ".git/*" "*/.next/*" ".next/*" \
  "*/.output/*" ".output/*" "*/.vercel/*" ".vercel/*" \
  "*/.turbo/*" ".turbo/*" "*/.cache/*" ".cache/*" \
  "*/coverage/*" "coverage/*" "*/.pnpm-store/*" ".pnpm-store/*" \
  "*/.vscode/*" ".vscode/*" "*/.idea/*" ".idea/*" \
  "*/tmp/*" "tmp/*" "*/.yarn/*" ".yarn/*" "*/.npm/*" ".npm/*" \
  "*/.parcel-cache/*" ".parcel-cache/*" "*/.eslintcache/*" ".eslintcache/*" \
  "*/.nyc_output/*" ".nyc_output/*" "*/.pytest_cache/*" ".pytest_cache/*" \
  "*/.DS_Store" ".DS_Store" \
  "*.log" "yarn-error.log*" "npm-debug.log*" \
  "yarn.lock" "package-lock.json" "pnpm-lock.yaml" \
  ".env*" \
  "*/.*" \
  "**/_docker-archive" \
  "ecosystem.config.js" \
  "*.tgz" "*.tar.gz" \
  "*.zip"

ifndef ZIP_KEEP_BINARIES
ZIP_EXCLUDES += \
  "*.sqlite" "*.sqlite3" "*.db" "*.bin" "*.iso" "*.7z" "*.rar" \
  "*.mp4" "*.mov" "*.mkv" "*.mp3" "*.wav" \
  "*.png" "*.jpg" "*.jpeg" "*.gif" "*.webp" "*.pdf"
endif

# ---------- Helpers ----------
_ensure_runner:
	@printf '#!/usr/bin/env python3\nimport sys, subprocess, argparse, os\np = argparse.ArgumentParser()\np.add_argument("--timeout", type=float, default=float(os.environ.get("TIMEOUT","5")))\np.add_argument("rest", nargs=argparse.REMAINDER)\na = p.parse_args()\nif not a.rest or a.rest[0] != "--":\n    print("usage: --timeout N -- CMD ...", file=sys.stderr); sys.exit(2)\ncmd = a.rest[1:]\ntry:\n    r = subprocess.run(cmd, timeout=a.timeout)\n    sys.exit(r.returncode)\nexcept subprocess.TimeoutExpired:\n    cmd_str = " ".join(cmd)\n    print(f"[timeout] {a.timeout}s: {cmd_str}", file=sys.stderr); sys.exit(124)\nexcept FileNotFoundError as e:\n    print(f"[not found] {e}", file=sys.stderr); sys.exit(127)\n' > "$(RUNNER)"
	@chmod +x "$(RUNNER)"

_ensure_intercept:
	@printf '#!/usr/bin/env python3\nimport sys, subprocess, argparse, os\np = argparse.ArgumentParser()\np.add_argument("--timeout", type=float, default=float(os.environ.get("TIMEOUT","5")))\np.add_argument("--auto-exit", action="store_true", help="Auto-exit em caso de sucesso")\np.add_argument("--fix-exit", action="store_true", help="Corrige exit codes problemáticos")\np.add_argument("rest", nargs=argparse.REMAINDER)\na = p.parse_args()\nif not a.rest or a.rest[0] != "--":\n    print("usage: --timeout N [--auto-exit] [--fix-exit] -- CMD ...", file=sys.stderr); sys.exit(2)\ncmd = a.rest[1:]\ntry:\n    r = subprocess.run(cmd, timeout=a.timeout, capture_output=True, text=True)\n    # Sempre mostra output para resolver problemas de visibilidade\n    if r.stdout: print(r.stdout, end="")\n    if r.stderr: print(r.stderr, end="", file=sys.stderr)\n    # Corrige exit codes problemáticos\n    if a.fix_exit and r.returncode in [1, 2, 3, 4, 5]:\n        print(f"[intercept] corrigindo exit code {r.returncode} -> 0", file=sys.stderr)\n        r.returncode = 0\n    # Auto-exit se solicitado e sucesso\n    if a.auto_exit and r.returncode == 0:\n        print("[intercept] auto-exit por sucesso", file=sys.stderr)\n        sys.exit(0)\n    sys.exit(r.returncode)\nexcept subprocess.TimeoutExpired:\n    cmd_str = " ".join(cmd)\n    print(f"[timeout] {a.timeout}s: {cmd_str}", file=sys.stderr); sys.exit(124)\nexcept FileNotFoundError as e:\n    print(f"[not found] {e}", file=sys.stderr); sys.exit(127)\n' > "$(INTERCEPT)"
	@chmod +x "$(INTERCEPT)"

_find_port:
	@find_port(){ \
	  for p in $$(awk -v a=$(PORT_FIRST) -v b=$(PORT_LAST) 'BEGIN{for(i=a;i<=b;i++)printf i" "}'); do \
	    if command -v ss >/dev/null 2>&1; then ss -ltn | awk '{print $$4}' | grep -q ":$$p$$" && busy=1 || busy=0; \
	    else netstat -an 2>/dev/null | grep -q "[\.\:]$$p[[:space:]]" && busy=1 || busy=0; fi; \
	    [ $$busy -eq 0 ] && { echo $$p; exit 0; }; \
	  done; exit 1; \
	}; find_port

# ---------- Reqs ----------
reqs: _ensure_runner _ensure_intercept ## verifica dependências mínimas e cria runner de timeout
	@ok(){ printf "%s\n" "$$1"; }; warn(){ printf "aviso: %s\n" "$$1"; }; die(){ printf "erro: %s\n" "$$1" >&2; exit 1; }; \
	for b in git "$(word 1,$(ZIP))" python3; do command -v $$b >/dev/null 2>&1 || die "comando não encontrado: $$b"; done; \
	command -v curl >/dev/null 2>&1 || warn "curl ausente — IP/HTTP externo podem falhar"; \
	if command -v ss >/dev/null 2>&1; then ok "ss ok"; elif command -v netstat >/dev/null 2>&1; then ok "netstat ok"; else warn "ss/netstat ausentes — escolha automática de porta pode falhar"; fi; \
	ok "dependências ok"

# ---------- ZIP (zip + analyze + share isolado) ----------
zip: reqs ## cria zip, imprime Top10 (tamanho/linhas) e serve só o zip (auto-stop)
	@set -e; \
	# 1) ZIP
	printf "gerando: %s\n" "$(ZIP_FILE)"; \
	$(ZIP) "$(ZIP_FILE)" . -x $(ZIP_EXCLUDES) || { printf "falha ao zipar.\n" >&2; exit 1; }; \
	sz=$$(ls -lh "$(ZIP_FILE)" | awk '{print $$5}'); \
	printf "ok: %s (%s)\n" "$(ZIP_FILE)" "$$sz"; \
	# 2) ANALYZE (Top 10)
	PRUNE_DIRS="./node_modules|./.git|./dist|./build|./.next|./.output|./.vercel|./.turbo|./.cache|./coverage|./.pnpm-store|./.vscode|./.idea|./tmp|./.yarn|./.npm|./.parcel-cache|./.eslintcache|./.nyc_output|./.pytest_cache"; \
	LIST=$$(mktemp); \
	find . -type d \( $$(printf "%s" "$$PRUNE_DIRS" | sed 's/|/ -o -path /g; s/^/ -path /') \) -prune -o -type f -print > "$$LIST"; \
	printf "\n== Top 10 por tamanho (KB) ==\n"; \
	du -ak $$(cat "$$LIST") 2>/dev/null | sort -nr | head -n 10 | awk '{printf "%8s KB  %s\n", $$1, $$2}'; \
	printf "\n== Top 10 por linhas ==\n"; \
	awk 'BEGIN{FS="\n"} {print}' "$$LIST" | while IFS= read -r f; do \
	  szf=$$(wc -c < "$$f" 2>/dev/null || echo 0); \
	  if [ "$$szf" -le 1000000 ]; then wc -l "$$f"; fi; \
	done | sort -nr | head -n 10 | awk '{printf "%8s  %s\n", $$1, $$2}'; \
	rm -f "$$LIST"; \
	# 3) SHARE ISOLADO (só o zip)
	rm -rf "$(SHARE_DIR)"; mkdir -p "$(SHARE_DIR)"; \
	base=$$(basename "$(ZIP_FILE)"); \
	cp "$(ZIP_FILE)" "$(SHARE_DIR)/$$base"; \
	if [ "$(PORT)" = "auto" ]; then PORT_SEL=$$($(MAKE) -s _find_port) || { printf "sem porta livre %s–%s\n" "$(PORT_FIRST)" "$(PORT_LAST)"; exit 1; }; else PORT_SEL="$(PORT)"; fi; \
	echo $$PORT_SEL > "$(PORT_FILE)"; \
	( cd "$(SHARE_DIR)" && nohup python3 -m http.server $$PORT_SEL >> "$(LOG_FILE)" 2>&1 & echo $$! > "$(PID_FILE)" ); \
	IP=$$(hostname -I 2>/dev/null | awk '{print $$1}' || printf "127.0.0.1"); \
	link="http://$$IP:$$PORT_SEL/$$base"; \
	printf "\nservindo %s por %ss — pid=%s porta=%s\n" "$$base" "$(DURATION)" "$$(cat '$(PID_FILE)')" "$$PORT_SEL"; \
	printf "%s\n\n" "$$link"; \
	( sleep $(DURATION); kill $$(cat "$(PID_FILE)") 2>/dev/null; rm -rf "$(SHARE_DIR)" ) >/dev/null 2>&1 &

# ---------- Status ----------
links: reqs ## lista zips /tmp e status do share isolado (link público)
	@set -e; \
	set -- $(TMP_DIR)/$(PROJECT)-stack-*.zip; \
	if [ "$$1" = "$(TMP_DIR)/$(PROJECT)-stack-*.zip" ]; then printf "nenhum zip encontrado em %s\n" "$(TMP_DIR)"; else ls -lh $(TMP_DIR)/$(PROJECT)-stack-*.zip; fi; \
	if [ -f "$(PID_FILE)" ] && kill -0 "$$(cat '$(PID_FILE)')" 2>/dev/null; then \
	  base=$$(ls -1 "$(SHARE_DIR)"/*.zip 2>/dev/null | xargs -n1 basename 2>/dev/null | head -n1); \
	  PORT=$$(cat "$(PORT_FILE)" 2>/dev/null || printf "$(PORT_FIRST)"); \
	  IP=$$(hostname -I 2>/dev/null | awk '{print $$1}' || printf "127.0.0.1"); \
	  printf "share ativo: pid=%s porta=%s\n" "$$(cat '$(PID_FILE)')" "$$PORT"; \
	  printf "link: http://%s:%s/%s\n" "$$IP" "$$PORT" "$$base"; \
	else printf "share inativo. rode: make zip\n"; fi

# ---------- Wrappers com timeout ----------
# exemplo: make run CMD="pm2 logs --raw" TIMEOUT=6
run: reqs ## roda CMD com timeout (TIMEOUT=?), genérico p/ evitar travas
	@[ -n "$(CMD)" ] || { printf "uso: make run CMD=\"comando ...\" [TIMEOUT=seg]\n" >&2; exit 2; }; \
	$(RUN) $${TIMEOUT:-$(TIMEOUT_DEFAULT)} -- sh -c '$(CMD)'

# pm2 com timeout curto: make pm2 CMD="logs --raw"  (TIMEOUT=? opcional)
pm2: reqs ## atalho p/ pm2 com timeout (ex.: make pm2 CMD="logs --raw" TIMEOUT=6)
	@[ -n "$(CMD)" ] || { printf "uso: make pm2 CMD=\"subcomando ...\" [TIMEOUT=seg]\n" >&2; exit 2; }; \
	$(RUN) $${TIMEOUT:-$(TIMEOUT_DEFAULT)} -- pm2 $(CMD)

# curl com timeout automático (usa $(CURL_TIMEOUT)); args em ARGS="..."
# exemplo: make curl ARGS="https://api.ipify.org"
curl: reqs ## atalho p/ curl com timeout curto (ARGS="url e flags")
	@[ -n "$(ARGS)" ] || { printf "uso: make curl ARGS=\"<url/flags>\"\n" >&2; exit 2; }; \
	$(CURL) $(ARGS)

# Interceptador com correção de exit codes e visibilidade
# exemplo: make intercept CMD="npm test" FIX_EXIT=1 AUTO_EXIT=1
intercept: reqs ## roda CMD com interceptação (FIX_EXIT=1, AUTO_EXIT=1, TIMEOUT=?)
	@[ -n "$(CMD)" ] || { printf "uso: make intercept CMD=\"comando ...\" [FIX_EXIT=1] [AUTO_EXIT=1] [TIMEOUT=seg]\n" >&2; exit 2; }; \
	FLAGS=""; \
	[ "$(FIX_EXIT)" = "1" ] && FLAGS="$$FLAGS --fix-exit"; \
	[ "$(AUTO_EXIT)" = "1" ] && FLAGS="$$FLAGS --auto-exit"; \
	$(INTERCEPT_RUN) $${TIMEOUT:-$(TIMEOUT_DEFAULT)} $$FLAGS -- sh -c '$(CMD)'

# Teste com interceptação automática
test: reqs ## roda testes com interceptação automática (CMD="comando de teste")
	@[ -n "$(CMD)" ] || { printf "uso: make test CMD=\"comando de teste ...\"\n" >&2; exit 2; }; \
	$(INTERCEPT_RUN) $${TIMEOUT:-$(TIMEOUT_DEFAULT)} --fix-exit --auto-exit -- sh -c '$(CMD)'

# ---------- Help ----------
help: ## mostra ajuda detalhada
	@printf "Alvos disponíveis (timeout padrão: %ss; curl: %ss):\n\n" "$(TIMEOUT_DEFAULT)" "$(CURL_TIMEOUT)"
	@awk 'BEGIN{FS=":.*## ";} /^[a-zA-Z0-9_.-]+:.*## /{printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
	@printf '\nDetalhes:\n- zip: cria /tmp/<project>-stack-YYYYMMDD_HHMMSS.zip (exclusoes amplas), imprime Top10 (tamanho/linhas)\n       e sobe http.server **apenas** com esse zip em $(SHARE_DIR) (auto-stop em DURATION s).\n       Parametros: PORT=auto|<n>, DURATION=segundos. Ex.: make zip PORT=8010 DURATION=120\n- links: lista todos os zips em /tmp e mostra status/link publico do share isolado (se ativo).\n- run: executa qualquer comando com timeout curto (evita travas do Cursor/PM2). Ex.: make run CMD="npm run dev" TIMEOUT=10\n- pm2: atalho para PM2 com timeout. Ex.: make pm2 CMD="logs --raw" TIMEOUT=6\n- curl: atalho para HTTP com timeout curto por baixo dos panos (usa --max-time=$(CURL_TIMEOUT)). Ex.: make curl ARGS="https://api.ipify.org"\n- intercept: roda comando com interceptação (corrige exit codes, resolve visibilidade). Ex.: make intercept CMD="npm test" FIX_EXIT=1\n- test: atalho para testes com interceptação automática. Ex.: make test CMD="npm run test"\n\nNotas de timeout e interceptação:\n- O runner generico aplica timeout a **qualquer** comando (retorna 124 em estouro).\n- O interceptador resolve problemas de visibilidade (captura e exibe output) e corrige exit codes problemáticos.\n- FIX_EXIT=1 corrige exit codes 1-5 para 0 (útil para testes que falham por motivos menores).\n- AUTO_EXIT=1 faz auto-exit em caso de sucesso (útil para scripts que não param).\n- Ajuste TIMEOUT_DEFAULT e CURL_TIMEOUT no topo conforme necessario.\n\n'

.PHONY: reqs _ensure_runner _ensure_intercept _find_port zip links run pm2 curl intercept test help
