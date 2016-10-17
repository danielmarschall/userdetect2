unit UD2_Utils;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

{$INCLUDE 'UserDetect2.inc'}

uses
  Windows, SysUtils, Dialogs, ShellAPI, Classes, UD2_Parsing;

const
  EXITCODE_OK = 0;
  EXITCODE_TASK_NOTHING_MATCHES = 1;
  EXITCODE_RUN_FAILURE = 2;
  EXITCODE_TASK_NOT_EXISTS = 10;
  EXITCODE_INI_NOT_FOUND = 11;
  EXITCODE_RUNCMD_SYNTAX_ERROR = 12;
  EXITCODE_SYNTAX_ERROR = 13;

type
  TArrayOfString = array of string;

  TIconFileIdx = record
    FileName: string;
    IconIndex: integer;
  end;

function SplitString(const aSeparator, aString: string; aMax: Integer = 0): TArrayOfString;
function MergeString(ary: TArrayOfString; glue: string): string;
function BetterInterpreteBool(str: string): boolean;
function GetOwnCmdName: string;
function ExpandEnvStr(const szInput: string): string;
procedure UD2_RunCMD(cmd: TUD2Command);
function SplitIconString(IconString: string): TIconFileIdx;
// function GetHTML(AUrl: string): string;
procedure VTS_CheckUpdates(VTSID, CurVer: string);
function FormatOSError(ec: DWORD): string;
function CheckBoolParam(idx: integer; name: string): boolean;
function IndexOf_CS(aStrings: TStrings; aToken: string): Integer;
function UD2_GetThreadErrorMode: DWORD;
function UD2_SetThreadErrorMode(dwNewMode: DWORD; lpOldMode: LPDWORD): BOOL;
function GetFileVersion(const FileName: string=''): string;

implementation

uses
  idhttp, Forms;

function SplitString(const aSeparator, aString: string; aMax: Integer = 0): TArrayOfString;
// http://stackoverflow.com/a/2626991/3544341
var
  i, strt, cnt: Integer;
  sepLen: Integer;

  procedure AddString(aEnd: Integer = -1);
  var
    endPos: Integer;
  begin
    if (aEnd = -1) then
      endPos := i
    else
      endPos := aEnd + 1;

    if (strt < endPos) then
      result[cnt] := Copy(aString, strt, endPos - strt)
    else
      result[cnt] := '';

    Inc(cnt);
  end;

begin
  if (aString = '') or (aMax < 0) then
  begin
    SetLength(result, 0);
    EXIT;
  end;

  if (aSeparator = '') then
  begin
    SetLength(result, 1);
    result[0] := aString;
    EXIT;
  end;

  sepLen := Length(aSeparator);
  SetLength(result, (Length(aString) div sepLen) + 1);

  i     := 1;
  strt  := i;
  cnt   := 0;
  while (i <= (Length(aString)- sepLen + 1)) do
  begin
    if (aString[i] = aSeparator[1]) then
      if (Copy(aString, i, sepLen) = aSeparator) then
      begin
        AddString;

        if (cnt = aMax) then
        begin
          SetLength(result, cnt);
          EXIT;
        end;

        Inc(i, sepLen - 1);
        strt := i + 1;
      end;

    Inc(i);
  end;

  AddString(Length(aString));

  SetLength(result, cnt);
end;

function BetterInterpreteBool(str: string): boolean;
resourcestring
  LNG_CANNOT_INTERPRETE_BOOL = 'Cannot determinate the boolean value of "%s"';
begin
  str := LowerCase(str);
  if (str = 'yes') or (str = 'true') or (str = '1') then
    result := true
  else if (str = 'no') or (str = 'false') or (str = '0') then
    result := false
  else
    raise EConvertError.CreateFmt(LNG_CANNOT_INTERPRETE_BOOL, [str]);
end;

function GetOwnCmdName: string;
begin
  result := ParamStr(0);
  result := ExtractFileName(result);
  result := ChangeFileExt(result, '');
  result := UpperCase(result);
