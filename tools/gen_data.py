"""Single source of truth for items -> scripts/data/GameData.gd catalogue + database/migrations/002_five_bins.sql"""
import json

BINS = [
    # id, label, color (r,g,b), icon
    ("paper", "PAPER", (0.16, 0.42, 0.85), "res://assets/icons/bin_paper.png"),
    ("textile", "TEXTILE", (0.52, 0.26, 0.80), "res://assets/icons/bin_textile.png"),
    ("pet", "PET", (0.95, 0.78, 0.12), "res://assets/icons/bin_pet.png"),
    ("residual", "RESIDUAL", (0.24, 0.25, 0.27), "res://assets/icons/bin_residual.png"),
    ("special", "SPECIAL", (0.86, 0.17, 0.15), "res://assets/icons/bin_special.png"),
]

# id, bin, label, shape, color, tip shown after a wrong sort
# (objets triables : présents aussi dans le catalogue serveur item_catalog_v2)
ITEMS = [
    ("newspaper", "paper", "Old newspaper", "sheet", (0.86, 0.84, 0.77), "Clean, dry paper goes in the blue PAPER bin."),
    ("cardboard_box", "paper", "Cardboard box", "box", (0.66, 0.50, 0.32), "Flattened cardboard is paper fibre: blue PAPER bin."),
    ("paper_bag", "paper", "Paper bag", "bag", (0.74, 0.60, 0.42), "A clean paper bag is recyclable paper."),
    ("magazine", "paper", "Magazine", "sheet", (0.88, 0.42, 0.50), "Glossy magazines are still paper: blue PAPER bin."),
    ("office_paper", "paper", "Office paper", "stack", (0.96, 0.96, 0.94), "Office paper is high-quality fibre: blue PAPER bin."),
    ("egg_carton", "paper", "Egg carton", "box", (0.70, 0.68, 0.62), "Moulded egg cartons are paper pulp."),
    ("tshirt", "textile", "Cotton T-shirt", "tshirt", (0.92, 0.92, 0.88), "Clothes, even worn out, go in the purple TEXTILE bin."),
    ("wool_sweater", "textile", "Wool sweater", "sweater", (0.58, 0.24, 0.30), "Wool can be unravelled and re-spun: TEXTILE bin."),
    ("jeans", "textile", "Old jeans", "pants", (0.24, 0.34, 0.60), "Denim is cotton: purple TEXTILE bin."),
    ("scarf", "textile", "Knitted scarf", "scarf", (0.20, 0.48, 0.80), "Knitted fabric is textile, even with holes."),
    ("socks", "textile", "Pair of socks", "sock", (0.30, 0.62, 0.56), "Single socks are welcome in the TEXTILE bin."),
    ("bed_sheet", "textile", "Bed sheet", "cloth", (0.86, 0.80, 0.90), "Household linen is textile."),
    ("water_bottle", "pet", "Water bottle (PET)", "bottle", (0.62, 0.86, 1.00), "Clear PET bottles go in the yellow PET bin."),
    ("soda_bottle", "pet", "Soda bottle (PET)", "bottle", (0.40, 0.84, 0.50), "Coloured PET bottles are still PET: yellow bin."),
    ("juice_bottle", "pet", "Juice bottle (PET)", "bottle", (1.00, 0.66, 0.24), "Empty PET juice bottles go in the yellow bin."),
    ("pet_tray", "pet", "Clear food tray (PET)", "tray", (0.80, 0.92, 0.98), "Clear PET trays are recyclable: yellow PET bin."),
    ("pet_jar", "pet", "PET jar", "jar", (0.76, 0.90, 0.96), "Clean PET jars go in the yellow PET bin."),
    ("chip_bag", "residual", "Chip bag (multilayer)", "pouch", (0.80, 0.82, 0.86), "Metallised multilayer film cannot be recycled: RESIDUAL."),
    ("greasy_pizza_box", "residual", "Greasy pizza box", "pizza", (0.70, 0.52, 0.32), "Grease ruins paper recycling: RESIDUAL bin."),
    ("cigarette_butt", "residual", "Cigarette butt", "butt", (0.95, 0.70, 0.40), "Butts are toxic and not recyclable: RESIDUAL."),
    ("dirty_tissue", "residual", "Used tissue", "crumple", (0.94, 0.94, 0.92), "Used tissues are soiled: RESIDUAL bin."),
    ("broken_mug", "residual", "Broken ceramic mug", "mug", (0.86, 0.36, 0.30), "Ceramic is not glass and not recyclable here: RESIDUAL."),
    ("battery", "special", "Battery", "battery", (0.20, 0.22, 0.25), "Batteries leak heavy metals: red SPECIAL bin."),
    ("paint_can", "special", "Paint can", "can", (0.80, 0.80, 0.84), "Paint is hazardous: red SPECIAL bin."),
    ("old_phone", "special", "Old phone", "phone", (0.12, 0.13, 0.15), "Electronics contain metals and batteries: SPECIAL."),
    ("spray_can", "special", "Aerosol can", "spray", (0.90, 0.30, 0.30), "Pressurised cans are hazardous: SPECIAL bin."),
    ("medicine", "special", "Expired medicine", "blister", (0.92, 0.92, 0.96), "Medicines must never reach the sea: SPECIAL bin."),
]

