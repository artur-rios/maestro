#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef OutputName
  #define OutputName "maestro-windows-x64-setup"
#endif
#ifndef AppIcon
  #error AppIcon is required
#endif

[Setup]
AppId={{225850DC-6179-46A0-962C-88F3BBA6D41D}
AppName=Maestro
AppVersion={#AppVersion}
AppPublisher=Artur Rios
DefaultDirName={localappdata}\Programs\Maestro
DefaultGroupName=Maestro
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile={#AppIcon}
UninstallDisplayIcon={app}\maestro.exe
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}.0
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Maestro"; Filename: "{app}\maestro.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\maestro.exe"; Description: "Launch Maestro"; Flags: nowait postinstall skipifsilent
