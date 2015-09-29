unit Functions;

interface

function GetComputerName: string;
function GetUserName: string;
function GetCurrentUserSid: string;
function ExpandEnvironmentStrings(ATemplate: string): string;
function StrICmp(a, b: string): boolean;
function EnforceLength(s: string; len: integer; filler: char;
  appendRight: boolean): string;
function GetHomeDir: string;

implementation

uses
  Windows, SysUtils, Registry, SPGetSid;

function GetComputerName: string; // Source: Luckie@DP
var
  buffer: array[0..MAX_PATH] of Char; // MAX_PATH ?
  size: DWORD;
begin
  size := SizeOf(buffer);
  ZeroMemory(@buffer, size);
  Windows.GetComputerName(buffer, size);
  SetString(result, buffer, lstrlen(buffer));
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

function GetCurrentUserSid: string;
begin
  result := SPGetSid.GetCurrentUserSid;
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

function StrICmp(a, b: string): boolean;
begin
  result := UpperCase(a) = UpperCase(b);
end;

function EnforceLength(s: string; len: integer; filler: char;
  appendRight: boolean): string;
begin
  result := s;
  while (Length(result) < len) do
  begin
    if appendRight then
    begin
      result := result + filler;
    end
    else
    begin
      result := filler + result;
    end;
  end;
end;

function GetHomeDir: string;
var
  reg: TRegistry;
begin
  result := Functions.ExpandEnvironmentStrings('%HOMEDRIVE%%HOMEPATH%');
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

end.
