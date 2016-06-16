unit MiscUtils;

interface

uses
  SysUtils,
  Registry,
  Windows,
  Classes;

function GetUserName: string;
function GetComputerName: string;
function ExpandEnvironmentStrings(ATemplate: string): string;
function GetHomeDir: string;
function GetComputerSID: string;
procedure EnvironmentStringsToStrings(outSL: TStrings);

implementation

function GetHomeDir: string;
var
  reg: TRegistry;
begin
  result := ExpandEnvironmentStrings('%HOMEDRIVE%%HOMEPATH%');
  if result = '%HOMEDRIVE%%HOMEPATH%' then
  begin
    result := '';

    // Windows 95
    reg := TRegistry.Create;
    try
      reg.RootKey := HKEY_CURRENT_USER;
      if reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\ProfileReconciliation') then
      begin
        result := reg.ReadString('ProfileDirectory');
        reg.CloseKey;
      end;
    finally;
      reg.Free;
    end;
  end;
end;

function GetComputerName: string;
// http://www.delphi-treff.de/tipps-tricks/netzwerkinternet/netzwerkeigenschaften/computernamen-des-eigenen-rechners-ermitteln/
var
  Len: DWORD;
begin
  Len := MAX_COMPUTERNAME_LENGTH+1;
  SetLength(Result,Len);
  if Windows.GetComputerName(PChar(Result), Len) then
    SetLength(Result,Len)
  else
    RaiseLastOSError;
end;

function ExpandEnvironmentStrings(ATemplate: string): string;
var
  buffer: array[0..MAX_PATH] of Char; // MAX_PATH ?
  size: DWORD;
begin
  size := SizeOf(buffer);
  ZeroMemory(@buffer, size);
  Windows.ExpandEnvironmentStrings(PChar(ATemplate), buffer, size);
  SetString(result, buffer, lstrlen(buffer));
end;



// --- http://stackoverflow.com/a/7643383 ---

function ConvertSidToStringSid(Sid: PSID; out StringSid: PChar): BOOL; stdcall;
  external 'ADVAPI32.DLL' name {$IFDEF UNICODE} 'ConvertSidToStringSidW'{$ELSE} 'ConvertSidToStringSidA'{$ENDIF};

function SIDToString(ASID: PSID): string;
var
  StringSid : PChar;
begin
  ConvertSidToStringSid(ASID, StringSid);
  Result := string(StringSid);
end;

function GetComputerSID:string;
var
  Sid: PSID;
  cbSid: DWORD;
  cbReferencedDomainName : DWORD;
  ReferencedDomainName: string;
  peUse: SID_NAME_USE;
  Success: BOOL;
  lpSystemName : string;
  lpAccountName: string;
begin
  Sid:=nil;
  try
    lpSystemName:='';
    lpAccountName:=GetComputerName;

    cbSid := 0;
    cbReferencedDomainName := 0;
    // First call to LookupAccountName to get the buffer sizes.
    Success := LookupAccountName(PChar(lpSystemName), PChar(lpAccountName), nil, cbSid, nil, cbReferencedDomainName, peUse);
    if (not Success) and (GetLastError = ERROR_INSUFFICIENT_BUFFER) then
    begin
      SetLength(ReferencedDomainName, cbReferencedDomainName);
      Sid := AllocMem(cbSid);
      // Second call to LookupAccountName to get the SID.
      Success := LookupAccountName(PChar(lpSystemName), PChar(lpAccountName), Sid, cbSid, PChar(ReferencedDomainName), cbReferencedDomainName, peUse);
      if not Success then
      begin
        FreeMem(Sid);
        Sid := nil;
        RaiseLastOSError;
      end
      else
        Result := SIDToString(Sid);
    end
    else
      RaiseLastOSError;
  finally
    if Assigned(Sid) then
     FreeMem(Sid);
  end;
end;

procedure EnvironmentStringsToStrings(outSL: TStrings);
var
  DosEnv: PChar;
begin
  DosEnv := GetEnvironmentStrings;
  try
    while DosEnv^ <> #0 do
    begin
      outSL.Add(StrPas(DosEnv));
      Inc(DosEnv, lStrLen(DosEnv) + 1);
    end;
  finally
    FreeEnvironmentStrings(DosEnv);
  end;
end;

function GetUserName: string; // Source: Luckie@DP
var
  buffer: array[0..MAX_PATH] of Char; // MAX_PATH ?
  size: DWORD;
begin
  size := SizeOf(buffer);
  ZeroMemory(@buffer, size);
  Windows.GetUserName(buffer, size);
  SetString(result, buffer, lstrlen(buffer));
end;

end.