# Objets de collecte uniquement (recettes et objets pièges) : jamais envoyés au serveur,
# donc absents de la migration SQL (le catalogue serveur reste inchangé).
COLLECT_ONLY = [
    ("notebook_pages", "paper", "Notebook pages", "stack", (0.97, 0.96, 0.90), "Notebook pages are clean paper: perfect for pulp."),
    ("paper_letters", "paper", "Old paper letters", "envelope", (0.93, 0.88, 0.76), "Letters are paper fibre, ready for a second life."),
    ("knitted_hat", "textile", "Knitted hat", "hat", (0.80, 0.30, 0.28), "A knitted hat can be unravelled into yarn."),
    ("cardigan", "textile", "Knitted cardigan", "cardigan", (0.36, 0.52, 0.42), "A knitted cardigan gives long, reusable yarn."),
    ("leftover_yarn", "textile", "Leftover yarn", "yarn", (0.22, 0.52, 0.92), "Leftover yarn goes straight to winding."),
    ("lemonade_bottle", "pet", "Lemonade bottle (PET)", "bottle", (0.95, 0.92, 0.55), "Clear PET bottle: code 1, ready to recycle."),
    ("sparkling_bottle", "pet", "Sparkling water bottle (PET)", "bottle", (0.55, 0.80, 0.95), "PET beverage bottle: code 1."),
    ("metal_can", "none", "Metal drink can", "drinkcan", (0.78, 0.80, 0.84), "A metal can is not part of this recipe: metal goes to metal recycling, it will never become pulp, yarn or PET."),
    ("broken_toy", "none", "Broken plastic toy", "toy", (0.95, 0.45, 0.20), "A broken toy mixes plastics and metal: it cannot enter this recipe."),
    ("plastic_container", "none", "Plastic food container", "container", (0.95, 0.60, 0.70), "A plastic tub is not a textile: it cannot be knitted again."),
    ("glass_bottle", "none", "Glass bottle", "glassbottle", (0.30, 0.62, 0.36), "Glass is not PET: it melts at a much higher temperature and has its own recycling."),
    ("paper_packaging", "none", "Paper packaging", "packaging", (0.80, 0.66, 0.46), "Paper packaging is not PET: it belongs to the paper stream, not this recipe."),
]

out = []
out.append('class_name GameData')
out.append('## Generated by tools/gen_data.py — single source of truth shared with database/migrations/002_five_bins.sql')
out.append('')
out.append('const BIN_ORDER := ["paper", "textile", "pet", "residual", "special"]')
out.append('const BINS := {')
for b, lab, c, ic in BINS:
    out.append(f'\t"{b}": {{"label": "{lab}", "color": Color({c[0]}, {c[1]}, {c[2]}), "icon": "{ic}"}},')
out.append('}')
out.append('')
# Nom et modèle affichés côté client seulement (l'identifiant et le bac
# restent ceux du catalogue serveur : la migration SQL ne change pas).
DISPLAY = {"office_paper": ("Old notebook", "notebook", "A paper notebook is clean fibre: blue PAPER bin."),
           "broken_mug": ("Broken mug", "mug", "Broken ceramic cannot be recycled here: dark RESIDUAL bin."),
           "battery": ("Used battery", "battery", "Used batteries leak heavy metals: red SPECIAL bin, never the trash.")}
out.append('const ITEMS := {')
for i, b, lab, sh, c, tip in ITEMS + COLLECT_ONLY:
    if i in DISPLAY:
        lab, sh, tip = DISPLAY[i]
    out.append(f'\t"{i}": {{"bin": "{b}", "label": "{lab}", "shape": "{sh}", "color": Color({c[0]}, {c[1]}, {c[2]}), "tip": "{tip}"}},')
out.append('}')
import os
levels_part = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'levels_part.gd.txt')).read()
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', 'data', 'GameData.gd'), 'w').write('\n'.join(out) + '\n' + levels_part)

sql = []
sql.append("""-- =====================================================================
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

insert into public.item_catalog_v2 (item_id, correct_bin, material_label) values""")
rows = []
for i, b, lab, sh, c, tip in ITEMS:
    rows.append("  ('%s', '%s', '%s')" % (i, b, lab.replace("'", "''")))
sql.append(',\n'.join(rows))
sql.append("""on conflict (item_id) do update
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
""")
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'database', 'migrations', '002_five_bins.sql'), 'w').write('\n'.join(sql))
print(len(ITEMS), 'items')
