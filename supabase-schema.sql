-- Corat-Coret stores one complete app snapshot per authenticated user.
-- The browser sync client uses version for optimistic concurrency checks.
create table public.user_states (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null,
  version uuid not null default gen_random_uuid(),
  updated_at timestamptz not null default now(),
  constraint user_states_data_object check (
    jsonb_typeof(data) = 'object'
  ),
  constraint user_states_data_shape check (
    data ?& array['owner', 'onboarded', 'books', 'notes', 'trash', 'prefs', 'activeBookId']
    and
    jsonb_typeof(data -> 'owner') = 'string'
    and jsonb_typeof(data -> 'onboarded') = 'boolean'
    and jsonb_typeof(data -> 'books') = 'array'
    and jsonb_array_length(data -> 'books') between 1 and 1000
    and jsonb_typeof(data -> 'notes') = 'array'
    and jsonb_array_length(data -> 'notes') <= 50000
    and jsonb_typeof(data -> 'trash') = 'array'
    and jsonb_array_length(data -> 'trash') <= 50000
    and jsonb_typeof(data -> 'prefs') = 'object'
    and jsonb_typeof(data -> 'prefs' -> 'sound') = 'boolean'
    and jsonb_typeof(data -> 'prefs' -> 'night') = 'boolean'
    and (
      jsonb_typeof(data -> 'prefs' -> 'lastBackupAt') = 'number'
      or jsonb_typeof(data -> 'prefs' -> 'lastBackupAt') = 'null'
    )
    and (
      jsonb_typeof(data -> 'activeBookId') = 'string'
      or jsonb_typeof(data -> 'activeBookId') = 'null'
    )
  )
);

comment on table public.user_states is
  'Complete Corat-Coret snapshot, isolated to one Supabase Auth user.';
comment on column public.user_states.data is
  'Snapshot containing owner, onboarded, books, notes, trash, prefs, and activeBookId.';
comment on column public.user_states.version is
  'Optimistic concurrency token checked before a client overwrites a snapshot.';

alter table public.user_states enable row level security;

revoke all on table public.user_states from anon, authenticated;
grant usage on schema public to authenticated;
grant select, insert, update on table public.user_states to authenticated;

create policy "Users read own Corat-Coret state"
  on public.user_states
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users insert own Corat-Coret state"
  on public.user_states
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users update own Corat-Coret state"
  on public.user_states
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
