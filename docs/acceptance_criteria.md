# Acceptance Criteria (Key Features)

## Check‑ins
- Can record completed/partial/skipped with a single tap.
- When skipped, a reason is recorded from a predefined list.
- Recording a check‑in updates points (if configured) and audit log.

## Routine Composer
- Endpoint validates input against Zod schema.
- Returns valid JSON matching output schema; retries on parse failure.
- Generates steps with at least one alternative and at least one buffer.

## RLS
- A user outside a family cannot read or write that family's data.
- Tests cover SELECT/INSERT/UPDATE/DELETE denial for non‑members.

## Notifications
- Payloads contain only opaque IDs; details loaded on open.
- Snooze options: 15m, 1h, tomorrow.

Rewards Bank (v0)

Purpose: Members earn points from check-ins, caregivers define redeemables, and points can be spent on rewards — all in a dignity-first, non-punitive way.

Acceptance:

Balance is computed from transactions (credits from check-ins, debits from redemptions).

Redeemables are family-scoped, visible to all members, and can be created/edited by members in v0.

Redemptions:

Cannot exceed available points.

Are logged in transactions (negative value) and audit_log.

Can be made by the member or by a caregiver on their behalf.

UI tone:

Neutral phrasing (“You’re redeeming…”).

No streaks, no shame.

Encourages partial/micro-start contributions.

Security:

Server verifies membership before any DB access.

RLS ensures only family members can view/edit relevant data.

Audit:

All redemption and redeemable changes recorded in audit_log.