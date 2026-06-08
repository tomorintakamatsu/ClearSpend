# Local First Money Logic V2 Summary

## What Changed

This branch adds the V2 money logic layer for PennyLet. The app keeps the existing SwiftUI UI, AI screens, wallpaper theme system, subscriptions, goals, import/export entry points, and local UserDefaults storage. The main change is that dashboard money calculations now use a deterministic, local-first V2 service.

The old in-app calculation fallback and Settings toggle have been removed. Reverting to the pre-V2 app now requires the backup branch, patch files, or source archive.

## Two Versions Preserved

- Old version: `.codex-backups/pre-local-money-logic-v2-20260529-170028/` contains the exact pre-V2 app state, including your newer UI/wallpaper/AI work, through `git-diff.patch` and `source-tree.tar.gz`.
- New version: `feature/local-first-money-logic-v2-20260529-170028` keeps the same app surface but routes the dashboard headline through Local Money Logic V2.

## Files Modified Or Added

- Added `main/Sources/MoneyLogicV2/MoneyLogicV2Models.swift`
- Added `main/Sources/MoneyLogicV2/MoneyLogicV2Calculations.swift`
- Added `main/Sources/MoneyLogicV2/MoneyLogicV2Detection.swift`
- Added `main/Sources/MoneyLogicV2/MoneyLogicV2CSVImport.swift`
- Added `main/Sources/MoneyLogicV2/LocalFirstMoneyLogicV2Service.swift`
- Added `main/Sources/MoneyLogicV2/MoneyLogicV2DataAdapter.swift`
- Added `moneyLogic/tests/LocalFirstMoneyLogicV2Tests.swift`
- Updated `main/Sources/AppViewModel.swift`
- Updated `main/Sources/Views/Dashboard/DashboardView.swift`
- Updated `main/Sources/Views/Dashboard/SpendHeroCard.swift`
- Updated `main/Sources/Views/Settings/SettingsView.swift`
- Updated `main/Sources/Views/Onboarding/WelcomeView.swift`
- Updated `main/Sources/Utilities/LocalizationStrings.swift`
- Updated `main/Sources/Models/Category.swift`
- Updated `main/Sources/Services/AIClient.swift`
- Updated `main/PennyLet.xcodeproj/project.pbxproj` through XcodeGen
- Added `REVERT_LOCAL_MONEY_LOGIC_V2.md`
- Added `test-data/pennylet-local-first-logic-sample-2026-03-to-05.csv`

Other modified files shown by Git were already part of the pre-V2 UI/wallpaper work and were preserved in the checkpoint before this logic change.

## New Data Model

The V2 layer defines local-only model types for:

- Accounts with budget and net-worth inclusion flags.
- Transactions with richer types: income, expense, transfer, refund, reimbursement, adjustment.
- Bucket types: income, fixed, flexible, non-monthly, goal, debt, transfer, excluded.
- Categories with rollover, monthly budget, targets, icons, colors, and archive state.
- Recurring series for income, bills, subscriptions, debt payments, transfers, and savings goals.
- Budget month summaries.
- Review queue items.
- Watchlists for merchants, tags, and categories.

No cloud sync, bank login, Plaid, credential storage, analytics, or network dependency was added for the V2 core logic.

## Formulas Implemented

- Spendable cash.
- Fallback plan funding.
- Safe to spend with negative internal value preserved and display clamped to zero.
- Daily safe to spend using days remaining in the month, including today.
- Left this month.
- Flexible spending remaining, expected pace, pace delta, and calm UX state.
- Category remaining with rollover.
- Non-monthly set-aside amount through target month.
- Net cash flow excluding transfers, credit card payments, adjustments, linked refunds, and excluded transactions.
- Net worth using asset and liability accounts.
- Credit card payment reserve.

## Detection And Local Import Logic

- Transfer matching by opposite signs, matching amount, nearby date, and different accounts.
- Credit card payments treated as transfers, not new expenses.
- Refund and reimbursement matching against earlier expenses.
- Recurring detection from local transaction history only.
- Local categorization suggestions with priority: user rules, confirmed merchant history, recurring series, local frequency, fallback.
- Review queue inclusion for low-confidence transactions, possible transfers, refunds, and recurring candidates.
- CSV parsing, column auto-mapping, date detection, duplicate preview, import batch IDs, and import batch undo in pure logic.
- The app's Settings and onboarding CSV import paths now share the V2 parser and normalize imported category names instead of falling back to `Other`.
- The included 3-month sample CSV has 185 transactions with explicit categories, income, expenses, transfers, refunds, reimbursements, subscriptions, and local-import metadata.

## AI And Data Accuracy

