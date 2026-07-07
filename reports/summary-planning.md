# Combined Summary — Portfolio-Wide Planning/Meta Repositories
(Sonnet subagent summary)

Repos: loop-plan, reaserch-plan, dev-plan/dev-plan-arch, star-club. All are single-commit repos (one commit each, titled like a PR description), suggesting single-session generation rather than iterative development.

## 1. Purpose of each repo

**loop-plan** (5 files) is the most abstract: fill-in-the-blank design templates for building any LLM agentic harness, not tied to Claude Code. Template 1 (`templates/01-agentic-harness-loop.md`) specs the assemble→model→decide→execute loop (system prompt, tool surface, termination/budgets, context management, verification, safety gates, observability). Template 2 (`02-self-education-agent.md`) layers a self-improving outer loop (skills, memory, reflection, curriculum, learning evaluation) atop Template 1. `skill-template/SKILL.md` defines the atomic unit of learned capability; `reference/loop-pseudocode.md` gives pseudocode plus invariant tables (I1–I8 inner loop, O1–O8 outer loop). Pure methodology — no working agents.

**reaserch-plan** (29 files) operationalizes loop-plan's ideas for research: a "clone-and-go" Claude Code template with 5 subagents (scout/analyst/architect/critic/scribe), 6 phase skills, 4 domain flows (universal/scientific/technical/market), and artifact templates. The most fully built-out repo — real `.claude/agents/*.md` and `.claude/skills/*/SKILL.md` with actual frontmatter (name/description/model/tools).

**dev-plan** (main) is just a one-line README stub — effectively empty. The real content lives on the sibling branch **dev-plan-arch** (20 files), a software-engineering analog of reaserch-plan: PRD → SPEC → code → test → review → ship pipeline for building one product as both a web app and Windows desktop app (Tauri 2), with 6 subagents (architect/coder/tester/reviewer/scout/docs-writer) and 3 skills (`/write-spec`, `/new-feature`, `/ship-check`).

**star-club** (1 file): `employee-competition-prompt.md` is a Russian-language corporate HR document — "Положение о годовом конкурсе сотрудников «Звезда года»" — a point-scoring bonus scheme for a design/engineering firm (productivity, sales contribution, priority-product placement, documentation quality categories, committee, appeals, monthly scoring template). A one-off business document sharing no structural/thematic link with the other three.

## 2. The agentic workflow system: how loop-plan / reaserch-plan / dev-plan-arch fit together

These three form a coherent stack at increasing specificity: **loop-plan = theory layer**; **reaserch-plan and dev-plan-arch = two concrete instantiations** of nearly the same pattern in different domains (research vs. software engineering). Both independently converge on the same architecture: orchestrator + tiered subagents + gated phase pipeline + file-based state.

**Tiered agent model (near-identical in both):**
- reaserch-plan: Haiku (`scout`, `scribe` — C1 mechanical: search, triage, formatting, citations) → Sonnet (`analyst` — C2 analytical: reading sources, extracting claims) → Opus (`architect`, `critic` — C3 integrative: synthesis, adversarial critique). Cited relative cost ratio ~1:4:20.
- dev-plan-arch: Haiku T1 (`scout`, `docs-writer` — lookups, docs) → Sonnet T2 (`coder`, `tester`, `reviewer` — implementation, tests, standard review) → Opus T3 (`architect` — SPECs, architecture decisions, security/migration review, perf investigations).
- Both encode an escalation ladder (cheaper tier fails twice → escalate one tier, always with a written summary not a raw transcript), both forbid using the expensive tier for retrieval/formatting, both allow downgrading if a task proves mechanical.

**Phase pipelines (gated, file-driven state machines):**
- reaserch-plan ROADMAP: Scoping(0)→Landscape scan(1)→Deep investigation(2)→Synthesis(3)→Critique(4)→Report(5)→Archive(6), each with a gate checklist and an "effort dial" (quick/standard/deep) scaling scout count, sources analyzed, critique rigor.
- dev-plan-arch WORKFLOW: PRD entry→`/write-spec` (architect drafts SPEC, human approves — the one human checkpoint)→SPEC split into TODO.md tasks with tier tags→parallel/serial `coder` implementation→`tester` (PASS/FAIL)→`reviewer` (APPROVED/CHANGES_REQUESTED)→`/ship-check`→merge.
- Both use skills as phase drivers (progressive disclosure, loaded on invocation) and agents as pinned-model executors — matching loop-plan's "skill = unit of capability" idea, though neither instantiation builds the actual self-education/learning loop from Template 2; they use Claude Code's static skill mechanism for procedure-following, not agent self-improvement.

**Token/context economy (shared philosophy, different vocabulary):** reaserch-plan's `docs/token-economy.md` ("subagents absorb the noise," "files are the memory, context is the scratchpad," digest caps 15–20 lines, phase-notes.md compaction checkpoints) mirrors dev-plan-arch's CLAUDE.md "Token economy rules" (scoped input, ≤300-word structured output, scout-first, narrow reads, one concern per agent). Both forbid raw source/file content re-entering orchestrator context — subagents return capped digests plus file paths only.

