# Portfolio Analysis & Architecture Decision Record — airwaves18244

**Date:** 2026-07-05
**Pipeline:** 4× Sonnet 5 analyst agents (per-repo deep dives, `reports/summary-*.md`) → Opus 4.8 synthesis (`reports/synthesis-opus.md`) → Fable 5 final analysis & rulings (this document).
**Purpose:** Capture the top-tier architecture and planning decisions for this portfolio *now*, so that after Fable 5 is no longer available by subscription, Opus 4.8 / Sonnet 5 / Haiku 4.5 can execute against settled decisions instead of re-deriving them.

---

## Executive summary

The 10 repositories are really **three lineages plus noise**:

1. **The MOEX trading terminal** — one product existing in four incarnations: an early copy embedded inside the `any` repo, **Market-flow** (the only one with real code: ~17k LOC Rust + ~6.3k LOC Svelte/TS, phases 0–9 CI-green), **Market-terminal-V3** (a docs-only architectural restart with ~70 unstarted tasks), and **Trading-strategies** (a rigorous 43-strategy research corpus meant to feed it).
2. **The agentic methodology stack** — loop-plan (theory) → reaserch-plan (research pipeline, actually used once, by Trading-strategies) → dev-plan (software pipeline, never used). All template, duplicated rather than shared.
3. **RevitNvf** (`any` repo) — a clean, working Revit 2024 ventilated-facade plugin, feature-complete per its roadmap, undistributable (no CI, no installer).

Noise: `star-club` (unrelated HR document), `Options` (empty, zero branches), `wo-FABLE-5` (this analysis repo).

The portfolio's systemic pattern: **plan-rich, execution-poor, memory-poor**. Every new effort cold-starts a new repo/PRD/architecture instead of continuing prior work — hence four terminal incarnations, two incompatible strategy taxonomies, three copies of the same architecture doc, and a methodology stack the products don't reference. The single most urgent finding is operational, not architectural: **a live-looking Finam API secret is committed to the public Market-flow repo** (Decision 1).

The ten decisions below are the ones that genuinely require top-tier reasoning — one-way, cross-cutting calls that cheaper models will then execute against for months. They are written as **rulings with rationale and execution handoffs**, not open questions.

---

## Decision 1 — SECURITY (URGENT): rotate the Finam key today; purge history; portfolio-wide secret policy

**Finding.** `Market-flow` is a **public** repository, and `.env` containing `Finam_API_SECRET=tapi_sk_…` is tracked in git (entered via the Phase-12 merge), despite `.gitignore` listing `.env` and README/SUMMARY explicitly claiming the secret never enters the repo. This is a live, public credential exposure for a brokerage API with (stubbed but present) order-routing code paths.

**Ruling & execution order (strict):**
1. **Rotate/revoke the key at Finam first.** History purging is pointless while the key is valid — assume it is already harvested (public-repo secret scanners index these within minutes).
2. Purge from history second: `git filter-repo --invert-paths --path .env` across **all** branches (19 remote branches on Market-flow — purge before consolidating branches per Decision 9, or the secret survives on unmerged refs), force-push, and contact GitHub support to clear cached views/forks if any.
3. Portfolio policy, enforced not documented: enable **GitHub push protection + secret scanning** on every repo (free for public repos); add a `gitleaks` pre-commit hook to the standard repo template; CI job fails on detection.
4. Standardize on Market-flow's existing (good) `SecretStore` chain — env var → OS keyring — and **delete the `.env` fallback path from the code**, since the portfolio has now empirically demonstrated that the `.env` convention fails under agent-driven commits. An agent workflow that bulk-stages files will eventually commit `.env` again; remove the class of error, not the instance.

**Why top-tier:** the individual fix is mechanical, but the *policy ruling* — "no file-based secrets at all in agent-operated repos, because agents bulk-stage" — is a generalization from a portfolio-level failure pattern that a task-scoped model would not make.

---

## Decision 2 — Terminal lineage: continue Market-flow; V3 becomes its roadmap, not its replacement