- AI prompts now use the same local-first interpretation as the dashboard: transfers, credit card payments, balance adjustments, ignored items, refunds, and reimbursements are handled separately instead of inflating spending or income.
- Category evidence sent to AI is normalized through the app category registry, so imported names like `Medical`, `Credit Card Payment`, or `Rent / Mortgage` are interpreted consistently.
- Dashboard summaries used by the UI and AI are cached from a stable signature to reduce repeated recomputation during SwiftUI refreshes.
- `AIClient` has longer request/resource timeouts and one retry.
- If remote AI times out or cannot be reached, PennyLet now immediately returns a localized on-device fallback analysis based on saved local transactions, budgets, goals, transfers, refunds, and recurring items.

## Math Audit Fixes

- Fixed plan-funded Safe to Spend so expected income is not counted twice when the user has no account-balance setup.
- Added the setup-page fixed spending value as a V2 fixed bucket when detailed fixed category limits do not exist yet.
- Fixed refund/reimbursement matching so matched refunds reduce the original spending bucket instead of being ignored.
- Fixed net cash flow so refunds reduce net expenses instead of inflating income or disappearing.
- Prevented same-sign transactions from being auto-matched as transfers.
- Canonicalized CSV categories like `Rent / Mortgage` before assigning buckets.
- Fixed currency input parsing so `30,000` is treated as thirty thousand, not thirty.
- Routed Budget Health, More-tab metrics, and budget alerts through the same V2 dashboard summary used by the home screen.

## Migration Behavior

No destructive schema migration was performed.

The app currently uses a data adapter that maps existing `Budget`, `Transaction`, `Goal`, and `RecurringSubscription` storage into V2 model types at calculation time. Existing saved data stays in place. Ambiguous or low-confidence imported/manual V2 transactions can be placed in the review queue by the V2 logic.

## Tests Added

Standalone Swift tests were added in `moneyLogic/tests/LocalFirstMoneyLogicV2Tests.swift` for:

- Safe to spend.
- Left this month.
- Flexible pacing.
- Category rollover remaining.
- Non-monthly set-aside.
- Transfer matching.
- Credit card payment exclusion.
- Refund matching.
- Reimbursement handling.
- Recurring detection.
- Categorization priority.
- Review queue inclusion.
- CSV import mapping.
- Duplicate detection.
- Import batch undo.
- Net cash flow excluding transfers.
- Net worth.
- Plan-funded Safe to Spend without double-counted income.
- Refunds reducing spending and net cash flow.
- Same-sign transfer rejection.
- Canonical CSV category mapping.
- Currency input parsing with thousands and decimal separators.
- Dashboard service integration.

## Verification

Commands run:

```sh
swiftc main/Sources/Utilities/CurrencyFormatter.swift main/Sources/MoneyLogicV2/MoneyLogicV2Models.swift main/Sources/MoneyLogicV2/MoneyLogicV2Calculations.swift main/Sources/MoneyLogicV2/MoneyLogicV2Detection.swift main/Sources/MoneyLogicV2/MoneyLogicV2CSVImport.swift main/Sources/MoneyLogicV2/LocalFirstMoneyLogicV2Service.swift moneyLogic/tests/LocalFirstMoneyLogicV2Tests.swift -o /tmp/LocalFirstMoneyLogicV2Tests && /tmp/LocalFirstMoneyLogicV2Tests
```

Result: passed.

```sh
xcodebuild -project main/PennyLet.xcodeproj -scheme PennyLet -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Result: passed. The only warning matched the baseline AppIntents metadata warning.

## How To Revert

Use `REVERT_LOCAL_MONEY_LOGIC_V2.md`.

Exact old-version app:

```sh
git switch backup/pre-local-money-logic-v2-20260529-170028
git apply .codex-backups/pre-local-money-logic-v2-20260529-170028/git-diff.patch
```

Archive fallback:

```sh
mkdir -p /tmp/pennylet-pre-v2
tar -xzf .codex-backups/pre-local-money-logic-v2-20260529-170028/source-tree.tar.gz -C /tmp/pennylet-pre-v2
```

Then compare or copy files back manually.

## Known Limitations

- V2 currently adapts the existing local data model at calculation time instead of replacing saved storage schemas.
- CSV preview, mapping, duplicate, and undo logic exists as pure logic; the visible Settings/onboarding import flow uses the improved parser but still does not expose the full preview/mapping UI yet.
- Account setup and envelope move-money UI are not fully built yet; V2 account/category structures are ready for those screens.
- Remote AI is still optional and may fail if the external service is unavailable, but the app now has a local fallback instead of leaving the user waiting indefinitely.

## Recommended Next Steps

- Add an in-app CSV preview screen that uses `MoneyLogicV2CSVImport.preview`.
- Add local account setup screens for checking, savings, cash, credit card, loan, and investment accounts.
- Add review queue UI for suggested transfers, refunds, categories, and recurring items.
- Add watchlist editing UI so users can choose 1-5 merchants, tags, or categories.
- Add a full Budget Month screen for fixed, flexible, non-monthly, goal, and debt buckets.
