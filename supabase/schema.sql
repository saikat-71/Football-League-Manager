-- Touchline Football League Manager — Supabase schema
-- Run this whole file in Supabase SQL Editor before using the app.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  email text not null default '',
  display_name text not null default '',
  role text not null default 'user' check (role in ('admin','user')),
  status text not null default 'pending' check (status in ('pending','active','deactivated','rejected','deleted')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.profiles add column if not exists email text not null default '';
alter table public.profiles drop constraint if exists profiles_status_check;
alter table public.profiles add constraint profiles_status_check check(status in ('pending','active','deactivated','rejected','deleted'));
create table if not exists public.settings (
  id boolean primary key default true check (id),
  currency_label text not null default 'TK M',
  default_budget numeric(14,2) not null default 280 check(default_budget >= 0 and default_budget=trunc(default_budget)),
  squad_limit integer not null default 25 check(squad_limit between 1 and 100),
  position_limits jsonb not null default '{}'::jsonb,
  points_win integer not null default 3 check(points_win between 0 and 10),
  points_draw integer not null default 1 check(points_draw between 0 and 10),
  updated_at timestamptz not null default now()
);
alter table public.settings add column if not exists position_limits jsonb not null default '{}'::jsonb;
insert into public.settings(id) values(true) on conflict(id) do nothing;
create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid unique references public.profiles(id) on delete set null,
  name text not null unique,
  logo_url text,
  formation text not null default '4-3-3',
  manager_name text not null default '',
  status text not null default 'active' check(status in ('pending','active','deactivated','rejected','deleted')),
  deactivation_reason text not null default '',
  budget numeric(14,2) not null default 280 check(budget >= 0 and budget=trunc(budget)),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.teams add column if not exists deactivation_reason text not null default '';
alter table public.teams drop constraint if exists teams_status_check;
alter table public.teams add constraint teams_status_check check(status in ('pending','active','deactivated','rejected','deleted'));
create or replace view public.public_teams as select id,name,logo_url,formation,manager_name,status,budget,created_at,updated_at,(owner_id is not null) as owner_assigned from public.teams;
grant select on public.public_teams to anon, authenticated;
create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  name text not null,
  position text not null default 'CM',
  rating integer not null default 70 check(rating between 1 and 100),
  age integer check(age is null or age between 14 and 60),
  nationality text not null default '',
  base_price numeric(14,2) not null default 1 check(base_price >= 0 and base_price=trunc(base_price)),
  owner_team_id uuid references public.teams(id) on delete set null,
  status text not null default 'free_agent' check(status in ('free_agent','owned','in_auction','unsold','unavailable')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.player_proposals (
  id uuid primary key default gen_random_uuid(), proposer_id uuid not null references public.profiles(id) on delete restrict,
  name text not null, position text not null, rating integer not null check(rating between 1 and 100), age integer,
  nationality text not null default '', proposed_price numeric(14,2) not null default 1 check(proposed_price >= 0 and proposed_price=trunc(proposed_price)),
  status text not null default 'pending' check(status in ('pending','approved','rejected','withdrawn')),
  admin_note text not null default '', reviewed_by uuid references public.profiles(id) on delete set null,
  player_id uuid references public.players(id) on delete set null, created_at timestamptz not null default now(), reviewed_at timestamptz
);
create table if not exists public.auctions (
  id uuid primary key default gen_random_uuid(), player_id uuid not null references public.players(id) on delete restrict,
  status text not null default 'draft' check(status in ('draft','live','paused','closed','cancelled','unsold')),
  base_price numeric(14,2) not null check(base_price >= 0 and base_price=trunc(base_price)), min_increment numeric(14,2) not null default 1 check(min_increment > 0 and min_increment=trunc(min_increment)),
  duration_seconds integer not null default 60 check(duration_seconds between 5 and 86400), ends_at timestamptz,
  remaining_seconds integer, winner_team_id uuid references public.teams(id) on delete set null, winning_bid numeric(14,2),
  result_note text not null default '', created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), finalized_at timestamptz
);
create unique index if not exists one_live_auction_per_player on public.auctions(player_id) where status in ('draft','live','paused');
create table if not exists public.bids (
  id uuid primary key default gen_random_uuid(), auction_id uuid not null references public.auctions(id) on delete restrict,
  team_id uuid not null references public.teams(id) on delete restrict, bidder_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(14,2) not null check(amount > 0 and amount=trunc(amount)), status text not null default 'active' check(status in ('active','outbid','withdrawn','won','frozen','ineligible','cancelled')),
  created_at timestamptz not null default now()
);
create index if not exists bids_active_team_idx on public.bids(team_id) where status in ('active','frozen');
create table if not exists public.transfers (
  id uuid primary key default gen_random_uuid(), player_id uuid not null references public.players(id) on delete restrict,
  seller_team_id uuid not null references public.teams(id) on delete restrict, buyer_team_id uuid not null references public.teams(id) on delete restrict,
  amount numeric(14,2) not null check(amount >= 0 and amount=trunc(amount)), requested_by uuid not null references public.profiles(id) on delete restrict,
  seller_accepted boolean not null default false, buyer_accepted boolean not null default false,
  status text not null default 'pending' check(status in ('pending','completed','cancelled','rejected')),
  created_at timestamptz not null default now(), completed_at timestamptz, cancel_reason text not null default ''
);
create unique index if not exists one_pending_transfer_per_player on public.transfers(player_id) where status='pending';
create table if not exists public.leagues (
  id uuid primary key default gen_random_uuid(), name text not null unique, season text not null default 'Season 1', status text not null default 'active' check(status in ('active','archived')), created_at timestamptz not null default now()
);
create table if not exists public.fixtures (
  id uuid primary key default gen_random_uuid(), league_id uuid references public.leagues(id) on delete set null,
  home_team_id uuid not null references public.teams(id) on delete restrict, away_team_id uuid not null references public.teams(id) on delete restrict,
  kickoff_at timestamptz, status text not null default 'scheduled' check(status in ('scheduled','live','postponed','completed','cancelled')),
  home_score integer check(home_score is null or home_score between 0 and 99), away_score integer check(away_score is null or away_score between 0 and 99),
  result_note text not null default '', created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(home_team_id <> away_team_id)
);
create table if not exists public.fixture_correction_requests (
  id uuid primary key default gen_random_uuid(), fixture_id uuid not null references public.fixtures(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict, proposed_home_score integer not null check(proposed_home_score between 0 and 99),
  proposed_away_score integer not null check(proposed_away_score between 0 and 99), reason text not null,
  status text not null default 'pending' check(status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null, review_reason text not null default '',
  created_at timestamptz not null default now(), reviewed_at timestamptz
);
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(), team_id uuid references public.teams(id) on delete set null,
  related_team_id uuid references public.teams(id) on delete set null, player_id uuid references public.players(id) on delete set null,
  auction_id uuid references public.auctions(id) on delete set null, transfer_id uuid references public.transfers(id) on delete set null,
  kind text not null, amount numeric(14,2) not null check(amount=trunc(amount)), description text not null, created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null, message text not null, kind text not null default 'info', read_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id) on delete set null,
  action text not null, entity_type text not null, entity_id text, reason text not null default '', before_data jsonb, after_data jsonb,
  created_at timestamptz not null default now()
);


create or replace view public.public_players as
 select id,legacy_id,name,position,rating,age,nationality,base_price,owner_team_id,status,created_at,updated_at from public.players;
grant select on public.public_players to anon, authenticated;
create or replace view public.public_fixtures as
 select id,league_id,home_team_id,away_team_id,kickoff_at,status,home_score,away_score,result_note,created_at,updated_at from public.fixtures;
grant select on public.public_fixtures to anon, authenticated;
create or replace view public.public_auctions as
 select id,player_id,status,base_price,min_increment,duration_seconds,ends_at,remaining_seconds,winner_team_id,winning_bid,result_note,created_at,finalized_at from public.auctions;
grant select on public.public_auctions to authenticated;

create or replace function public.audit_row_change() returns trigger language plpgsql security definer set search_path=public as $$
declare before_row jsonb; after_row jsonb; row_id text; operation_name text;
begin
 if tg_op='UPDATE' then before_row:=to_jsonb(old); after_row:=to_jsonb(new); row_id:=coalesce(after_row->>'id',before_row->>'id'); operation_name:='update';
 else before_row:=to_jsonb(old); after_row:=null; row_id:=before_row->>'id'; operation_name:='delete'; end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,before_data,after_data)
 values(auth.uid(),tg_table_name||'_'||operation_name,tg_table_name,row_id,before_row,after_row);
 if tg_op='DELETE' then return old; else return new; end if;
