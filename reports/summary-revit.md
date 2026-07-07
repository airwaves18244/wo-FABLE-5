# Repo Review: airwaves18244/any (RevitNvf)
(Sonnet subagent summary)

## 1. Purpose & Domain

RevitNvf is a C# plugin for **Autodesk Revit 2024** that automates modeling of **ventilated facade systems** (НВФ — навесные вентилируемые фасады, rainscreen cladding assemblies). It automates: substructure layout (brackets and vertical guides on a grid pitch), cladding panel layout (with joint width and start-mode alignment), the layer "pie" (insulation, wind barrier, air gap), and quantity-takeoff/specification output. Target users are facade designers and structural engineers. Domain references cited in docs are Russian normative standards (СП 426.1325800.2020, ГОСТ Р 58154/58155-2018, СП 50.13330) used as parameter/constraint sources, not as a load-bearing calculation engine — explicitly out of scope. Curved facades and CAD/KMD drawing generation are also out of scope for the MVP; only planar faces are supported. All documentation, code comments, and UI strings are in Russian.

## 2. Architecture

Clean, deliberately-enforced layered design across a 4-project solution (`RevitNvf.sln`):

- **`RevitNvf.Core`** (netstandard2.0): pure domain — geometry (`Point2d`), models (`FacadeSystem`, `Substrate`, `Bracket`, `Guide`, `Cladding`, `Panel`, `PieLayers`/`Layer`, `FacadePreset`), layout algorithms (`BracketLayout`, `GuideLayout`, `PanelLayout`, `LayerStackup`, shared `GridAxis`), and reporting (`FacadeTakeoff`, `TakeoffReport`). **Zero references to `Autodesk.Revit.*`** — enforced as an explicit architectural rule in CLAUDE.md. Units are mm/SI, custom point/vector types instead of Revit's `XYZ`. Layout algorithms are pure functions `(Substrate, FacadeSystem) → positions`, documented as deterministic and idempotent.
- **`RevitNvf.Revit`** (net48, Revit 2024 runs on .NET Framework 4.8): thin adapter — `IExternalCommand` implementations, face→domain geometry translation (`PlanarFaceSubstrate`, `UnitsConvert` mm↔feet), family symbol lookup (`FamilyResolver`), model-curve visualization (`ModelCurveFactory`), and `IExternalApplication` ribbon entry point (`RibbonApp`). Revit API refs are local, `Private=false`, path configurable via MSBuild property `RevitApiDir`.
- **`RevitNvf.UI`** (net48, WPF): dockable-pane MVVM layer (`FacadeParametersViewModel`, `FacadeParametersView.xaml`, `FacadeParametersStore` as shared parameter state). Depends only on Core; `RevitNvf.Revit` references UI (no cycle).
- **`RevitNvf.Core.Tests`** (net8.0, xUnit): unit tests for Core layout algorithms, cross-platform, runnable in a Linux cloud container where Revit isn't available.

The Revit/Core boundary is the key abstraction, explicitly motivated by cloud-agent constraints — Core builds/tests in a sandbox without Revit; Revit/UI only build on Windows with Revit 2024 + VS2022.

## 3. Current State

Per `docs/ROADMAP.md`, 8/8 planned steps are marked complete: scaffolding, ribbon/hello-world command, bracket layout (TDD), Revit materialization of brackets, guides, cladding panels + layer pie + takeoff/edge-panel reporting, and a WPF parameters panel with facade presets (ceramic granite/cassette/composite). Implemented commands: `PlaceBrackets`, `PlaceGuides`, `PlaceCladding`, `ShowLayerStackup`, `ShowParametersPane`, `ShowTakeoff`, `ShowAbout`. ~1,415 LOC across Core+Revit, 467 LOC of tests (Core-only; **no tests for the Revit adapter layer**). No CI workflow; a SessionStart hook in `.claude/settings.json` auto-runs `dotnet test` when the Core test project/SDK are present. No installer — deployment is a post-build MSBuild target (`DeployAddin`) copying the DLL and manifest to `%AppData%\Autodesk\Revit\Addins\2024`, dev-machine-only. Notably, `README.md`'s status line still reads "Этап 0 — ... Кода плагина ещё нет" ("no plugin code yet") despite all 8 steps and full source existing — a stale top-level doc.

