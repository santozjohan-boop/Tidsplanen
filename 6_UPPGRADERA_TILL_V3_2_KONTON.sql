-- Ramavtalade tidsplaner v3.2 – e-post/lösenord via Supabase Auth.
-- Kör EN gång i Supabase SQL Editor. Befintliga företag/projektfiler raderas inte.
begin;

create table if not exists public.rtp_members (
 id uuid primary key default gen_random_uuid(),
 license_id uuid not null references public.rtp_licenses(id) on delete cascade,
 auth_user_id uuid unique,
 email text not null,
 display_name text not null default '',
 role text not null default 'Användare' check (role in ('Företagsadmin','Projektledare','Användare','Läsare')),
 enabled boolean not null default true,
 created_at timestamptz not null default now(),
 unique (license_id,email)
);
create unique index if not exists rtp_members_email_lower_uq on public.rtp_members(lower(email));

create table if not exists public.rtp_system_admins (
 auth_user_id uuid primary key,
 email text not null unique,
 created_at timestamptz not null default now()
);
alter table public.rtp_members enable row level security;
alter table public.rtp_system_admins enable row level security;
revoke all on public.rtp_members from anon,authenticated;
revoke all on public.rtp_system_admins from anon,authenticated;

-- Migrera befintliga e-postadresser från användarnycklar. Admin -> Företagsadmin.
insert into public.rtp_members(license_id,email,display_name,role,enabled)
select k.license_id,lower(btrim(k.email)),coalesce(k.display_name,''),case when k.role='Admin' then 'Företagsadmin' else k.role end,k.enabled
from public.rtp_user_keys k
where nullif(btrim(k.email),'') is not null
on conflict do nothing;

create or replace function public.rtp_my_profile()
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); em text; m public.rtp_members%rowtype; l public.rtp_licenses%rowtype; sys boolean;
begin
 if uid is null then return jsonb_build_object('ok',false,'message','Inte inloggad.'); end if;
 select lower(email) into em from auth.users where id=uid;
 select exists(select 1 from public.rtp_system_admins where auth_user_id=uid) into sys;
 select * into m from public.rtp_members where (auth_user_id=uid or (auth_user_id is null and lower(email)=em)) and enabled limit 1;
 if found and m.auth_user_id is null then update public.rtp_members set auth_user_id=uid where id=m.id; m.auth_user_id:=uid; end if;
 if not found then
   if sys then return jsonb_build_object('ok',true,'scope','system','email',em,'role','Systemadmin','display_name','Systemadmin'); end if;
   return jsonb_build_object('ok',false,'message','Din e-postadress är inte tillagd i något företag. Kontakta företagets administratör.');
 end if;
 select * into l from public.rtp_licenses where id=m.license_id;
 if not found or not l.enabled then return jsonb_build_object('ok',false,'message','Företagskontot är spärrat.'); end if;
 if l.expires_at is not null and l.expires_at<current_date then return jsonb_build_object('ok',false,'message','Företagslicensen har gått ut.'); end if;
 return jsonb_build_object('ok',true,'scope',case when sys then 'system' else 'company' end,'license_id',l.id,'customer',l.customer_name,'expires_at',l.expires_at,'role',m.role,'display_name',m.display_name,'email',em,'admin_email',l.admin_email,'onedrive_folder_name',l.onedrive_folder_name,'onedrive_share_url',l.onedrive_share_url,'ai_provider',l.ai_provider,'ai_model',l.ai_model);
end $$;