end $$;

drop trigger if exists audit_settings_changes on public.settings;
create trigger audit_settings_changes after update or delete on public.settings for each row execute function public.audit_row_change();
drop trigger if exists audit_profiles_changes on public.profiles;
create trigger audit_profiles_changes after update or delete on public.profiles for each row execute function public.audit_row_change();
drop trigger if exists audit_teams_changes on public.teams;
create trigger audit_teams_changes after update or delete on public.teams for each row execute function public.audit_row_change();
drop trigger if exists audit_players_changes on public.players;
create trigger audit_players_changes after update or delete on public.players for each row execute function public.audit_row_change();
drop trigger if exists audit_auctions_changes on public.auctions;
create trigger audit_auctions_changes after update or delete on public.auctions for each row execute function public.audit_row_change();
drop trigger if exists audit_bids_changes on public.bids;
create trigger audit_bids_changes after update or delete on public.bids for each row execute function public.audit_row_change();
drop trigger if exists audit_transfers_changes on public.transfers;
create trigger audit_transfers_changes after update or delete on public.transfers for each row execute function public.audit_row_change();
drop trigger if exists audit_fixtures_changes on public.fixtures;
create trigger audit_fixtures_changes after update or delete on public.fixtures for each row execute function public.audit_row_change();
drop trigger if exists audit_proposals_changes on public.player_proposals;
create trigger audit_proposals_changes after update or delete on public.player_proposals for each row execute function public.audit_row_change();

create or replace function public.current_role() returns text language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid() $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select coalesce(public.current_role()='admin',false) $$;
create or replace function public.is_active_user() returns boolean language sql stable security definer set search_path=public as $$ select coalesce((select status='active' from public.profiles where id=auth.uid()),false) $$;
create or replace function public.my_team_id() returns uuid language sql stable security definer set search_path=public as $$ select id from public.teams where owner_id=auth.uid() and status<>'deleted' limit 1 $$;




create or replace function public.update_my_team(p_name text,p_logo_url text,p_formation text,p_manager_name text) returns public.teams language plpgsql security definer set search_path=public as $$
declare t public.teams%rowtype; next_status text;
begin
 if not public.is_active_user() then raise exception 'Your account is not active.'; end if;
 select * into t from public.teams where owner_id=auth.uid() and status<>'deleted' for update;
 if not found then raise exception 'You do not have a team.'; end if;
 if t.status='deactivated' then raise exception 'Your team is deactivated and cannot be edited.'; end if;
 next_status:=case when t.status='rejected' then 'pending' else t.status end;
 update public.teams set name=trim(p_name),logo_url=nullif(trim(coalesce(p_logo_url,'')),''),formation=p_formation,manager_name=left(trim(coalesce(p_manager_name,'')),80),status=next_status,updated_at=now() where id=t.id returning * into t;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'update_team','team',t.id::text,jsonb_build_object('name',t.name,'formation',t.formation,'status',t.status));
 if next_status='pending' then insert into public.notifications(user_id,title,message,kind) select id,'Team resubmitted','Team '||t.name||' was edited and resubmitted for Admin review.','team' from public.profiles where role='admin' and status='active'; end if;
 return t;
end $$;

create or replace function public.admin_delete_team(p_team_id uuid,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.teams%rowtype;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A deletion reason is required.'; end if;
 select * into t from public.teams where id=p_team_id for update;
 if not found or t.status='deleted' then raise exception 'Team not found or already deleted.'; end if;
 update public.bids set status='cancelled' where team_id=t.id and status in ('active','frozen');
 update public.transfers set status='cancelled',cancel_reason='Team deleted: '||p_reason where status='pending' and (seller_team_id=t.id or buyer_team_id=t.id);
 update public.players set owner_team_id=null,status='free_agent',updated_at=now() where owner_team_id=t.id;
 update public.teams set owner_id=null,status='deleted',deactivation_reason='deleted: '||p_reason,updated_at=now() where id=t.id;
 update public.fixtures set status='cancelled',updated_at=now() where status in ('scheduled','postponed') and (home_team_id=t.id or away_team_id=t.id);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'delete_team','team',t.id::text,p_reason,jsonb_build_object('name',t.name,'status',t.status),jsonb_build_object('name_retained',t.name,'status','deleted','players_released',true));
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.get_auction_leaders() returns table(auction_id uuid,current_bid numeric,leading_team_id uuid,leading_team_name text) language sql stable security definer set search_path=public as $$
 select distinct on (a.id) a.id,b.amount,t.id,t.name
 from public.auctions a join public.bids b on b.auction_id=a.id join public.teams t on t.id=b.team_id join public.profiles p on p.id=t.owner_id
 where a.status in ('live','paused') and b.status='active' and t.status='active' and p.status='active'
 order by a.id,b.amount desc,b.created_at asc
$$;

create or replace function public.update_my_profile(p_display_name text,p_username text) returns public.profiles language plpgsql security definer set search_path=public as $$
declare updated public.profiles%rowtype; uname text:=lower(trim(coalesce(p_username,'')));
begin
 if not public.is_active_user() then raise exception 'Your account is not active.'; end if;
 if uname !~ '^[a-z0-9_.-]{3,32}$' then raise exception 'Username must be 3–32 letters, digits, dots, underscores or hyphens.'; end if;
 if exists(select 1 from public.profiles where username=uname and id<>auth.uid()) then raise exception 'Username is already taken.'; end if;
 update public.profiles set username=uname,display_name=left(trim(coalesce(p_display_name,'')),80),updated_at=now() where id=auth.uid() returning * into updated;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'update_profile','profile',auth.uid()::text,jsonb_build_object('username',uname));
 return updated;
