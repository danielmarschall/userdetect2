unit UD2_Parsing;

interface

uses
  Windows, SysUtils;

// TODO : WideStrings  idName: WideString;   ???

const
  // Prefixes for UD2_RunCmd()
  UD2_RUN_IN_OWN_DIRECTORY_PREFIX = '$RIOD$';
  UD2_RUN_AS_ADMIN                = '$ADMIN$';

type
  TUD2Command = record
    executable: string;
    runAsAdmin: boolean;
    runInOwnDirectory: boolean;
    windowMode: integer;
  end;
  TUD2CommandArray = array of TUD2Command;

  TUD2TDFCondition = record
    idMethodName: string;
    idStr: string;
    dynamicDataUsed: Boolean;
    dynamicData: string;
    caseSensitive: boolean;
  end;
  TUD2TDFConditionArray = array of TUD2TDFCondition;

  TUD2TDFEntry = record
    ids: TUD2TDFConditionArray;
    commands: TUD2CommandArray;
  end;
  TUD2TDFEntryArray = array of TUD2TDFEntry;

// Split
function UD2P_ParseConditions(idTerm: string): TUD2TDFConditionArray;
function UD2P_ParseTdfLine(idTermAndCmd: string; var entry: TUD2TDFEntry): boolean;
function UD2P_DecodeCommand(line: string): TUD2Command;
function UD2P_DecodeCondition(idName: string; var cond: TUD2TDFCondition): boolean;

// Merge
function UD2_CondToStr(cond: TUD2TDFCondition): string;
function UD2_CondsToStr(conds: TUD2TDFConditionArray): string;

implementation

uses
  UD2_Utils;

function UD2_CondsToStr(conds: TUD2TDFConditionArray): string;
var
  i: integer;
begin
  result := '';
  for i := Low(conds) to High(conds) do
  begin
    if result <> '' then result := result + '&&';
    result := result + UD2_CondToStr(conds[i]);
  end;
end;

function UD2_CondToStr(cond: TUD2TDFCondition): string;
begin
  if cond.dynamicDataUsed then
  begin
    result := cond.idMethodName+'('+cond.dynamicData+'):'+cond.idStr;
  end
  else
  begin
    result := cond.idMethodName+':'+cond.idStr;
  end;
end;

function UD2P_DecodeCommand(line: string): TUD2Command;
begin
  result.runAsAdmin := Pos(UD2_RUN_AS_ADMIN, line) >= 1;
  if result.runAsAdmin then
  begin
    line := StringReplace(line, UD2_RUN_AS_ADMIN, '', [rfReplaceAll]);
  end;

  result.runInOwnDirectory := Pos(UD2_RUN_IN_OWN_DIRECTORY_PREFIX, line) >= 1;
  if result.runInOwnDirectory then
  begin
    line := StringReplace(line, UD2_RUN_IN_OWN_DIRECTORY_PREFIX, '', [rfReplaceAll]);
  end;

  result.executable := line;
  result.WindowMode := SW_NORMAL;  // TODO (future): make it configurable
end;

function UD2P_DecodeCondition(idName: string; var cond: TUD2TDFCondition): boolean;
const
  CASE_SENSITIVE_FLAG = '$CASESENSITIVE$';
var
  a, b: TArrayOfString;
begin
  result := false;

  cond.caseSensitive := Pos(CASE_SENSITIVE_FLAG, idName) >= 1;
  if cond.caseSensitive then
  begin
    idName := StringReplace(idName, CASE_SENSITIVE_FLAG, '', [rfReplaceAll]);
  end;

  /// --- Start Dynamic Extension
  // xxxxxx ( xxxxx ):  xxxxxxxxxxxx
  // xxxxx  ( xx:xx ):  xxxxx:xxx(x)
  // xxxxxxxxxxxx    :  xxxxx(xxx)xx

  SetLength(a, 0);
  a := SplitString('(', idName);
  if (Length(a) >= 2) and (Pos(':', a[0]) = 0) then
  begin
    SetLength(b, 0);
    b := SplitString('):', a[1]);
    if Length(b) >= 2 then
    begin
      cond.idMethodName    := a[0];
      cond.idStr           := b[1];
      cond.dynamicDataUsed := true;
      cond.dynamicData     := b[0];
      result := true;
      Exit;
    end;
  end;
  /// --- End Dynamic Extension

  if not result then
  begin
    a := SplitString(':', idName);
    if Length(a) >= 2 then
    begin
      cond.idMethodName    := a[0];
      cond.idStr           := a[1];
      cond.dynamicDataUsed := false;
      cond.dynamicData     := '';
      result := true;
      Exit;
    end;
  end;
end;

function UD2P_ParseConditions(idTerm: string): TUD2TDFConditionArray;
var
  cond: TUD2TDFCondition;
  x: TArrayOfString;
  i, l: integer;
  idName: string;
begin
  SetLength(x, 0);
  x := SplitString('&&', idTerm);
  SetLength(result, 0);
  for i := Low(x) to High(x) do
  begin
    idName := x[i];
    if UD2P_DecodeCondition(idName, cond) then
    begin
      l := Length(result);
      SetLength(result, l+1);
      result[l] := cond;
    end;
  end;
end;

function UD2P_ParseTdfLine(idTermAndCmd: string; var entry: TUD2TDFEntry): boolean;
var
  nameVal: TArrayOfString;
  idTerm, cmd: string;
begin
  result := false;

  // Split conditions and command
  nameVal := SplitString('=', idTermAndCmd); // TODO: problem... "=" could be inside dynamicData...
  if Length(nameVal) < 2 then exit;
  idTerm := nameVal[0];
  if Pos(':', idTerm) = 0 then Exit; // e.g. the INI entry "Description" 
  cmd    := nameVal[1];

  // Decode conditions
  entry.ids := UD2P_ParseConditions(idTerm);

  // Decode command
  SetLength(entry.commands, 1);
  entry.commands[0] := UD2P_DecodeCommand(cmd);

  result := true;
end;

end.
 