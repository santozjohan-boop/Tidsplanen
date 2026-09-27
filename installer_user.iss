#define MyAppName "Ramavtalade tidsplaner"
#define MyAppVersion "3.3.1"
[Setup]
AppId={{A69F5F7B-1A91-4E4B-BBEA-72D25B4DB892}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\Ramavtalade tidsplaner
DefaultGroupName={#MyAppName}
OutputDir=installer_output
OutputBaseFilename=Ramavtalade_tidsplaner_ANVANDARE_Setup_v3.3.1
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
[Files]
Source: "dist\Ramavtalade tidsplaner.exe"; DestDir: "{app}"; Flags: ignoreversion
[Icons]
Name: "{autoprograms}\Ramavtalade tidsplaner"; Filename: "{app}\Ramavtalade tidsplaner.exe"
Name: "{autodesktop}\Ramavtalade tidsplaner"; Filename: "{app}\Ramavtalade tidsplaner.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Skapa genväg på skrivbordet"; GroupDescription: "Genvägar:"; Flags: unchecked
[Run]
Filename: "{app}\Ramavtalade tidsplaner.exe"; Description: "Starta Ramavtalade tidsplaner"; Flags: nowait postinstall skipifsilent
