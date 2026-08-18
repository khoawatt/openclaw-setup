# RESEARCH.md — Operating Rules: Research/Search Stack

_Applies to this agent (main session). Full spec: `docs/openclaw-research-search-stack.md` (repo); local copy installed to `research/openclaw-research-search-stack.md` by setup.sh (§15 persistence)._

## Stack layout

```
You (chat) 
  → intent: "search X" (lightweight) vs "research X" (deep, multi-source)
  → rc: deterministic zero-LLM helper (~/.openclaw/workspace/research/rc)
      ├── route  : keyword strategy classifier (quick|news|technical|recommendation)
      ├── search : provider chain + cache + dedupe
      ├── fetch  : curl text extraction fallback
      ├── cache  : ~/.openclaw/search-cache/ (entries=meta, results=JSON)
      └── status/provider/test : health & config
  → web_search / web_fetch : native OpenClaw tools (agent layer, model-driven)
  → browser automation     : LAST resort, needs working Chromium (currently BROKEN in WSL)
```

## Providers (primary/fallback)

- **Primary: Brave Search API** — `https://brave.com/search/api/` (free tier ~2000 queries/mo, `X-Subscription-Token`).
  - **✅ CONFIGURED 2026-08-18**: key stored in `~/.openclaw/openclaw.json` → `plugins.entries.brave.config.webSearch.apiKey` (file 0600). Official plugin `@openclaw/brave-plugin` installed (`openclaw plugins install @openclaw/brave-plugin`). Provider set to `brave`. Native `web_search` verified working via Brave with `freshness=day` timestamps.
  - `rc` reads key from env `$BRAVE_API_KEY` or the same config path; chain = `brave → ddg`.
- **Fallback (always active): DuckDuckGo** — key-free, unofficial HTML/lite endpoints (`html.duckduckgo.com`, fallback `lite.duckduckgo.com`), challenge-aware retry ×4, backoff 4s.
  - **Limitation:** subject to bot-challenge/rate-limit under burst testing; recovers after a few minutes. Native `web_search` (OpenClaw-side provider) is a separate path and keeps working.
- **Rule:** `query → brave (if key) → success? yes/continue : no → duckduckgo`. NEVER remove DDG. Fail of both → clear error, NO fabricated results.
- **Override:** `./rc set-provider brave|duckduckgo|auto`; `auto` unsets config (auto-detect).

## Query strategies (keyword routing, zero-LLM — `rc route`)

| Strategy | Keywords (case-insensitive, substring) | Cache TTL |
|---|---|---|
| `news` | today, latest, current, recent, this week, now, news, new release, breaking, announcement, right now | **900s (15m)** |
| `recommendation` | vs, best, recommend, worth, compare, reddit, opinion, experience, alternative, which, should i use | **3600s (1h)** |
| `technical` | doc, github, api, sdk, library, framework, config, install, version, compatib, how to, error, bug, plugin, openclaw, opencode, release | **43200s (12h)** |
| `quick` *(default)* | everything else | **86400s (24h)** |

TTLs per spec §10: news 5–15min, current 1h, technical 6–24h, evergreen (quick) 24h.

## Freshness policy (time-sensitive queries)

- If `route == news` (or query mentions today/latest/recent): **freshness beats ranking**.
- Prefer sources dated ≤ 7 days; no-date sources only as context, never as the headline answer.
- State the as-of date in answers; if nothing recent found → say so; never stretch old data to look fresh.

## Source quality tiers

- **A (official/primary):** docs.openclaw.ai, openclaw/openclaw GitHub, vendor docs, gov/edu, primary announcements.
- **B (strong secondary):** reputable tech press, vendor blogs, well-known references.
- **C (community):** Reddit, HN, forums — useful for sentiment; label as such.
- **D (weak/unknown):** SEO farms, anonymous — avoid or clearly caveat.
- TECHNICAL strategy must prefer A over C. RECOMMENDATION must separate facts (A/B) from sentiment (C).

## Deep research (`research <query>`) vs `search <query>`