end $$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare uname text;
begin
  uname := lower(coalesce(new.raw_user_meta_data->>'username', split_part(coalesce(new.email,''),'@',1), 'player'));
  uname := regexp_replace(uname, '[^a-z0-9_.-]', '', 'g');
  if length(uname)<3 then uname := 'player_' || substr(new.id::text,1,8); end if;
  if exists(select 1 from public.profiles p where p.username=uname and p.id<>new.id) then uname := uname || '_' || substr(new.id::text,1,6); end if;
  insert into public.profiles(id,username,email,display_name,role,status)
  values(new.id,uname,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'display_name',''), 'user','pending')
  on conflict(id) do nothing;
  insert into public.notifications(user_id,title,message,kind) select id,'New registration','A new account ('||uname||') is awaiting Admin approval.','registration' from public.profiles where role='admin' and status='active';
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Atomic live bid: reserve is represented by the team's current active bid(s), not a permanent deduction.
create or replace function public.place_bid(p_auction_id uuid,p_amount numeric) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.auctions%rowtype; t public.teams%rowtype; uid uuid:=auth.uid(); min_bid numeric; spent numeric; reserved numeric;
begin
 if uid is null or not public.is_active_user() then raise exception 'Your account is not active.'; end if;
 select * into a from public.auctions where id=p_auction_id for update;
 if not found or a.status<>'live' or a.ends_at is null or a.ends_at<=now() then raise exception 'Auction is not live.'; end if;
 select * into t from public.teams where owner_id=uid and status='active' for update;
 if not found then raise exception 'You need one active team to bid.'; end if;
 if exists(select 1 from public.transfers tr where tr.player_id=a.player_id and tr.status='pending') then raise exception 'Player has a pending transfer.'; end if;
 if (select status from public.players where id=a.player_id) not in ('free_agent','in_auction','unsold') then raise exception 'Player is not eligible for auction.'; end if;
 if (select count(*) from public.players where owner_team_id=t.id and status='owned') >= (select squad_limit from public.settings where id=true) then raise exception 'Squad limit reached.'; end if;
 if coalesce(((select position_limits->>(select position from public.players where id=a.player_id) from public.settings where id=true)::integer),0)>0 and (select count(*) from public.players where owner_team_id=t.id and status='owned' and position=(select position from public.players where id=a.player_id)) >= coalesce(((select position_limits->>(select position from public.players where id=a.player_id) from public.settings where id=true)::integer),0) then raise exception 'Position-wise squad limit reached.'; end if;
 min_bid := greatest(a.base_price,coalesce((select max(amount) from public.bids where auction_id=a.id and status in ('active','frozen')),0)+a.min_increment);
 if p_amount<=0 or p_amount<>trunc(p_amount) then raise exception 'Bid must be a positive whole number.'; end if;
 if p_amount < min_bid then raise exception 'Bid must be at least %.',min_bid; end if;
 select coalesce(sum(amount),0) into spent from public.transactions where team_id=t.id and kind in ('auction_purchase','transfer_purchase','transfer_sale','budget_adjustment');
 -- Notify prior leaders, then supersede their bid and release its reservation.
 insert into public.notifications(user_id,title,message,kind) select bidder_id,'You were outbid','Another team placed a higher bid on '||(select name from public.players where id=a.player_id)||'.','auction' from public.bids where auction_id=a.id and status='active' and bidder_id<>uid;
 update public.bids set status='outbid' where auction_id=a.id and status='active';
 select coalesce(sum(amount),0) into reserved from public.bids where team_id=t.id and status in ('active','frozen');
 if p_amount + reserved + spent > t.budget then raise exception 'Bid exceeds available budget after active reservations.'; end if;
 insert into public.bids(auction_id,team_id,bidder_id,amount,status) values(a.id,t.id,uid,p_amount,'active');
 update public.players set status='in_auction' where id=a.player_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,after_data) values(uid,'place_bid','auction',a.id::text,jsonb_build_object('amount',p_amount,'team_id',t.id));
 return jsonb_build_object('ok',true,'minimum_next_bid',p_amount+a.min_increment);
end $$;

create or replace function public.withdraw_bid(p_bid_id uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare b public.bids%rowtype;
begin
 if not public.is_active_user() then raise exception 'Your account is not active.'; end if;
 select * into b from public.bids where id=p_bid_id for update;
 if not found or b.bidder_id<>auth.uid() or b.status<>'active' then raise exception 'Bid cannot be withdrawn.'; end if;
 if exists(select 1 from public.auctions where id=b.auction_id and status='live' and ends_at>now()) is false then raise exception 'Only a live auction bid can be withdrawn.'; end if;
 update public.bids set status='withdrawn' where id=b.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason) values(auth.uid(),'withdraw_bid','bid',b.id::text,'Bid withdrawn by owner');
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.resolve_expired_auctions() returns integer language plpgsql security definer set search_path=public as $$
declare a record; b record; player_status text; n integer:=0; spent numeric;
begin
 for a in select * from public.auctions where status='live' and ends_at<=now() for update skip locked loop
   select b0.* into b from public.bids b0 join public.teams t on t.id=b0.team_id join public.profiles p on p.id=t.owner_id
    where b0.auction_id=a.id and b0.status='active' and b0.amount>=a.base_price and t.status='active' and p.status='active'
      and (select count(*) from public.players px where px.owner_team_id=t.id and px.status='owned') < (select squad_limit from public.settings where id=true)
      and (coalesce(((select position_limits->>(select position from public.players where id=a.player_id) from public.settings where id=true)::integer),0)=0 or (select count(*) from public.players px where px.owner_team_id=t.id and px.status='owned' and px.position=(select position from public.players where id=a.player_id)) < coalesce(((select position_limits->>(select position from public.players where id=a.player_id) from public.settings where id=true)::integer),0))
      and (select coalesce(sum(tx.amount),0) from public.transactions tx where tx.team_id=t.id and tx.kind in ('auction_purchase','transfer_purchase','transfer_sale','budget_adjustment')) + b0.amount + (select coalesce(sum(rb.amount),0) from public.bids rb join public.auctions ra on ra.id=rb.auction_id where rb.team_id=t.id and rb.status in ('active','frozen') and rb.auction_id<>a.id and ra.status in ('live','paused')) <= t.budget
    order by b0.amount desc,b0.created_at asc limit 1;
   if b.id is null then
     update public.auctions set status='unsold',finalized_at=now(),result_note='No eligible bids at expiry.' where id=a.id;
     update public.players set status='unsold' where id=a.player_id;
     update public.bids set status=case when status='active' then 'ineligible' else status end where auction_id=a.id;
     insert into public.notifications(user_id,title,message,kind) select id,'Auction ended unsold','No eligible bid was available for '||(select name from public.players where id=a.player_id)||'. Admin decision required.','auction' from public.profiles where role='admin' and status='active';
   else
     select coalesce(sum(amount),0) into spent from public.transactions where team_id=b.team_id and kind in ('auction_purchase','transfer_purchase','transfer_sale','budget_adjustment');
     if spent + b.amount <= (select budget from public.teams where id=b.team_id) then
       update public.bids set status=case when id=b.id then 'won' when status in ('active','frozen') then 'outbid' else status end where auction_id=a.id;
       update public.auctions set status='closed',winner_team_id=b.team_id,winning_bid=b.amount,finalized_at=now(),result_note='Automatically finalized at countdown expiry.' where id=a.id;
       update public.players set status='owned',owner_team_id=b.team_id where id=a.player_id;
       insert into public.transactions(team_id,player_id,auction_id,kind,amount,description) values(b.team_id,a.player_id,a.id,'auction_purchase',b.amount,'Auction purchase: '||(select name from public.players where id=a.player_id));
       insert into public.notifications(user_id,title,message,kind) select owner_id,'Auction won','Your team won '||(select name from public.players where id=a.player_id)||' for '||b.amount||'.','auction' from public.teams where id=b.team_id and owner_id is not null;
       insert into public.audit_logs(action,entity_type,entity_id,after_data) values('auto_finalize_auction','auction',a.id::text,jsonb_build_object('winner_team_id',b.team_id,'amount',b.amount));
     else
       update public.auctions set status='unsold',finalized_at=now(),result_note='Highest bid became ineligible due to budget validation.' where id=a.id;
       update public.players set status='unsold' where id=a.player_id;
       update public.bids set status=case when status in ('active','frozen') then 'ineligible' else status end where auction_id=a.id;
     end if;
   end if;
   n:=n+1;
 end loop;
 return n;
end $$;




