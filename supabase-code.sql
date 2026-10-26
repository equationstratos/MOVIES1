-- Réserve « vu / aimé / commentaire » à la personne qui connaît le code.
-- À exécuter APRÈS supabase.sql, dans Supabase : SQL Editor → New query → coller → Run.
--
-- 1. Remplace TON_CODE ci-dessous par ton code (garde les apostrophes autour).
--    Supabase n'en garde qu'une version chiffrée : le code n'apparaît ni dans la page ni sur GitHub.
-- 2. Pour changer de code plus tard, relance ce script avec le nouveau code.

create extension if not exists pgcrypto with schema extensions;

-- Schéma privé : invisible depuis l'API publique
create schema if not exists private;
revoke all on schema private from anon, authenticated;

create table if not exists private.settings (
  id        int primary key default 1 check (id = 1),
  code_hash text not null
);

insert into private.settings (id, code_hash)
values (1, extensions.crypt('TON_CODE', extensions.gen_salt('bf')))
on conflict (id) do update set code_hash = excluded.code_hash;

-- Les visiteurs peuvent toujours lire la liste, mais plus la modifier directement
revoke insert, update, delete on public.film_marks from anon, authenticated;
drop policy if exists "ajout public" on public.film_marks;
drop policy if exists "modification publique" on public.film_marks;

-- Seul moyen de modifier la liste : cette fonction, qui vérifie le code.
-- Appelée sans film (p_imdb_id null), elle sert juste à vérifier le code.
create or replace function public.set_film_mark(
  p_code text,
  p_imdb_id text default null,
  p_seen boolean default false,
  p_liked boolean default false,
  p_note text default ''
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h text;
  cur public.film_marks;
begin
  select code_hash into h from private.settings where id = 1;
  if h is null or p_code is null or extensions.crypt(p_code, h) <> h then
    perform pg_sleep(1);  -- ralentit les essais au hasard
    raise exception 'Code incorrect' using errcode = '28P01';
  end if;

  if p_imdb_id is null then
    return;
  end if;
  if p_imdb_id !~ '^tt[0-9]{6,10}$' then
    raise exception 'Film inconnu';
  end if;

  select * into cur from public.film_marks where imdb_id = p_imdb_id;

  insert into public.film_marks (imdb_id, seen, liked, note, seen_at, liked_at, updated_at)
  values (
    p_imdb_id,
    p_seen,
    p_liked,
    left(coalesce(p_note, ''), 280),
    case when p_seen then coalesce(cur.seen_at, now()) end,
    case when p_liked then coalesce(cur.liked_at, now()) end,
    now()
  )
  on conflict (imdb_id) do update set
    seen = excluded.seen,
    liked = excluded.liked,
    note = excluded.note,
    seen_at = excluded.seen_at,
    liked_at = excluded.liked_at,
    updated_at = now();
end;
$$;

revoke all on function public.set_film_mark(text, text, boolean, boolean, text) from public;
grant execute on function public.set_film_mark(text, text, boolean, boolean, text) to anon;

notify pgrst, 'reload schema';