end;

function ExpandEnvStr(const szInput: string): string;
// http://stackoverflow.com/a/2833147/3544341
const
  MAXSIZE = 32768;
begin
  SetLength(Result, MAXSIZE);
  SetLength(Result, ExpandEnvironmentStrings(pchar(szInput),
    @Result[1],length(Result)));
end;

function FormatOSError(ec: DWORD): string;
resourcestring
  LNG_UNKNOWN_ERROR = 'Operating system error %d';
begin
  result := SysErrorMessage(ec);

  // Some errors have no error message, e.g. error 193 (BAD_EXE_FORMAT) in the German version of Windows 10
  if result = '' then result := Format(LNG_UNKNOWN_ERROR, [ec]);
end;

function CheckLastOSCall(AThrowException: boolean): boolean;
var
  LastError: Cardinal;
begin
  LastError := GetLastError;
  result := LastError = 0;
  if not result then
  begin
    if AThrowException then
    begin
      RaiseLastOSError;
    end
    else
    begin
      MessageDlg(FormatOSError(LastError), mtError, [mbOK], 0);
    end;
  end;
end;

function SplitIconString(IconString: string): TIconFileIdx;
var
  p: integer;
begin
  p := Pos(',', IconString);

  if p = 0 then
  begin
    result.FileName := IconString;
    result.IconIndex := 0;
  end
  else
  begin
    result.FileName  := ExpandEnvStr(copy(IconString, 0, p-1));
    result.IconIndex := StrToInt(Copy(IconString, p+1, Length(IconString)-p));
  end;
end;

procedure UD2_RunCMD(cmd: TUD2Command);
// Discussion: http://stackoverflow.com/questions/32802679/acceptable-replacement-for-winexec/32804669#32804669
// Version 1: http://pastebin.com/xQjDmyVe
// --> CreateProcess + ShellExecuteEx
// --> Problem: Run-In-Same-Directory functionality is not possible
//              (requires manual command and argument separation)
// Version 2: http://pastebin.com/YpUmF5rd
// --> Splits command and arguments manually, and uses ShellExecute
// --> Problem: error handling wrong
// --> Problem: Run-In-Same-Directory functionality is not implemented
// Current version:
// --> Splits command and arguments manually, and uses ShellExecute
// --> Run-In-Same-Directory functionality is implemented
resourcestring
  LNG_INVALID_SYNTAX = 'The command line has an invalid syntax';
var
  cmdFile, cmdArgs, cmdDir: string;
  p: integer;
  sei: TShellExecuteInfo;
  cmdLine: string;