| | `search` | `research` |
|---|---|---|
| Cost | lightweight (1 query, cache-first, zero-LLM infra) | deliberate, more tokens OK |
| Flow | route → provider chain → cache → results | decompose → multi-query (news+official+community angles) → fetch top sources → verify numbers/dates → cross-source synthesis → answer with sources + uncertainty |
| Output | raw ranked results | synthesized answer: key findings, facts vs sentiment, disagreements, caveats, sources |
| Cache hits | reuse if fresh | partial reuse OK but re-verify freshness for news |

## Cache

- Location: `~/.openclaw/search-cache/` (`entries/*.json` metadata, `results/*.json` payload).
- TTL per strategy (table above). Key = sha1(normalized query). Fresh hit → no provider call.
- `./rc cache list | clear | get <query> <strategy>`. Clear when testing or after provider config change.
- **Never cache failures.**

## Browser escalation (when & how)

- Normal research: `web_search` + `web_fetch` + `rc` — browser NOT required (spec §13).
- Browser used only when: JS-heavy page, login-walled content, anti-bot beyond DDG-level, or multi-step flow.
- **Current status: UNAVAILABLE** — Playwright Chromium missing WSL shared libs (`libnspr4`, `libnss3`, `libnsutil3`, `libsmime3`, `libasound2`); `sudo` unavailable. Fix options (user decision, needs approval):
  1. `sudo apt-get install -y libnspr4 libnss3 libasound2` (or `npx playwright install-deps chromium`)
  2. CDP connect to Windows Chrome (`/mnt/c/Program Files/Google/Chrome/Application/chrome.exe`) — no sudo.
- Browser must never be treated as required for research.

## Token/cost behavior

- **Zero-LLM (deterministic infra):** provider health checks, fallback logic, cache get/put/clear, HTTP status checks, dedupe, strategy routing, retry/backoff. These are shell/curl/python — never model calls.
- **Model OK:** intent parsing, query decomposition, evidence evaluation, cross-source synthesis, final answers, deep research. One model pass for search answers, more for research. No repeated model calls where shell can do it.

## Security boundaries

- Secrets (Brave key, Telegram credentials) live ONLY in env vars (`$BRAVE_API_KEY`) or `~/.openclaw/openclaw.json` (0600). Never in logs/docs/chat.
- `rc` never prints keys (status/providers show configured/not-configured only). Cache contains queries+results only.
- **Locked down (do NOT change without explicit user approval):** sudo/root changes, system package installs, network exposure, browser/CDP exposure, credential rotation, broad filesystem permission changes, **`~/.openclaw/watcher/` entirely** (see below).
- No logs of queries containing secrets; `rc.log` is plain run log.

## Existing OpenCode watcher — DO NOT TOUCH

- `~/.openclaw/watcher/` (ocw CLI, daemon, aliases, telegram.env) is a separate subsystem. This stack must never modify it: no edits, no remaps, no restarts from research code.
- Interaction boundary: `ocw status` may be READ by the agent when the user asks about feaon/qvak; nothing in the research stack calls or writes to it.

## Troubleshooting commands

```
./rc status                  # provider/fallback/health/cache summary
./rc provider                # configured provider + rule
./rc route "<query>"         # what strategy a query maps to
./rc search "<q>" [--live] [--strategy S] [--max N]   # cached search
./rc fetch "<url>"           # curl text extraction
./rc cache list|clear|get <q> <s>
./rc test [--live]           # diagnostics (bounded)
./rc set-provider brave|duckduckgo|auto
```

Agent-layer (model) commands for the user:
- `search <query>` — lightweight search via the stack (+ native web_search)
- `research <query>` — deep multi-source research + synthesis
- `search status` / `search provider` / `search test` — mapped to `rc status/provider/test`

## Known limitations (honest)

- Brave active: key configured + official plugin installed; native web_search uses it; `rc` uses it as primary with DDG fallback.
- DDG unofficial endpoints can challenge under burst load → retry or wait; native web_search unaffected (Brave path).
- Browser broken (missing libs) until user approves a fix path.
- Routing is keyword-heuristic; exotic phrasings may misclassify (user can force `--strategy`).
- Snippets only (no full-page fetch) for `rc search`; use `fetch`/`web_fetch` for depth.