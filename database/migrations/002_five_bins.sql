-- =====================================================================
--  BLUE THREAD: THE LAST BLUE — migration 002 : les 5 bacs
--  ADDITIVE et IDEMPOTENTE : ne supprime et ne modifie AUCUNE table existante.
--  Les anciennes tables (item_catalog, sort_events) et les anciennes
--  fonctions (submit_sort, get_ocean_stats) restent intactes.
--  À coller dans Supabase > SQL Editor > New query > Run (relançable).
-- =====================================================================

create table if not exists public.item_catalog_v2 (
  item_id        text primary key,
  correct_bin    text not null check (correct_bin in ('paper','textile','pet','residual','special')),
  material_label text not null
);

insert into public.item_catalog_v2 (item_id, correct_bin, material_label) values
  ('newspaper', 'paper', 'Old newspaper'),
  ('cardboard_box', 'paper', 'Cardboard box'),
  ('paper_bag', 'paper', 'Paper bag'),
  ('magazine', 'paper', 'Magazine'),
  ('office_paper', 'paper', 'Office paper'),
  ('egg_carton', 'paper', 'Egg carton'),
  ('tshirt', 'textile', 'Cotton T-shirt'),
  ('wool_sweater', 'textile', 'Wool sweater'),
  ('jeans', 'textile', 'Old jeans'),
  ('scarf', 'textile', 'Knitted scarf'),
  ('socks', 'textile', 'Pair of socks'),
  ('bed_sheet', 'textile', 'Bed sheet'),
  ('water_bottle', 'pet', 'Water bottle (PET)'),
  ('soda_bottle', 'pet', 'Soda bottle (PET)'),
  ('juice_bottle', 'pet', 'Juice bottle (PET)'),
  ('pet_tray', 'pet', 'Clear food tray (PET)'),
  ('pet_jar', 'pet', 'PET jar'),
  ('chip_bag', 'residual', 'Chip bag (multilayer)'),
  ('greasy_pizza_box', 'residual', 'Greasy pizza box'),
  ('cigarette_butt', 'residual', 'Cigarette butt'),
  ('dirty_tissue', 'residual', 'Used tissue'),
  ('broken_mug', 'residual', 'Broken ceramic mug'),
  ('battery', 'special', 'Battery'),
  ('paint_can', 'special', 'Paint can'),
  ('old_phone', 'special', 'Old phone'),
  ('spray_can', 'special', 'Aerosol can'),
  ('medicine', 'special', 'Expired medicine')
on conflict (item_id) do update
  set correct_bin = excluded.correct_bin,
      material_label = excluded.material_label;

create table if not exists public.sort_events_v2 (
  id           bigint generated always as identity primary key,
  session_id   text        not null check (char_length(session_id) between 4 and 64),
  level_id     text        not null check (level_id in ('gabes','skhira','sidi_mansour','demo')),
  action_type  text        not null default 'sort' check (action_type in ('sort','collect','step','level_complete')),
  item_id      text        references public.item_catalog_v2(item_id),
  selected_bin text        check (selected_bin in ('paper','textile','pet','residual','special')),
  reaction_ms  integer     not null default 0 check (reaction_ms between 0 and 600000),
  is_correct   boolean     not null,                 -- calculé par le serveur
  created_at   timestamptz not null default now()    -- horodaté par la base
);
create index if not exists sort_events_v2_created_idx on public.sort_events_v2 (created_at);
create index if not exists sort_events_v2_session_idx on public.sort_events_v2 (session_id, created_at);

alter table public.item_catalog_v2 enable row level security;
alter table public.sort_events_v2  enable row level security;
revoke all on public.item_catalog_v2, public.sort_events_v2 from anon, authenticated;