begin
  // We need a function which does following:
  // 1. Replace the Environment strings, e.g. %SystemRoot%
  // 2. Runs EXE files with parameters (e.g. "cmd.exe /?")
  // 3. Runs EXE files without path (e.g. "calc.exe")
  // 4. Runs EXE files without extension (e.g. "calc")
  // 5. Runs non-EXE files (e.g. "Letter.doc")
  // 6. Commands with white spaces (e.g. "C:\Program Files\xyz.exe") must be enclosed in quotes.

  cmdLine := ExpandEnvStr(cmd.executable);

  // Split command line from argument list
  if Copy(cmdLine, 1, 1) = '"' then
  begin
    cmdLine := Copy(cmdLine, 2, Length(cmdLine)-1);
    p := Pos('"', cmdLine);
    if p = 0 then
    begin
      // No matching quotes
      // CreateProcess() handles the whole command line as single file name  ("abc -> "abc")
      // ShellExecuteEx() does not accept the command line
      ExitCode := EXITCODE_RUNCMD_SYNTAX_ERROR;
      MessageDlg(LNG_INVALID_SYNTAX, mtError, [mbOK], 0);
      Exit;
    end;
    cmdFile := Copy(cmdLine, 1, p-1);
    cmdArgs := Copy(cmdLine, p+2, Length(cmdLine)-p-1);
  end
  else
  begin
    p := Pos(' ', cmdLine);
    if p = 0 then
    begin
      cmdFile := cmdLine;
      cmdArgs := '';
    end
    else
    begin
      cmdFile := Copy(cmdLine, 1, p-1);
      cmdArgs := Copy(cmdLine, p+1, Length(cmdLine)-p);
    end;
  end;

  ZeroMemory(@sei, SizeOf(sei));

  if cmd.runAsAdmin then
  begin
    sei.lpVerb := 'runas';
  end;

  if cmd.runInOwnDirectory then
  begin
    cmdFile := ExtractFileName(cmdLine);
    cmdDir  := ExtractFilePath(cmdLine);
  end
  else
  begin
    cmdFile := cmdLine;
    cmdDir := '';
  end;

  sei.cbSize       := SizeOf(sei);
  sei.lpFile       := PChar(cmdFile);
  {$IFNDEF PREFER_SHELLEXECUTEEX_MESSAGES}
  sei.fMask        := SEE_MASK_FLAG_NO_UI;
  {$ENDIF}
  if cmdArgs <> '' then sei.lpParameters := PChar(cmdArgs);
  if cmdDir  <> '' then sei.lpDirectory  := PChar(cmdDir);
  sei.nShow        := cmd.windowMode;
  if ShellExecuteEx(@sei) then Exit;
  {$IFNDEF PREFER_SHELLEXECUTEEX_MESSAGES}
  if not CheckLastOSCall(false) then ExitCode := EXITCODE_RUN_FAILURE;
  {$ENDIF}
end;

function GetHTML(const url: string): string;
var
  idhttp :Tidhttp;
begin
  idhttp := Tidhttp.Create(nil);
  try
    result := idhttp.Get(url);
  finally
    idhttp.Free;
  end;
end;

procedure VTS_CheckUpdates(VTSID, CurVer: string);
resourcestring
  (*
  LNG_DOWNLOAD_ERR = 'Ein Fehler ist aufgetreten. Wahrscheinlich ist keine Internetverbindung aufgebaut, oder der der ViaThinkSoft-Server temporär offline.';
  LNG_NEW_VERSION = 'Eine neue Programmversion ist vorhanden. Möchten Sie diese jetzt herunterladen?';
  LNG_NO_UPDATE = 'Es ist keine neue Programmversion vorhanden.';
  *)
  LNG_DOWNLOAD_ERR = 'An error occurred while searching for updates. Please check your internet connection and firewall.';
  LNG_NEW_VERSION = 'A new version is available. Do you want to download it now?';
  LNG_NO_UPDATE = 'You already have the newest program version.';
var
  status: string;
begin
  status := GetHTML('http://www.viathinksoft.de/update/?id='+VTSID);
  if Copy(status, 0, 7) = 'Status:' then
  begin
    MessageDlg(LNG_DOWNLOAD_ERR, mtError, [mbOK], 0);
  end
  else
  begin
    if status <> CurVer then
    begin
      if MessageDlg(LNG_NEW_VERSION, mtConfirmation, mbYesNoCancel, 0) = ID_YES then
      begin
        shellexecute(application.handle, 'open', pchar('http://www.viathinksoft.de/update/?id=@'+VTSID), '', '', SW_Normal);
      end;
    end
    else
    begin
      MessageDlg(LNG_NO_UPDATE, mtInformation, [mbOk], 0);
    end;
  end;
end;

function CheckBoolParam(idx: integer; name: string): boolean;
begin
  Result := ('/'+LowerCase(name) = LowerCase(ParamStr(idx))) or
            ('-'+LowerCase(name) = LowerCase(ParamStr(idx)));
end;

// function GetThreadErrorMode: DWORD; stdcall; external kernel32 name 'GetThreadErrorMode';
function UD2_GetThreadErrorMode: DWORD;
type
  TFuncGetThreadErrorMode = function: DWORD; stdcall;
