#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "=== Ramavtalade tidsplaner v3.3.1 – macOS ==="
echo "Installerar byggverktyg..."
python3 -m pip install --user --upgrade pyinstaller reportlab python-docx pillow

rm -rf build dist mac_output dmg_user dmg_admin
mkdir -p mac_output

echo "Bygger huvudprogrammet..."
python3 -m PyInstaller --noconfirm --clean --windowed --name "Ramavtalade tidsplaner" ramavtalade_tidsplaner.py

echo "Bygger Administration..."
python3 -m PyInstaller --noconfirm --clean --windowed --name "Ramavtalade Administration" licensadmin.py

# Användar-DMG
mkdir -p dmg_user
cp -R "dist/Ramavtalade tidsplaner.app" dmg_user/
ln -s /Applications dmg_user/Applications
hdiutil create -volname "Ramavtalade tidsplaner" -srcfolder dmg_user -ov -format UDZO "mac_output/Ramavtalade_tidsplaner_ANVANDARE_v3.3.1.dmg"

# Admin-DMG: huvudprogram + administration
mkdir -p dmg_admin
cp -R "dist/Ramavtalade tidsplaner.app" dmg_admin/
cp -R "dist/Ramavtalade Administration.app" dmg_admin/
ln -s /Applications dmg_admin/Applications
hdiutil create -volname "Ramavtalade ADMIN" -srcfolder dmg_admin -ov -format UDZO "mac_output/Ramavtalade_tidsplaner_ADMIN_v3.3.1.dmg"

echo
echo "KLART. Filerna ligger i mac_output:"
echo " - Ramavtalade_tidsplaner_ANVANDARE_v3.3.1.dmg"
echo " - Ramavtalade_tidsplaner_ADMIN_v3.3.1.dmg"
echo
echo "OBS: Betabygget är inte Apple-notariserat. Första starten kan kräva högerklick > Öppna."
open mac_output
