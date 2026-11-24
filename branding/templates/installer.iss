; Script Inno Setup per {{name}} (Windows x64). GENERATO da tools/brand_apply.py.
; Compilazione (richiede Inno Setup 6), dopo tools/package.ps1:
;   ISCC.exe installer\{{exeName}}.iss
; Cartella di installazione, identificativo e preferenze sono propri di {{name}}:
; nessun file di altri programmi viene letto, modificato o sovrascritto.

#define AppName "{{name}}"
#define AppVersion "{{version}}"
#define AppExe "{{exeName}}.exe"
#define SrcDir "..\dist\{{exeName}}-{{version}}-windows-x64"
; versione numerica per le proprietà del file (es. "1.0.0-beta.1" -> "1.0.0")
#if Pos("-", AppVersion) > 0
  #define AppVersionNum Copy(AppVersion, 1, Pos("-", AppVersion) - 1)
#else
  #define AppVersionNum AppVersion
#endif

[Setup]
AppId={{{{windowsInstallerAppId}}}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={{publisher}}
AppCopyright={{copyright}}
DefaultDirName={autopf}\{{name}}
DefaultGroupName={{name}}
; la cartella di installazione si può sempre scegliere
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename={{exeName}}-{#AppVersion}-setup
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Nessun privilegio di amministratore richiesto: installazione per l'utente corrente,
; con la possibilità di scegliere "per tutti gli utenti" (che chiede l'amministratore).
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
VersionInfoVersion={#AppVersionNum}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersionNum}
VersionInfoProductTextVersion={#AppVersion}
VersionInfoDescription={#AppName} setup
SetupIconFile=..\branding\out\{{exeName}}.ico
#if FileExists(AddBackslash(SourcePath) + "..\LICENSE")
; licenza mostrata durante l'installazione (GPL-3.0-or-later nel repository pubblico)
LicenseFile=..\LICENSE
#endif
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion}
CloseApplications=yes
; Le preferenze in %APPDATA%\{{appDataFolder}} restano dopo la disinstallazione (si possono cancellare a mano).

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "pt"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[CustomMessages]
en.DesktopIcon=Create a desktop shortcut
it.DesktopIcon=Crea un collegamento sul desktop
es.DesktopIcon=Crear un acceso directo en el escritorio
fr.DesktopIcon=Créer un raccourci sur le bureau
de.DesktopIcon=Verknüpfung auf dem Desktop erstellen
pt.DesktopIcon=Criar um atalho na área de trabalho
en.QuickGuide=Quick guide (Italian)
it.QuickGuide=Guida rapida
es.QuickGuide=Guía rápida (italiano)
fr.QuickGuide=Guide rapide (italien)
de.QuickGuide=Kurzanleitung (Italienisch)
pt.QuickGuide=Guia rápido (italiano)
en.LaunchApp=Launch {#AppName}
it.LaunchApp=Avvia {#AppName}
es.LaunchApp=Iniciar {#AppName}
fr.LaunchApp=Lancer {#AppName}
de.LaunchApp={#AppName} starten
pt.LaunchApp=Iniciar {#AppName}

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; Flags: unchecked

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\{cm:QuickGuide}"; Filename: "{win}\notepad.exe"; Parameters: """{app}\LEGGIMI.md"""
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchApp}"; Flags: nowait postinstall skipifsilent
