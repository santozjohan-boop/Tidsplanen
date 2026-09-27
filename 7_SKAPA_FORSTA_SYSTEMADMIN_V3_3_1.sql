-- Ramavtalade tidsplaner v3.3.1
-- Engångsbootstrap för en helt ny installation.
-- Säkerhetsregel: körs bara om det saknas systemadmin OCH exakt ett Auth-konto finns.
-- Då blir det enda befintliga Auth-kontot Systemadmin.
DO $$
DECLARE
  v_count integer;
  v_uid uuid;
  v_email text;
BEGIN
  IF EXISTS (SELECT 1 FROM public.rtp_system_admins) THEN
    RAISE EXCEPTION 'Systemadmin finns redan. Ingen ändring gjord.';
  END IF;

  SELECT count(*), min(id), min(lower(email))
    INTO v_count, v_uid, v_email
  FROM auth.users;

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Första bootstrap kräver exakt 1 Auth-användare. Hittade %.', v_count;
  END IF;

  IF v_email IS NULL OR btrim(v_email) = '' THEN
    RAISE EXCEPTION 'Auth-användaren saknar e-postadress.';
  END IF;

  INSERT INTO public.rtp_system_admins(auth_user_id,email)
  VALUES(v_uid,v_email);

  RAISE NOTICE 'Systemadmin skapad för %', v_email;
END $$;
