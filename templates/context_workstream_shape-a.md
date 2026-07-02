> When to use this shape
> Shape A is a running session log: reverse-chronological dated entries, each capturing what was tried, what was found, and what's still open. Reach for it on diagnostic or iterative technical work, debugging, tuning, anything where the value is in the trail of root-cause reasoning across sessions. This is a domain-driven choice, not an enforced one: if the same workstream turns into a pile of pending decisions and deliverables instead of a debugging trail, switch to Shape B (categorical buckets) instead.

# Context - webapp
Last updated: 2026-04-11 (checkout 500 traced to a stale cache key, fix deployed, monitoring for recurrence)

## Session 3 - checkout 500s under load (2026-04-11)
**Status**: COMPLETE
Root cause: the checkout service was reading a cached pricing token that outlived the promo window by roughly six minutes, so any request landing in that gap called a discount that no longer existed and the downstream payment call rejected it with a 500. Key insight: the error rate spiked in a tight band right after each promo ended, not randomly, which is what pointed at a cache TTL problem rather than a payment-provider issue.
Fix applied: shortened the pricing cache TTL to match the promo window exactly and added a hard invalidation call when a promo closes, instead of relying on TTL alone.
Deferred: the payment provider's error message for this case is generic ("invalid discount"), which cost real time; a follow-up ticket to ask them for a more specific error code is filed but not started.
Watch-items: confirm no 500s reappear over the next two promo cycles before calling this closed.

## Session 2 - reproduced the 500 locally (2026-04-08)
**Status**: COMPLETE
Spent the session getting a reliable local repro since the bug only showed up in production traffic. Found that forcing the promo to expire mid-session (via a manual clock override) reproduced it every time. That repro is what made Session 3's cache-TTL theory testable instead of a guess.

## Session 1 - initial triage from error alerts (2026-04-06)
**Status**: COMPLETE
Alert volume on checkout 500s crossed threshold overnight. First pass ruled out the obvious candidates (payment provider outage, deploy correlation, traffic spike) since none lined up with the error timestamps. Flagged the promo-window overlap as the next thing to check.

[reverse chronological; the domain drives each entry's shape]
