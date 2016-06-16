unit UD2_Utils;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

{$INCLUDE 'UserDetect2.inc'}

uses
  Windows, SysUtils, Dialogs, ShellAPI;

const
  EXITCODE_OK = 0;
  EXITCODE_TASK_NOTHING_MATCHES = 1;
  EXITCODE_RUN_FAILURE = 2;
  EXITCODE_TASK_NOT_EXISTS = 10;
  EXITCODE_INI_NOT_FOUND = 11;
  EXITCODE_RUNCMD_SYNTAX_ERROR = 12;
  EXTICODE_SYNTAX_ERROR = 13;

type
  TArrayOfString = array of String;

  TIconFileIdx = record
    FileName: string;
    IconIndex: integer;
  end;

const
  // Prefixes for UD2_RunCmd()
  UD2_RUN_IN_OWN_DIRECTORY_PREFIX = '$RIOD$';
  UD2_RUN_AS_ADMIN                = '$ADMIN$';

function SplitString(const aSeparator, aString: String; aMax: Integer = 0): TArrayOfString;
function BetterInterpreteBool(str: String): boolean;
function GetOwnCmdName: string;
function ExpandEnvStr(const szInput: string): string;
procedure UD2_RunCMD(cmdLine: string; WindowMode: integer=SW_NORMAL);
function SplitIconString(IconString: string): TIconFileIdx;
// function GetHTML(AUrl: string): string;
procedure VTS_CheckUpdates(VTSID, CurVer: string);
function FormatOSError(ec: DWORD): string;

implementation

uses
  WinInet, Forms;

function SplitString(const aSeparator, aString: String; aMax: Integer = 0): TArrayOfString;
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

function BetterInterpreteBool(str: String): boolean;
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

procedure UD2_RunCMD(cmdLine: string; WindowMode: integer=SW_NORMAL);
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
begin
  // We need a function which does following:
  // 1. Replace the Environment strings, e.g. %SystemRoot%
  // 2. Runs EXE files with parameters (e.g. "cmd.exe /?")
  // 3. Runs EXE files without path (e.g. "calc.exe")
  // 4. Runs EXE files without extension (e.g. "calc")
  // 5. Runs non-EXE files (e.g. "Letter.doc")
  // 6. Commands with white spaces (e.g. "C:\Program Files\xyz.exe") must be enclosed in quotes.

  cmdLine := ExpandEnvStr(cmdLine);

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

  if Pos(UD2_RUN_IN_OWN_DIRECTORY_PREFIX, cmdLine) >= 1 then
  begin
    cmdLine := StringReplace(cmdLine, UD2_RUN_IN_OWN_DIRECTORY_PREFIX, '', [rfReplaceAll]);

    cmdLine := Copy(cmdLine, 1+Length(UD2_RUN_IN_OWN_DIRECTORY_PREFIX), Length(cmdLine)-Length(UD2_RUN_IN_OWN_DIRECTORY_PREFIX));

    cmdFile := ExtractFileName(cmdLine);
    cmdDir  := ExtractFilePath(cmdLine);
  end
  else
  begin
    cmdFile := cmdLine;
    cmdDir := '';
  end;

  ZeroMemory(@sei, SizeOf(sei));

  if Pos(UD2_RUN_AS_ADMIN, cmdLine) >= 1 then
  begin
    cmdLine := StringReplace(cmdLine, UD2_RUN_AS_ADMIN, '', [rfReplaceAll]);

    sei.lpVerb := 'runas';
  end;

  sei.cbSize       := SizeOf(sei);
  sei.lpFile       := PChar(cmdFile);
  {$IFNDEF PREFER_SHELLEXECUTEEX_MESSAGES}
  sei.fMask        := SEE_MASK_FLAG_NO_UI;
  {$ENDIF}
  if cmdArgs <> '' then sei.lpParameters := PChar(cmdArgs);
  if cmdDir  <> '' then sei.lpDirectory  := PChar(cmdDir);
  sei.nShow        := WindowMode;
  if ShellExecuteEx(@sei) then Exit;
  {$IFNDEF PREFER_SHELLEXECUTEEX_MESSAGES}
  if not CheckLastOSCall(false) then ExitCode := EXITCODE_RUN_FAILURE;
  {$ENDIF}
end;

function GetHTML(AUrl: string): string;
// http://www.delphipraxis.net/post43515.html
// Modificated by ViaThinkSoft
var
  databuffer : array[0..4095] of char;
  ResStr : string;
  hSession, hfile: hInternet;
  dwindex,dwcodelen,dwread,dwNumber: cardinal;
  dwcode : array[1..20] of char;
  res    : pchar;
  Str    : pchar;
begin
  ResStr := '';
  if system.pos('http://',lowercase(AUrl)) = 0 then
  begin
     AUrl:='http://'+AUrl;
  end;

  // [ViaThinkSoft] Added
  Application.ProcessMessages;

  hSession:=InternetOpen('InetURL:/1.0',
                         INTERNET_OPEN_TYPE_PRECONFIG,
                         nil,
                         nil,
                         0);
  if assigned(hsession) then
  begin
    // [ViaThinkSoft] Added
    Application.ProcessMessages;

    hfile := InternetOpenUrl(hsession,
                             pchar(AUrl),
                             nil,
                             0,
                             INTERNET_FLAG_RELOAD,
                             0);
    dwIndex   := 0;
    dwCodeLen := 10;

    // [ViaThinkSoft] Added
    Application.ProcessMessages;

    HttpQueryInfo(hfile,
                  HTTP_QUERY_STATUS_CODE,
                  @dwcode,
                  dwcodeLen,
                  dwIndex);
    res := pchar(@dwcode);
    dwNumber := sizeof(databuffer)-1;
    if (res ='200') or (res ='302') then
    begin
      while (InternetReadfile(hfile,
                              @databuffer,
                              dwNumber,
                              DwRead)) do
      begin

        // [ViaThinkSoft] Added
        Application.ProcessMessages;

        if dwRead =0 then
          break;
        databuffer[dwread]:=#0;
        Str := pchar(@databuffer);
        resStr := resStr + Str;
      end;
    end
    else
      ResStr := 'Status:'+res;
    if assigned(hfile) then
      InternetCloseHandle(hfile);
  end;

  // Hinzugefügt
  Application.ProcessMessages;

  InternetCloseHandle(hsession);
  Result := resStr; 
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
        shellexecute(application.handle, 'open', pchar('http://www.viathinksoft.de/update/?id=@'+VTSID), '', '', sw_normal);
      end;
    end
    else
    begin
      MessageDlg(LNG_NO_UPDATE, mtInformation, [mbOk], 0);
    end;
  end;
end;

end.
