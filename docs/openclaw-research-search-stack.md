# OpenClaw Research/Search Stack --- Implementation Specification

## 1. Goal

Implement a robust research/search subsystem for Crestodian/OpenClaw
that can be used primarily from Telegram.

The system should support:

-   fast everyday web search
-   current/news queries with freshness awareness
-   technical research with primary-source preference
-   recommendation/community research
-   explicit deep-research mode
-   automatic provider fallback
-   efficient fetching and deduplication
-   optional browser escalation only when normal search/fetch is
    insufficient
-   sensible caching and cost/token controls

This subsystem must remain independent from the existing OpenCode
watcher.

## 2. Critical Boundary: Do Not Modify the OpenCode Watcher

The existing OpenCode monitoring system is working and has passed its
safety audit.

Do NOT modify, refactor, replace, or integrate into:

-   `~/.openclaw/watcher/`
-   watcher daemon behavior
-   watcher cron jobs
-   tmux aliases
-   `ocw send`
-   OpenCode ↔ ChatGPT Web review integration
-   watcher Telegram notifications
-   watcher safety boundaries

The desired architecture is:

``` text
Crestodian
├── OpenCode Watcher          # existing, leave untouched
│   ├── feaon
│   └── qvak
│
└── Research/Search Stack     # implement this task
    ├── primary search
    ├── fallback search
    ├── web fetch
    ├── query routing
    ├── source ranking
    ├── deep research
    ├── cache
    └── browser fallback
```

If implementing this task would require changing the watcher, stop and
ask first.

------------------------------------------------------------------------

## 3. Search Provider Architecture

### Current state

DuckDuckGo search is already configured and working as a key-free
provider.

Preserve it.

### Target state

Use:

``` text
Primary:   Brave Search
Fallback:  DuckDuckGo
```

Desired behavior:

``` text
query
  ↓
Brave Search
  ↓
success? ── yes → continue
  │
  no
  ↓
DuckDuckGo
```

Fallback should happen automatically for recoverable conditions such as:

-   provider unavailable
-   transient request failure
-   rate limit
-   invalid/empty result set when fallback is appropriate

Do not remove DuckDuckGo.

### Brave credentials

If a Brave API key is not configured:

1.  Do not invent one.
2.  Do not expose credentials in logs or documentation.
3.  Tell me exactly where to obtain/configure the key.
4.  Ask me only when the credential is actually required.

Until Brave is available, DuckDuckGo should remain usable.

------------------------------------------------------------------------

## 4. Query Router

Implement or document deterministic routing rules so search strategy
depends on query intent.

The model may determine query intent when I explicitly ask Crestodian a
research/search question, but provider health checks, cache operations,
and background mechanics must not require LLM inference.

At minimum recognize these strategies:

### QUICK

For simple lookups such as:

-   current version
-   official URL
-   basic fact
-   package/project information

Strategy:

``` text
search
→ inspect ~3–5 useful results
→ prefer authoritative source
→ fetch only if necessary
→ answer
```

### NEWS / CURRENT

Trigger for concepts such as:

-   today
-   latest
-   current
-   recently
-   this week
-   news
-   new release
-   current status

Strategy:

``` text
fresh search
→ prioritize recent publication/update dates
→ prefer primary/reputable reporting
→ fetch multiple relevant sources
→ verify event dates
→ cross-check important claims
→ answer with source links/citations
```

Do not treat search-result snippets alone as sufficient evidence for
important current claims.

### TECHNICAL

For:

-   libraries
-   frameworks
-   APIs
-   GitHub projects
-   OpenClaw/OpenCode
-   configuration
-   software behavior
-   release compatibility

Priority order:

1.  official documentation
2.  official repository/source
3.  official changelog/releases
4.  maintainer material
5.  GitHub issues/discussions
6.  reputable technical sources
7.  community sources

Prefer current official documentation over SEO tutorials.

### RECOMMENDATION / COMMUNITY

For questions such as:

-   A vs B
-   what are people using
-   real-world experience
-   developer preference
-   ecosystem sentiment

Combine:

-   official facts
-   GitHub/project activity where relevant
-   reputable independent analysis
-   community discussions such as Reddit when useful

Clearly distinguish:

``` text
Verified facts
vs.
Community sentiment / anecdotal experience
```

Do not present community opinion as established fact.

------------------------------------------------------------------------

## 5. Source Quality Policy

Use a source hierarchy.

### Tier A --- Primary

-   official documentation
-   official project/company website
-   official GitHub repository
-   official releases/changelog
-   original research/publication

### Tier B --- Strong secondary

-   maintainer posts
-   reputable news organizations
-   reputable technical publications
-   well-supported GitHub issues/discussions

### Tier C --- Community

-   Reddit
-   Stack Overflow
-   forums
-   independent technical blogs
-   community discussions

### Tier D --- Weak

-   SEO content farms
-   scraped aggregators
-   low-quality AI-generated pages
-   unattributed reposts

