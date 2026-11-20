# Backend plan

The app talks to the server only through the `BackendService` protocol (`LiftBros/Core/Services/BackendService.swift`).
`MockBackendService` implements it in memory, using a generated community of ~300 lifters across 13 UK gyms.
That lets every screen work today without a server.

To go live, implement `BackendService` against a real backend and pass it to `AppStore(backend:)` in
`LiftBrosApp.swift`. No UI changes are needed.

## Suggested stack

[Supabase](https://supabase.com) (Postgres, Auth with Sign in with Apple, Storage and Row Level Security) fits well.
Firebase works too.

## Schema (Postgres)

```sql
create table gyms (
  id text primary key,
  name text not null,
  city text not null,
  nation text not null check (nation in ('england','scotland','wales','northernIreland')),
  postcode_area text not null,
  join_code text unique              -- for QR-code joining at reception
);

create table profiles (
  id uuid primary key references auth.users,
  display_name text not null,
  username text unique not null,
  gym_id text references gyms,
  sex text not null,
  bodyweight_kg numeric not null,
  body_fat_percent numeric,
  height_cm numeric,
  birth_year int,
  years_lifting numeric,
  progress_audience text not null default 'everyone',   -- everyone | gymMembers | onlyMe
  body_stats_audience text not null default 'onlyMe',
  show_on_leaderboards boolean not null default true
);

create table lift_sets (
  id uuid primary key,
  lifter_id uuid not null references profiles on delete cascade,
  gym_id text not null references gyms,
  exercise_id text not null,
  weight_kg numeric not null,
  reps int not null,
  bodyweight_kg numeric not null,
  performed_at timestamptz not null,
  verification text not null default 'unverified',     -- unverified | pending | verified | rejected
  proof_path text,                                      -- Storage object, private bucket
  e1rm_kg numeric generated always as (...) stored,     -- or compute in a view
  flag_count int not null default 0
);
create index on lift_sets (exercise_id, gym_id);

create table flags (
  set_id uuid references lift_sets on delete cascade,
  reporter_id uuid references profiles,
  reason text not null,
  created_at timestamptz default now(),
  primary key (set_id, reporter_id)          -- one flag per person per lift
);

create table verification_reviews (
  set_id uuid primary key references lift_sets on delete cascade,
  reviewer_id uuid,                          -- moderator or gym staff (B2B)
  outcome text not null,                     -- verified | rejected
  notes text,
  reviewed_at timestamptz default now()
);
```

Leaderboards should be served from a materialized view (best set per lifter per exercise), refreshed on insert,
using the same rules as `LeaderboardEngine`:

- Rank by best estimated 1RM from 1–12 reps (Epley below 10 reps, Brzycki from 10).
- The pound-for-pound score uses the bodyweight recorded with the set.
- Unverified sets with 3 or more flags are hidden.

`LeaderboardEngine` is fully unit-tested and can serve as the reference implementation.

## Verification pipeline

1. The app uploads the video to a **private** Storage bucket and sets the set to `pending`.
2. Automated checks: video length, the video's metadata date matches the set, and (later) AI rep counting.
3. Human review. Moderators at first; gym staff under B2B. The reviewer writes `verification_reviews` and updates
   `lift_sets.verification`.
4. A push notification tells the lifter the outcome.

## Privacy and RLS rules

- `profiles` body stats are readable only when `body_stats_audience` allows the viewer.
- `lift_sets` history is readable when `progress_audience` allows. The leaderboard view exposes only the best set,
  and only when `show_on_leaderboards` is true.
- Proof videos are readable only by the owner and reviewers.