var
  dllHandle: Cardinal;
  fGetThreadErrorMode: TFuncGetThreadErrorMode;
begin
  dllHandle := LoadLibrary(kernel32);
  if dllHandle = 0 then
  begin
    result := 0;
    Exit;
  end;
  try
    @fGetThreadErrorMode := GetProcAddress(dllHandle, 'GetThreadErrorMode');
    if not Assigned(fGetThreadErrorMode) then
    begin
      result := 0; // Windows Vista and prior
      Exit;
    end;
    result := fGetThreadErrorMode();
  finally
    FreeLibrary(dllHandle);
  end;
end;

// function SetThreadErrorMode(dwNewMode: DWORD; lpOldMode: LPDWORD): BOOL; stdcall; external kernel32 name 'SetThreadErrorMode';
function UD2_SetThreadErrorMode(dwNewMode: DWORD; lpOldMode: LPDWORD): BOOL;
type
  TFuncSetThreadErrorMode = function(dwNewMode: DWORD; lpOldMode: LPDWORD): BOOL; stdcall;
var
  dllHandle: Cardinal;
  fSetThreadErrorMode: TFuncSetThreadErrorMode;
begin
  dllHandle := LoadLibrary(kernel32);
  if dllHandle = 0 then
  begin
    result := FALSE;
    if Assigned(lpOldMode) then lpOldMode^ := UD2_GetThreadErrorMode;
    Exit;
  end;
  try
    @fSetThreadErrorMode := GetProcAddress(dllHandle, 'SetThreadErrorMode');
    if not Assigned(fSetThreadErrorMode) then
    begin
      result := FALSE; // Windows Vista and prior
      if Assigned(lpOldMode) then lpOldMode^ := UD2_GetThreadErrorMode;
      Exit;
    end;
    result := fSetThreadErrorMode(dwNewMode, lpOldMode);
  finally
    FreeLibrary(dllHandle);
  end;
end;

function IndexOf_CS(aStrings: TStrings; aToken: String): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to aStrings.Count-1 do
  begin
    if aStrings[i] = aToken then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function MergeString(ary: TArrayOfString; glue: string): string;
var
  i: integer;
begin
  result := '';
  for i := Low(ary) to High(ary) do
  begin
    if result <> '' then result := result + glue;
    result := result + ary[i];
  end;
end;

function GetFileVersion(const FileName: string=''): string;
var
  lpVerInfo: pointer;
  rVerValue: PVSFixedFileInfo;
  dwInfoSize: cardinal;
  dwValueSize: cardinal;
  dwDummy: cardinal;
  lpstrPath: pchar;
  a, b, c, d: word;
resourcestring
  LNG_NO_VERSION = 'No version specification';
begin
  if Trim(FileName) = EmptyStr then
    lpstrPath := pchar(ParamStr(0))
  else
    lpstrPath := pchar(FileName);

  dwInfoSize := GetFileVersionInfoSize(lpstrPath, dwDummy);

  if dwInfoSize = 0 then
  begin
    Result := LNG_NO_VERSION;
    Exit;
  end;

  GetMem(lpVerInfo, dwInfoSize);
  try
    GetFileVersionInfo(lpstrPath, 0, dwInfoSize, lpVerInfo);
    VerQueryValue(lpVerInfo, '', pointer(rVerValue), dwValueSize);

    with rVerValue^ do
    begin
      a := dwFileVersionMS shr 16;
      b := dwFileVersionMS and $FFFF;
      c := dwFileVersionLS shr 16;
      d := dwFileVersionLS and $FFFF;

      Result := IntToStr(a);
      if (b <> 0) or (c <> 0) or (d <> 0) then Result := Result + '.' + IntToStr(b);
      if (c <> 0) or (d <> 0) then Result := Result + '.' + IntToStr(c);
      if (d <> 0) then Result := Result + '.' + IntToStr(d);
    end;
  finally
    FreeMem(lpVerInfo, dwInfoSize);
  end;

end;

end.
