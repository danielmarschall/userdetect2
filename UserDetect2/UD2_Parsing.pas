unit UD2_Parsing;

interface

uses
  Windows, SysUtils;

// TODO: use this for better object oriented programming

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

implementation

uses
  UD2_Utils;

function ParseTdfLine(line: string; var entry: TUD2TDFEntry): boolean;
begin
  // TODO: xxxxx

  (*
  entry.idName: string;
  entry.idValue: string;
  entry.dynamicDataUsed: Boolean;
  entry.dynamicData: string;
  entry.caseSensitive: boolean;
  entry.commands: TUD2CommandArray;
  *)

  // ReadSectionValues


  (*
    nameVal := SplitString('=', idTermAndCmd);
    if Length(nameVal) < 2 then exit;
    idTerm := nameVal[0];
    cmd    := nameVal[1];
  *)
end;

function ParseCommandLine(line: string; var cmd: TUD2Command): boolean;
begin
  if Pos(UD2_RUN_AS_ADMIN, line) >= 1 then
  begin
    line := StringReplace(line, UD2_RUN_AS_ADMIN, '', [rfReplaceAll]);
    cmd.runAsAdmin := true;
  end
  else cmd.runAsAdmin := false;

  if Pos(UD2_RUN_IN_OWN_DIRECTORY_PREFIX, line) >= 1 then
  begin
    line := StringReplace(line, UD2_RUN_IN_OWN_DIRECTORY_PREFIX, '', [rfReplaceAll]);
    cmd.runInOwnDirectory := true;
  end
  else cmd.runInOwnDirectory := false;

  cmd.executable := line;

  cmd.windowMode := SW_NORMAL; // TODO (future): make it configurable

  result := true;
end;

end.
 