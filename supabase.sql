-- Cole TUDO no Supabase > SQL Editor > New query > Run
create table if not exists users(
  id text primary key, username text unique, name text default '', bio text default '',
  photo text default '', banner text default '', ad_link text default '',
  products jsonb default '[]'::jsonb, created_at timestamptz default now());
create table if not exists videos(
  id uuid primary key default gen_random_uuid(), uid text references users(id) on delete cascade,
  title text, descr text default '', url text, type text, views int default 0,
  likes int default 0, comments int default 0, created_at timestamptz default now());
create table if not exists likes(vid uuid references videos(id) on delete cascade, uid text, primary key(vid,uid));
create table if not exists follows(follower text, followed text, primary key(follower,followed));
create table if not exists comments(
  id uuid primary key default gen_random_uuid(), vid uuid references videos(id) on delete cascade,
  uid text, text text, created_at timestamptz default now());
create table if not exists notifications(
  id uuid primary key default gen_random_uuid(), to_uid text, from_uid text, type text,
  vid uuid, text text default '', read boolean default false, created_at timestamptz default now());
create table if not exists adviews(
  id uuid primary key default gen_random_uuid(), creator text, vid uuid, type text, created_at timestamptz default now());
create index if not exists i_vid on videos(uid); create index if not exists i_not on notifications(to_uid);
create or replace function bump_likes() returns trigger language plpgsql security definer as $$
begin if tg_op='INSERT' then update videos set likes=likes+1 where id=new.vid;
else update videos set likes=greatest(likes-1,0) where id=old.vid; end if; return null; end $$;
drop trigger if exists t_likes on likes;
create trigger t_likes after insert or delete on likes for each row execute function bump_likes();
create or replace function bump_comments() returns trigger language plpgsql security definer as $$
begin if tg_op='INSERT' then update videos set comments=comments+1 where id=new.vid;
else update videos set comments=greatest(comments-1,0) where id=old.vid; end if; return null; end $$;
drop trigger if exists t_comments on comments;
create trigger t_comments after insert or delete on comments for each row execute function bump_comments();
create or replace function add_view(p_id uuid) returns void language sql security definer as
$$ update videos set views=views+1 where id=p_id $$;
do $$ declare t text; begin
  foreach t in array array['users','videos','likes','follows','comments','notifications','adviews'] loop
    execute format('alter table %I enable row level security',t);
    execute format('drop policy if exists "open" on %I',t);
    execute format('create policy "open" on %I for all to anon, authenticated using (true) with check (true)',t);
  end loop; end $$;
grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant execute on function add_view(uuid) to anon, authenticated;
do $$ begin alter publication supabase_realtime add table notifications; exception when others then null; end $$;
insert into storage.buckets(id,name,public,file_size_limit) values('media','media',true,52428800)
  on conflict(id) do update set public=true,file_size_limit=52428800;
drop policy if exists "media_read" on storage.objects;
create policy "media_read" on storage.objects for select to anon, authenticated using (bucket_id='media');
drop policy if exists "media_insert" on storage.objects;
create policy "media_insert" on storage.objects for insert to anon, authenticated with check (bucket_id='media');