create or replace function public.rtp_activate_account(p_installation_id text,p_computer_name text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p jsonb; lid uuid; a public.rtp_installations%rowtype; n int; mx int;
begin
 p:=public.rtp_my_profile(); if not coalesce((p->>'ok')::boolean,false) then return p; end if;
 if p->>'license_id' is null then return jsonb_build_object('ok',false,'message','Systemadmin saknar företagsarbetsyta i huvudprogrammet.'); end if;
 lid:=(p->>'license_id')::uuid; select max_devices into mx from public.rtp_licenses where id=lid;
 select * into a from public.rtp_installations where license_id=lid and installation_id=p_installation_id limit 1;
 if not found then
  select count(*) into n from public.rtp_installations where license_id=lid and active;
  if n>=mx then return jsonb_build_object('ok',false,'message','Företagets maxantal aktiva datorer är uppnått.'); end if;
  insert into public.rtp_installations(license_id,installation_id,computer_name,active) values(lid,p_installation_id,p_computer_name,true);
 else update public.rtp_installations set active=true,computer_name=coalesce(p_computer_name,computer_name),last_seen_at=now() where id=a.id; end if;
 return p;
end $$;

create or replace function public.rtp_bootstrap_system_admin(p_old_token text,p_email text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare expected text; uid uuid:=auth.uid(); em text;
begin
 if uid is null then return jsonb_build_object('ok',false,'message','Logga in med e-postkontot först.'); end if;
 select admin_token into expected from public.rtp_admin_config where id=1;
 if expected is null or p_old_token is distinct from expected then return jsonb_build_object('ok',false,'message','Fel gammal systemadminnyckel.'); end if;
 select lower(email) into em from auth.users where id=uid;
 if em<>lower(btrim(p_email)) then return jsonb_build_object('ok',false,'message','E-postadressen matchar inte det inloggade kontot.'); end if;
 insert into public.rtp_system_admins(auth_user_id,email) values(uid,em) on conflict(auth_user_id) do update set email=excluded.email;
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.rtp_admin_v32(p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); sys boolean; m public.rtp_members%rowtype; scope_license uuid; l public.rtp_licenses%rowtype; cnt int; target uuid;
begin
 if uid is null then return jsonb_build_object('ok',false,'message','Inte inloggad.'); end if;
 select exists(select 1 from public.rtp_system_admins where auth_user_id=uid) into sys;
 select * into m from public.rtp_members where auth_user_id=uid and enabled limit 1;
 if found and m.role='Företagsadmin' then scope_license:=m.license_id;
 elsif not sys then return jsonb_build_object('ok',false,'message','Adminbehörighet saknas.'); end if;
 if p_action='login' then return jsonb_build_object('ok',true,'scope',case when sys then 'system' else 'company' end,'license_id',scope_license); end if;
 if p_action='list' then return jsonb_build_object('ok',true,'licenses',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'customer',x.customer_name,'max_users',x.max_devices,'expires_at',x.expires_at,'active',x.enabled,'users',(select count(*) from public.rtp_members mm where mm.license_id=x.id and mm.enabled)) order by x.customer_name),'[]'::jsonb) from public.rtp_licenses x where sys or x.id=scope_license)); end if;
 if p_action='create' then
  if not sys then return jsonb_build_object('ok',false,'message','Endast systemadmin kan skapa företag.'); end if;
  insert into public.rtp_licenses(license_key,customer_name,max_devices,expires_at,enabled) values('AUTH-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),btrim(p_data->>'customer'),greatest(1,coalesce(nullif(p_data->>'max_users','')::int,10)),nullif(p_data->>'expires_at','')::date,true) returning * into l;
  return jsonb_build_object('ok',true,'id',l.id);
 end if;
 begin target:=(p_data->>'id')::uuid; select * into l from public.rtp_licenses where id=target; exception when others then return jsonb_build_object('ok',false,'message','Ogiltigt företags-ID.'); end;
 if not found then return jsonb_build_object('ok',false,'message','Företaget hittades inte.'); end if;
 if not sys and l.id<>scope_license then return jsonb_build_object('ok',false,'message','Åtkomst nekad.'); end if;
 if p_action='toggle' then if not sys then return jsonb_build_object('ok',false,'message','Endast systemadmin kan spärra företag.'); end if; update public.rtp_licenses set enabled=coalesce((p_data->>'active')::boolean,false),updated_at=now() where id=l.id; return jsonb_build_object('ok',true); end if;
 if p_action='delete_company' then
  if not sys then return jsonb_build_object('ok',false,'message','Endast systemadmin kan ta bort företag.'); end if;
  if p_data->>'confirm_name' is distinct from l.customer_name then return jsonb_build_object('ok',false,'message','Företagsnamnet matchar inte.'); end if;
  delete from public.rtp_installations where license_id=l.id; delete from public.rtp_user_keys where license_id=l.id; delete from public.rtp_members where license_id=l.id; delete from public.rtp_license_events where license_id=l.id; delete from public.rtp_licenses where id=l.id;
  return jsonb_build_object('ok',true);
 end if;
 if p_action='workspace_get' then return jsonb_build_object('ok',true,'workspace',jsonb_build_object('onedrive_folder_name',l.onedrive_folder_name,'onedrive_share_url',l.onedrive_share_url,'ai_provider',l.ai_provider,'ai_model',l.ai_model)); end if;
 if p_action='workspace_set' then update public.rtp_licenses set onedrive_folder_name=coalesce(nullif(p_data->>'onedrive_folder_name',''),'Ramavtalade tidsplaner'),onedrive_share_url=nullif(p_data->>'onedrive_share_url',''),ai_provider=coalesce(nullif(p_data->>'ai_provider',''),'Gemini'),ai_model=coalesce(nullif(p_data->>'ai_model',''),'gemini-3.5-flash'),updated_at=now() where id=l.id; return jsonb_build_object('ok',true); end if;
 if p_action='users' then return jsonb_build_object('ok',true,'users',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'display_name',display_name,'email',email,'role',role,'enabled',enabled) order by display_name),'[]'::jsonb) from public.rtp_members where license_id=l.id)); end if;
 if p_action='user_create' then
  select count(*) into cnt from public.rtp_members where license_id=l.id and enabled; if cnt>=l.max_devices then return jsonb_build_object('ok',false,'message','Max antal användare är uppnått.'); end if;
  if coalesce(p_data->>'role','') not in ('Företagsadmin','Projektledare','Användare','Läsare') then return jsonb_build_object('ok',false,'message','Ogiltig roll.'); end if;
  insert into public.rtp_members(license_id,email,display_name,role) values(l.id,lower(btrim(p_data->>'email')),btrim(p_data->>'display_name'),p_data->>'role'); return jsonb_build_object('ok',true);
 end if;
 if p_action='user_toggle' then update public.rtp_members set enabled=coalesce((p_data->>'active')::boolean,false) where license_id=l.id and id=(p_data->>'member_id')::uuid; return jsonb_build_object('ok',true); end if;
 if p_action='devices' then return jsonb_build_object('ok',true,'devices',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'device_name',coalesce(computer_name,''),'active',active,'last_seen',last_seen_at) order by last_seen_at desc),'[]'::jsonb) from public.rtp_installations where license_id=l.id)); end if;
 if p_action='release_device' then update public.rtp_installations set active=false where license_id=l.id and id=(p_data->>'activation_id')::uuid; return jsonb_build_object('ok',true); end if;
 return jsonb_build_object('ok',false,'message','Okänd adminåtgärd.');
end $$;

revoke all on function public.rtp_my_profile() from public,anon;
revoke all on function public.rtp_activate_account(text,text) from public,anon;
revoke all on function public.rtp_admin_v32(text,jsonb) from public,anon;
revoke all on function public.rtp_bootstrap_system_admin(text,text) from public,anon;
grant execute on function public.rtp_my_profile() to authenticated;
grant execute on function public.rtp_activate_account(text,text) to authenticated;
grant execute on function public.rtp_admin_v32(text,jsonb) to authenticated;
grant execute on function public.rtp_bootstrap_system_admin(text,text) to authenticated;
commit;
