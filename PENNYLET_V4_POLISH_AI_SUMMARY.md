# PennyLet V4 Polish + Pro Intelligence Summary

Date: 2026-06-08
Branch: `codex/pennylet-v4-polish-ai-20260608-172126`
V3 backup branch: `codex/backup-v3-before-v4-20260608-172126`
V3 backup tag: `v3-before-v4-20260608-172126`

## Product Direction

V4 keeps PennyLet's local-first V3 money logic and adds the first concrete version of the Pro Intelligence layer:

- Free PennyLet gives users a complete daily money app.
- Pro PennyLet learns from saved Money Checks and uses those notes across the app.
- PennyLet still calculates money with deterministic local logic.
- Pro explains, remembers, and connects the dots.

Core positioning:

`Start today. No bank login. No old cleanup. Know what is safe to spend.`

Pro positioning:

`PennyLet Pro learns your rhythm and helps before you ask.`

## What Changed

- Added `AIInsightMemory`, a small local model for saved Pro insight memory.
- Persisted saved insight memory locally in `UserDefaults` with the rest of app data.
- Added dismissible Pro insight cards generated from:
  - completed Money Checks;
  - Safe Until Payday inputs;
  - Review Queue counts;
  - Watchlists;
  - upcoming commitments.
- Added a Home Pro insight card under Safe Until Payday so AI feels connected to the daily decision screen.
- Added an Insights-screen Pro insight rail.
- Added `Ask PennyLet`, a small grounded local Q&A surface for Pro users.
- Added `Clear saved insights` in Settings.
- Added saved insight memory into future AI prompts as continuity context.
- Kept AI as explanation/context only; it does not overwrite transactions, categories, budgets, refunds, transfers, or Safe Until Payday.
- Renamed user-facing AI labels toward `Money Checks`, `Check Today`, `Check This Week`, and `Check This Month`.
- Updated Upgrade messaging around rhythm learning, Ask PennyLet, payday forecasts, and proactive insight cards.
- Increased the user-facing AI deadline to reduce premature timeouts:
  - Free: 9 seconds;
  - Pro: 14 seconds;
  - local fallback still prevents indefinite waiting.
- Made shared Settings rows taller and clearer so secondary settings screens feel less cramped.
- Localized new Japanese and Simplified Chinese strings for the V4 AI/Pro UI.

## Accuracy Rules

- Safe Until Payday remains deterministic local math.
- Saved insight memory is context only.
- Future AI checks can read saved insight summaries, but must verify claims against the current PennyLet data snapshot.
- AI must not invent bank data, hidden transactions, missing merchants, income, or dates.
- AI must not suggest bank login, Plaid, credential sharing, or cloud account aggregation.

## Files Modified

- `main/Sources/AppViewModel.swift`
- `main/Sources/Models/AnalysisHistory.swift`
- `main/Sources/Utilities/LocalizationStrings.swift`
- `main/Sources/Views/AI/AIFeaturesView.swift`
- `main/Sources/Views/Dashboard/DashboardView.swift`
- `main/Sources/Views/Settings/SettingsView.swift`
- `main/Sources/Views/Upgrade/UpgradeView.swift`

## Tests And Build

- Passed: localization duplicate-key scan for Japanese and Chinese dictionaries.
- Passed: standalone local money logic tests.
- Passed: XcodeBuildMCP simulator build for `PennyLet`.
- Passed: XcodeBuildMCP simulator build + launch smoke test.

Runtime notes:

- Debug simulator log shows an APNs entitlement warning because the simulator Debug build is not signed with push notification entitlement.
- Debug simulator log also shows a WebKit accessibility duplicate-class warning from the iOS simulator runtime.
- Neither warning blocked launch.

## Revert To V3

Best option:

```bash
git fetch origin
git switch codex/backup-v3-before-v4-20260608-172126
```

Or use the tag:

```bash
git fetch origin --tags
git switch --detach v3-before-v4-20260608-172126
```

Local checkpoint:

`.codex-backups/pre-v4-from-v3-20260608-172126/`

That folder contains:

- `git-status.txt`
- `git-head.txt`
- `git-branch.txt`
- `git-diff.patch`
- `git-diff-staged.patch`
- `git-diff-stat.txt`
- `project-summary.md`
- `revert-instructions.md`
- `source-tree.tar.gz`

## Known Limitations

- `Ask PennyLet` is intentionally practical and grounded, not a full financial adviser chatbot.
- Background AI is not implemented as always-running background intelligence because iOS controls background execution tightly.
- Proactive insight cards are generated from local app state when the app is open.
- Siri/App Intents and voice input remain future work.
