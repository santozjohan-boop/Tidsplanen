-- Ramavtalade tidsplaner v3.1 - ICKE-DESTRUKTIV UPPGRADERING
begin;

alter table public.rtp_licenses add column if not exists admin_email text;
alter table public.rtp_licenses add column if not exists onedrive_folder_name text default 'Ramavtalade tidsplaner';
alter table public.rtp_licenses add column if not exists onedrive_share_url text;
alter table public.rtp_licenses add column if not exists ai_provider text default 'Gemini';
alter table public.rtp_licenses add column if not exists ai_model text default 'gemini-3.5-flash';

create table if not exists public.rtp_user_keys (
 id uuid primary key default gen_random_uuid(),
 license_id uuid not null references public.rtp_licenses(id) on delete cascade,
 user_key text not null unique,
 display_name text not null,
 email text,
 role text not null default 'Användare' check(role in ('Admin','Projektledare','Användare','Läsare')),
 enabled boolean not null default true,
 created_at timestamptz not null default now()
);
alter table public.rtp_user_keys enable row level security;
revoke all on table public.rtp_user_keys from anon, authenticated;

-- Klient-RPC: undernyckeln identifierar både företag och användare.
create or replace function public.rtp_activate_user(
 p_user_key text, p_installation_id text, p_computer_name text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare u public.rtp_user_keys%rowtype; l public.rtp_licenses%rowtype; a public.rtp_installations%rowtype; n int;
begin
 select * into u from public.rtp_user_keys where upper(user_key)=upper(btrim(p_user_key)) limit 1;
 if not found or not u.enabled then return jsonb_build_object('ok',false,'message','Användarnyckeln är ogiltig eller spärrad.'); end if;
 select * into l from public.rtp_licenses where id=u.license_id;
 if not l.enabled then return jsonb_build_object('ok',false,'message','Företagslicensen är spärrad.'); end if;
 if l.expires_at is not null and l.expires_at<current_date then return jsonb_build_object('ok',false,'message','Företagslicensen har gått ut.'); end if;
 select * into a from public.rtp_installations where license_id=l.id and installation_id=p_installation_id limit 1;
 if not found then
   select count(*) into n from public.rtp_installations where license_id=l.id and active;
   if n>=l.max_devices then return jsonb_build_object('ok',false,'message','Licensens maxantal datorer är uppnått.'); end if;
   insert into public.rtp_installations(license_id,installation_id,computer_name,active) values(l.id,p_installation_id,p_computer_name,true);
 else
   update public.rtp_installations set active=true,computer_name=coalesce(p_computer_name,computer_name),last_seen_at=now() where id=a.id;
 end if;
 return jsonb_build_object('ok',true,'customer',l.customer_name,'expires_at',l.expires_at,'role',u.role,'display_name',u.display_name,
  'admin_email',l.admin_email,'onedrive_folder_name',l.onedrive_folder_name,'onedrive_share_url',l.onedrive_share_url,
  'ai_provider',l.ai_provider,'ai_model',l.ai_model);
end $$;

create or replace function public.rtp_validate_user(p_user_key text,p_installation_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u public.rtp_user_keys%rowtype; l public.rtp_licenses%rowtype; a public.rtp_installations%rowtype;
begin
 select * into u from public.rtp_user_keys where upper(user_key)=upper(btrim(p_user_key)) limit 1;
 if not found or not u.enabled then return jsonb_build_object('ok',false,'message','Användarnyckeln är ogiltig eller spärrad.'); end if;
 select * into l from public.rtp_licenses where id=u.license_id;
 if not l.enabled then return jsonb_build_object('ok',false,'message','Företagslicensen är spärrad.'); end if;
 if l.expires_at is not null and l.expires_at<current_date then return jsonb_build_object('ok',false,'message','Företagslicensen har gått ut.'); end if;
 select * into a from public.rtp_installations where license_id=l.id and installation_id=p_installation_id and active limit 1;
 if not found then return jsonb_build_object('ok',false,'message','Datorn är inte aktiv på licensen.'); end if;
 update public.rtp_installations set last_seen_at=now() where id=a.id;
 return jsonb_build_object('ok',true,'customer',l.customer_name,'expires_at',l.expires_at,'role',u.role,'display_name',u.display_name,
  'admin_email',l.admin_email,'onedrive_folder_name',l.onedrive_folder_name,'onedrive_share_url',l.onedrive_share_url,
  'ai_provider',l.ai_provider,'ai_model',l.ai_model);
end $$;
revoke all on function public.rtp_activate_user(text,text,text) from public,authenticated;
revoke all on function public.rtp_validate_user(text,text) from public,authenticated;
grant execute on function public.rtp_activate_user(text,text,text) to anon;
grant execute on function public.rtp_validate_user(text,text) to anon;

-- Ersätt admin-RPC med v3.1-funktioner, men behåll samma admin-token.
create or replace function public.rtp_admin(p_token text,p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare expected text; l public.rtp_licenses%rowtype; u public.rtp_user_keys%rowtype; newkey text; cnt int;
begin
 select admin_token into expected from public.rtp_admin_config where id=1;
 if expected is null or p_token is distinct from expected then return jsonb_build_object('ok',false,'message','Fel adminnyckel.'); end if;
 if p_action='list' then return jsonb_build_object('ok',true,'licenses',(select coalesce(jsonb_agg(jsonb_build_object(
   'id',x.id,'license_key',x.license_key,'customer',x.customer_name,'max_devices',x.max_devices,'expires_at',x.expires_at,'active',x.enabled,
   'devices',(select count(*) from public.rtp_installations a where a.license_id=x.id and a.active),
   'users',(select count(*) from public.rtp_user_keys k where k.license_id=x.id and k.enabled),
   'admin_email',x.admin_email,'onedrive_folder_name',x.onedrive_folder_name,'onedrive_share_url',x.onedrive_share_url,'ai_provider',x.ai_provider,'ai_model',x.ai_model
 ) order by x.customer_name),'[]'::jsonb) from public.rtp_licenses x)); end if;
 if p_action='create' then
   newkey:='RTP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4));
   insert into public.rtp_licenses(license_key,customer_name,max_devices,expires_at,enabled) values(newkey,btrim(p_data->>'customer'),greatest(1,coalesce(nullif(p_data->>'max_devices','')::int,1)),nullif(p_data->>'expires_at','')::date,true) returning * into l;
   return jsonb_build_object('ok',true,'license_key',l.license_key); end if;
 begin select * into l from public.rtp_licenses where id=(p_data->>'id')::uuid; exception when others then return jsonb_build_object('ok',false,'message','Ogiltigt licens-ID.'); end;
 if not found then return jsonb_build_object('ok',false,'message','Licensen hittades inte.'); end if;
 if p_action='toggle' then update public.rtp_licenses set enabled=coalesce((p_data->>'active')::boolean,false),updated_at=now() where id=l.id; return jsonb_build_object('ok',true); end if;
 if p_action='update' then update public.rtp_licenses set customer_name=coalesce(nullif(btrim(p_data->>'customer'),''),customer_name),max_devices=coalesce(nullif(p_data->>'max_devices','')::int,max_devices),expires_at=case when p_data?'expires_at' then nullif(p_data->>'expires_at','')::date else expires_at end,updated_at=now() where id=l.id; return jsonb_build_object('ok',true); end if;
 if p_action='workspace_get' then return jsonb_build_object('ok',true,'workspace',jsonb_build_object('admin_email',l.admin_email,'onedrive_folder_name',l.onedrive_folder_name,'onedrive_share_url',l.onedrive_share_url,'ai_provider',l.ai_provider,'ai_model',l.ai_model)); end if;
 if p_action='workspace_set' then update public.rtp_licenses set admin_email=nullif(p_data->>'admin_email',''),onedrive_folder_name=coalesce(nullif(p_data->>'onedrive_folder_name',''),'Ramavtalade tidsplaner'),onedrive_share_url=nullif(p_data->>'onedrive_share_url',''),ai_provider=coalesce(nullif(p_data->>'ai_provider',''),'Gemini'),ai_model=coalesce(nullif(p_data->>'ai_model',''),'gemini-3.5-flash'),updated_at=now() where id=l.id; return jsonb_build_object('ok',true); end if;
 if p_action='users' then return jsonb_build_object('ok',true,'users',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'user_key',user_key,'display_name',display_name,'email',email,'role',role,'enabled',enabled) order by display_name),'[]'::jsonb) from public.rtp_user_keys where license_id=l.id)); end if;
 if p_action='user_create' then
   select count(*) into cnt from public.rtp_user_keys where license_id=l.id and enabled;
   if cnt>=l.max_devices then return jsonb_build_object('ok',false,'message','Max antal aktiva användarnycklar är uppnått.'); end if;
   newkey:='RTP-U-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4));
   insert into public.rtp_user_keys(license_id,user_key,display_name,email,role) values(l.id,newkey,btrim(p_data->>'display_name'),nullif(btrim(p_data->>'email'),''),coalesce(nullif(p_data->>'role',''),'Användare')) returning * into u;
   return jsonb_build_object('ok',true,'user_key',u.user_key); end if;
 if p_action='user_toggle' then update public.rtp_user_keys set enabled=coalesce((p_data->>'active')::boolean,false) where license_id=l.id and id=(p_data->>'user_id')::uuid; return jsonb_build_object('ok',true); end if;
 if p_action='devices' then return jsonb_build_object('ok',true,'devices',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'device_name',coalesce(computer_name,''),'device_id',installation_id,'active',active,'activated_at',activated_at,'last_seen',last_seen_at) order by last_seen_at desc),'[]'::jsonb) from public.rtp_installations where license_id=l.id)); end if;
 if p_action='release_device' then update public.rtp_installations set active=false where license_id=l.id and id=(p_data->>'activation_id')::uuid; return jsonb_build_object('ok',true); end if;
 return jsonb_build_object('ok',false,'message','Okänd adminåtgärd.');
end $$;
revoke all on function public.rtp_admin(text,text,jsonb) from public,authenticated;
grant execute on function public.rtp_admin(text,text,jsonb) to anon;
commit;