create or replace function public.admin_set_fixture_status(p_fixture_id uuid,p_status text,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare f public.fixtures%rowtype;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if p_status not in ('scheduled','live','postponed','cancelled') then raise exception 'Use the result form to complete a match.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A status-change reason is required.'; end if;
 select * into f from public.fixtures where id=p_fixture_id for update;
 if not found then raise exception 'Fixture not found.'; end if;
 if f.status='completed' then raise exception 'Completed results must be corrected through the result workflow.'; end if;
 update public.fixtures set status=p_status,updated_at=now(),result_note=p_reason where id=f.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'fixture_status_change','fixture',f.id::text,p_reason,jsonb_build_object('status',f.status),jsonb_build_object('status',p_status));
 insert into public.notifications(user_id,title,message,kind) select id,'Fixture status updated','Fixture status changed to '||p_status||'. '||p_reason,'fixture' from public.profiles where status='active';
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.admin_reschedule_fixture(p_fixture_id uuid,p_kickoff_at timestamptz,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare f public.fixtures%rowtype;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if p_kickoff_at is null or p_kickoff_at<=now() then raise exception 'Choose a future kickoff time.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A rescheduling reason is required.'; end if;
 select * into f from public.fixtures where id=p_fixture_id for update;
 if not found or f.status not in ('postponed','scheduled') then raise exception 'Only scheduled or postponed fixtures can be rescheduled.'; end if;
 update public.fixtures set kickoff_at=p_kickoff_at,status='scheduled',updated_at=now(),result_note=p_reason where id=f.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'reschedule_fixture','fixture',f.id::text,p_reason,jsonb_build_object('kickoff_at',f.kickoff_at,'status',f.status),jsonb_build_object('kickoff_at',p_kickoff_at,'status','scheduled'));
 insert into public.notifications(user_id,title,message,kind) select id,'Fixture rescheduled','A league fixture has been rescheduled to '||p_kickoff_at||'.','fixture' from public.profiles where status='active';
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.admin_save_fixture_result(p_fixture_id uuid,p_home_score integer,p_away_score integer,p_reason text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare f public.fixtures%rowtype; reason_text text:=trim(coalesce(p_reason,''));
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if p_home_score<0 or p_home_score>99 or p_away_score<0 or p_away_score>99 then raise exception 'Scores must be whole numbers from 0 to 99.'; end if;
 select * into f from public.fixtures where id=p_fixture_id for update;
 if not found then raise exception 'Fixture not found.'; end if;
 if f.status='completed' and (f.home_score is distinct from p_home_score or f.away_score is distinct from p_away_score) and length(reason_text)<3 then raise exception 'A reason is required to correct a published result.'; end if;
 update public.fixtures set home_score=p_home_score,away_score=p_away_score,status='completed',result_note=reason_text,updated_at=now() where id=f.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),case when f.status='completed' then 'correct_fixture_result' else 'enter_fixture_result' end,'fixture',f.id::text,reason_text,jsonb_build_object('home_score',f.home_score,'away_score',f.away_score,'status',f.status),jsonb_build_object('home_score',p_home_score,'away_score',p_away_score,'status','completed'));
 insert into public.notifications(user_id,title,message,kind) select id,'Fixture result updated',(select name from public.teams where id=f.home_team_id)||' '||p_home_score||' – '||p_away_score||' '||(select name from public.teams where id=f.away_team_id),'fixture' from public.profiles where status='active';
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.admin_set_auction_status(p_auction_id uuid,p_action text,p_reason text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.auctions%rowtype; rem integer;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 select * into a from public.auctions where id=p_auction_id for update;
 if not found then raise exception 'Auction not found.'; end if;
 if p_action='start' and a.status='draft' then
   if exists(select 1 from public.players p where p.id=a.player_id and (p.owner_team_id is not null or p.status not in ('free_agent','unsold'))) then raise exception 'Player must be a free agent.'; end if;
   if exists(select 1 from public.transfers tr where tr.player_id=a.player_id and tr.status='pending') then raise exception 'Player has a pending transfer.'; end if;
   update public.auctions set status='live',ends_at=now()+make_interval(secs=>duration_seconds),remaining_seconds=duration_seconds where id=a.id;
   update public.players set status='in_auction' where id=a.player_id;
 elsif p_action='pause' and a.status='live' then
   rem:=greatest(0,ceil(extract(epoch from (a.ends_at-now())))::integer);
   update public.auctions set status='paused',remaining_seconds=rem,ends_at=null where id=a.id;
 elsif p_action='resume' and a.status='paused' then
   update public.auctions set status='live',ends_at=now()+make_interval(secs=>greatest(1,coalesce(a.remaining_seconds,1))) where id=a.id;
 elsif p_action='cancel' and a.status in ('draft','live','paused') then
   update public.bids set status='cancelled' where auction_id=a.id and status in ('active','frozen');
   update public.auctions set status='cancelled',ends_at=null,finalized_at=now(),result_note=coalesce(p_reason,'') where id=a.id;
   update public.players set status='unsold' where id=a.player_id;
 elsif p_action='close' and a.status in ('live','paused') then
   if a.status='live' then update public.auctions set ends_at=now() where id=a.id; end if;
   update public.auctions set status='live',ends_at=now() where id=a.id;
   perform public.resolve_expired_auctions();
 else raise exception 'Invalid auction state/action.';
 end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason) values(auth.uid(),'auction_'||p_action,'auction',a.id::text,coalesce(p_reason,''));
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.respond_transfer(p_transfer_id uuid,p_accept boolean) returns jsonb language plpgsql security definer set search_path=public as $$
declare tr public.transfers%rowtype; myteam uuid; player_owner uuid; spent numeric; reserved numeric; seller public.teams%rowtype; buyer public.teams%rowtype; pl public.players%rowtype; pos_limit integer;
begin
 if not public.is_active_user() then raise exception 'Your account is not active.'; end if;
 myteam:=public.my_team_id();
 select * into tr from public.transfers where id=p_transfer_id for update;
 if not found or tr.status<>'pending' then raise exception 'Transfer is no longer pending.'; end if;
 if myteam is null or myteam not in (tr.seller_team_id,tr.buyer_team_id) then raise exception 'This transfer does not belong to your team.'; end if;
 if not p_accept then
   update public.transfers set status='cancelled',cancel_reason='Cancelled by team participant' where id=tr.id;
   insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason) values(auth.uid(),'cancel_transfer','transfer',tr.id::text,'Cancelled by participant');
   return jsonb_build_object('ok',true,'status','cancelled');
 end if;
 if myteam=tr.seller_team_id then update public.transfers set seller_accepted=true where id=tr.id returning * into tr; else update public.transfers set buyer_accepted=true where id=tr.id returning * into tr; end if;
 if tr.seller_accepted and tr.buyer_accepted then
   select * into seller from public.teams where id=tr.seller_team_id for update;
   select * into buyer from public.teams where id=tr.buyer_team_id for update;
   select * into pl from public.players where id=tr.player_id for update;
   player_owner:=pl.owner_team_id;
   if player_owner is distinct from tr.seller_team_id then raise exception 'Player ownership changed; transfer cannot settle.'; end if;
   if seller.status<>'active' or buyer.status<>'active' then raise exception 'Both teams must be active.'; end if;
   if (select count(*) from public.players where owner_team_id=buyer.id and status='owned') >= (select squad_limit from public.settings where id=true) then raise exception 'Buyer squad limit reached.'; end if;
   select coalesce((position_limits->>pl.position)::integer,0) into pos_limit from public.settings where id=true;
   if pos_limit>0 and (select count(*) from public.players where owner_team_id=buyer.id and status='owned' and position=pl.position)>=pos_limit then raise exception 'Buyer position-wise squad limit reached.'; end if;
   select coalesce(sum(amount),0) into spent from public.transactions where team_id=buyer.id and kind in ('auction_purchase','transfer_purchase','transfer_sale','budget_adjustment');
   select coalesce(sum(b.amount),0) into reserved from public.bids b join public.auctions a on a.id=b.auction_id where b.team_id=buyer.id and b.status in ('active','frozen') and a.status in ('live','paused');
   if buyer.budget-spent-reserved<tr.amount then raise exception 'Buyer has insufficient available budget after active bid reservations.'; end if;
   update public.players set owner_team_id=buyer.id,status='owned' where id=tr.player_id;
   insert into public.transactions(team_id,related_team_id,player_id,transfer_id,kind,amount,description,created_by) values(buyer.id,seller.id,tr.player_id,tr.id,'transfer_purchase',tr.amount,'Transfer purchase',auth.uid());
   insert into public.transactions(team_id,related_team_id,player_id,transfer_id,kind,amount,description,created_by) values(seller.id,buyer.id,tr.player_id,tr.id,'transfer_sale',-tr.amount,'Transfer sale proceeds',auth.uid());
   update public.transfers set status='completed',completed_at=now() where id=tr.id;
   if seller.owner_id is not null then insert into public.notifications(user_id,title,message,kind) values(seller.owner_id,'Transfer completed','Your player transfer has completed. Sale proceeds: '||tr.amount||'.','transfer'); end if;
   if buyer.owner_id is not null then insert into public.notifications(user_id,title,message,kind) values(buyer.owner_id,'Transfer completed','Your player transfer has completed. Purchase amount: '||tr.amount||'.','transfer'); end if;
   insert into public.audit_logs(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'finalize_transfer','transfer',tr.id::text,jsonb_build_object('seller',seller.id,'buyer',buyer.id,'amount',tr.amount));
 end if;
 return jsonb_build_object('ok',true,'status',case when tr.seller_accepted and tr.buyer_accepted then 'completed' else 'pending' end);