Rules:

-   Important factual claims should prefer Tier A/B support.
-   Tier C is valuable for experience/sentiment.
-   Tier D should not be the sole basis for an important claim when
    stronger sources are available.
-   Do not rank a result as trustworthy merely because the search engine
    ranked it highly.

------------------------------------------------------------------------

## 6. Freshness Policy

Current AI/software information becomes stale quickly.

For time-sensitive queries:

``` text
freshness > generic ranking
```

Check:

-   publication date
-   update date
-   release date
-   whether an older page has been superseded
-   current official docs/model catalogs when applicable

For queries containing concepts like `latest`, `today`, `current`, or
`recent`, explicitly verify that the evidence is recent enough for the
question.

Do not silently answer a 2026-current question from stale 2024/2025
material when newer authoritative information exists.

------------------------------------------------------------------------

## 7. Fetch Strategy

Search identifies candidates; fetch is used to inspect evidence.

Preferred flow:

``` text
search
  ↓
rank candidates
  ↓
deduplicate
  ↓
fetch only useful sources
  ↓
extract relevant sections
  ↓
synthesize
```

Avoid fetching every search result.

For normal questions, fetch only enough sources to answer confidently.

When fetching fails:

1.  try another strong source if available
2.  use configured fetch fallback if appropriate
3.  escalate to browser only if rendered/interactive access is actually
    needed

------------------------------------------------------------------------

## 8. Deep Research Mode

Provide an explicit user-facing concept:

``` text
research <query>
```

This should be materially deeper than normal `search`.

Suggested workflow:

``` text
research query
      ↓
identify subquestions
      ↓
run multiple targeted searches
      ↓
collect candidate sources
      ↓
rank by authority + freshness + relevance
      ↓
deduplicate
      ↓
fetch strongest evidence
      ↓
cross-check claims
      ↓
identify disagreement/uncertainty
      ↓
synthesize report
```

Deep research may use more model tokens because it is explicitly
requested.

Do not run deep research automatically for every simple search.

### Deep research output

Prefer:

-   concise executive answer
-   important findings
-   evidence/source links
-   disagreements or uncertainty
-   practical conclusion/recommendation

Do not inflate the answer merely to appear comprehensive.

------------------------------------------------------------------------

## 9. Telegram/User Interface

Support the concepts:

``` text
search <query>
research <query>

search status
search provider
search test
```

Natural-language requests should also work where OpenClaw already
handles them.

Examples:

``` text
search OpenClaw latest release
search latest OpenAI news
research OpenClaw vs Hermes for a coding-agent workflow
```

I should not need to manually choose Brave/DDG for ordinary queries.

### `search status`

Report:

-   primary provider
-   fallback provider
-   provider availability
-   fetch availability
-   browser availability
-   cache status

Do not expose API keys.

### `search provider`

Report active provider configuration and fallback behavior.

### `search test`

Perform a small safe test that validates:

-   primary provider if configured
-   fallback provider
-   fetch

Do not consume excessive queries merely for diagnostics.

------------------------------------------------------------------------

## 10. Cache

Implement a small research/search cache only if it can be done simply
and transparently.

Suggested location:

``` text
~/.openclaw/search-cache/
```

Do not place secrets in the cache.

Cache should include enough metadata to know:

-   normalized query
-   strategy
-   timestamp
-   provider
-   source URLs/results as appropriate

Suggested TTL concepts:

``` text
breaking/current news:   ~5–15 minutes
current information:     ~1 hour
technical documentation: ~6–24 hours
evergreen information:   longer when appropriate
```

These are guidelines, not absolute rules.

A query explicitly asking for `latest`, `right now`, or equivalent may
require bypassing stale cache.

Provide a simple way to inspect/clear cache if implemented.

Do not build a complex database for this unless clearly justified.

------------------------------------------------------------------------

## 11. Browser Escalation

Browser automation is NOT the primary search mechanism.

Use this escalation path:

``` text
search
  ↓
fetch
  ↓
content unavailable because rendering/interaction is required?
  ↓ yes
browser
```

Browser is appropriate for:

-   JS-rendered content
-   interactive pages
-   pagination requiring interaction
-   authenticated content where explicitly authorized
-   pages normal fetch cannot meaningfully extract

Do not launch Chromium for ordinary searchable/fetchable pages.

### Current browser limitation

Browser automation currently has missing WSL system dependencies.

Do NOT:

-   run sudo automatically
-   install system packages without approval
-   expose a Windows Chrome CDP endpoint without approval
-   change browser security boundaries without approval

Research/search implementation should work without browser automation.

Browser can be enabled later.

------------------------------------------------------------------------

## 12. Cost and Token Controls

Search mechanics should be efficient.

### Zero/low-model operations

Do not invoke an LLM merely for:

-   provider health checking
-   cache lookup
-   cache expiry
-   provider fallback mechanics
-   HTTP status checks
-   deduplication that can be deterministic

