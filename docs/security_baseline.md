# Security & Privacy Baseline

## Data Minimization
- Store only what is necessary (nicknames for kids are allowed; legal names optional).
- Avoid transmitting sensitive content to third-party LLMs unless strictly necessary and anonymized.

## Access Control
- Postgres Row Level Security (RLS) on every table with `family_id`.
- Policies ensure `auth.uid()` must be a member of the associated family for any read/write.

### Example RLS Policy (pseudo-SQL)
```sql
-- families table
ALTER TABLE families ENABLE ROW LEVEL SECURITY;

CREATE POLICY families_is_member
ON families
USING (
  id IN (
    SELECT family_id FROM family_members WHERE user_id = auth.uid()
  )
);

-- Example WITH CHECK for inserts
CREATE POLICY families_insert
ON families
FOR INSERT
WITH CHECK (creator_user_id = auth.uid());
```

## Secrets
- Use platform secret stores (e.g., Netlify/Cloudflare/Expo EAS/Server) — never commit secrets.
- Rotate API keys. Do not log secrets or PII.

## Transport & Storage
- TLS for all network communication.
- Encrypt data at rest (managed Postgres provider) and backups.

## Audit Logging
- Append-only `audit_log` for security-relevant actions (invites, role changes, reward redemptions).
- Include actor, entity, action, timestamp.

## Push Notifications
- Do not include sensitive schedule details in payloads.
- Use opaque IDs and fetch details on open.

## Children & Consent
- Kid accounts are created/managed by caregivers; no peer-to-peer messaging.
- Exports (JSON) and account deletion must be available.
