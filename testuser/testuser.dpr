program testuser;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  Functions in 'Functions.pas';

type
  EInvalidName = class(Exception);

const
  C_TEMPLATES: array[0..5] of String =
    ('USER', 'COMP', 'SID', 'HOME', 'HOMESHARE', 'HOMECOMP');

resourcestring
  C_TEMPLATE_MARKER = ':%s:';
  C_EQUAL = '%s = %s';

function _GetArgExpect(param1: string): string;
resourcestring
  LNG_EXCEPTION = 'Unknown value "%s"';
begin
  if param1 = C_TEMPLATES[0] then
  begin
    result := Functions.GetUserName;
  end
  else if param1 = C_TEMPLATES[1] then
  begin
    result := Functions.GetComputerName;
  end
  else if param1 = C_TEMPLATES[2] then
  begin
    result := Functions.GetCurrentUserSid;
  end
  else if param1 = C_TEMPLATES[3] then
  begin
    result := Functions.GetHomeDir;
  end
  else if param1 = C_TEMPLATES[4] then
  begin
    result := ExpandEnvironmentStrings('%HOMESHARE%');
    if result = '%HOMESHARE%' then result := '';
  end
  else if param1 = C_TEMPLATES[5] then
  begin
    result := Functions.GetHomeDir;
    if result <> '' then
    begin
      result := '\\' + GetComputerName + '\' + StringReplace(result, ':', '$', []);
    end;
  end
  else
  begin
    raise EInvalidName.CreateFmt(LNG_EXCEPTION, [param1]);
  end;
end;

function _MaxTemplateLen: integer;
var
  i, L: integer;
begin
  result := -1;
  for i := Low(C_TEMPLATES) to High(C_TEMPLATES) do
  begin
    L := Length(Format(C_TEMPLATE_MARKER, [C_TEMPLATES[i]]));
    if L > result then result := L;
  end;
end;

procedure _ShowSyntax;
resourcestring
  LNG_SYNTAX_1 = 'Syntax:' + #13#10 + '%s [templateString] [comparisonValue]';
  LNG_SYNTAX_2 = 'templateString may contain following variables:';
  LNG_SYNTAX_3 = 'If comparisonValue is provided, the value will be compared with templateString ' + #13#10 +
                 'where variables are resolved. The ExitCode will be 0 if the values match ' + #13#10 +
                 '(case insensitive) or 1 if the value does not match.' + #13#10#13#10 +
                 'If comparisonValue is not provided, the value will be printed and the program' + #13#10 +
                 'terminates with ExitCode 0.';
var
  i: integer;
  s: string;
  maxLen: integer;
begin
  WriteLn(Format(LNG_SYNTAX_1, [UpperCase(ExtractFileName(ParamStr(0)))]));
  WriteLn('');
  WriteLn(LNG_SYNTAX_2);
  maxLen := _MaxTemplateLen;
  for i := Low(C_TEMPLATES) to High(C_TEMPLATES) do
  begin
    s := C_TEMPLATES[i];
    WriteLn(Format(C_EQUAL, [EnforceLength(Format(C_TEMPLATE_MARKER, [s]),
      maxLen, ' ', true), _GetArgExpect(s)]));
  end;
  WriteLn('');
  WriteLn(LNG_SYNTAX_3);
  WriteLn('');
end;

function _Expand(AInput: string): string;
var
  i: integer;
  s: string;
begin
  result := AInput;
  for i := Low(C_TEMPLATES) to High(C_TEMPLATES) do
  begin
    s := C_TEMPLATES[i];
    result := StringReplace(result, Format(C_TEMPLATE_MARKER, [s]),
      _GetArgExpect(s), [rfIgnoreCase, rfReplaceAll]);
  end;
end;

function _Main: integer;
var
  arg2expect: string;
begin
  result := 0;

  if (ParamCount() = 0) or (ParamCount() > 2) or (ParamStr(1) = '/?') then
  begin
    _ShowSyntax;
    result := 2;
    Exit;
  end;

  arg2expect := _Expand(ParamStr(1));

  if ParamCount() = 1 then
  begin
    WriteLn(Format(C_EQUAL, [ParamStr(1), arg2expect]));
  end
  else if ParamCount() = 2 then
  begin
    if not StrICmp(ParamStr(2), arg2expect) then result := 1;
  end;
end;

begin
  ExitCode := _Main;
end.
