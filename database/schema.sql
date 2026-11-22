-- =====================================================================
--  BLUE THREAD — CONNECTED OCEAN   (Personne C)
--  À coller tel quel dans Supabase > SQL Editor > New query > Run.
--  Peut être relancé sans risque (idempotent).
--
--  Sécurité : les tables ne sont PAS lisibles ni modifiables avec la clé
--  publique. Le jeu passe uniquement par deux fonctions limitées :
--    - submit_sort(...)     : enregistre un tri, le serveur décide s'il est juste
--    - get_ocean_stats()    : renvoie uniquement des chiffres agrégés
-- =====================================================================

-- 1) Catalogue : le BON bac de chaque objet est stocké côté serveur
create table if not exists public.item_catalog (
  item_id        text primary key,
  correct_bin    text not null check (correct_bin in ('cotton','polyester','pet','mixed','reject')),
  material_label text not null
);

insert into public.item_catalog (item_id, correct_bin, material_label) values
  ('cotton_shirt',        'cotton',    'T-shirt en coton'),
  ('jeans',               'cotton',    'Jean'),
  ('fleece',              'polyester', 'Polaire'),
  ('sport_leggings',      'polyester', 'Legging de sport'),
  ('pet_bottle',          'pet',       'Bouteille PET'),
  ('pet_tray',            'pet',       'Barquette PET'),
  ('blended_sweater',     'mixed',     'Pull en fibres mélangées'),
  ('blended_socks',       'mixed',     'Chaussettes mélangées'),
  ('oily_bottle',         'reject',    'Bouteille souillée d''huile'),
  ('paint_stained_shirt', 'reject',    'Chemise tachée de peinture')
on conflict (item_id) do update
  set correct_bin = excluded.correct_bin,
      material_label = excluded.material_label;

-- 2) Événements de tri (une ligne par décision du joueur)
create table if not exists public.sort_events (
  id           bigint generated always as identity primary key,
  session_id   text        not null check (char_length(session_id) between 4 and 64),
  item_id      text        not null references public.item_catalog(item_id),
  selected_bin text        not null check (selected_bin in ('cotton','polyester','pet','mixed','reject')),
  reaction_ms  integer     not null check (reaction_ms between 0 and 600000),
  is_correct   boolean     not null,                 -- calculé par le serveur, jamais par le navigateur
  created_at   timestamptz not null default now()    -- horodaté par la base, jamais par le navigateur
);
create index if not exists sort_events_created_idx on public.sort_events (created_at);
create index if not exists sort_events_session_idx on public.sort_events (session_id, created_at);

-- 3) Remise à zéro de l'océan avant la démo jury (on garde l'historique)
create table if not exists public.ocean_resets (
  id       bigint generated always as identity primary key,
  reset_at timestamptz not null default now()
);

-- 4) Verrouillage : aucune lecture/écriture directe avec les clés publiques
alter table public.item_catalog enable row level security;
alter table public.sort_events  enable row level security;
alter table public.ocean_resets enable row level security;
revoke all on public.item_catalog, public.sort_events, public.ocean_resets from anon, authenticated;

-- 5) RPC : enregistrer un tri (correction faite sur le serveur)
create or replace function public.submit_sort(
  p_session_id   text,
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

  select correct_bin into v_correct_bin from item_catalog where item_id = p_item_id;
  if v_correct_bin is null then
    raise exception 'unknown item_id: %', p_item_id using errcode = '22023';
  end if;

  if p_selected_bin not in ('cotton','polyester','pet','mixed','reject') then
    raise exception 'unknown bin: %', p_selected_bin using errcode = '22023';
  end if;

  -- Anti-spam simple : 5 envois maximum par seconde et par session
  select count(*) into v_recent
    from sort_events
   where session_id = p_session_id
     and created_at > now() - interval '1 second';
  if v_recent >= 5 then
    raise exception 'too many requests' using errcode = '22023';
  end if;

  v_is_correct := (p_selected_bin = v_correct_bin);

  insert into sort_events (session_id, item_id, selected_bin, reaction_ms, is_correct)
  values (p_session_id, p_item_id, p_selected_bin,
          greatest(0, least(coalesce(p_reaction_ms, 0), 600000)), v_is_correct);

  return json_build_object('is_correct', v_is_correct, 'correct_bin', v_correct_bin);
end;
$$;

-- 6) RPC : statistiques agrégées pour l'océan partagé et le panneau jury
create or replace function public.get_ocean_stats()
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
    select e.* from sort_events e, since where e.created_at >= since.t
  ),
  agg as (
    select count(*)                                          as total,
           count(*) filter (where is_correct)                as correct,
           count(distinct session_id)                        as players,
           coalesce(round(avg(reaction_ms) filter (where is_correct)), 0) as avg_ms
      from ev
  ),
  errs as (
    select c.material_label, count(*) as n
      from ev join item_catalog c using (item_id)
     where not ev.is_correct
     group by c.material_label
     order by n desc
     limit 5
  )
  select json_build_object(
    'total_events',      agg.total,
    'correct_events',    agg.correct,
    'wrong_events',      agg.total - agg.correct,
    'accuracy',          case when agg.total > 0 then round(100.0 * agg.correct / agg.total, 1) else 0 end,
    'ocean_percent',     least(100, agg.correct * 4),        -- +4 % par tri juste vérifié, plafond 100 %
    'players',           agg.players,
    'avg_reaction_ms',   agg.avg_ms,
    'errors_by_material', coalesce((select json_object_agg(material_label, n) from errs), '{}'::json),
    'server_time',       now()
  )
  from agg;
$$;

-- 7) Seules ces deux fonctions sont appelables avec la clé publique
revoke all on function public.submit_sort(text, text, text, integer) from public;
revoke all on function public.get_ocean_stats() from public;
grant execute on function public.submit_sort(text, text, text, integer) to anon, authenticated;
grant execute on function public.get_ocean_stats() to anon, authenticated;

-- ---------------------------------------------------------------------
--  Avant la démo jury, pour repartir d'un océan à 0 % :
--    insert into public.ocean_resets default values;
--  Pour voir les derniers événements (preuve « vraies données ») :
--    select * from public.sort_events order by created_at desc limit 20;
-- ---------------------------------------------------------------------
