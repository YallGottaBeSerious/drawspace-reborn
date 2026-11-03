-- drawspace.reborn database schema
create extension if not exists pgcrypto;

create type public.staff_role as enum ('user','moderator','admin','owner','developer');
create type public.friend_status as enum ('pending','accepted','declined','blocked');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 20),
  display_name text not null default '',
  bio text not null default '',
  avatar_url text,
  gender text,
  vip boolean not null default false,
  xp bigint not null default 0,
  level integer not null default 1,
  gold bigint not null default 0,
  rubies bigint not null default 0,
  likes bigint not null default 0,
  gifts bigint not null default 0,
  online boolean not null default false,
  last_active timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.staff_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.staff_role not null default 'user'
);

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester uuid not null references public.profiles(id) on delete cascade,
  addressee uuid not null references public.profiles(id) on delete cascade,
  status public.friend_status not null default 'pending',
  created_at timestamptz not null default now(),
  unique(requester, addressee),
  check (requester <> addressee)
);

create table public.wall_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  wall_owner_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  kind text not null,
  body text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 50),
  description text not null default '',
  is_vip boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profile_ratings (
  id uuid primary key default gen_random_uuid(),
  rater_id uuid not null references public.profiles(id) on delete cascade,
  rated_id uuid not null references public.profiles(id) on delete cascade,
  score int not null check (score between 1 and 10),
  created_at timestamptz not null default now(),
  unique(rater_id, rated_id),
  check (rater_id <> rated_id)
);

create table public.crushes (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references public.profiles(id) on delete cascade,
  to_user uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(from_user, to_user),
  check (from_user <> to_user)
);

create table public.secret_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.profiles(id) on delete set null,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  image_url text,
  created_at timestamptz not null default now()
);

create table public.gallery_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  created_at timestamptz not null default now()
);

create table public.gifts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  gift_name text not null,
  created_at timestamptz not null default now()
);

create table public.boss_state (
  id int primary key default 1 check (id = 1),
  boss_name text not null default 'Abyssal Beholder',
  max_hp bigint not null default 445000,
  hp bigint not null default 445000,
  reward_claimed boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.boss_state(id) values (1) on conflict do nothing;

create table public.boss_hits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  damage int not null default 100,
  created_at timestamptz not null default now()
);

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id),
  target_id uuid not null references auth.users(id),
  action text not null check (action in ('kick','ban','unban')),
  reason text not null default '',
  created_at timestamptz not null default now()
);

create table public.bot_profiles (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id),
  username text unique not null,
  display_name text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create or replace function public.current_staff_role()
returns public.staff_role language sql stable security definer
set search_path = public
as $$
  select coalesce((select role from public.staff_roles where user_id = auth.uid()), 'user'::public.staff_role)
$$;

create or replace function public.is_friend(a uuid, b uuid)
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists(select 1 from public.friendships
    where status='accepted'
    and ((requester=a and addressee=b) or (requester=b and addressee=a)))
$$;

create or replace function public.create_profile()
returns trigger language plpgsql security definer set search_path=public
as $$
declare uname text;
begin
  uname := coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1));
  uname := regexp_replace(lower(uname), '[^a-z0-9_]', '', 'g');
  if char_length(uname) < 3 then uname := 'member_' || substr(new.id::text,1,8); end if;
  insert into public.profiles(id, username, display_name)
  values(new.id, uname, uname)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.create_profile();

alter table public.profiles enable row level security;
alter table public.staff_roles enable row level security;
alter table public.friendships enable row level security;
alter table public.wall_posts enable row level security;
alter table public.notifications enable row level security;
alter table public.rooms enable row level security;
alter table public.profile_ratings enable row level security;
alter table public.crushes enable row level security;
alter table public.secret_messages enable row level security;
alter table public.gallery_items enable row level security;
alter table public.gifts enable row level security;
alter table public.boss_state enable row level security;
alter table public.boss_hits enable row level security;
alter table public.moderation_actions enable row level security;
alter table public.bot_profiles enable row level security;

