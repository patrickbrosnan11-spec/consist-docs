-- Consist: Minimal MVP Data Model (Postgres + RLS)
-- Note: Add indexes, constraints, triggers as appropriate.

CREATE TABLE users (
  id uuid PRIMARY KEY,
  email text UNIQUE NOT NULL,
  display_name text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE families (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  creator_user_id uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE family_members (
  family_id uuid REFERENCES families(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role text CHECK (role IN ('admin','caregiver','member')) NOT NULL DEFAULT 'member',
  display_name text,
  preferences_json jsonb DEFAULT '{}',
  PRIMARY KEY (family_id, user_id)
);

CREATE TABLE calendars (
  id uuid PRIMARY KEY,
  family_id uuid REFERENCES families(id) ON DELETE CASCADE,
  name text NOT NULL
);

CREATE TABLE events (
  id uuid PRIMARY KEY,
  calendar_id uuid REFERENCES calendars(id) ON DELETE CASCADE,
  family_id uuid REFERENCES families(id) ON DELETE CASCADE,
  type text CHECK (type IN ('oneoff','routine')) NOT NULL,
  title text NOT NULL,
  start_ts timestamptz NOT NULL,
  end_ts timestamptz NOT NULL,
  recurrence_rule text, -- iCal RRULE for routines
  tags text[] DEFAULT '{}',
  sensory_level text, -- e.g., 'low','medium','high'
  energy_level text,  -- e.g., 'low-spoons','regular'
  flexible boolean DEFAULT true,
  buffer_before_min int DEFAULT 0
);

CREATE TABLE assignments (
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  member_user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (event_id, member_user_id)
);

CREATE TABLE check_ins (
  id uuid PRIMARY KEY,
  event_id uuid REFERENCES events(id) ON DELETE SET NULL,
  member_user_id uuid REFERENCES users(id),
  status text CHECK (status IN ('completed','partial','skipped')) NOT NULL,
  reason text, -- e.g., 'overwhelm','sensory','schedule-clash'
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE rewards (
  id uuid PRIMARY KEY,
  family_id uuid REFERENCES families(id) ON DELETE CASCADE,
  name text NOT NULL,
  cost_points int NOT NULL CHECK (cost_points > 0),
  limited boolean DEFAULT false
);

CREATE TABLE wallets (
  member_user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance_points int NOT NULL DEFAULT 0
);

CREATE TABLE transactions (
  id uuid PRIMARY KEY,
  member_user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  delta int NOT NULL,
  reason text,
  related_check_in_id uuid REFERENCES check_ins(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE notifications (
  id uuid PRIMARY KEY,
  member_user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL,
  payload_json jsonb NOT NULL,
  scheduled_ts timestamptz,
  sent_ts timestamptz
);

CREATE TABLE audit_log (
  id uuid PRIMARY KEY,
  actor_user_id uuid REFERENCES users(id),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  meta jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Recommend creating RLS policies per table based on family membership.

-- ========================================================
-- Rewards: Redeemables (caregiver-defined items) & Redemptions (point spending)
-- ========================================================

create table if not exists redeemables (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  title text not null,
  description text,
  points_cost integer not null check (points_cost >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_redeemables_family on redeemables(family_id);

alter table redeemables enable row level security;

create policy "redeemables_select_if_member"
  on redeemables for select using (
    exists (
      select 1 from family_members fm
      where fm.family_id = redeemables.family_id
        and fm.user_id = auth.uid()
    )
  );

create policy "redeemables_write_if_member"
  on redeemables for all using (
    exists (
      select 1 from family_members fm
      where fm.family_id = redeemables.family_id
        and fm.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from family_members fm
      where fm.family_id = redeemables.family_id
        and fm.user_id = auth.uid()
    )
  );

-- ========================================================
-- Redemptions: Actual spending events
-- ========================================================

create table if not exists redemptions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  member_user_id uuid not null,  -- who receives the reward
  redeemable_id uuid not null references redeemables(id),
  points_spent integer not null check (points_spent >= 0),
  notes text,
  created_by_user_id uuid not null,  -- actor (may be caregiver)
  created_at timestamptz not null default now()
);

create index if not exists idx_redemptions_family on redemptions(family_id);
create index if not exists idx_redemptions_member on redemptions(member_user_id);

alter table redemptions enable row level security;

create policy "redemptions_select_if_member"
  on redemptions for select using (
    exists (
      select 1 from family_members fm
      where fm.family_id = redemptions.family_id
        and fm.user_id = auth.uid()
    )
  );

create policy "redemptions_write_if_member"
  on redemptions for insert using (
    exists (
      select 1 from family_members fm
      where fm.family_id = redemptions.family_id
        and fm.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from family_members fm
      where fm.family_id = redemptions.family_id
        and fm.user_id = auth.uid()
    )
  );

-- ========================================================
-- Balance calculation
-- ========================================================
-- Wallet balance is derived from transactions:
--   Credits from check-ins (completed/partial)
--   Debits from redemptions (negative values)
-- No negative balances allowed at redemption time.
