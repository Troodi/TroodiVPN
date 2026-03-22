; Troodi VPN — Inno Setup 6+
; Build Flutter first: flutter build windows --release
; Optional: download VC++ x64 redistributable and save as packaging\windows\vc_redist.x64.exe
;   https://aka.ms/vs/17/release/vc_redist.x64.exe

#define MyAppName "Troodi VPN"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Troodi"
#define MyAppExeName "xray_desktop_ui.exe"
#define BuildRoot "..\..\app_ui\build\windows\x64\runner\Release"

[Setup]
AppId={{A7B2E4F1-9C3D-4E8A-B5F6-1D2E3C4B5A60}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\..\dist\windows
OutputBaseFilename=TroodiVPN-Setup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildRoot}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Uncomment after placing vc_redist.x64.exe next to this script:
; Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Uncomment together with [Files] vc_redist line above:
; Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Microsoft Visual C++ Runtime..."; Flags: waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"
