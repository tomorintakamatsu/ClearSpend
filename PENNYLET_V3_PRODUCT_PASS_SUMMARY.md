# PennyLet V3 Product Pass Summary

Date: 2026-06-03
Branch: `codex/pennylet-v3-differentiation-20260601-194515`
Checkpoint: `.codex-backups/pre-v3-concrete-product-pass-20260603-161220/`
Backup branch: `codex/backup-v3-before-product-pass-20260603-161220`

## What Changed

- Made Safe Until Payday explainable on the Home screen with a visible calculation breakdown:
  - money available today;
  - bills before payday;
  - known subscriptions before payday;
  - savings before payday;
  - protected/untouched money;
  - final safe amount.
- Added a Today Snapshot editor from the Home card so users can update current money, cash, protected money, payday, next paycheck, bills, and savings without importing old bank data.
- Updated the Start From Today logic so expired stored payday dates roll forward from the configured payday instead of continuing to use an old date.
- Made active subscriptions due before payday reduce Safe Until Payday.
- Added dashboard data-confidence messaging so the app clearly says whether numbers are based on a light snapshot, strong local data, or items needing review.
- Surfaced the local Review Queue as a dashboard card and detail sheet.
- Added user-created Watchlists stored locally in UserDefaults. Users can track merchants or categories such as Coffee, Dining, Amazon, games, or transit.
- Improved watchlist matching so a merchant watchlist like `Amazon` can match `Amazon Marketplace`.
- Shortened the online AI wait before local fallback from about 12 seconds to about 7 seconds.
- Reworded AI progress so local analysis feels like an intentional private feature, not a failed backup.
- Localized new user-visible strings in English fallback, Japanese, and Chinese.

## Logic Difference From Earlier V3

Earlier V3 had the “start today” positioning, but the user had to trust the headline number. This pass makes the number inspectable and editable, and connects saved recurring subscriptions to the payday bridge.

The app now treats the first-use snapshot as a living local model:

`current spendable balance + cash - bills before payday - known subscriptions before payday - savings before payday - protected money = Safe Until Payday`

The next paycheck is shown as context, but it is not counted as spendable money until the user actually has it.

## Files To Review First

- `main/Sources/AppViewModel.swift`
- `main/Sources/Views/Dashboard/SpendHeroCard.swift`
- `main/Sources/Views/Dashboard/DashboardView.swift`
- `main/Sources/MoneyLogicV2/MoneyLogicV2DataAdapter.swift`
- `main/Sources/MoneyLogicV2/LocalFirstMoneyLogicV2Service.swift`
- `main/Sources/Views/AI/AIFeaturesView.swift`
- `main/Sources/Utilities/LocalizationStrings.swift`
- `moneyLogic/tests/LocalFirstMoneyLogicV2Tests.swift`

## Tests And Build

- Passed: standalone local V2 logic tests via `swiftc`.
- Passed: XcodeBuildMCP simulator build for `PennyLet` on iPhone 17 Pro, iOS 26.5.
- Not run: Xcode scheme test action, because the `PennyLet` scheme is not configured for testing.

## Revert

To return to the pre-pass state:

1. Save any new work you want to keep.
2. Switch to the backup branch:
   `git switch codex/backup-v3-before-product-pass-20260603-161220`
3. Or restore from the checkpoint folder:
   `.codex-backups/pre-v3-concrete-product-pass-20260603-161220/`
4. The checkpoint includes:
   - `git-status.txt`
   - `git-head.txt`
   - `git-diff.patch`
   - `git-diff-staged.patch`
   - `source-tree-v3-current.tar.gz`

Known limitation: the Review Queue sheet currently explains why items need attention, but it does not yet provide one-tap accept/override actions. That should be the next product pass.