end $$;




create or replace function public.admin_prepare_account_deletion(p_user_id uuid,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare target public.profiles%rowtype; v_team_id uuid;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if auth.uid()=p_user_id then raise exception 'An Admin cannot delete their own account from this workflow.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A deletion reason is required.'; end if;
 select * into target from public.profiles where id=p_user_id for update;
 if not found then raise exception 'Account not found.'; end if;
 if target.role='admin' then raise exception 'Admin accounts cannot be deleted.'; end if;
 select id into v_team_id from public.teams where owner_id=p_user_id and status<>'deleted' limit 1;
 if v_team_id is not null then
   update public.bids set status='cancelled' where (bidder_id=p_user_id or team_id=v_team_id) and status in ('active','frozen');
   update public.transfers set status='cancelled',cancel_reason='Account deleted' where status='pending' and (seller_team_id=v_team_id or buyer_team_id=v_team_id);
   update public.players set owner_team_id=null,status='free_agent',updated_at=now() where owner_team_id=v_team_id;
   update public.teams set owner_id=null,status='deleted',deactivation_reason='account deleted',updated_at=now() where id=v_team_id;
   update public.fixtures set status='cancelled',updated_at=now() where status in ('scheduled','postponed') and (home_team_id=v_team_id or away_team_id=v_team_id);
 end if;
 update public.profiles set status='deleted',display_name='',email='',updated_at=now() where id=p_user_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'prepare_account_deletion','profile',p_user_id::text,p_reason,jsonb_build_object('username',target.username,'role',target.role,'status',target.status),jsonb_build_object('username_retained',target.username,'status','deleted','personal_display_name_removed',true));
 return jsonb_build_object('ok',true,'username_retained',target.username);
end $$;

create or replace function public.admin_set_profile_status(p_user_id uuid,p_status text,p_reason text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare target public.profiles%rowtype; v_team_id uuid; active_admins integer;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if p_status not in ('pending','active','deactivated','rejected') then raise exception 'Invalid account status.'; end if;
 select * into target from public.profiles where id=p_user_id for update;
 if not found then raise exception 'Account not found.'; end if;
 if target.role='admin' and p_status<>'active' then
   select count(*) into active_admins from public.profiles where role='admin' and status='active';
   if active_admins<=1 then raise exception 'At least one active Admin must remain.'; end if;
 end if;
 select id into v_team_id from public.teams where owner_id=p_user_id and status<>'deleted' limit 1;
 if p_status='deactivated' then
   if v_team_id is not null then
     update public.bids set status='cancelled' where (bidder_id=p_user_id or team_id=v_team_id) and status='active';
     update public.transfers set status='cancelled',cancel_reason='Account deactivated by Admin' where status='pending' and (seller_team_id=v_team_id or buyer_team_id=v_team_id);
     update public.teams set status='deactivated',deactivation_reason='account deactivation',updated_at=now() where id=v_team_id;
     update public.fixtures set status='postponed',updated_at=now() where status='scheduled' and (home_team_id=v_team_id or away_team_id=v_team_id);
   else update public.bids set status='cancelled' where bidder_id=p_user_id and status='active'; end if;
 elsif p_status='active' and v_team_id is not null then
   update public.teams set status='active',deactivation_reason='',updated_at=now() where id=v_team_id and deactivation_reason='account deactivation';
 end if;
 update public.profiles set status=p_status,updated_at=now() where id=p_user_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'account_status_change','profile',p_user_id::text,coalesce(p_reason,''),jsonb_build_object('status',target.status),jsonb_build_object('status',p_status));
 insert into public.notifications(user_id,title,message,kind) values(p_user_id,'Account status updated','Your account status is now '||p_status||'. '||coalesce(p_reason,''),'account');
 return jsonb_build_object('ok',true);
end $$;
create or replace function public.admin_set_profile_role(p_user_id uuid,p_role text) returns jsonb language plpgsql security definer set search_path=public as $$
declare target public.profiles%rowtype; active_admins integer;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if p_role not in ('admin','user') then raise exception 'Invalid role.'; end if;
 select * into target from public.profiles where id=p_user_id for update;
 if not found then raise exception 'Account not found.'; end if;
 if target.status='deleted' then raise exception 'Archived accounts cannot change role.'; end if;
 if target.role='admin' and p_role='user' and target.status='active' then
   select count(*) into active_admins from public.profiles where role='admin' and status='active';
   if active_admins<=1 then raise exception 'At least one active Admin must remain.'; end if;
 end if;
 update public.profiles set role=p_role,updated_at=now() where id=p_user_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data)
 values(auth.uid(),'role_change','profile',p_user_id::text,'Role changed by Admin',jsonb_build_object('role',target.role),jsonb_build_object('role',p_role));
 insert into public.notifications(user_id,title,message,kind) values(p_user_id,'Account role updated','Your account role is now '||p_role||'.','account');
 return jsonb_build_object('ok',true,'role',p_role);
end $$;

create or replace function public.admin_set_team_status(p_team_id uuid,p_status text,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.teams%rowtype;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if p_status not in ('active','deactivated','rejected','pending') then raise exception 'Invalid team status.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'Please provide a reason.'; end if;
 select * into t from public.teams where id=p_team_id for update;
 if not found then raise exception 'Team not found.'; end if;
 if p_status='rejected' and t.status<>'pending' then raise exception 'Only a pending team can be rejected.'; end if;
 if p_status='deactivated' then
   update public.bids set status='frozen' where team_id=t.id and status='active';
   update public.transfers set status='cancelled',cancel_reason='Team deactivated by Admin' where status='pending' and (seller_team_id=t.id or buyer_team_id=t.id);
   update public.teams set status='deactivated',deactivation_reason='admin: '||p_reason,updated_at=now() where id=t.id;
   update public.fixtures set status='postponed',updated_at=now() where status='scheduled' and (home_team_id=t.id or away_team_id=t.id);
 elsif p_status='rejected' then
   update public.teams set status='rejected',deactivation_reason='rejected: '||p_reason,updated_at=now() where id=t.id;
 else
   update public.teams set status=p_status,deactivation_reason='',updated_at=now() where id=t.id;
   if p_status='active' then
     update public.bids b set status='active' from public.auctions a where b.auction_id=a.id and b.team_id=t.id and b.status='frozen' and a.status='live' and a.ends_at>now();
     update public.bids b set status='ineligible' from public.auctions a where b.auction_id=a.id and b.team_id=t.id and b.status='frozen' and (a.status<>'live' or a.ends_at<=now());
   end if;
 end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'team_status_change','team',t.id::text,p_reason,jsonb_build_object('status',t.status),jsonb_build_object('status',p_status));
 if t.owner_id is not null then insert into public.notifications(user_id,title,message,kind) values(t.owner_id,'Team status updated',t.name||' is now '||p_status||'. '||p_reason,'team'); end if;
 return jsonb_build_object('ok',true);