**Ruling.** Do **not** build Market-terminal-V3 from scratch. Market-flow already implements, with 244+ passing tests and CI enforcement, the exact architecture V3's docs re-derive: layered Rust workspace with a pure `domain` crate (no network/UI/DB), Tauri 2 shell, DuckDB behind a `Store` trait, Svelte 5 frontend, trait-based ports/adapters with in-memory test doubles. V3's ARCHITECTURE.md is a *description of Market-flow written by someone who hadn't read Market-flow*.

**Execution plan (hand to Opus/Sonnet):**
1. Move V3's five architecture docs into `Market-flow/docs/v3/`; rewrite ARCHITECTURE.md as a **delta document**: "what V3 adds to the existing implementation" (order routing/E4, screening/E3, LLM copilot/E7, options UI/E6) rather than a from-zero spec.
2. Produce one **module reconciliation table**: V3's 14-module catalog mapped onto existing crates (`crates/data` ⇄ E1 connectivity, `crates/storage` ⇄ storage/backfill, `crates/domain` ⇄ analytics/backtest/options math — already partially built in phases 10–12, `crates/app` + `frontend/` ⇄ E2 charting/workspaces). Every V3 module must resolve to *extend crate X* or *new crate, justified*.
3. Re-baseline V3's TODO.md: delete every task Market-flow phases 0–12 already cover; renumber the remainder as Market-flow phases 13+.
4. Archive `Market-terminal-V3` the repo with a README pointing at Market-flow (after merging its docs). Also delete the stale embedded `market-terminal/` copy inside `any` (Decision 9).
5. **Condition:** the V3 PRD references a "working V1–V2.5" that exists nowhere in the analyzed repos. If that prototype exists on a local machine, diff it against Market-flow *before* step 1; anything it has that Market-flow lacks becomes a phase-13 backlog item. If it doesn't exist, strike the claim from the PRD — the plan must not cite unverifiable prior art.

**Why top-tier:** classic restart-vs-continue judgment. The evidence (working tested code embodying the identical layering; restart motivated by doc drift, not code rot) makes this decisive now; six months of Sonnet execution against the wrong call is the single largest avoidable cost in the portfolio.

---

## Decision 3 — Decouple the two NFRs hiding inside "≥50k ticks/s, ≤100ms feed-to-pixel", then run spike S-0 before any V3 epic work

**Insight.** V3's scariest NFR is actually two independent NFRs conflated, and separating them removes most of the perceived risk:

- **Ingest NFR** (≥50k ticks/s): applies to `domain` + `storage` only. Pure Rust aggregation at 50k events/s is trivial (this is <1% of what a single core handles); DuckDB batch-append with 100–250ms flush windows is well within budget. This NFR is *low risk* and needs only a benchmark, not a redesign.
- **Paint NFR** (p50 feed-to-pixel ≤100ms at 60Hz): applies to the WebView rendering path. Crucially, **≤100ms latency does not require painting 50k discrete updates** — a screen has finite pixels. The correct architecture is *pre-binning in Rust*: aggregate ticks into screen-resolution buckets (price×time matrix for the heatmap, level-aggregated DOM), and push ≤30–60 pre-binned frames/s over Tauri events. IPC then carries bounded, resolution-capped payloads regardless of tick rate. The unvalidated bet shrinks from "can a WebView render 50k ticks/s?" (probably not) to "can Canvas/WebGL blit a precomputed ~200×400 matrix at 60fps?" (almost certainly yes).

**Ruling:** amend the V3 NFR section to state the two NFRs separately with the binning contract between them; then run a **time-boxed spike S-0 (≤2 weeks) before any epic task**:
- Synthetic tick generator in `domain` at 50k/s (deterministic, seeded).
- Bench 1 (ingest): domain aggregation + DuckDB append throughput; pass ≥50k/s sustained on target hardware.
- Bench 2 (paint): pre-binned heatmap via (a) Canvas2D batched draw, (b) WebGL instanced quads; pass = sustained 60fps, p95 frame <16ms, panel memory <300MB.
- Kill criteria: if both render paths fail in WebView2, the fallback is a native wgpu overlay window for the heatmap panel only — do not abandon Tauri for one panel.

