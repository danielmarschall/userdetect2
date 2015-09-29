unit UD2_PluginUtils;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows, Classes, UD2_PluginIntf;

(*
function WritePascalStringToPointerA(lpDestination: LPSTR; cchSize: DWORD;
  stSource: AnsiString): UD2_STATUSCODE;
*)

function WritePascalStringToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  stSource: WideString): UD2_STATUSCODE;

(*
function WriteStringListToPointerA(lpDestination: LPSTR; cchSize: DWORD;
  slSource: TStrings): UD2_STATUSCODE;
*)

function WriteStringListToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  slSource: TStrings): UD2_STATUSCODE;

implementation

uses
  Math;

(*
function WritePascalStringToPointerA(lpDestination: LPSTR; cchSize: DWORD;
  stSource: AnsiString): UD2_STATUSCODE;
var
  cchSource: DWORD;
begin
  if cchSize = 0 then
  begin
    result := STATUS_INVALID_ARGS;
    Exit;
  end;
  if stSource = '' then
  begin
    ZeroMemory(lpDestination, SizeOf(AnsiChar));
    result := STATUS_OK;
  end
  else
  begin
    CopyMemory(lpDestination, @stSource[1], cchSize*SizeOf(AnsiChar));
    cchSource := Cardinal(Length(stSource));
    if cchSource >= cchSize then
    begin
      result := STATUS_BUFFER_TOO_SMALL;
      ZeroMemory(lpDestination+(cchSize-1)*SizeOf(AnsiChar), SizeOf(AnsiChar));
    end
    else
    begin
      result := STATUS_OK;
    end;
  end;
end;
*)

function WritePascalStringToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  stSource: WideString): UD2_STATUSCODE;
var
  cchSource: DWORD;
  cchCopy: DWORD;
begin
  if cchSize = 0 then
  begin
    result := UD2_STATUS_INVALID_ARGS;
    Exit;
  end;
  
  cchSource := Cardinal(Length(stSource));
  cchCopy   := Cardinal(Min(cchSource, cchSize));
  if cchCopy > 0 then
  begin
    CopyMemory(lpDestination, @stSource[1], cchCopy*SizeOf(WideChar));
  end;
  ZeroMemory(lpDestination+cchCopy*SizeOf(WideChar), SizeOf(WideChar));

  if cchSource >= cchSize then
  begin
    result := UD2_STATUS_BUFFER_TOO_SMALL;
  end
  else
  begin
    result := UD2_STATUS_OK;
  end;
end;

(*
function WriteStringListToPointerA(lpDestination: LPSTR; cchSize: DWORD;
  slSource: TStrings): UD2_STATUSCODE;
var
  stSource: AnsiString;
  i: integer;
begin
  stSource := '';
  for i := 0 to slSource.Count-1 do
  begin
    if i > 0 then stSource := stSource + UD2_MULTIPLE_ITEMS_DELIMITER;
    stSource := stSource + slSource.Strings[i];
  end;
  result := WritePascalStringToPointerA(lpDestination, cchSize, stSource);
end;
*)

function WriteStringListToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  slSource: TStrings): UD2_STATUSCODE;
var
  stSource: WideString;
  i: integer;
begin
  stSource := '';
  for i := 0 to slSource.Count-1 do
  begin
    if i > 0 then stSource := stSource + UD2_MULTIPLE_ITEMS_DELIMITER;
    stSource := stSource + slSource.Strings[i];
  end;
  result := WritePascalStringToPointerW(lpDestination, cchSize, stSource);
end;

end.
