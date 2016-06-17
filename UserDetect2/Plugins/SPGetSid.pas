(******************************************************************************)
(* SPGetSid - Retrieve the current user's SID in text format                  *)
(*                                                                            *)
(* Copyright (c) 2004 Shorter Path Software                                   *)
(* http://www.shorterpath.com                                                 *)
(******************************************************************************)

            (*** Modified and extended by ViaThinkSoft ***)

{
  SID is a data structure of variable length that identifies user, group,
  and computer accounts.
  Every account on a network is issued a unique SID when the account is first created.
  Internal processes in Windows refer to an account's SID
  rather than the account's user or group name.
}


unit SPGetSid;

interface

uses
  Windows, SysUtils;

function GetCurrentUserSid: string;
function GetComputerSID: string;

implementation

const
  HEAP_ZERO_MEMORY = $00000008;
  SID_REVISION     = 1; // Current revision level

type
  PTokenUser = ^TTokenUser;
  TTokenUser = packed record
    User: TSidAndAttributes;
  end;

function ConvertSid(Sid: PSID; pszSidText: PChar; var dwBufferLen: DWORD): BOOL;
var
  psia: PSIDIdentifierAuthority;
  dwSubAuthorities: DWORD;
  dwSidRev: DWORD;
  dwCounter: DWORD;
  dwSidSize: DWORD;
begin
  Result := False;

  dwSidRev := SID_REVISION;

  if not IsValidSid(Sid) then Exit;

  psia := GetSidIdentifierAuthority(Sid);

  dwSubAuthorities := GetSidSubAuthorityCount(Sid)^;

  dwSidSize := (15 + 12 + (12 * dwSubAuthorities) + 1) * SizeOf(Char);

  if (dwBufferLen < dwSidSize) then
  begin
    dwBufferLen := dwSidSize;
    SetLastError(ERROR_INSUFFICIENT_BUFFER);
    Exit;
  end;

  StrFmt(pszSidText, 'S-%u-', [dwSidRev]);

  if (psia.Value[0] <> 0) or (psia.Value[1] <> 0) then
    StrFmt(pszSidText + StrLen(pszSidText),
      '0x%.2x%.2x%.2x%.2x%.2x%.2x',
      [psia.Value[0], psia.Value[1], psia.Value[2],
      psia.Value[3], psia.Value[4], psia.Value[5]])
  else
    StrFmt(pszSidText + StrLen(pszSidText),
      '%u',
      [DWORD(psia.Value[5]) +
      DWORD(psia.Value[4] shl 8) +
      DWORD(psia.Value[3] shl 16) +
      DWORD(psia.Value[2] shl 24)]);

  dwSidSize := StrLen(pszSidText);

  for dwCounter := 0 to dwSubAuthorities - 1 do
  begin
    StrFmt(pszSidText + dwSidSize, '-%u',
      [GetSidSubAuthority(Sid, dwCounter)^]);
    dwSidSize := StrLen(pszSidText);
  end;

  Result := True;
end;

function ObtainTextSid(hToken: THandle; pszSid: PChar; var dwBufferLen: DWORD): BOOL;
var
  dwReturnLength: DWORD;
  dwTokenUserLength: DWORD;
  tic: TTokenInformationClass;
  ptu: Pointer;
begin
  Result := False;
  dwReturnLength := 0;
  dwTokenUserLength := 0;
  tic := TokenUser;
  ptu := nil;

  if not GetTokenInformation(hToken, tic, ptu, dwTokenUserLength,
    dwReturnLength) then
  begin
    if GetLastError = ERROR_INSUFFICIENT_BUFFER then
    begin
      ptu := HeapAlloc(GetProcessHeap, HEAP_ZERO_MEMORY, dwReturnLength);
      if ptu = nil then Exit;
      dwTokenUserLength := dwReturnLength;
      dwReturnLength    := 0;

      if not GetTokenInformation(hToken, tic, ptu, dwTokenUserLength,
        dwReturnLength) then Exit;
    end 
    else 
      Exit;
  end;

  if not ConvertSid((PTokenUser(ptu).User).Sid, pszSid, dwBufferLen) then Exit;

  if not HeapFree(GetProcessHeap, 0, ptu) then Exit;

  Result := True;
end;

function GetCurrentUserSid: string;
var
  hAccessToken: THandle;
  bSuccess: BOOL;
  dwBufferLen: DWORD;
  szSid: array[0..MAX_PATH] of Char;
begin
  Result := '';

  bSuccess := OpenThreadToken(GetCurrentThread, TOKEN_QUERY, True,
    hAccessToken);
  if not bSuccess then
  begin
    if GetLastError = ERROR_NO_TOKEN then
      bSuccess := OpenProcessToken(GetCurrentProcess, TOKEN_QUERY,
        hAccessToken);
  end;
  if bSuccess then
  begin
    ZeroMemory(@szSid, SizeOf(szSid));
    dwBufferLen := SizeOf(szSid);

    if ObtainTextSid(hAccessToken, szSid, dwBufferLen) then
      Result := szSid;
    CloseHandle(hAccessToken);
  end;
end;

// --- Section added by ViaThinkSoft ---

function SIDToString(ASID: PSID): string;

  function _FallBack: string;
  var
    StringSid : PChar;
    len: DWORD;
  begin
    len := MAX_PATH;
    StringSid := AllocMem(MAX_PATH);
    ConvertSid(ASID, StringSid, len);
    Result := string(StringSid);
    FreeMem(StringSid);
  end;

type
  TFuncConvertSidToStringSid = function(Sid: PSID; out StringSid: PChar): BOOL; stdcall;
var
  dllHandle: Cardinal;
  fConvertSidToStringSid: TFuncConvertSidToStringSid;
  StringSid : PChar;
begin
  dllHandle := LoadLibrary(advapi32);
  if dllHandle = 0 then
  begin
    result := _FallBack;
    Exit;
  end;
  try
    @fConvertSidToStringSid := GetProcAddress(dllHandle, {$IFDEF UNICODE}'ConvertSidToStringSidW'{$ELSE}'ConvertSidToStringSidA'{$ENDIF});
    if not Assigned(fConvertSidToStringSid) then
    begin
      result := _FallBack;
      Exit;
    end;

    fConvertSidToStringSid(ASID, StringSid);
    Result := string(StringSid);
    LocalFree(HLocal(StringSid)); // added by ViaThinkSoft
  finally
    FreeLibrary(dllHandle);
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

function GetComputerSID: string;
// Source: http://stackoverflow.com/a/7643383
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
  result := '';
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

end.