create or replace function public.submit_sort_v2(
  p_session_id   text,
  p_level_id     text,
  p_item_id      text,
  p_selected_bin text,
  p_reaction_ms  integer
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_correct_bin text;
  v_is_correct  boolean;
  v_recent      integer;
begin
  if p_session_id is null or char_length(p_session_id) not between 4 and 64 then
    raise exception 'invalid session_id' using errcode = '22023';
  end if;
  if p_level_id not in ('gabes','skhira','sidi_mansour','demo') then
    raise exception 'unknown level: %', p_level_id using errcode = '22023';
  end if;
  select correct_bin into v_correct_bin from item_catalog_v2 where item_id = p_item_id;
  if v_correct_bin is null then
    raise exception 'unknown item_id: %', p_item_id using errcode = '22023';
  end if;
  if p_selected_bin not in ('paper','textile','pet','residual','special') then
    raise exception 'unknown bin: %', p_selected_bin using errcode = '22023';
  end if;
  select count(*) into v_recent from sort_events_v2
   where session_id = p_session_id and created_at > now() - interval '1 second';
  if v_recent >= 5 then
    raise exception 'too many requests' using errcode = '22023';
  end if;
  v_is_correct := (p_selected_bin = v_correct_bin);
  insert into sort_events_v2 (session_id, level_id, action_type, item_id, selected_bin, reaction_ms, is_correct)
  values (p_session_id, p_level_id, 'sort', p_item_id, p_selected_bin,
          greatest(0, least(coalesce(p_reaction_ms, 0), 600000)), v_is_correct);
  return json_build_object('is_correct', v_is_correct, 'correct_bin', v_correct_bin);
end;
$$;

-- Fin de niveau : comptée côté serveur (une seule fois par session et par niveau)
create or replace function public.complete_level_v2(p_session_id text, p_level_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_done integer;
begin
  if p_session_id is null or char_length(p_session_id) not between 4 and 64 then
    raise exception 'invalid session_id' using errcode = '22023';
  end if;
  if p_level_id not in ('gabes','skhira','sidi_mansour','demo') then
    raise exception 'unknown level: %', p_level_id using errcode = '22023';
  end if;
  select count(*) into v_done from sort_events_v2
   where session_id = p_session_id and level_id = p_level_id and action_type = 'level_complete';
  if v_done = 0 then
    insert into sort_events_v2 (session_id, level_id, action_type, is_correct)
    values (p_session_id, p_level_id, 'level_complete', true);
  end if;
  return json_build_object('recorded', v_done = 0);
end;
$$;

create or replace function public.get_ocean_stats_v2()
returns json
language sql
stable
security definer
set search_path = public
as $$
  with since as (
    select coalesce(max(reset_at), 'epoch'::timestamptz) as t from ocean_resets
  ),
  ev as (
    select e.* from sort_events_v2 e, since where e.created_at >= since.t
  ),
  agg as (
    select count(*) filter (where action_type = 'sort')                       as total,
           count(*) filter (where action_type = 'sort' and is_correct)        as correct,
           count(*) filter (where action_type = 'level_complete')             as levels,
           count(distinct session_id)                                         as players,
           coalesce(round(avg(reaction_ms) filter (where action_type = 'sort' and is_correct)), 0) as avg_ms
      from ev
  ),
  errs as (
    select c.material_label, count(*) as n
      from ev join item_catalog_v2 c using (item_id)
     where ev.action_type = 'sort' and not ev.is_correct
     group by c.material_label order by n desc limit 5
  ),
  bins as (
    select selected_bin, count(*) as n from ev
     where action_type = 'sort' and is_correct group by selected_bin
  )
  select json_build_object(
    'total_events',       agg.total,
    'correct_events',     agg.correct,
    'wrong_events',       agg.total - agg.correct,
    'levels_completed',   agg.levels,
    'accuracy',           case when agg.total > 0 then round(100.0 * agg.correct / agg.total, 1) else 0 end,
    'ocean_percent',      least(100, agg.correct * 2 + agg.levels * 5),   -- +2 % par tri juste, +5 % par niveau fini
    'players',            agg.players,
    'avg_reaction_ms',    agg.avg_ms,
    'errors_by_material', coalesce((select json_object_agg(material_label, n) from errs), '{}'::json),
    'correct_by_bin',     coalesce((select json_object_agg(selected_bin, n) from bins), '{}'::json),
    'schema',             'v2',
    'server_time',        now()
  )
  from agg;
$$;

revoke all on function public.submit_sort_v2(text, text, text, text, integer) from public;
revoke all on function public.complete_level_v2(text, text) from public;
revoke all on function public.get_ocean_stats_v2() from public;
grant execute on function public.submit_sort_v2(text, text, text, text, integer) to anon, authenticated;
grant execute on function public.complete_level_v2(text, text) to anon, authenticated;
grant execute on function public.get_ocean_stats_v2() to anon, authenticated;

-- Vérification rapide après exécution :
--   select public.get_ocean_stats_v2();
-- Remise à zéro avant le jury (garde l'historique, commune v1/v2) :
--   insert into public.ocean_resets default values;
