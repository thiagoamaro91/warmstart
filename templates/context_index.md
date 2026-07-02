# Context Index

Last updated: 2026-01-15 | Sessions: webapp - **Checkout flow rebuilt on new payment provider** (2026-01-15): Swapped the legacy payment SDK for the new provider's hosted checkout, fixed the cart-total rounding bug that had been reported since December, and added a retry path for declined cards. Prior: research - **Competitor pricing sweep completed** (2026-01-12): Pulled pricing pages for the five closest competitors, logged tier structure and discount patterns into `research/notes_v1.md`, flagged one competitor's usage-based model as worth a deeper look next session. Prior: ops - **Staging environment migrated to new host** (2026-01-08): Moved staging off the old shared box onto its own instance after repeated noisy-neighbor slowdowns; smoke tests green, DNS cutover done, old box scheduled for teardown.

## Active Workstreams
| Workstream | Status | Last touched | Blockers |
|------------|--------|---------------|----------|
| webapp | active | 2026-01-15 | waiting on design sign-off for the new checkout confirmation screen |
| research | active | 2026-01-12 | none |
| ops | parked | 2026-01-08 | old staging box teardown pending ticket approval |

## Hot Items (cross-workstream)
- 🔴 **webapp - Checkout retry path needs a load test before rollout (2026-01-15)**: The new decline-retry logic has not been exercised under concurrent load; want a synthetic load test before flipping the feature flag for all users. See `webapp/notes/checkout-retry_v1.md` for the current design.
- 🟡 **research - Usage-based competitor pricing worth a deeper pass (2026-01-12)**: One competitor's shift to usage-based tiers could be relevant to our own Q2 pricing review; notes so far are shallow, logged in `research/notes_v1.md`, needs a follow-up session.

## Recently Completed (auto-clears after 14 days)
<!-- disposable by design: this is what the hook truncates first at the 16KB cap -->
- [2026-01-15] **webapp - Checkout flow rebuilt on new payment provider**: Legacy SDK replaced, rounding bug fixed, retry path added; pending load test before full rollout.
- [2026-01-08] **ops - Staging environment migrated to new host**: Cutover complete, smoke tests passing, old box awaiting teardown.