**Why top-tier:** recognizing that an NFR as written is a category error (conflating data rate with paint rate) and re-cutting the architecture boundary (bin in Rust, blit in JS) is exactly the kind of reframing that changes a 70-task plan's shape; everything downstream (dockview choice, IPC design, heatmap module) inherits it.

---

## Decision 4 — One canonical strategy taxonomy + machine-readable `StrategySpec`, bridging Trading-strategies → terminal

**Finding.** Trading-strategies (10 folders, 43 docs) and V3's STRATEGY_FRAMEWORK.md (8 classes) were authored independently, share no schema, and neither references the other. As-is, none of the 43 research docs is machine-consumable by the backtester they were written for.

**Ruling — canonical model is two orthogonal axes plus tags, 8 classes:**

| Canonical class | Absorbs (Trading-strategies) | Absorbs (V3 framework) |
|---|---|---|
| trend-momentum (time-series) | momentum, trend-following | momentum/trend |
| cross-sectional (rotation/factor) | value/factor | cross-sectional rotation |
| mean-reversion-swing | mean-reversion/swing | swing/mean-reversion |
| breakout | (subset of momentum docs) | breakout |
| arbitrage-rv | arbitrage/RV | stat-arb, futures arbitrage |
| carry | carry | carry |
| volatility-options | volatility | volatility/options |
| event-driven | event-driven, flows/seasonality | — |

- **`crypto` is not a class** — it's a venue. Venue (`moex-equity`, `moex-futures`, `bonds`, `crypto`, …) becomes a tag, fixing the current category/venue confusion.
- **Edge type** (risk-premium / behavioral / structural-flow / constraint — already rigorously tagged in Trading-strategies) is the second axis; flows/seasonality docs keep `structural-flow` edge and land in event-driven or carry by mechanism.
- **`StrategySpec`**: YAML frontmatter added to each of the 43 docs and consumed verbatim by the terminal's JSON strategy packages: `id, name, class, edge_type, venues[], instruments[], decay_status (active|decaying|dead), lifecycle (research|backtest|paper|live), params{name: [min,max,default]}, evidence_ids[], correlation_cluster`. The `correlation_cluster` field carries Trading-strategies' key insight (43 docs ≈ 10–12 independent bets) into position-sizing logic — the terminal must budget risk per cluster, not per strategy.
- Lifecycle states unify Trading-strategies' "research complete" status with V3's promotion gates (backtest→paper→live); a strategy doc *is* the seed of a strategy package, one artifact end-to-end.

**Execution handoff:** Sonnet migrates all 43 docs to frontmatter + writes the JSON-schema validator; Haiku fixes citations. The four "known-dead" control strategies get `decay_status: dead` and stay — they are regression tests for the promotion gate (a backtest pipeline that promotes a dead strategy is broken).

**Why top-tier:** ontology unification across two independently evolved corpora, with a subtle modeling call (venue-as-tag, cluster-as-risk-budget) that every future strategy doc and the backtester's data model must conform to.

---

## Decision 5 — Kill the hand-synced IPC boundary: generate the contract from Rust

**Finding.** Market-flow's 26 IPC commands are manually kept in sync in **three places**: Rust command registration, the typed TS client, and `mock.ts`. This is the portfolio's most error-prone recurring mechanical task and it grows with every V3 epic (E3/E4/E7 all add commands).

**Ruling:** single source of truth in Rust; TypeScript is generated.
1. Adopt **`specta` + `tauri-specta`** (purpose-built for Tauri 2) to derive TS types and a typed client from the Rust command definitions; DTOs get `#[derive(specta::Type)]`. (`ts-rs` is acceptable fallback if tauri-specta friction is high.)
2. One `AppError` enum in Rust, serialized tagged, generated into TS — replacing ad-hoc error strings. This also satisfies dev-plan-arch's "one AppError mirrored across the boundary" rule with zero manual mirroring.
3. `mock.ts` implements the *generated* interface, so a missing/renamed command is a compile error in CI, not a runtime surprise.
4. Contract test in CI: enumerate registered commands on the Rust side, diff against the generated client surface; fail on drift.

