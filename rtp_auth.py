import json, urllib.request, urllib.error, os, socket, uuid, hashlib, platform
from pathlib import Path
SUPABASE_URL='https://ipldltuoqstsplnvuijz.supabase.co'
SUPABASE_KEY='sb_publishable_ehE_J4RXZP2G6Y-AYyoCIA_87RGGBLj'
APPDATA=(Path.home()/'Library'/'Application Support'/'Ramavtalade tidsplaner') if platform.system()=='Darwin' else Path(os.getenv('APPDATA',Path.home()))/'Ramavtalade tidsplaner'
SESSION=APPDATA/'session.json'

def machine_id():
    raw='|'.join([platform.system(),platform.machine(),socket.gethostname(),str(uuid.getnode())])
    return hashlib.sha256(raw.encode()).hexdigest()

def _request(path, data=None, token=None, method='POST', timeout=12):
    headers={'apikey':SUPABASE_KEY,'Content-Type':'application/json','Accept':'application/json'}
    if token: headers['Authorization']='Bearer '+token
    body=None if data is None else json.dumps(data).encode()
    req=urllib.request.Request(SUPABASE_URL+path,data=body,method=method,headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=timeout) as r:
            b=r.read().decode(); return json.loads(b) if b else {}
    except urllib.error.HTTPError as e:
        b=e.read().decode('utf-8','replace')
        try:
            j=json.loads(b); msg=j.get('msg') or j.get('message') or j.get('error_description') or b
        except: msg=b
        raise RuntimeError(msg)

def save_session(s):
    APPDATA.mkdir(parents=True,exist_ok=True); SESSION.write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
def load_session():
    try:return json.loads(SESSION.read_text(encoding='utf-8'))
    except:return {}
def clear_session():
    try: SESSION.unlink()
    except: pass

def sign_in(email,password,remember=True):
    s=_request('/auth/v1/token?grant_type=password',{'email':email.strip(),'password':password})
    if remember: save_session({'access_token':s['access_token'],'refresh_token':s['refresh_token'],'email':email.strip()})
    return s

def sign_up(email,password): return _request('/auth/v1/signup',{'email':email.strip(),'password':password})
def recover(email): return _request('/auth/v1/recover',{'email':email.strip()})
def refresh_session():
    old=load_session(); rt=old.get('refresh_token')
    if not rt:return None
    s=_request('/auth/v1/token?grant_type=refresh_token',{'refresh_token':rt})
    save_session({'access_token':s['access_token'],'refresh_token':s['refresh_token'],'email':old.get('email','')}); return s

def token():
    s=load_session(); t=s.get('access_token')
    if not t:return None
    try:
        rpc('rtp_my_profile',{},t); return t
    except:
        try:return refresh_session()['access_token']
        except:return None

def rpc(name,payload=None,access_token=None):
    t=access_token or token()
    if not t:raise RuntimeError('Du är inte inloggad.')
    return _request('/rest/v1/rpc/'+name,payload or {},t)

def profile(access_token=None): return rpc('rtp_my_profile',{},access_token)
def activate_device(access_token=None):
    return rpc('rtp_activate_account',{'p_installation_id':machine_id(),'p_computer_name':socket.gethostname()},access_token)
def admin(action,data=None,access_token=None):
    return rpc('rtp_admin_v32',{'p_action':action,'p_data':data or {}},access_token)
def bootstrap_system_admin(old_token,email,access_token=None):
    return rpc('rtp_bootstrap_system_admin',{'p_old_token':old_token,'p_email':email},access_token)