**Verification/gates:** both insist success cannot be self-reported. reaserch-plan requires a Critic to red-team findings and trace every claim to a source ID; dev-plan-arch requires tester PASS + reviewer APPROVED before merge, treating perf-budget breaches as BLOCKER-severity bugs. Both mirror loop-plan's "verify(), not the model's claim" invariant almost verbatim.

## 3. Multiplatform architecture guidance in dev-plan-arch

Concrete, opinionated stack:
- **Web:** React 18 + Vite + TypeScript strict, static SPA (SSR deferred). State: Zustand (selector-based, stores in `packages/core`, no React dependency). Server data via TanStack Query. React Router with lazy routes. Styling: CSS Modules/vanilla-extract — explicitly bans runtime CSS-in-JS. Zod schemas shared between UI and IPC.
- **Desktop:** Tauri 2 (Rust + same React frontend in WebView2), chosen over Electron (~10x smaller installs) and over native WinUI (~90% code reuse). SQLite via sqlx with FTS5 search. Rust layered into thin `commands/` over pure, unit-testable `services/` with no `tauri::` imports. IPC rules: coarse/batched commands, async everywhere, long jobs report via Tauri events not polling.
- **Shared:** pnpm-workspace monorepo — `apps/web`, `apps/desktop`, `packages/core` (business logic, no React/DOM), `packages/ui` (components, no business logic), enforced dependency direction (core←ui←apps). One `AppError` type mirrored across the Rust/TS boundary.
- **Performance treated as correctness**: hard numeric budgets for both platforms (web: ≤180KB initial JS gzip, LCP ≤2.0s, INP ≤100ms; desktop: cold start ≤1.5s, installer ≤15MB, idle memory ≤150MB, IPC p95 ≤10ms), enforced in CI (size-limit/Lighthouse CI/cargo bench); a budget breach is a BLOCKER review finding.
- Distribution: NSIS/MSI installer, WebView2 bootstrapper, `tauri-plugin-updater` for signed auto-update, code signing tracked as an M4 task.
- Explicitly deferred (with named revisit triggers): SSR migration, offline web, i18n, micro-frontends, macOS/Linux builds, multi-window, sidecar binaries.

## 4. Maturity and gaps

- **Everything is template, nothing filled in.** dev-plan-arch's PRD.md/ROADMAP.md/TODO.md/SPEC-TEMPLATE.md all still contain `<placeholder>` fields and a worked "Quick Notes"/NoteFlow example rather than a real product — no actual code exists yet. reaserch-plan has no filled `projects/<slug>/` directory. loop-plan's templates are unfilled by design.
- **dev-plan (main) is essentially a dead stub** — all real content sits on an unmerged branch; a viewer cloning dev-plan without knowing the branch finds nothing.
- **Single-commit repos** — each was scaffolded in one shot, LLM-generated in a single session rather than organically iterated.
- **Duplication across reaserch-plan and dev-plan-arch:** the token-economy playbook, tiered-model routing table, escalation ladder, and scout-first/digest-cap discipline are reimplemented near-identically with different domain vocabulary rather than factored into a shared package — no cross-repo references found despite loop-plan seemingly being the intended shared abstraction.
- **The self-education layer (loop-plan Template 2) has no working instantiation.** Neither downstream repo implements skill drafting/promotion/reflection loops (DRAFT→CANDIDATE→ACTIVE→DEPRECATED); both use Claude Code's static `.claude/skills/` mechanism instead. The most sophisticated template in the portfolio is unused.
- **star-club is a genuine outlier**, likely an unrelated personal/business document mixed into the same account.
- **No evidence gates have ever fired** — dev-plan-arch's TODO.md "Done" contains only "Repo scaffolding" itself; no SPEC exists in `docs/specs/` despite the template being ready.

## 5. Signals about the owner's goals and workflow

- **Heavy upfront planning / spec-before-code discipline** — three of four repos are pure planning/scaffolding with zero application logic; the fourth (loop-plan) is meta-planning about planning agents.
- **Strong, consistent model-tiering philosophy** — "pay for reasoning, not volume" recurs across reaserch-plan and dev-plan-arch: cheap models for bulk/mechanical work, mid-tier for bounded judgment, top-tier reserved for design/synthesis/critique. The single most repeated idea in the portfolio.
- **Auditability/reversibility as core values** — recurring demands for git-diffable artifacts, verified-not-self-reported success signals, human-approval gates on irreversible actions, and never letting subagent raw output re-enter context.
- **Prompt-engineering style:** dense, tabular, checklist-driven markdown with strict machine-parseable subagent output contracts (reviewer's `VERDICT: APPROVED|CHANGES_REQUESTED` block, tester's `VERDICT/SUITE/FAILURES/COVERAGE` block, line-count caps on scout/analyst/scribe returns).
- **Reusable-template mindset** over one-off scripts — every repo but star-club is built to be cloned/copied and adapted, an internal methodology toolkit spanning research work and multiplatform software engineering.
- **Platform commitment to Claude Code** for the two working instantiations (`.claude/agents`, `.claude/skills`, CLAUDE.md orchestrator-rules convention) even though loop-plan's theory is model/tool agnostic.
