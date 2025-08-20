# API Shape

## Options
- **tRPC** for type‑safe RPC over HTTPS within Next.js routes.
- **REST** for mobile app if needed; keep route handlers with Zod validation.

## Conventions
- All inputs validated with Zod.
- Server enforces family scoping; never trust `family_id` from client without verifying membership.

## Example (pseudo tRPC)
```
family.get: ({ id }) => ensureMember(ctx.user, id) && db.family.findUnique({id})
event.create: ({ calendarId, ... }) => ensureFamily(ctx.user, calendarId) && db.event.create(...)
```

GET /api/rewards

Description: Returns balance info, available redeemables, and recent transactions.

Query params:

familyId (string, required)

memberUserId (string, optional — defaults to current actor)

Response:

{
  "balance": 5,
  "redeemables": [
    { "id": "...", "title": "Extra park time", "points_cost": 2, "description": "15 minutes" }
  ],
  "transactions": [
    { "id": "...", "delta": 2, "source": "check_in", "created_at": "2025-08-15T14:03:21Z" }
  ]
}


Rules:

Server enforces membership (ensureMember).

Only active redeemables are returned.

POST /api/redeem

Description: Spend points on a reward.

Body (Zod):

{
  "familyId": "uuid",
  "redeemableId": "uuid",
  "memberUserId": "uuid (optional)",
  "notes": "string (optional)"
}


Response:

{ "ok": true, "newBalance": 3 }


Rules:

Actor must be a member of familyId.

Reject if member’s balance < points_cost.

Creates a negative transaction, a redemption record, and an audit log entry.

POST /api/redeemables

Description: Create or update a redeemable.

Body (Zod):

{
  "familyId": "uuid",
  "title": "string",
  "description": "string (optional)",
  "pointsCost": "integer >= 0",
  "isActive": "boolean (optional)"
}


Response:

{ "ok": true, "redeemableId": "uuid" }


Rules:

Membership required.

v0 allows any member to create; later may restrict to caregivers.