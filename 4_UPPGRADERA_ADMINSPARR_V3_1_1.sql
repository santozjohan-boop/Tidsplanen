-- Ramavtalade tidsplaner v3.1.1 - spärrad Licensadmin
-- Icke-destruktiv: behåller företag, licenser, användarnycklar och datorer.
begin;

create or replace function public.rtp_admin(p_token text,p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 expected text; is_system boolean:=false; admin_user public.rtp_user_keys%rowtype;
 scope_license uuid; l public.rtp_licenses%rowtype; u public.rtp_user_keys%rowtype; newkey text; cnt int;
begin
 select admin_token into expected from public.rtp_admin_config where id=1;
 is_system := expected is not null and p_token is not distinct from expected;
 if not is_system then
   select * into admin_user from public.rtp_user_keys
   where upper(user_key)=upper(btrim(p_token)) and enabled and role='Admin' limit 1;
   if not found then return jsonb_build_object('ok',false,'message','Adminbehörighet saknas.'); end if;
   scope_license:=admin_user.license_id;
   select * into l from public.rtp_licenses where id=scope_license;
   if not found or not l.enabled or (l.expires_at is not null and l.expires_at<current_date) then
     return jsonb_build_object('ok',false,'message','Företagslicensen är inte aktiv.');
   end if;
 end if;

 if p_action='login' then
   return jsonb_build_object('ok',true,'scope',case when is_system then 'system' else 'company' end,
     'license_id',scope_license,'display_name',case when is_system then 'Systemadmin' else admin_user.display_name end);
 end if;

 if p_action='list' then
   return jsonb_build_object('ok',true,'scope',case when is_system then 'system' else 'company' end,'licenses',(
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',x.id,'license_key',x.license_key,'customer',x.customer_name,'max_devices',x.max_devices,'expires_at',x.expires_at,'active',x.enabled,
      'devices',(select count(*) from public.rtp_installations a where a.license_id=x.id and a.active),
      'users',(select count(*) from public.rtp_user_keys k where k.license_id=x.id and k.enabled),
      'admin_email',x.admin_email,'onedrive_folder_name',x.onedrive_folder_name,'onedrive_share_url',x.onedrive_share_url,'ai_provider',x.ai_provider,'ai_model',x.ai_model
    ) order by x.customer_name),'[]'::jsonb)
    from public.rtp_licenses x where is_system or x.id=scope_license));
 end if;

 if p_action='create' then
   if not is_system then return jsonb_build_object('ok',false,'message','Endast systemadmin kan skapa företagslicenser.'); end if;
   newkey:='RTP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4));
   insert into public.rtp_licenses(license_key,customer_name,max_devices,expires_at,enabled)
   values(newkey,btrim(p_data->>'customer'),greatest(1,coalesce(nullif(p_data->>'max_devices','')::int,1)),nullif(p_data->>'expires_at','')::date,true) returning * into l;
   return jsonb_build_object('ok',true,'license_key',l.license_key);
 end if;

 begin select * into l from public.rtp_licenses where id=(p_data->>'id')::uuid; exception when others then return jsonb_build_object('ok',false,'message','Ogiltigt licens-ID.'); end;
 if not found then return jsonb_build_object('ok',false,'message','Licensen hittades inte.'); end if;
 if not is_system and l.id<>scope_license then return jsonb_build_object('ok',false,'message','Åtkomst nekad till annat företag.'); end if;

 if p_action='toggle' then
   if not is_system then return jsonb_build_object('ok',false,'message','Endast systemadmin kan spärra företagslicensen.'); end if;
   update public.rtp_licenses set enabled=coalesce((p_data->>'active')::boolean,false),updated_at=now() where id=l.id;
   return jsonb_build_object('ok',true);
 end if;
 if p_action='update' then
   if not is_system then return jsonb_build_object('ok',false,'message','Endast systemadmin kan ändra huvudlicensen.'); end if;
   update public.rtp_licenses set customer_name=coalesce(nullif(btrim(p_data->>'customer'),''),customer_name),max_devices=coalesce(nullif(p_data->>'max_devices','')::int,max_devices),expires_at=case when p_data?'expires_at' then nullif(p_data->>'expires_at','')::date else expires_at end,updated_at=now() where id=l.id;
   return jsonb_build_object('ok',true);
 end if;
 if p_action='workspace_get' then return jsonb_build_object('ok',true,'workspace',jsonb_build_object('admin_email',l.admin_email,'onedrive_folder_name',l.onedrive_folder_name,'onedrive_share_url',l.onedrive_share_url,'ai_provider',l.ai_provider,'ai_model',l.ai_model)); end if;
 if p_action='workspace_set' then
   update public.rtp_licenses set admin_email=nullif(p_data->>'admin_email',''),onedrive_folder_name=coalesce(nullif(p_data->>'onedrive_folder_name',''),'Ramavtalade tidsplaner'),onedrive_share_url=nullif(p_data->>'onedrive_share_url',''),ai_provider=coalesce(nullif(p_data->>'ai_provider',''),'Gemini'),ai_model=coalesce(nullif(p_data->>'ai_model',''),'gemini-3.5-flash'),updated_at=now() where id=l.id;
   return jsonb_build_object('ok',true);
 end if;
 if p_action='users' then return jsonb_build_object('ok',true,'users',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'user_key',user_key,'display_name',display_name,'email',email,'role',role,'enabled',enabled) order by display_name),'[]'::jsonb) from public.rtp_user_keys where license_id=l.id)); end if;
 if p_action='user_create' then
   select count(*) into cnt from public.rtp_user_keys where license_id=l.id and enabled;
   if cnt>=l.max_devices then return jsonb_build_object('ok',false,'message','Max antal aktiva användarnycklar är uppnått.'); end if;
   if coalesce(nullif(p_data->>'role',''),'Användare') not in ('Admin','Projektledare','Användare','Läsare') then return jsonb_build_object('ok',false,'message','Ogiltig roll.'); end if;
   newkey:='RTP-U-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4))||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,4));
   insert into public.rtp_user_keys(license_id,user_key,display_name,email,role)
   values(l.id,newkey,btrim(p_data->>'display_name'),nullif(btrim(p_data->>'email'),''),coalesce(nullif(p_data->>'role',''),'Användare')) returning * into u;
   return jsonb_build_object('ok',true,'user_key',u.user_key);
 end if;
 if p_action='user_toggle' then
   if not is_system and (p_data->>'user_id')::uuid=admin_user.id and coalesce((p_data->>'active')::boolean,false)=false then
     return jsonb_build_object('ok',false,'message','Du kan inte spärra din egen adminnyckel.');
   end if;
   update public.rtp_user_keys set enabled=coalesce((p_data->>'active')::boolean,false) where license_id=l.id and id=(p_data->>'user_id')::uuid;
   return jsonb_build_object('ok',true);
 end if;
 if p_action='devices' then return jsonb_build_object('ok',true,'devices',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'device_name',coalesce(computer_name,''),'device_id',installation_id,'active',active,'activated_at',activated_at,'last_seen',last_seen_at) order by last_seen_at desc),'[]'::jsonb) from public.rtp_installations where license_id=l.id)); end if;
 if p_action='release_device' then update public.rtp_installations set active=false where license_id=l.id and id=(p_data->>'activation_id')::uuid; return jsonb_build_object('ok',true); end if;
 return jsonb_build_object('ok',false,'message','Okänd adminåtgärd.');
end $$;
revoke all on function public.rtp_admin(text,text,jsonb) from public,authenticated;
grant execute on function public.rtp_admin(text,text,jsonb) to anon;
commit;
