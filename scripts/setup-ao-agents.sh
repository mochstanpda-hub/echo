#!/usr/bin/env bash
# Napojí Claude Code a Gemini CLI do Orchestrator.inc (agent-orchestrator, CLI `ao`).
#
# Použití:
#   ./scripts/setup-ao-agents.sh --path /abs/cesta/k/repu [--id muj-projekt] [--worker claude-code|gemini] [--yes]
#
# Co dělá:
#   1. Ověří, že je nainstalované `ao`, `node` a `npm`.
#   2. Doinstaluje chybějící `claude` (Claude Code) a `gemini` (Gemini CLI >= 0.60.0).
#   3. Ověří, že běží AO daemon (případně otevře app přes `ao start`), a zkontroluje připravenost agentů (`ao agent ls --refresh`).
#   4. Zaregistruje repo jako AO projekt (pokud ještě není) a nastaví:
#        orchestrator = claude-code
#        worker       = claude-code (nebo gemini přes --worker gemini)
#        reviewer     = claude-code
#      Gemini se pak používá pro konkrétní úkoly: `ao spawn --agent gemini ...`
set -euo pipefail

PROJECT_PATH=""
PROJECT_ID=""
WORKER_AGENT="claude-code"
ASSUME_YES=0
GEMINI_MIN="0.60.0"

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) PROJECT_PATH="$2"; shift 2 ;;
    --id) PROJECT_ID="$2"; shift 2 ;;
    --worker) WORKER_AGENT="$2"; shift 2 ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Neznámý argument: $1" >&2; usage 1 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Vrací 0, pokud verze $1 >= $2.
version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }

case "$WORKER_AGENT" in
  claude-code|gemini) ;;
  *) die "--worker musí být 'claude-code' nebo 'gemini'" ;;
esac

# --- 1. Předpoklady ----------------------------------------------------------
have ao  || die "Nenalezeno 'ao'. Nainstaluj Orchestrator.inc z https://orchestrator.inc (desktop app obsahuje CLI) a spusť ho aspoň jednou."
have npm || die "Nenalezeno 'npm'. Nainstaluj Node.js 20+ (https://nodejs.org)."

# --- 2. Claude Code ---------------------------------------------------------
if have claude; then
  info "Claude Code nalezen: $(claude --version 2>/dev/null | head -n1)"
else
  info "Instaluji Claude Code (@anthropic-ai/claude-code)…"
  npm install -g @anthropic-ai/claude-code
fi

# --- 3. Gemini CLI ----------------------------------------------------------
gemini_version() { gemini --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1; }
if have gemini && version_ge "$(gemini_version)" "$GEMINI_MIN"; then
  info "Gemini CLI nalezen: $(gemini_version)"
else
  have gemini && warn "Gemini CLI $(gemini_version) je starší než $GEMINI_MIN (minimum pro AO) – aktualizuji."
  info "Instaluji Gemini CLI (@google/gemini-cli)…"
  npm install -g @google/gemini-cli@latest
  version_ge "$(gemini_version)" "$GEMINI_MIN" || die "Gemini CLI je pořád starší než $GEMINI_MIN."
fi

# --- 4. AO daemon a připravenost agentů --------------------------------------
if ! ao status >/dev/null 2>&1; then
  info "Otevírám AO desktop app (vlastní daemon)…"
  ao start >/dev/null
  for _ in $(seq 1 30); do ao status >/dev/null 2>&1 && break; sleep 2; done
  ao status >/dev/null 2>&1 || die "AO daemon neběží. Otevři desktop app Orchestrator.inc a spusť skript znovu."
fi

info "Stav agentů (ao agent ls --refresh):"
AGENTS_OUT="$(ao agent ls --refresh 2>&1 || true)"
printf '%s\n' "$AGENTS_OUT" | grep -Ei 'agent|claude|gemini' || printf '%s\n' "$AGENTS_OUT"

# --- 5. Projekt -------------------------------------------------------------
if [[ -z "$PROJECT_PATH" ]]; then
  cat <<'EOF'

Agenti jsou nainstalovaní. Projekt nebyl zadán (--path), takže konfiguraci projektu přeskakuji.
Gemini/Claude můžeš použít rovnou:
  ao spawn --standalone --agent gemini --name test-gemini
  ao spawn --standalone --agent claude-code --name test-claude
EOF
  exit 0
fi

[[ "$PROJECT_PATH" = /* ]] || PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1 || die "$PROJECT_PATH není git repozitář."
[[ -n "$PROJECT_ID" ]] || PROJECT_ID="$(basename "$PROJECT_PATH" | tr '[:upper:] ' '[:lower:]-')"

if ao project get "$PROJECT_ID" >/dev/null 2>&1; then
  info "Projekt '$PROJECT_ID' už je zaregistrovaný."
  warn "'ao project set-config' NAHRADÍ celou dosavadní konfiguraci projektu (env, post-create, rules, effort…)."
  if [[ $ASSUME_YES -ne 1 ]]; then
    read -r -p "Pokračovat a přepsat konfiguraci projektu '$PROJECT_ID'? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Přeskočeno. Agenty nastav ručně v desktop app: Project Settings."; exit 0; }
  fi
else
  info "Registruji projekt '$PROJECT_ID' ($PROJECT_PATH)…"
  ao project add --path "$PROJECT_PATH" --id "$PROJECT_ID" \
    --orchestrator-agent claude-code --worker-agent "$WORKER_AGENT"
fi

info "Nastavuji agenty: orchestrator=claude-code, worker=$WORKER_AGENT, reviewer=claude-code"
ao project set-config "$PROJECT_ID" \
  --orchestrator-agent claude-code \
  --worker-agent "$WORKER_AGENT" \
  --reviewer claude-code \
  --permission accept-edits

cat <<EOF

Hotovo. Další kroky:
  1. Přihlášení Claude Code (jednorázově):   claude      → v něm /login
  2. Přihlášení Gemini (jednorázově):        AO app → Settings → Agents → "Set up Gemini CLI"
                                             (nebo: gemini → /auth, případně export GEMINI_API_KEY=...)
  3. Ověření:                                ao agent ls --refresh
  4. Worker s Gemini:                        cd "$PROJECT_PATH" && ao spawn --agent gemini
     Worker s Claude Code:                   cd "$PROJECT_PATH" && ao spawn --agent claude-code
EOF
