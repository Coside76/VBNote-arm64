; VBNote installer (Universal x64 / ARM64).
;
; Built by `installer\build.ps1`, which passes /DTargetArch=x64 or /DTargetArch=arm64.

#ifndef TargetArch
  #define TargetArch "x64"
#endif

#define Name "VBNote"
#define Version "1.2.0"
#define Publisher "Fractal Microsystems"
#define Url "https://github.com/highenergymagic/VBNote"
#define Copyright "Copyright (C) 2026 Fractal Microsystems. GPL-2.0-only."
#define Exe "vbnote.exe"
#define SetupExe "VBNote Setup.exe"

[Setup]
AppId={{7B2F1C4E-9A3D-4E62-9C1B-5D4A8F0E2B77}
AppName={#Name}
AppVersion={#Version}
AppPublisher={#Publisher}
AppCopyright={#Copyright}
VersionInfoCompany={#Publisher}
VersionInfoCopyright={#Copyright}
VersionInfoProductName={#Name}
VersionInfoVersion={#Version}
AppPublisherURL={#Url}
AppSupportURL={#Url}/issues
DefaultDirName={autopf}\{#Name}
DefaultGroupName={#Name}
DisableProgramGroupPage=yes
DisableDirPage=auto
DisableReadyPage=yes
DisableWelcomePage=no
AllowNoIcons=no
OutputDir=..\dist
WizardStyle=modern
PrivilegesRequiredOverridesAllowed=dialog
PrivilegesRequired=lowest
LicenseFile=terms.txt
UninstallDisplayName={#Name}

; Conditional Architecture Settings
#if TargetArch == "arm64"
  OutputBaseFilename=VBNote-{#Version}-arm64-setup
  ArchitecturesAllowed=arm64
  ArchitecturesInstallIn64BitMode=arm64
#else
  OutputBaseFilename=VBNote-{#Version}-setup
  ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
#if TargetArch == "arm64"
  Source: "..\target\aarch64-pc-windows-msvc\release\{#Exe}"; DestDir: "{app}"; Flags: ignoreversion
#else
  Source: "..\target\release\{#Exe}"; DestDir: "{app}"; Flags: ignoreversion
#endif

Source: "..\dist\wizard\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\README.md"; DestDir: "{app}"; DestName: "README.txt"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion isreadme
Source: "..\nvdaControllerClient.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "nvda-controllerclient-license.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Set up VBNote"; Filename: "{app}\{#SetupExe}"; Comment: "Build your machine from your own firmware. Do this first."
Name: "{group}\VBNote"; Filename: "{app}\{#Exe}"; Comment: "Start your machine"
Name: "{group}\VBNote settings"; Filename: "notepad.exe"; Parameters: """{%USERPROFILE}\.VBNote\VBNote.ini"""; Comment: "Edit the settings file"
Name: "{group}\Uninstall VBNote"; Filename: "{uninstallexe}"
Name: "{autodesktop}\VBNote"; Filename: "{app}\{#Exe}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Put VBNote on the desktop"; GroupDescription: "Shortcuts:"

[Run]
Filename: "{app}\{#SetupExe}"; Description: "Set up my machine now"; Flags: postinstall nowait skipifsilent

[Messages]
WelcomeLabel2=This will install [name/ver].%n%nVBNote is an emulator of the VoiceNote QT and BrailleNote mPower. It is not a HumanWare product and is not supported by them.%n%nAfter installing, run "Set up VBNote" once. It builds your machine from firmware files you supply from a machine you own; VBNote does not include them and cannot obtain them.
