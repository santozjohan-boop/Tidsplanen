#define MyAppName "Ramavtalade tidsplaner – Admin"
#define MyAppVersion "3.3.1"
[Setup]
AppId={{BFCC3B77-C53C-47D5-BDD2-651E6942B38E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\Ramavtalade tidsplaner
DefaultGroupName="Ramavtalade tidsplaner"
OutputDir=installer_output
OutputBaseFilename=Ramavtalade_tidsplaner_ADMIN_Setup_v3.3.1
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
[Files]
Source: "dist\Ramavtalade tidsplaner.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\Licensadmin.exe"; DestDir: "{app}"; Flags: ignoreversion
[Icons]
Name: "{autoprograms}\Ramavtalade tidsplaner"; Filename: "{app}\Ramavtalade tidsplaner.exe"
Name: "{autoprograms}\Ramavtalade tidsplaner – Administration"; Filename: "{app}\Licensadmin.exe"
Name: "{autodesktop}\Ramavtalade tidsplaner"; Filename: "{app}\Ramavtalade tidsplaner.exe"; Tasks: desktopicon
Name: "{autodesktop}\Ramavtalade tidsplaner – Administration"; Filename: "{app}\Licensadmin.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Skapa genvägar på skrivbordet"; GroupDescription: "Genvägar:"; Flags: unchecked
[Run]
Filename: "{app}\Licensadmin.exe"; Description: "Starta Administration"; Flags: nowait postinstall skipifsilent
