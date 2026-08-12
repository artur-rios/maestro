#ifndef DisplayVersion
  #error DisplayVersion is required
#endif
#ifndef WindowsVersion
  #error WindowsVersion is required
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
AppVersion={#DisplayVersion}
AppPublisher=Artur Rios
DefaultDirName={localappdata}\Programs\Maestro
DefaultGroupName=Maestro
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile={#AppIcon}
UninstallDisplayIcon={app}\maestro.exe
UninstallFilesDir={app}-uninstall
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#WindowsVersion}
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Maestro"; Filename: "{app}\maestro.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\maestro.exe"; Description: "Launch Maestro"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
function DirectoryIsEmpty(Path: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := True;
  if FindFirst(AddBackslash(Path) + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
        begin
          Result := False;
          Break;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExpectedDir: String;
begin
  Result := '';
#ifndef AllowCustomDirectoryForSmoke
  ExpectedDir := RemoveBackslashUnlessRoot(
    ExpandConstant('{localappdata}\Programs\Maestro'));
  if CompareText(RemoveBackslashUnlessRoot(ExpandConstant('{app}')), ExpectedDir) <> 0 then
  begin
    Result := 'Maestro installation directory is fixed.';
    Exit;
  end;

  if DirExists(ExpandConstant('{app}')) and
     (not DirectoryIsEmpty(ExpandConstant('{app}'))) and
     (not RegKeyExists(HKCU,
       'Software\Microsoft\Windows\CurrentVersion\Uninstall\{225850DC-6179-46A0-962C-88F3BBA6D41D}_is1')) then
  begin
    Result := 'Existing directory is not owned by Maestro.';
    Exit;
  end;
#endif
end;