**Branch vs main**: the checked-out default branch (`claude/busy-gauss-PdcDZ`, 90 files) is byte-identical to merged main (62 files) for every RevitNvf file. The sole difference is an entire extra top-level directory, `market-terminal/`, present on the branch and absent from main — a **complete, unrelated Rust project**: a Tauri-based desktop "Market Terminal" for Russian stock-market analytics (Finam Trade API via gRPC/tonic, DuckDB storage, Svelte+ECharts+TradingView frontend), its own Cargo workspace (`crates/{finam-proto,domain,data,storage,app}`), own README/ROADMAP/CI. It was merged from a differently-named Claude session branch (`zealous-gates-dzww68`, PR #3) than the RevitNvf work (PR #1, `busy-gauss-PdcDZ`). It shares no code/dependency relationship with RevitNvf — an unrelated side project pushed into the same GitHub repo. (This appears to be an earlier version of what later became the standalone Market-flow repo.)

## 4. Key Design Decisions & Patterns

- **Hard Revit-isolation rule** enforced by convention/doc (CLAUDE.md) rather than a build-time check — no analyzer enforces "no Autodesk.Revit.* in Core."
- **Pure/deterministic/idempotent layout functions** — good testability; explicitly a functional requirement (re-running layout must not duplicate elements).
- **MVVM for the WPF panel**, decoupled from Revit via a static `FacadeParametersStore.Current` singleton that commands read from.
- **Config decomposition**: `FacadeSystem`/`Cladding`/`PieLayers` as separate immutable value objects unified via `FacadePreset`.
- **Single-transaction batch placement** for performance/undo correctness (one Revit `Transaction` per command = one undo step).
- **Units boundary discipline**: Core strictly mm/SI; conversion to/from feet isolated to the adapter.
- Three `.claude/skills/` (revit-api-2024, nvf-domain, revit-family-generation) capture domain/API knowledge as reusable Claude Code skills.

## 5. Quality/Risk Observations

- **Zero test coverage for the Revit adapter layer** (Commands, geometry adapters, family resolution) — inherent to the domain (no headless Revit in CI), but integration bugs are only caught by manual testing in a licensed Revit install.
- **Hardcoded family-name dependency**: `PlaceBracketsCommand` fails outright if a family literally named `"NVF_Bracket_Load"` isn't pre-loaded into the project — brittle coupling to an out-of-repo asset with no fallback.
- **No CI pipeline** for the RevitNvf side; Windows-only Revit/UI projects have no automated build verification at all.
- **No installer** — unsuitable for distributing to end users.
- **Stale top-level docs**: README status section contradicts actual repo state.
- **Repo hygiene**: an unrelated `market-terminal` Rust/Tauri project living inside the same repo root pollutes diffs/history and mixes a C# `.sln` with a `Cargo.toml` workspace at the root.

## 6. Signals About Owner's Development Workflow

- Heavy use of **Claude Code**: auto-generated branch names, `.claude/skills/`, `.claude/settings.json` with a custom SessionStart hook, `.mcp.json` template for Revit-MCP, and a detailed `CLAUDE.md` "gotchas" file (transactions, units, ElementId lifetime, threading) — the repo is engineered for productive AI-agent sessions, explicitly working around the constraint that Revit/.NET Framework can't build in a cloud sandbox.
- **Roadmap-driven, step-by-step TDD workflow**: `docs/ROADMAP.md` reads as a literal task list consumed one step at a time, each marked done with what was implemented and how it was verified.
- **Multiple unrelated projects sharing one GitHub repo** via distinctly-named Claude Code sessions merged as separate PRs — the owner used one repo as a general scratch space before splitting projects out.
- Documentation-first, Russian-language, industry-code-literate structure suggests genuine domain expertise rather than a toy plugin.