**Why top-tier:** it's a boundary-ownership decision (codegen direction: Rust→TS, never schema-first or TS-first) that eliminates a whole class of drift the portfolio has already institutionalized as manual labor. Decide once; Sonnet mechanically migrates the 26 commands.

---

## Decision 6 — Frontend stack ruling: Svelte 5 is the terminal-lineage standard; dev-plan-arch becomes stack-parameterized

**Finding.** dev-plan-arch mandates React 18 + Zustand + TanStack Query for Tauri products; the only real Tauri product (Market-flow, 37 Svelte components, ECharts + Lightweight Charts integrations) and V3's own architecture docs both use Svelte 5. The owner's playbook contradicts the owner's flagship.

**Ruling:** **Svelte 5 stays** for the terminal lineage. Rationale: (a) 6.3k LOC of working, tested components exist; (b) Svelte's compiled, no-VDOM output is *better aligned* with dev-plan-arch's own hard perf budgets (≤180KB initial JS, INP ≤100ms) than React; (c) the charting stack (ECharts/Lightweight Charts) is framework-agnostic imperative code — React would add wrapper friction for zero gain; (d) high-frequency panel updates (DOM/T&S at 60Hz) are Svelte's strength case.

dev-plan-arch is restructured rather than rewritten: its genuinely reusable 80% (monorepo layout, `packages/core` with no framework deps, dependency direction, perf-budgets-as-CI-blockers, Tauri IPC rules, error model) becomes **stack-agnostic core guidance**; framework choice becomes a per-product appendix (React appendix kept as-written; Svelte appendix distilled from Market-flow's actual conventions). The "business logic lives framework-free in core packages" rule is the load-bearing idea and survives either framework.

**Why top-tier:** resolving a contradiction between two authoritative documents requires deciding *which document is wrong and in what scope* — and the non-obvious answer is "neither: the playbook's framework layer was over-specified; demote it to a parameter."

---

## Decision 7 — Methodology stack: consolidate to one versioned `agent-os` repo; instantiate the skill-promotion loop minimally; retire the rest of Template 2

**Finding.** reaserch-plan and dev-plan-arch duplicate the same token-economy playbook, tier ladder, and escalation rules with different vocabulary; loop-plan (the intended shared abstraction) is referenced by nothing; products (Market-flow, V3) re-embed their own `.claude/` machinery instead of consuming the stack. The most sophisticated artifact — loop-plan Template 2's self-education loop (DRAFT→CANDIDATE→ACTIVE→DEPRECATED skill promotion, reflection, curriculum) — has zero instantiations.

**Ruling:**
1. **One repo (`agent-os`)** replaces loop-plan + reaserch-plan + dev-plan: `core/` (token economy, tier ladder, escalation ladder, verification invariants — written ONCE), `flows/research/` and `flows/dev/` (thin domain overlays: agents, skills, phase gates), `docs/theory/` (loop-plan's templates, preserved as design rationale). Products consume it as a **pinned copy with a recorded version** (`.claude/agent-os.version`), refreshed deliberately — not a submodule (agent tooling handles submodules poorly), not ad-hoc divergence. Archive the three source repos with pointer READMEs.
2. **Instantiate Template 2's skill-promotion loop in its minimal file-based form, and only that:** `skills/draft/` vs `skills/active/`; promotion requires the skill having been used successfully in ≥2 sessions with a one-line evidence log; demotion after 2 failures or 90 days unused; reviewed monthly by a human-triggered `/skill-review` skill. **Formally retire** the reflection/curriculum/learning-evaluation machinery — it is speculative, has no consumer, and its maintenance cost lands on cheaper models later. Record this as an ADR so future sessions don't re-propose it cold.
3. Rule for products: a repo may *extend* agent-os locally (repo-specific skills like RevitNvf's `revit-api-2024`) but may not *redefine* core rules; the core file is copied verbatim so drift is `diff`-detectable.

**Why top-tier:** "is this methodology a product, a library, or scaffolding?" is the architecture-of-the-architecture question, and the discipline call to *kill* the self-education layer (rather than keep it aspirationally) is the kind of scope ruling that prevents compounding template debt.

---

## Decision 8 — Post-Fable model routing: the succession plan for top-tier work

**Finding.** V3's TODO.md and both methodology repos route work across Fable 5 / Opus 4.8 / Sonnet 5 / Haiku 4.5, with Fable assigned architecture, numerical correctness, and risk-critical review. That tier disappears from the subscription. The mitigation is not "Opus does what Fable did" — it is restructuring the work so less of it *requires* the missing tier.

**Ruling — three-part succession:**
1. **Decisions in this document are settled.** Future sessions execute them; they do not re-open them without new external evidence. (This document is the portfolio's ADR log seed — Decision 9 makes it durable.)
2. **Convert judgment into protocol.** The classes of work previously routed to Fable get *mechanical verification substitutes* that Opus can operate:
   - *Numerical correctness (options pricing, vol smile, backtest math):* golden test vectors generated once from independent references (QuantLib / py_vollib / hand-computed edge cases) and committed; property-based tests (put-call parity, monotonicity in vol, arbitrage-free smile constraints) as invariants. Opus then verifies against oracles instead of self-certifying derivations.
   - *Risk-critical review (order routing, live-trading gates):* two independent Opus passes with different briefs (implementation review vs adversarial "how do I lose money" red-team), plus the mandatory kill-switch/paper-parity checklist from the V3 PRD as a literal CI-gated checklist. Independence substitutes for depth.
   - *Architecture decisions:* new one-way calls get batched into a written "decision memo" queue with an explicit options/evidence/recommendation format (reuse reaserch-plan's decision-matrix template). Opus-high with a structured brief and an adversarial second pass is a fair substitute *when the framing is done in the memo*; the failure mode to guard against is unframed, open-ended "figure out the architecture" prompts.
3. **Amend the routing tables** (V3 TODO.md, agent-os core): Fable rows → `Opus 4.8, effort high/max, + protocol from §2`; delete the effort-level distinctions that only existed to ration Fable. Sonnet/Haiku rows unchanged — the bottom of the ladder is unaffected.

**Why top-tier:** this is meta-reasoning about which of my own judgment tasks decompose into protocol + weaker judgment, and which genuinely don't (the memo queue exists precisely to make the residue visible instead of silently absorbed).

---

## Decision 9 — Portfolio governance: main-is-truth, repo consolidation, and a continuation gate

**Ruling, in three parts:**

**(a) Main-is-truth, executed now.** Merge stranded content to `main` (fast-forward or PR-merge, then set `main` default): Trading-strategies (`claude/trading-strategies-research-qhrq6q` → main — main is currently *empty*), market-terminal-v3 plan branch, dev-plan arch branch, star-club, loop-plan, reaserch-plan (default branches are claude/* session branches). Standing rule for every future agent session: **a session ends with merge-or-PR the same day; `claude/*` branches older than 7 days are triaged (merge or delete) weekly.** On Market-flow, triage the 19 branches after the history purge of Decision 1.

**(b) Repo consolidation.** Rename `any` → `revit-nvf` (its actual product) and delete the embedded `market-terminal/` tree from its branch (superseded by Market-flow; keeping two divergent copies of a trading terminal inside a CAD plugin repo is pure hazard). Delete the empty `Options` repo, or if options work is planned it lands in Market-flow's existing options domain module — not a new empty repo. Archive superseded repos per Decisions 2 and 7. Move `star-club`'s document wherever personal/business docs live; it isn't a software project.

**(c) The continuation gate — the fix for the cold-start pattern.** A `PORTFOLIO.md` index (living in the agent-os repo) lists every active repo: one line each — purpose, lineage, status, canonical branch. Every planning-type agent session gets a mandatory first step: *read PORTFOLIO.md and state which existing lineage this work continues; creating a new repo requires writing one sentence in PORTFOLIO.md justifying why no existing lineage fits.* This is deliberately lightweight — the failure mode being fixed (four terminal incarnations, two taxonomies) came from sessions that had no portfolio context at all, not from bad judgment within context.

**Why top-tier:** the individual moves are mechanical, but diagnosing *portfolio amnesia* as the root cause (rather than treating each duplicate as a local accident) and designing the minimal standing mechanism against it is the cross-cutting call.

---

## Decision 10 — Verification standard: "done" must be machine-checked, because the portfolio's own docs already drifted

**Finding.** The portfolio preaches "verified, not self-reported" (loop-plan invariants, dev-plan gates) but practices self-reporting: RevitNvf's README still says "no plugin code exists" with 8/8 roadmap steps complete; Market-flow's installable artifact has never been built by CI; methodology gates have never fired.

**Ruling — provable-done becomes CI, per repo:**
1. **Market-flow:** add a Windows CI job building the Tauri bundle + NSIS installer on every release tag (the "needs a desktop machine" blocker is false — GitHub-hosted `windows-latest` runners build Tauri/WebView2 apps routinely). Add one e2e smoke test driving the built app against the existing replay data source (launch → ingest replay → assert a populated panel via tauri-driver/WebDriver). The riskiest untested path (live gRPC auth) stays manual but gets a documented manual-test checklist gated on release.
2. **RevitNvf:** the "can't build net48 adapter in CI" constraint is also removable — reference the Revit API via the **Nice3point.Revit.Api NuGet packages** instead of local DLLs, enabling compile-verification of the adapter layer on a Windows runner (behavioral testing still needs licensed Revit; compile + Core tests + a build artifact is the achievable bar). Fix the stale README as part of the same PR.
3. **Doc freshness as a check, not a hope:** test counts and phase-status claims in ROADMAP/SUMMARY files are either generated by CI or asserted by a lightweight script that diffs claimed vs actual (`cargo test -- --list | wc -l` vs the number quoted in docs); mismatch fails CI. Agent-written status prose has now twice been shown to drift from reality — treat status docs as build artifacts.
4. **Methodology repos:** a gate that has never fired is untested code. When agent-os lands (Decision 7), its first real consumer runs one full pipeline (e.g., the S-0 spike of Decision 3 run through the dev flow) as the acceptance test of the methodology itself.

**Why top-tier:** the insight is not "add CI" — it's that in an agent-operated portfolio, *self-reported completion is the primary integrity threat*, so verification must be adversarial to the agents' own claims, and the two "environment-blocked" excuses in the repos were both factually wrong and worth challenging.

---

## Suggested execution order

| # | Decision | First action | Executor |
|---|---|---|---|
| 1 | Rotate Finam key + purge history | today, manual + Opus | human + Opus |
| 9a | Merge stranded branches to main | this week | Sonnet |
| 2 | Terminal consolidation (V3 docs → Market-flow delta) | this week | Opus (memo) + Sonnet |
| 3 | NFR split + spike S-0 | before any V3 epic | Sonnet (bench code), Opus (verdict) |
| 5 | tauri-specta contract codegen | with first V3 epic | Sonnet |
| 4 | StrategySpec frontmatter migration (43 docs) | parallel, low risk | Sonnet + Haiku |
| 7 | agent-os consolidation | next planning session | Opus + Sonnet |
| 8 | Routing-table amendment | with 7 | Haiku (mechanical edit) |
| 6 | dev-plan-arch restructure | with 7 | Sonnet |
| 10 | CI verification jobs | rolling | Sonnet |

---

*Intermediate artifacts: `reports/summary-market-flow.md`, `reports/summary-trading.md`, `reports/summary-planning.md`, `reports/summary-revit.md` (Sonnet 5 analysts), `reports/synthesis-opus.md` (Opus 4.8 synthesis).*
