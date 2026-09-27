-- v3.1.4: returnerar företagets stabila license_id till klienten.
-- Ingen data raderas.
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
 return jsonb_build_object('ok',true,'license_id',l.id,'customer',l.customer_name,'expires_at',l.expires_at,'role',u.role,'display_name',u.display_name,
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
 return jsonb_build_object('ok',true,'license_id',l.id,'customer',l.customer_name,'expires_at',l.expires_at,'role',u.role,'display_name',u.display_name,
  'admin_email',l.admin_email,'onedrive_folder_name',l.onedrive_folder_name,'onedrive_share_url',l.onedrive_share_url,
  'ai_provider',l.ai_provider,'ai_model',l.ai_model);
end $$;
revoke all on function public.rtp_activate_user(text,text,text) from public,authenticated;
revoke all on function public.rtp_validate_user(text,text) from public,authenticated;
grant execute on function public.rtp_activate_user(text,text,text) to anon;
grant execute on function public.rtp_validate_user(text,text) to anon;
