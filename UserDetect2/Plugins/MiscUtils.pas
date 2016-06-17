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
procedure EnvironmentStringsToStrings(outSL: TStrings);
function GetPlatformID: integer;

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
// Source: http://www.delphi-treff.de/tipps-tricks/netzwerkinternet/netzwerkeigenschaften/computernamen-des-eigenen-rechners-ermitteln/
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

function GetPlatformID: integer;
var
  OSVersionInfo: TOSVersionInfo;
begin
  OSVersionInfo.dwOSVersionInfoSize := SizeOf(OSVersionInfo);
  GetVersionEx(OSVersionInfo);
  result := OSVersionInfo.dwPlatformID;
end;

end.
