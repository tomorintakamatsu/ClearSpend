# PennyLet V3 Differentiation Summary

Created: 2026-06-01

## What V3 Is Optimized For

PennyLet V3 is positioned around a different job than connected-account finance assistants:

> Start today with the money picture you have now. No bank login, no old transaction cleanup, and no cloud account required.

The app should now consistently reinforce this sharper line:

> No bank login. No old cleanup. Know what is safe to spend today.

## What I Learned From OpenAI's Finance Preview

Official OpenAI materials describe Finances in ChatGPT as a Pro-only preview in the U.S. on web and iOS. It centers on connected financial accounts through Plaid, synced dashboards, financial memories, and questions grounded in connected financial context. OpenAI's current Pro tiers include a $100 plan and a $200 plan, so PennyLet should avoid trying to look like a premium all-in-one financial command center and instead own the simpler local-first daily clarity lane.

Sources:

- https://openai.com/index/personal-finance-chatgpt/
- https://help.openai.com/en/articles/20001222-finances-in-chatgpt
- https://help.openai.com/en/articles/9793128-about-chatgpt-pro-plans

Useful ideas to study without copying:

- Explain what data was used.
- Show dashboard widgets only when there is enough data.
- Let users customize what they see.
- Remember goals and personal context.
- Be explicit when data is incomplete or stale.
- Keep finance answers source-backed and calm.

## PennyLet's Different Lane

PennyLet should avoid competing as a high-end connected-account financial assistant. Its stronger lane is:

- local-first daily money clarity;
- no bank login;
- no old data cleanup;
- useful from today's balance;
- explainable Safe Until Payday from counted local inputs;
- optional CSV import;
- optional AI with local fallback;
- simple watch, budget, subscription, and goal tools.

## V3 App Changes

- Strengthened onboarding around "tell PennyLet what you have now."
- Added no-bank-login, no-old-cleanup, and explainable-local-number cues.
- Added Help answers for no old history, AI data scope, and missing data.
- Updated the empty dashboard state to sell "ready from today" instead of just saying no transactions exist.
- Added an always-included promise card to the Upgrade screen so Pro upsells do not hide the free/local core.
- Tightened AI rules so responses stay based on saved PennyLet data and do not suggest bank connections or credentials.
- Shortened the user-facing AI wait before local fallback, making local fallback feel like a feature instead of a failure.
- Added a V3 polish pass so money fields do not wrap currency labels, Review Queue suggestions show concrete local transaction details, Settings feels closer to iOS Settings, and Pro remains visually gold instead of inheriting the active theme.
- Added a regression test that keeps Safe Until Payday grounded in money the user has today. The next paycheck is shown for timing, but is not counted as spendable before payday.

## V2 Revert Point

- Backup folder: `.codex-backups/pre-pennylet-v3-20260601-194515/`
- Backup branch: `codex/backup-v2-before-v3-20260601-194515`
- V3 branch: `codex/pennylet-v3-differentiation-20260601-194515`

See `REVERT_PENNYLET_V3.md` for exact rollback steps.
