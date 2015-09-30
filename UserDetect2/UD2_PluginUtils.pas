unit UD2_PluginUtils;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows, Classes, UD2_PluginIntf;

function UD2_WritePascalStringToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  stSource: WideString): UD2_STATUS;

function UD2_WriteStringListToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  slSource: TStrings): UD2_STATUS;

implementation

uses
  Math;

function UD2_IsMultiLineW(s: WideString): boolean;
var
  i: integer;
  c: WideChar;
begin
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if c = UD2_MULTIPLE_ITEMS_DELIMITER then //if (c = #10) or (c = #13) then
    begin
      Result := true;
      Exit;
    end;
  end;
  Result := false;
end;

function UD2_WritePascalStringToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  stSource: WideString): UD2_STATUS;
var
  cchSource: DWORD;
  cchCopy: DWORD;
begin
  if cchSize = 0 then
  begin
    result := UD2_STATUS_ERROR_INVALID_ARGS;
    Exit;
  end;

  cchSource := Cardinal(Length(stSource));
  cchCopy   := Cardinal(Min(cchSource, cchSize));
  if cchCopy > 0 then
  begin
    CopyMemory(lpDestination, @stSource[1], cchCopy*SizeOf(WideChar));
  end;
  lpDestination[cchCopy] := #0;

  if cchSource >= cchSize then
    result := UD2_STATUS_ERROR_BUFFER_TOO_SMALL
  else if stSource = '' then
    result := UD2_STATUS_NOTAVAIL_UNSPECIFIED
  else if UD2_IsMultiLineW(stSource) then
    result := UD2_STATUS_OK_MULTILINE
  else
    result := UD2_STATUS_OK_SINGLELINE;
end;

function UD2_WriteStringListToPointerW(lpDestination: LPWSTR; cchSize: DWORD;
  slSource: TStrings): UD2_STATUS;
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
  result := UD2_WritePascalStringToPointerW(lpDestination, cchSize, stSource);
end;

end.