### Model usage is appropriate for

-   understanding a natural-language research request
-   query decomposition
-   evaluating nuanced evidence
-   cross-source synthesis
-   producing the final answer
-   explicit deep research

Normal search should remain lightweight.

Deep research may intentionally use more tokens.

Do not call the model repeatedly when deterministic code can perform the
same infrastructure operation.

------------------------------------------------------------------------

## 13. Failure Behavior

Search must degrade gracefully.

Examples:

### Brave unavailable

``` text
Brave fails
→ automatically try DuckDuckGo
→ continue if fallback succeeds
```

### Fetch unavailable for one source

``` text
fetch fails
→ try another strong source
→ browser only if necessary and available
```

### All search providers fail

Report the failure clearly.

Do not fabricate results.

### Browser unavailable

Continue using search/fetch where possible.

Do not treat browser availability as required for normal research.

------------------------------------------------------------------------

## 14. Security

Do not expose or log:

-   Brave API key
-   Telegram credentials
-   other provider secrets

Store secrets with appropriately restrictive permissions.

Before making any:

-   sudo/root change
-   system-wide package installation
-   network exposure change
-   browser/CDP exposure
-   credential rotation
-   broad filesystem permission change

stop and ask me first.

Ordinary workspace-local/config-local implementation may proceed without
asking when safe.

------------------------------------------------------------------------

## 15. Persistence and Documentation

Persist the research/search operating rules in an appropriate OpenClaw
workspace document.

Document:

-   primary/fallback providers
-   query strategies
-   source hierarchy
-   freshness rules
-   deep research behavior
-   cache behavior
-   browser escalation
-   security boundaries
-   token/cost behavior
-   troubleshooting commands

Keep credentials out of documentation.

Do not overwrite unrelated existing instructions.

------------------------------------------------------------------------

## 16. Validation

Before declaring implementation complete, validate:

1.  DuckDuckGo still works.
2.  Brave works if credentials are available.
3.  Brave failure correctly falls back to DuckDuckGo.
4.  QUICK query strategy works.
5.  NEWS/CURRENT strategy prefers fresh evidence.
6.  TECHNICAL strategy prefers official sources.
7.  RECOMMENDATION strategy can distinguish facts from community
    sentiment.
8.  Fetch works.
9.  Duplicate sources are avoided.
10. `research <query>` performs deeper multi-source work.
11. `search status` works.
12. `search provider` works.
13. `search test` works.
14. Cache behavior works if implemented.
15. Browser is not unnecessarily invoked.
16. Existing `~/.openclaw/watcher/` remains unchanged.

Do not burn significant paid quota merely for testing.

------------------------------------------------------------------------

## 17. Suggested Validation Queries

Use lightweight equivalents of these if helpful:

### QUICK

``` text
search OpenClaw official documentation
```

Expected: official OpenClaw material should rank strongly.

### CURRENT

``` text
search latest OpenAI news
```

Expected: recent sources and explicit date awareness.

### TECHNICAL

``` text
search OpenClaw web search provider configuration
```

Expected: official documentation/source preferred over random tutorials.

### RESEARCH

``` text
research OpenClaw vs Hermes for personal AI agent use
```

Expected: multiple source types, facts separated from sentiment,
uncertainty acknowledged.

Keep validation bounded.

------------------------------------------------------------------------

## 18. Implementation Order

Use this sequence:

### Phase 1

Preserve DuckDuckGo and add/configure Brave as primary when credentials
are available.

### Phase 2

Implement/document query routing, freshness policy, and source-quality
ranking.

### Phase 3

Implement explicit deep-research behavior.

### Phase 4

Add simple caching/deduplication if justified.

### Phase 5

Prepare browser escalation behavior without making security-sensitive
browser/system changes.

Do not block Phases 1--4 on browser availability.

------------------------------------------------------------------------

## 19. Final Report

When complete, return a concise implementation report containing:

### Architecture

How the final search/research flow works.

### Providers

Primary, fallback, and failure behavior.

### Files/config

Every relevant file/config changed or created.

### Search strategies

How QUICK / NEWS / TECHNICAL / RECOMMENDATION are routed.

### Deep research

How `research` differs from `search`.

### Cache

Whether implemented, location, and TTL behavior.

### Browser

Current status and when escalation occurs.

### Token/cost behavior

What uses model tokens and what does not.

### Security

Where credentials live and what was deliberately not changed.

### Validation

Tests performed and results.

### Existing watcher

Explicitly confirm that the OpenCode watcher was not modified.

### Remaining limitations

Anything heuristic, experimental, provider-limited, or pending.

------------------------------------------------------------------------

## 20. Execution Authority

Proceed with safe local implementation.

Do not ask me about ordinary implementation details that can be
determined safely from the existing environment.

Stop and ask before any security-sensitive/system-wide operation, or
when a required credential must be supplied.

Do not modify the existing OpenCode watcher.