end $$;


create or replace function public.admin_edit_auction_rules(p_auction_id uuid,p_base_price numeric,p_min_increment numeric,p_duration_seconds integer,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.auctions%rowtype;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A reason is required for auction rule changes.'; end if;
 if p_base_price<0 or p_base_price<>trunc(p_base_price) or p_min_increment<=0 or p_min_increment<>trunc(p_min_increment) or p_duration_seconds<5 or p_duration_seconds>86400 then raise exception 'Invalid auction rules.'; end if;
 select * into a from public.auctions where id=p_auction_id for update;
 if not found or a.status not in ('draft','paused') then raise exception 'Pause the auction before changing its rules.'; end if;
 update public.auctions set base_price=p_base_price,min_increment=p_min_increment,duration_seconds=p_duration_seconds,remaining_seconds=case when a.status='paused' then p_duration_seconds else remaining_seconds end where id=a.id;
 update public.players set base_price=p_base_price,updated_at=now() where id=a.player_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'edit_auction_rules','auction',a.id::text,p_reason,jsonb_build_object('base_price',a.base_price,'min_increment',a.min_increment,'duration_seconds',a.duration_seconds),jsonb_build_object('base_price',p_base_price,'min_increment',p_min_increment,'duration_seconds',p_duration_seconds));
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.admin_correct_auction(p_auction_id uuid,p_winner_team_id uuid,p_winning_bid numeric,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.auctions%rowtype; old_amount numeric; old_team uuid; new_team public.teams%rowtype; pl public.players%rowtype; spent numeric;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A correction reason is required.'; end if;
 select * into a from public.auctions where id=p_auction_id for update;
 if not found or a.status not in ('closed','unsold') then raise exception 'Only a finalized auction can be corrected.'; end if;
 select * into pl from public.players where id=a.player_id for update;
 old_team:=a.winner_team_id; old_amount:=coalesce(a.winning_bid,0);
 if p_winner_team_id is null then p_winning_bid:=0;
 else
   select * into new_team from public.teams where id=p_winner_team_id and status='active' for update;
   if not found then raise exception 'Corrected winner must be an active team.'; end if;
   if p_winning_bid<a.base_price or p_winning_bid<>trunc(p_winning_bid) then raise exception 'Corrected winning bid must be a whole number at least the auction base price.'; end if;
   if old_team is distinct from p_winner_team_id and (select count(*) from public.players where owner_team_id=new_team.id and status='owned') >= (select squad_limit from public.settings where id=true) then raise exception 'Corrected winner has reached the squad limit.'; end if;
   if old_team is distinct from p_winner_team_id and coalesce(((select position_limits->>pl.position from public.settings where id=true)::integer),0)>0 and (select count(*) from public.players where owner_team_id=new_team.id and status='owned' and position=pl.position)>=coalesce(((select position_limits->>pl.position from public.settings where id=true)::integer),0) then raise exception 'Corrected winner has reached the position-wise limit.'; end if;
   select coalesce(sum(amount),0) into spent from public.transactions where team_id=new_team.id and kind in ('auction_purchase','transfer_purchase','transfer_sale','budget_adjustment');
   if old_team=new_team.id then spent:=spent-old_amount; end if;
   if new_team.budget-spent<p_winning_bid then raise exception 'Correction would make the winner budget negative.'; end if;
 end if;
 -- Append-only reversal and replacement entries preserve the accounting trail.
 if old_team is not null and old_amount>0 then
   insert into public.transactions(team_id,player_id,auction_id,kind,amount,description,created_by) values(old_team,a.player_id,a.id,'budget_adjustment',-old_amount,'Auction correction reversal: '||p_reason,auth.uid());
 end if;
 if p_winner_team_id is not null and p_winning_bid>0 then
   insert into public.transactions(team_id,player_id,auction_id,kind,amount,description,created_by) values(p_winner_team_id,a.player_id,a.id,'auction_purchase',p_winning_bid,'Corrected auction purchase: '||p_reason,auth.uid());
   update public.players set owner_team_id=p_winner_team_id,status='owned',updated_at=now() where id=a.player_id;
 else
   update public.players set owner_team_id=null,status='unsold',updated_at=now() where id=a.player_id;
 end if;
 update public.bids set status='ineligible' where auction_id=a.id and status='won';
 if p_winner_team_id is not null then
   update public.bids set status='won' where id=(select id from public.bids where auction_id=a.id and team_id=p_winner_team_id and amount=p_winning_bid order by created_at asc limit 1);
 end if;
 update public.auctions set status=case when p_winner_team_id is null then 'unsold' else 'closed' end,winner_team_id=p_winner_team_id,winning_bid=case when p_winner_team_id is null then null else p_winning_bid end,result_note='Corrected: '||p_reason,finalized_at=now() where id=a.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'correct_auction_result','auction',a.id::text,p_reason,jsonb_build_object('winner_team_id',old_team,'winning_bid',old_amount),jsonb_build_object('winner_team_id',p_winner_team_id,'winning_bid',p_winning_bid));
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.admin_adjust_budget(p_team_id uuid,p_delta numeric,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.teams%rowtype; current_spent numeric;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'Please provide a correction reason.'; end if;
 if p_delta<>trunc(p_delta) then raise exception 'Budget adjustments must be whole numbers.'; end if;
 select * into t from public.teams where id=p_team_id for update;
 select coalesce(sum(amount),0) into current_spent from public.transactions where team_id=t.id and kind in ('auction_purchase','transfer_purchase','transfer_sale','budget_adjustment');
 if t.budget-current_spent+p_delta<0 then raise exception 'Adjustment would make available budget negative.'; end if;
 insert into public.transactions(team_id,kind,amount,description,created_by) values(t.id,'budget_adjustment',-p_delta,p_reason,auth.uid());
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'adjust_budget','team',t.id::text,p_reason,jsonb_build_object('available_budget',t.budget-current_spent),jsonb_build_object('available_budget',t.budget-current_spent+p_delta));
 return jsonb_build_object('ok',true,'available_budget',t.budget-current_spent+p_delta);
end $$;


