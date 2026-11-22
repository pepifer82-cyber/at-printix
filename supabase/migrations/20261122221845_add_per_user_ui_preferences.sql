create table if not exists public.user_ui_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  preference_key text not null check (char_length(preference_key) between 1 and 120),
  preference_value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, preference_key)
);

alter table public.user_ui_preferences enable row level security;

grant select, insert, update, delete on table public.user_ui_preferences to authenticated;

drop policy if exists "Users can read their own UI preferences" on public.user_ui_preferences;
create policy "Users can read their own UI preferences"
  on public.user_ui_preferences for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own UI preferences" on public.user_ui_preferences;
create policy "Users can insert their own UI preferences"
  on public.user_ui_preferences for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own UI preferences" on public.user_ui_preferences;
create policy "Users can update their own UI preferences"
  on public.user_ui_preferences for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own UI preferences" on public.user_ui_preferences;
create policy "Users can delete their own UI preferences"
  on public.user_ui_preferences for delete
  to authenticated
  using ((select auth.uid()) = user_id);
