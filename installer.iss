; installer.iss  —  Inno Setup script for "Talk to Dad"
; Builds: Install Dad's App.exe
;
; Before compiling:
;   1. Run: pyinstaller --onefile --noconsole --name "Talk to Dad" --hidden-import requests talk_to_dad.py
;   2. Place OllamaSetup.exe in this folder (download from https://ollama.com/download/windows)
;   3. Run build_installer.bat  (or open this file in Inno Setup IDE)

#define AppName    "Talk to Dad"
#define AppVersion "1.0"
#define Publisher  "Andrew Ryan Pennington"
#define ExeName    "Talk to Dad.exe"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
AppPublisherURL=https://github.com/kobashix/DadAI
DefaultDirName={autopf}\Talk to Dad
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputBaseFilename=Install Dad's App
SetupIconFile=
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardResizable=no
; Require Windows 10+
MinVersion=10.0

; Allow installing without admin if Ollama already present
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &Desktop shortcut"; GroupDescription: "Additional icons:"; Flags: checked

[Files]
; Main application
Source: "dist\Talk to Dad.exe";   DestDir: "{app}"; Flags: ignoreversion

; Modelfile (so the app can rebuild the model if ever needed)
Source: "Legacy.Modelfile";        DestDir: "{app}"; Flags: ignoreversion

; Ollama installer — bundled so no internet needed
Source: "OllamaSetup.exe";         DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

[Icons]
; Desktop shortcut
Name: "{autodesktop}\Talk to Dad"; Filename: "{app}\{#ExeName}"; \
    Comment: "Talk to Dad"; Tasks: desktopicon

; Start Menu
Name: "{autoprograms}\Talk to Dad"; Filename: "{app}\{#ExeName}"

[Run]
; Install Ollama silently if not already installed
Filename: "{tmp}\OllamaSetup.exe"; \
    Parameters: "/S"; \
    StatusMsg: "Installing Ollama (this takes a moment)..."; \
    Check: OllamaNotInstalled; \
    Flags: waituntilterminated

[Code]

// ── helpers ──────────────────────────────────────────────────────────────────

function OllamaNotInstalled(): Boolean;
// Returns True if ollama.exe is not found anywhere in PATH or common locations.
var
  ResultCode: Integer;
begin
  Result := not FileExists(ExpandConstant('{localappdata}\Programs\Ollama\ollama.exe'));
end;


procedure CopyModelFiles();
// Copies ollama-models\ from next to the installer into %USERPROFILE%\.ollama\models\
var
  InstallerDir : String;
  ModelSrc     : String;
  ModelDest    : String;
  FindRec      : TFindRec;
  BlobSrc      : String;
  BlobDest     : String;
  ManSrc       : String;
  ManDest      : String;
begin
  InstallerDir := ExtractFilePath(ExpandConstant('{srcexe}'));
  ModelSrc     := InstallerDir + 'ollama-models\';
  ModelDest    := ExpandConstant('{userappdata}') + '\..\' + '.ollama\models\';

  if not DirExists(ModelSrc + 'blobs') then
  begin
    // No model files next to installer — app will auto-download on first launch
    Exit;
  end;

  WizardForm.StatusLabel.Caption := 'Copying model files (one-time, may take a minute)...';

  // Copy blobs
  BlobSrc  := ModelSrc  + 'blobs\';
  BlobDest := ModelDest + 'blobs\';
  ForceDirectories(BlobDest);

  if FindFirst(BlobSrc + '*', FindRec) then
  begin
    repeat
      if FindRec.Name <> '.' then
        if FindRec.Name <> '..' then
          if not FileExists(BlobDest + FindRec.Name) then
            FileCopy(BlobSrc + FindRec.Name, BlobDest + FindRec.Name, False);
    until not FindNext(FindRec);
    FindClose(FindRec);
  end;

  // Copy manifests recursively using xcopy via shell
  ManSrc  := ModelSrc  + 'manifests\';
  ManDest := ModelDest + 'manifests\';
  ForceDirectories(ManDest);
  Exec(
    ExpandConstant('{sys}\xcopy.exe'),
    '/s /y /q "' + ManSrc + '*" "' + ManDest + '"',
    '', SW_HIDE, ewWaitUntilTerminated, ManDest{ reuse var }
  );
end;


procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    CopyModelFiles();
end;


function InitializeSetup(): Boolean;
begin
  Result := True;
  // Friendly intro
  if not WizardSilent() then
    MsgBox(
      'This will set up "Talk to Dad" on your computer.' + #13#10 + #13#10 +
      'It only takes a few minutes. You''ll find a shortcut on your Desktop when it''s done.',
      mbInformation, MB_OK
    );
end;