create or replace function public.create_transfer(p_player_id uuid,p_buyer_team_id uuid,p_amount numeric) returns jsonb language plpgsql security definer set search_path=public as $$
declare seller_id uuid; buyer public.teams%rowtype; player_row public.players%rowtype; tr public.transfers%rowtype;
begin
 if not public.is_active_user() then raise exception 'Your account is not active.'; end if;
 seller_id:=public.my_team_id();
 if seller_id is null or not exists(select 1 from public.teams where id=seller_id and status='active') then raise exception 'You need an active team.'; end if;
 select * into player_row from public.players where id=p_player_id for update;
 if not found or player_row.owner_team_id<>seller_id or player_row.status<>'owned' then raise exception 'You can only transfer a player owned by your team.'; end if;
 select * into buyer from public.teams where id=p_buyer_team_id and status='active';
 if not found or buyer.id=seller_id or buyer.owner_id is null or not exists(select 1 from public.profiles where id=buyer.owner_id and status='active') then raise exception 'Select another active team assigned to an approved User.'; end if;
 if exists(select 1 from public.auctions where player_id=p_player_id and status in ('draft','live','paused')) then raise exception 'Player is listed in an auction.'; end if;
 if exists(select 1 from public.transfers where player_id=p_player_id and status='pending') then raise exception 'Player already has a pending transfer.'; end if;
 insert into public.transfers(player_id,seller_team_id,buyer_team_id,amount,requested_by,seller_accepted) values(p_player_id,seller_id,buyer.id,p_amount,auth.uid(),true) returning * into tr;
 insert into public.notifications(user_id,title,message,kind) values(buyer.owner_id,'Transfer request','A transfer request was received for '||player_row.name||' at '||p_amount||'.','transfer');
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'create_transfer','transfer',tr.id::text,jsonb_build_object('player_id',p_player_id,'buyer_team_id',buyer.id,'amount',p_amount));
 return jsonb_build_object('ok',true,'transfer_id',tr.id);
end $$;

create or replace function public.admin_set_player_market_status(p_player_id uuid,p_status text,p_reason text) returns jsonb language plpgsql security definer set search_path=public as $$
declare pl public.players%rowtype;
begin
 if not public.is_admin() then raise exception 'Admin permission required.'; end if;
 if p_status not in ('free_agent','unavailable') then raise exception 'Choose free_agent or unavailable.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A reason is required.'; end if;
 select * into pl from public.players where id=p_player_id for update;
 if not found or pl.owner_team_id is not null or pl.status<>'unsold' then raise exception 'Only an unsold free player can be changed this way.'; end if;
 if exists(select 1 from public.auctions a where a.player_id=pl.id and a.status in ('draft','live','paused')) or exists(select 1 from public.transfers tr where tr.player_id=pl.id and tr.status='pending') then raise exception 'Player is locked by another operation.'; end if;
 update public.players set status=p_status,updated_at=now() where id=pl.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'set_player_market_status','player',pl.id::text,p_reason,jsonb_build_object('status',pl.status),jsonb_build_object('status',p_status));
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.release_player(p_player_id uuid,p_reason text default 'Released by team') returns jsonb language plpgsql security definer set search_path=public as $$
declare pl public.players%rowtype; team_id uuid;
begin
 if not public.is_active_user() then raise exception 'Your account is not active.'; end if;
 team_id:=public.my_team_id();
 if team_id is null or not exists(select 1 from public.teams where id=team_id and status='active') then raise exception 'Your team is not active.'; end if;
 select * into pl from public.players where id=p_player_id for update;
 if not found or pl.owner_team_id<>team_id or pl.status<>'owned' then raise exception 'Player is not owned by your active team.'; end if;
 if exists(select 1 from public.auctions where player_id=pl.id and status in ('draft','live','paused')) or exists(select 1 from public.transfers where player_id=pl.id and status='pending') then raise exception 'Player has an active auction or pending transfer.'; end if;
 update public.players set owner_team_id=null,status='free_agent',updated_at=now() where id=pl.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data) values(auth.uid(),'release_player','player',pl.id::text,p_reason,jsonb_build_object('owner_team_id',team_id),jsonb_build_object('owner_team_id',null,'status','free_agent'));
 return jsonb_build_object('ok',true);
end $$;


create or replace function public.send_notification(p_user_id uuid,p_title text,p_message text,p_kind text default 'info') returns jsonb language plpgsql security definer set search_path=public as $$
declare allowed boolean:=false;
begin
 if auth.uid() is null then raise exception 'Authentication required.'; end if;
 if public.is_admin() then allowed:=true;
 elsif p_user_id=auth.uid() then allowed:=true;
 elsif public.is_active_user() and exists(select 1 from public.profiles p where p.id=p_user_id and p.role='admin' and p.status='active') then allowed:=true;
 elsif public.is_active_user() and exists(select 1 from public.transfers tr join public.teams st on st.id=tr.seller_team_id join public.teams bt on bt.id=tr.buyer_team_id where tr.requested_by=auth.uid() and tr.status='pending' and (st.owner_id=p_user_id or bt.owner_id=p_user_id)) then allowed:=true;
 end if;
 if not allowed then raise exception 'You cannot send a notification to this account.'; end if;
 insert into public.notifications(user_id,title,message,kind) values(p_user_id,p_title,p_message,p_kind);
 return jsonb_build_object('ok',true);
end $$;


create or replace function public.notify_admins(p_title text,p_message text,p_kind text default 'info') returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
 if auth.uid() is null or not public.is_active_user() then raise exception 'Active account required.'; end if;
 insert into public.notifications(user_id,title,message,kind)
 select id,p_title,p_message,p_kind from public.profiles where role='admin' and status='active';
 get diagnostics n=row_count;
 return n;
end $$;

