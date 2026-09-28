#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== Ramavtalade tidsplaner v3.3.1 - macOS ==="

python3 -m pip install --upgrade pip
python3 -m pip install --upgrade pyinstaller reportlab python-docx pillow requests certifi

rm -rf build dist mac_output dmg_user dmg_admin
mkdir -p mac_output

# Hamta sokvagen till certifi CA-bundle
CERTIFI_PATH=$(python3 -c "import certifi; print(certifi.where())")
echo "Certifikat: $CERTIFI_PATH"

echo "Bygger huvudprogrammet..."
python3 -m PyInstaller \
  --noconfirm \
  --clean \
  --windowed \
  --name "Ramavtalade tidsplaner" \
  --add-data "$CERTIFI_PATH:certifi" \
  --collect-data certifi \
  ramavtalade_tidsplaner.py

echo "Bygger Administration..."
python3 -m PyInstaller \
  --noconfirm \
  --clean \
  --windowed \
  --name "Ramavtalade Administration" \
  --add-data "$CERTIFI_PATH:certifi" \
  --collect-data certifi \
  licensadmin.py

mkdir -p dmg_user dmg_admin

cp -R "dist/Ramavtalade tidsplaner.app" dmg_user/
ln -s /Applications dmg_user/Applications

hdiutil create \
  -volname "Ramavtalade tidsplaner" \
  -srcfolder dmg_user \
  -ov \
  -format UDZO \
  "mac_output/Ramavtalade_tidsplaner_ANVANDARE_v3.3.1.dmg"

cp -R "dist/Ramavtalade tidsplaner.app" dmg_admin/
cp -R "dist/Ramavtalade Administration.app" dmg_admin/
ln -s /Applications dmg_admin/Applications

hdiutil create \
  -volname "Ramavtalade tidsplaner ADMIN" \
  -srcfolder dmg_admin \
  -ov \
  -format UDZO \
  "mac_output/Ramavtalade_tidsplaner_ADMIN_v3.3.1.dmg"

echo "KLART - DMG-filerna ligger i mac_output/"
