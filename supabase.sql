-- À exécuter une fois dans Supabase : SQL Editor → New query → coller → Run.
-- Crée la liste commune « vu / aimé / commentaire » des films.

create table if not exists public.film_marks (
  imdb_id    text primary key,
  seen       boolean not null default false,
  liked      boolean not null default false,
  note       text not null default '' check (char_length(note) <= 280),
  seen_at    timestamptz,
  liked_at   timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.film_marks enable row level security;

-- La page est publique : tout visiteur peut lire et modifier la liste commune,
-- mais pas la supprimer.
create policy "lecture publique" on public.film_marks
  for select to anon using (true);
create policy "ajout public" on public.film_marks
  for insert to anon with check (true);
create policy "modification publique" on public.film_marks
  for update to anon using (true) with check (true);