-- RLS is mandatory: browser-side checks are not security boundaries.
alter table public.profiles enable row level security;
alter table public.settings enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.player_proposals enable row level security;
alter table public.auctions enable row level security;
alter table public.bids enable row level security;
alter table public.transfers enable row level security;
alter table public.leagues enable row level security;
alter table public.fixtures enable row level security;
alter table public.fixture_correction_requests enable row level security;
alter table public.transactions enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "profiles read self or admin" on public.profiles;
create policy "profiles read self or admin" on public.profiles for select using(id=auth.uid() or public.is_admin());
drop policy if exists "profile update self or admin" on public.profiles;
drop policy if exists "admin update profiles only" on public.profiles;
create policy "admin update profiles only" on public.profiles for update using(public.is_admin()) with check(public.is_admin());
drop policy if exists "public settings read" on public.settings;
create policy "public settings read" on public.settings for select using(true);
drop policy if exists "admin settings update" on public.settings;
create policy "admin settings update" on public.settings for update using(public.is_admin()) with check(public.is_admin());
drop policy if exists "public teams read" on public.teams;
create policy "teams owner or admin read" on public.teams for select using(owner_id=auth.uid() or public.is_admin());
drop policy if exists "active user create team" on public.teams;
create policy "active user create team" on public.teams for insert with check(public.is_active_user() and owner_id=auth.uid() and status='active' and budget=(select default_budget from public.settings where id=true));
drop policy if exists "owner or admin update team" on public.teams;
drop policy if exists "admin update team" on public.teams;
create policy "admin update team" on public.teams for update using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin delete team" on public.teams;
drop policy if exists "public players read" on public.players;
create policy "admin players read" on public.players for select using(public.is_admin());
drop policy if exists "admin player insert" on public.players;
create policy "admin player insert" on public.players for insert with check(public.is_admin());
drop policy if exists "admin player update" on public.players;
create policy "admin player update" on public.players for update using(public.is_admin() and not exists(select 1 from public.auctions a where a.player_id=players.id and a.status in ('draft','live','paused')) and not exists(select 1 from public.transfers tr where tr.player_id=players.id and tr.status='pending')) with check(public.is_admin() and not exists(select 1 from public.auctions a where a.player_id=players.id and a.status in ('draft','live','paused')) and not exists(select 1 from public.transfers tr where tr.player_id=players.id and tr.status='pending'));
drop policy if exists "admin player delete" on public.players;
create policy "admin player delete" on public.players for delete using(public.is_admin() and owner_team_id is null and not exists(select 1 from public.auctions a where a.player_id=players.id and a.status in ('draft','live','paused')) and not exists(select 1 from public.transfers tr where tr.player_id=players.id and tr.status='pending'));
drop policy if exists "proposal read own or admin" on public.player_proposals;
create policy "proposal read own or admin" on public.player_proposals for select using(proposer_id=auth.uid() or public.is_admin());
drop policy if exists "user submit proposal" on public.player_proposals;
create policy "user submit proposal" on public.player_proposals for insert with check(public.is_active_user() and proposer_id=auth.uid());
drop policy if exists "proposal update own pending or admin" on public.player_proposals;
create policy "proposal update own pending or admin" on public.player_proposals for update using((proposer_id=auth.uid() and status='pending') or public.is_admin()) with check((proposer_id=auth.uid() and status='withdrawn') or public.is_admin());
drop policy if exists "public auctions read" on public.auctions;
create policy "admin auctions read" on public.auctions for select using(public.is_admin());
drop policy if exists "admin auction manage" on public.auctions;
create policy "admin auction manage" on public.auctions for all using(public.is_admin()) with check(public.is_admin());
drop policy if exists "bid history own or admin" on public.bids;
create policy "bid history own or admin" on public.bids for select using(bidder_id=auth.uid() or public.is_admin());
drop policy if exists "public leagues read" on public.leagues;
create policy "public leagues read" on public.leagues for select using(true);
drop policy if exists "admin leagues manage" on public.leagues;
create policy "admin leagues manage" on public.leagues for all using(public.is_admin()) with check(public.is_admin());
drop policy if exists "public fixtures read" on public.fixtures;
create policy "admin fixtures read" on public.fixtures for select using(public.is_admin());
drop policy if exists "admin fixtures manage" on public.fixtures;
create policy "admin fixtures manage" on public.fixtures for all using(public.is_admin()) with check(public.is_admin());
drop policy if exists "transfer participants or admin read" on public.transfers;
create policy "transfer participants or admin read" on public.transfers for select using(public.is_admin() or seller_team_id=public.my_team_id() or buyer_team_id=public.my_team_id());
drop policy if exists "active user create transfer" on public.transfers;
drop policy if exists "active user create transfer via rpc only" on public.transfers;
-- Transfer creation is performed by the checked create_transfer RPC, not direct table inserts.
drop policy if exists "fixture correction request read own or admin" on public.fixture_correction_requests;
create policy "fixture correction request read own or admin" on public.fixture_correction_requests for select using(user_id=auth.uid() or public.is_admin());
drop policy if exists "active user request fixture correction" on public.fixture_correction_requests;
create policy "active user request fixture correction" on public.fixture_correction_requests for insert with check(public.is_active_user() and user_id=auth.uid());
drop policy if exists "admin review fixture correction" on public.fixture_correction_requests;
create policy "admin review fixture correction" on public.fixture_correction_requests for update using(public.is_admin()) with check(public.is_admin());
drop policy if exists "transaction own team or admin read" on public.transactions;
create policy "transaction own team or admin read" on public.transactions for select using(public.is_admin() or team_id=public.my_team_id());
drop policy if exists "notifications own or admin read" on public.notifications;
create policy "notifications own or admin read" on public.notifications for select using(user_id=auth.uid() or public.is_admin());
drop policy if exists "send notifications to self or admins" on public.notifications;
-- Notification creation is restricted to a checked security-definer RPC.
drop policy if exists "notifications owner mark read" on public.notifications;
create policy "notifications owner mark read" on public.notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists "audit admin read" on public.audit_logs;
create policy "audit admin read" on public.audit_logs for select using(public.is_admin());

-- Execute sensitive operations only through these checked RPCs; never expose service-role credentials.
grant execute on function public.place_bid(uuid,numeric) to authenticated;
grant execute on function public.withdraw_bid(uuid) to authenticated;
grant execute on function public.resolve_expired_auctions() to authenticated;
grant execute on function public.admin_set_auction_status(uuid,text,text) to authenticated;
grant execute on function public.admin_save_fixture_result(uuid,integer,integer,text) to authenticated;
grant execute on function public.admin_reschedule_fixture(uuid,timestamptz,text) to authenticated;
grant execute on function public.admin_set_fixture_status(uuid,text,text) to authenticated;
grant execute on function public.respond_transfer(uuid,boolean) to authenticated;
grant execute on function public.admin_adjust_budget(uuid,numeric,text) to authenticated;
grant execute on function public.admin_correct_auction(uuid,uuid,numeric,text) to authenticated;
grant execute on function public.admin_edit_auction_rules(uuid,numeric,numeric,integer,text) to authenticated;
grant execute on function public.admin_set_profile_status(uuid,text,text) to authenticated;
grant execute on function public.admin_set_profile_role(uuid,text) to authenticated;
grant execute on function public.update_my_team(text,text,text,text) to authenticated;
grant execute on function public.admin_delete_team(uuid,text) to authenticated;
grant execute on function public.admin_prepare_account_deletion(uuid,text) to authenticated;
revoke all on function public.admin_set_profile_status(uuid,text,text) from public, anon;
revoke all on function public.admin_set_profile_role(uuid,text) from public, anon;
revoke all on function public.update_my_team(text,text,text,text) from public, anon;
revoke all on function public.admin_delete_team(uuid,text) from public, anon;
revoke all on function public.admin_prepare_account_deletion(uuid,text) from public, anon;
grant execute on function public.admin_set_team_status(uuid,text,text) to authenticated;
revoke all on function public.admin_set_team_status(uuid,text,text) from public, anon;
grant execute on function public.create_transfer(uuid,uuid,numeric) to authenticated;
grant execute on function public.release_player(uuid,text) to authenticated;
grant execute on function public.admin_set_player_market_status(uuid,text,text) to authenticated;
grant execute on function public.send_notification(uuid,text,text,text) to authenticated;
grant execute on function public.notify_admins(text,text,text) to authenticated;
grant execute on function public.update_my_profile(text,text) to authenticated;
grant execute on function public.get_auction_leaders() to authenticated;

revoke all on function public.place_bid(uuid,numeric) from public, anon;
revoke all on function public.withdraw_bid(uuid) from public, anon;
revoke all on function public.resolve_expired_auctions() from public, anon;
revoke all on function public.admin_set_auction_status(uuid,text,text) from public, anon;
revoke all on function public.admin_save_fixture_result(uuid,integer,integer,text) from public, anon;
revoke all on function public.admin_reschedule_fixture(uuid,timestamptz,text) from public, anon;
revoke all on function public.admin_set_fixture_status(uuid,text,text) from public, anon;
revoke all on function public.respond_transfer(uuid,boolean) from public, anon;
revoke all on function public.admin_adjust_budget(uuid,numeric,text) from public, anon;
revoke all on function public.admin_correct_auction(uuid,uuid,numeric,text) from public, anon;
revoke all on function public.admin_edit_auction_rules(uuid,numeric,numeric,integer,text) from public, anon;
revoke all on function public.admin_set_profile_status(uuid,text,text) from public, anon;
revoke all on function public.admin_set_profile_role(uuid,text) from public, anon;
revoke all on function public.update_my_team(text,text,text,text) from public, anon;
revoke all on function public.admin_delete_team(uuid,text) from public, anon;
revoke all on function public.admin_prepare_account_deletion(uuid,text) from public, anon;
revoke all on function public.admin_set_team_status(uuid,text,text) from public, anon;
revoke all on function public.create_transfer(uuid,uuid,numeric) from public, anon;
revoke all on function public.release_player(uuid,text) from public, anon;
revoke all on function public.admin_set_player_market_status(uuid,text,text) from public, anon;
revoke all on function public.send_notification(uuid,text,text,text) from public, anon;
revoke all on function public.notify_admins(text,text,text) from public, anon;
revoke all on function public.update_my_profile(text,text) from public, anon;
revoke all on function public.get_auction_leaders() from public, anon;

