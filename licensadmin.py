import sys
import tkinter as tk
from tkinter import ttk,messagebox,simpledialog
import rtp_auth

ROLES=('Företagsadmin','Projektledare','Användare','Läsare')
class Admin(tk.Tk):
 def __init__(self):
  super().__init__(); self.title('Ramavtalade tidsplaner – Administration v3.3.1'); self.geometry('1080x650'); self.rows={}; self.scope=None; self.profile={}; self.build(); self.withdraw(); self.after(100,self.login)
 def login(self):
  d=tk.Toplevel(self); d.title('Admin – Logga in'); d.geometry('470x330'); d.resizable(False,False); d.grab_set(); f=ttk.Frame(d,padding=24);f.pack(fill='both',expand=True)
  ttk.Label(f,text='Administration',font=(('SF Pro Text' if sys.platform == 'darwin' else 'Segoe UI'),19,'bold')).pack(anchor='w');ttk.Label(f,text='Logga in med ditt arbetskonto.',foreground='#64748b').pack(anchor='w',pady=(4,16))
  em=tk.StringVar(value=rtp_auth.load_session().get('email','')); pw=tk.StringVar(); ttk.Label(f,text='E-post').pack(anchor='w');ttk.Entry(f,textvariable=em).pack(fill='x',pady=(3,9));ttk.Label(f,text='Lösenord').pack(anchor='w');pe=ttk.Entry(f,textvariable=pw,show='•');pe.pack(fill='x',pady=(3,9)); st=ttk.Label(f,text='');st.pack(anchor='w')
  def go():
   try:
    st.config(text='Loggar in…');d.update_idletasks();rtp_auth.sign_in(em.get(),pw.get(),True); x=rtp_auth.admin('login');self.scope=x.get('scope');self.profile=x;d.destroy();self.deiconify();self.apply_scope();self.refresh()
   except Exception as e:st.config(text='');messagebox.showerror('Åtkomst nekad',str(e),parent=d)
  def bootstrap():
   if not em.get().strip() or not pw.get():messagebox.showinfo('Första systemadmin','Fyll först i e-post och lösenord. Skapa konto om det inte finns.',parent=d);return
   old=simpledialog.askstring('Första systemadmin','Ange den gamla systemadminnyckeln en sista gång:',show='*',parent=d)
   if not old:return
   try:
    try:rtp_auth.sign_in(em.get(),pw.get(),True)
    except:rtp_auth.sign_up(em.get(),pw.get());rtp_auth.sign_in(em.get(),pw.get(),True)
    rtp_auth.bootstrap_system_admin(old,em.get());messagebox.showinfo('Klart','Kontot är nu systemadmin. Logga in.',parent=d)
   except Exception as e:messagebox.showerror('Fel',str(e),parent=d)
  ttk.Button(f,text='Logga in',command=go).pack(anchor='e',pady=8);ttk.Label(f,text='Första installationen? Kör 7_SKAPA_FORSTA_SYSTEMADMIN_V3_3_1.sql en gång i Supabase.',foreground='#64748b',wraplength=410).pack(anchor='w',pady=(8,3));pe.bind('<Return>',lambda e:go());d.protocol('WM_DELETE_WINDOW',self.destroy)
 def call(self,a,d=None):
  x=rtp_auth.admin(a,d or {});
  if not x.get('ok'):raise RuntimeError(x.get('message','Fel'))
  return x
 def build(self):
  h=ttk.Frame(self,padding=12);h.pack(fill='x');ttk.Label(h,text='Företag & användare',font=(('SF Pro Text' if sys.platform == 'darwin' else 'Segoe UI'),18,'bold')).pack(side='left');ttk.Button(h,text='Logga ut',command=self.logout).pack(side='right',padx=4);ttk.Button(h,text='Uppdatera',command=self.refresh).pack(side='right',padx=4);self.new_btn=ttk.Button(h,text='Nytt företag',command=self.new);self.new_btn.pack(side='right',padx=4)
  cols=('customer','users','max','expires','status');self.t=ttk.Treeview(self,columns=cols,show='headings');
  for c,n,w in [('customer','Företag',300),('users','Användare',100),('max','Max',70),('expires','Giltig till',130),('status','Status',100)]:self.t.heading(c,text=n);self.t.column(c,width=w)
  self.t.pack(fill='both',expand=True,padx=12)
  b=ttk.Frame(self,padding=12);b.pack(fill='x');ttk.Button(b,text='Inställningar',command=self.workspace).pack(side='left',padx=4);ttk.Button(b,text='Användare',command=self.users).pack(side='left',padx=4);ttk.Button(b,text='Datorer',command=self.devices).pack(side='left',padx=4);self.toggle_btn=ttk.Button(b,text='Spärra/aktivera',command=self.toggle);self.toggle_btn.pack(side='left',padx=4);self.delete_btn=ttk.Button(b,text='Ta bort företag…',command=self.delete_company);self.delete_btn.pack(side='right',padx=4)
 def apply_scope(self):
  if self.scope!='system':self.new_btn.pack_forget();self.toggle_btn.pack_forget();self.delete_btn.pack_forget()
 def logout(self):rtp_auth.clear_session();self.destroy()
 def selected(self):
  s=self.t.selection();return self.rows.get(s[0]) if s else None
 def refresh(self):
  try:x=self.call('list')
  except Exception as e:messagebox.showerror('Fel',str(e),parent=self);return
  self.rows={};self.t.delete(*self.t.get_children())
  for l in x.get('licenses',[]):
   i=self.t.insert('','end',values=(l['customer'],l.get('users',0),l.get('max_users',l.get('max_devices',0)),l.get('expires_at') or 'Ingen','Aktiv' if l['active'] else 'SPÄRRAD'));self.rows[i]=l
 def new(self):
  c=simpledialog.askstring('Nytt företag','Företagsnamn:',parent=self)
  if not c:return
  m=simpledialog.askinteger('Nytt företag','Max antal användare:',initialvalue=10,minvalue=1,parent=self)
  e=simpledialog.askstring('Nytt företag','Giltig till ÅÅÅÅ-MM-DD (tomt = tills vidare):',parent=self) or ''
  try:self.call('create',{'customer':c,'max_users':m,'expires_at':e});self.refresh()
  except Exception as ex:messagebox.showerror('Fel',str(ex),parent=self)
 def toggle(self):
  l=self.selected()
  if not l:return
  try:self.call('toggle',{'id':l['id'],'active':not l['active']});self.refresh()
  except Exception as e:messagebox.showerror('Fel',str(e),parent=self)
 def delete_company(self):
  l=self.selected()
  if not l:return
  name=simpledialog.askstring('Ta bort företag',f'Detta tar bort företagskopplingar, användare och datorregistreringar för:\n\n{l["customer"]}\n\nSkriv företagsnamnet exakt för att fortsätta:',parent=self)
  if name!=l['customer']:return
  if not messagebox.askyesno('Slutlig bekräftelse','Åtgärden kan inte ångras. Ta bort företaget?',parent=self):return
  try:self.call('delete_company',{'id':l['id'],'confirm_name':name});self.refresh()
  except Exception as e:messagebox.showerror('Fel',str(e),parent=self)
 def workspace(self):
  l=self.selected()
  if not l:return
  try:w=self.call('workspace_get',{'id':l['id']})['workspace']
  except Exception as e:messagebox.showerror('Fel',str(e),parent=self);return
  d=tk.Toplevel(self);d.title('Inställningar – '+l['customer']);f=ttk.Frame(d,padding=18);f.pack(fill='both',expand=True);vals={k:tk.StringVar(value=w.get(k) or '') for k in ['onedrive_folder_name','onedrive_share_url','ai_provider','ai_model']}
  for i,(lab,k) in enumerate([('OneDrive-mapp','onedrive_folder_name'),('OneDrive delningslänk','onedrive_share_url'),('AI-leverantör','ai_provider'),('AI-modell','ai_model')]):ttk.Label(f,text=lab).grid(row=i,column=0,sticky='w',pady=7);ttk.Entry(f,textvariable=vals[k],width=58).grid(row=i,column=1,pady=7)
  def save():
   try:self.call('workspace_set',{'id':l['id'],**{k:v.get().strip() for k,v in vals.items()}});d.destroy()
   except Exception as e:messagebox.showerror('Fel',str(e),parent=d)
  ttk.Button(f,text='Spara',command=save).grid(row=5,column=1,sticky='e',pady=10)
 def users(self):
  l=self.selected()
  if not l:return
  w=tk.Toplevel(self);w.title('Användare – '+l['customer']);w.geometry('820x470');t=ttk.Treeview(w,columns=('name','email','role','status'),show='headings');rows={}
  for c,n,wd in [('name','Namn',180),('email','E-post',260),('role','Roll',140),('status','Status',90)]:t.heading(c,text=n);t.column(c,width=wd)
  t.pack(fill='both',expand=True,padx=10,pady=10)
  def load():
   t.delete(*t.get_children());rows.clear();us=self.call('users',{'id':l['id']})['users']
   for u in us:i=t.insert('','end',values=(u.get('display_name',''),u['email'],u['role'],'Aktiv' if u['enabled'] else 'Spärrad'));rows[i]=u
  def add():
   d=tk.Toplevel(w);d.title('Lägg till användare');f=ttk.Frame(d,padding=16);f.pack();n=tk.StringVar();em=tk.StringVar();role=tk.StringVar(value='Användare')
   for i,(lab,var) in enumerate([('Namn',n),('E-post',em)]):ttk.Label(f,text=lab).grid(row=i,column=0,sticky='w',pady=5);ttk.Entry(f,textvariable=var,width=38).grid(row=i,column=1,pady=5)
   ttk.Label(f,text='Roll').grid(row=2,column=0,sticky='w');ttk.Combobox(f,textvariable=role,values=ROLES,state='readonly').grid(row=2,column=1,sticky='ew')
   def save():
    try:self.call('user_create',{'id':l['id'],'display_name':n.get(),'email':em.get(),'role':role.get()});d.destroy();load();messagebox.showinfo('Användare tillagd',f'{em.get()} kan nu skapa konto eller logga in i programmet.',parent=w)
    except Exception as e:messagebox.showerror('Fel',str(e),parent=d)
   ttk.Button(f,text='Lägg till',command=save).grid(row=3,column=1,sticky='e',pady=10)
  def tog():
   s=t.selection()
   if not s:return
   u=rows[s[0]]
   try:self.call('user_toggle',{'id':l['id'],'member_id':u['id'],'active':not u['enabled']});load()
   except Exception as e:messagebox.showerror('Fel',str(e),parent=w)
  bb=ttk.Frame(w,padding=10);bb.pack(fill='x');ttk.Button(bb,text='Lägg till användare',command=add).pack(side='left');ttk.Button(bb,text='Spärra/aktivera',command=tog).pack(side='left',padx=8);load()
 def devices(self):
  l=self.selected()
  if not l:return
  ds=self.call('devices',{'id':l['id']})['devices'];w=tk.Toplevel(self);w.title('Datorer – '+l['customer']);w.geometry('760x400');t=ttk.Treeview(w,columns=('name','last','status'),show='headings');rows={}
  for c,n in [('name','Dator'),('last','Senast sedd'),('status','Status')]:t.heading(c,text=n)
  t.pack(fill='both',expand=True,padx=10,pady=10)
  for d in ds:i=t.insert('','end',values=(d.get('device_name'),d.get('last_seen'),'Aktiv' if d.get('active') else 'Frigjord'));rows[i]=d
  def rel():
   s=t.selection()
   if s and messagebox.askyesno('Frigör dator','Frigöra markerad dator?',parent=w):self.call('release_device',{'id':l['id'],'activation_id':rows[s[0]]['id']});w.destroy()
  ttk.Button(w,text='Frigör markerad dator',command=rel).pack(pady=8)
if __name__=='__main__':Admin().mainloop()