create policy "profiles readable" on public.profiles for select using (true);
create policy "users update own profile" on public.profiles for update using (auth.uid()=id) with check (auth.uid()=id);
create policy "roles visible to self or staff" on public.staff_roles for select using (auth.uid()=user_id or public.current_staff_role() in ('moderator','admin','owner','developer'));
create policy "friendship participants read" on public.friendships for select using (auth.uid()=requester or auth.uid()=addressee);
create policy "send friend request" on public.friendships for insert with check (auth.uid()=requester and status='pending');
create policy "participants update friendship" on public.friendships for update using (auth.uid()=requester or auth.uid()=addressee);
create policy "friend wall readable" on public.wall_posts for select using (auth.uid()=wall_owner_id or public.is_friend(auth.uid(),wall_owner_id));
create policy "friend wall write" on public.wall_posts for insert with check (auth.uid()=author_id and public.is_friend(auth.uid(),wall_owner_id));
create policy "wall owner delete" on public.wall_posts for delete using (auth.uid()=author_id or auth.uid()=wall_owner_id);
create policy "notifications own" on public.notifications for select using (auth.uid()=user_id);
create policy "notifications own update" on public.notifications for update using (auth.uid()=user_id);
create policy "rooms public read" on public.rooms for select using (true);
create policy "vip room create" on public.rooms for insert with check (auth.uid()=owner_id and exists(select 1 from public.profiles p where p.id=auth.uid() and p.vip));
create policy "room owner delete" on public.rooms for delete using (auth.uid()=owner_id or public.current_staff_role() in ('admin','owner','developer'));
create policy "ratings readable" on public.profile_ratings for select using (true);
create policy "rate once" on public.profile_ratings for insert with check (auth.uid()=rater_id);
create policy "ratings update own" on public.profile_ratings for update using (auth.uid()=rater_id);
create policy "crushes participants" on public.crushes for select using (auth.uid()=from_user or auth.uid()=to_user);
create policy "send crush" on public.crushes for insert with check (auth.uid()=from_user);
create policy "secret messages participants" on public.secret_messages for select using (auth.uid()=recipient_id or auth.uid()=sender_id);
create policy "send secret message" on public.secret_messages for insert with check (auth.uid()=sender_id);
create policy "gallery public read" on public.gallery_items for select using (true);
create policy "gallery owner add" on public.gallery_items for insert with check (auth.uid()=user_id);
create policy "gallery owner delete" on public.gallery_items for delete using (auth.uid()=user_id);
create policy "gifts readable" on public.gifts for select using (auth.uid()=sender_id or auth.uid()=recipient_id);
create policy "send gift" on public.gifts for insert with check (auth.uid()=sender_id);
create policy "boss public read" on public.boss_state for select using (true);
create policy "hits public read" on public.boss_hits for select using (true);
create policy "hit own insert" on public.boss_hits for insert with check (auth.uid()=user_id);
create policy "moderation staff read" on public.moderation_actions for select using (public.current_staff_role() in ('moderator','admin','owner','developer'));
create policy "bot profiles staff read" on public.bot_profiles for select using (public.current_staff_role() in ('admin','owner','developer'));
create policy "developer creates bots" on public.bot_profiles for insert with check (auth.uid()=created_by and public.current_staff_role()='developer');

-- Moderation: developer can ban/kick; owner/admin/moderator can kick only.
create or replace function public.moderate_user(target uuid, action_name text, why text default '')
returns void language plpgsql security definer set search_path=public
as $$
declare actor_role public.staff_role;
begin
  actor_role := public.current_staff_role();
  if action_name not in ('kick','ban','unban') then raise exception 'Invalid action'; end if;
  if action_name='kick' and actor_role not in ('moderator','admin','owner','developer') then raise exception 'Not authorized'; end if;
  if action_name in ('ban','unban') and actor_role <> 'developer' then raise exception 'Developer permission required'; end if;
  if target = auth.uid() then raise exception 'Cannot moderate yourself'; end if;
  insert into public.moderation_actions(actor_id,target_id,action,reason)
  values(auth.uid(),target,action_name,left(coalesce(why,''),500));
end $$;
revoke all on function public.moderate_user(uuid,text,text) from public;
grant execute on function public.moderate_user(uuid,text,text) to authenticated;

-- Basic useful indexes
create index on public.profiles(username);
create index on public.profiles(last_active desc);
create index on public.friendships(addressee,status);
create index on public.wall_posts(wall_owner_id,created_at desc);
create index on public.notifications(user_id,created_at desc);
create index on public.boss_hits(user_id,created_at desc);
