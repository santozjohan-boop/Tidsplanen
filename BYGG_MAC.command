#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "=== Ramavtalade tidsplaner v3.3.1 - macOS ==="
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt
python3 - <<'TLSCHECK'
import ssl, urllib.request, urllib.error, certifi
ctx=ssl.create_default_context(cafile=certifi.where())
req=urllib.request.Request('https://ipldltuoqstsplnvuijz.supabase.co/auth/v1/settings')
try:
    urllib.request.urlopen(req, timeout=15, context=ctx)
except urllib.error.HTTPError as e:
    print('TLS OK, HTTP status:', e.code)
else:
    print('TLS OK')
print('CA bundle:', certifi.where())
TLSCHECK
rm -rf build dist mac_output dmg_user dmg_admin
mkdir -p mac_output
COMMON=(--noconfirm --clean --windowed --collect-data certifi --hidden-import certifi --hidden-import ssl)
echo "Bygger huvudprogrammet..."
python3 -m PyInstaller "${COMMON[@]}" --name "Ramavtalade tidsplaner" ramavtalade_tidsplaner.py
echo "Bygger Administration..."
python3 -m PyInstaller "${COMMON[@]}" --name "Ramavtalade Administration" licensadmin.py
mkdir -p dmg_user dmg_admin
cp -R "dist/Ramavtalade tidsplaner.app" dmg_user/
ln -s /Applications dmg_user/Applications
hdiutil create -volname "Ramavtalade tidsplaner" -srcfolder dmg_user -ov -format UDZO "mac_output/Ramavtalade_tidsplaner_ANVANDARE_v3.3.1.dmg"
cp -R "dist/Ramavtalade tidsplaner.app" dmg_admin/
cp -R "dist/Ramavtalade Administration.app" dmg_admin/
ln -s /Applications dmg_admin/Applications
hdiutil create -volname "Ramavtalade tidsplaner ADMIN" -srcfolder dmg_admin -ov -format UDZO "mac_output/Ramavtalade_tidsplaner_ADMIN_v3.3.1.dmg"
echo "KLART - DMG-filerna ligger i mac_output/"
