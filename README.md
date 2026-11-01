# echo – Claude Code + Gemini v Orchestrator.inc

Návod a skript, jak do [Orchestrator.inc (agent-orchestrator)](https://github.com/OrchestratorInc/agent-orchestrator)
napojit **Claude Code** a **Gemini CLI**. AO oba agenty podporuje nativně jako harnessy
`claude-code` a `gemini` – nic se nemusí programovat, stačí nainstalovat CLI, přihlásit se
a nastavit projekt.

## Rozdělení rolí

| Role v AO     | Agent         | Proč |
|---------------|---------------|------|
| Orchestrator  | `claude-code` | plánuje práci a rozděluje ji workerům |
| Worker        | `claude-code` (výchozí) nebo `gemini` | Gemini lze zvolit per úkol |
| Reviewer      | `claude-code` | Gemini v AO zatím reviewer ani Chat režim nepodporuje |

Gemini v AO běží jen v režimu **Terminal UI** a vyžaduje **Gemini CLI ≥ 0.60.0**.

## Rychlé nastavení

Předpoklady: nainstalovaná desktop app Orchestrator.inc (obsahuje CLI `ao`), Node.js 20+ s `npm`.

```bash
./scripts/setup-ao-agents.sh --path /absolutni/cesta/k/tvemu/repu
```

Volby:

- `--id <id>` – ID projektu v AO (výchozí: název složky)
- `--worker gemini` – výchozím workerem bude Gemini místo Claude Code
- `--yes` – bez dotazu přepsat konfiguraci už existujícího projektu

> ⚠️ `ao project set-config` **nahrazuje celou** konfiguraci projektu (env, post-create, rules, effort…).
> Pokud už máš projekt nastavený, raději změň agenty v app: **Project Settings**.

## Přihlášení (jednorázově)

**Claude Code**

```bash
claude
```

V Claude Code pak zadej `/login` (předplatné Claude nebo `ANTHROPIC_API_KEY`).

**Gemini CLI** – v AO app: **Settings → Agents → Set up Gemini CLI** (otevře nativní `/auth`).
Alternativně spusť `gemini` a v něm `/auth`, nebo nastav API klíč:

```bash
export GEMINI_API_KEY=tvuj-klic
```

Ověření, že AO oba agenty vidí jako připravené:

```bash
ao agent ls --refresh
```

## Použití

```bash
ao spawn --agent gemini
```

```bash
ao spawn --agent claude-code
```

Model se předává nativním ID, např. Gemini `--model gemini-2.5-pro`. Oprávnění AO se u Gemini mapují:
`accept-edits`/`auto` → `auto_edit`, `bypass-permissions` → `yolo`.

## Ruční nastavení bez skriptu

```bash
npm install -g @anthropic-ai/claude-code @google/gemini-cli@latest
```

```bash
ao project add --path /absolutni/cesta/k/repu --id muj-projekt --orchestrator-agent claude-code --worker-agent claude-code
```

```bash
ao project set-config muj-projekt --orchestrator-agent claude-code --worker-agent claude-code --reviewer claude-code --permission accept-edits
```
