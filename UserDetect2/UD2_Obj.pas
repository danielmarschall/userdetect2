unit UD2_Obj;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

{$INCLUDE 'UserDetect2.inc'}

uses
  Windows, SysUtils, Classes, IniFiles, Contnrs, Dialogs, UD2_PluginIntf,
  UD2_PluginStatus, UD2_Utils, UD2_Parsing;

const
  UD2_TagDescription = 'Description';

type
  TUD2IdentificationEntry = class;

  TUD2Plugin = class(TObject)
  protected
    FDetectedIdentifications: TObjectList{<TUD2IdentificationEntry>};
    FOSNotSupportedEnforced: boolean;
    FPluginDLL: string;
    FPluginGUIDSet: boolean;
    FPluginGUID: TGUID;
    FPluginName: WideString;
    FPluginVendor: WideString;
    FPluginVersion: WideString;
    FIdentificationMethodName: WideString;
    FAcceptsDynamicRequests: boolean;
    FIdentificationProcedureStatusCode: UD2_STATUS;
    FIdentificationProcedureStatusCodeDescribed: WideString;
    FLoadingTime: Cardinal;
  public
    // This flag will be set if "AutoOSNotSupportedCompatibility" of the INI manifest had to be enforced/used
    property OSNotSupportedEnforced: boolean read FOSNotSupportedEnforced;

    // Data read from the DLL
    property PluginDLL: string read FPluginDLL;
    property PluginGUIDSet: boolean read FPluginGUIDSet;
    property PluginGUID: TGUID read FPluginGUID;
    property PluginName: WideString read FPluginName;
    property PluginVendor: WideString read FPluginVendor;
    property PluginVersion: WideString read FPluginVersion;
    property IdentificationMethodName: WideString read FIdentificationMethodName;
    property AcceptsDynamicRequests: boolean read FAcceptsDynamicRequests;

    // ONLY contains the non-failure status code of IdentificationStringW
    property IdentificationProcedureStatusCode: UD2_STATUS read FIdentificationProcedureStatusCode;
    property IdentificationProcedureStatusCodeDescribed: WideString read FIdentificationProcedureStatusCodeDescribed;

    // How long did the plugin to load?
    property LoadingTime: Cardinal read FLoadingTime;

    function PluginGUIDString: string;
    property DetectedIdentifications: TObjectList{<TUD2IdentificationEntry>} read FDetectedIdentifications;
    destructor Destroy; override;
    constructor Create;
    function AddIdentification(IdStr: WideString): TUD2IdentificationEntry;

    function InvokeDynamicCheck(dynamicData: WideString; AErrorOut: TStrings; var outIDs: TArrayOfString): boolean; overload;
    function InvokeDynamicCheck(dynamicData: WideString; AErrorOut: TStrings): boolean; overload;
    function GetDynamicRequestResult(dynamicData: WideString; AErrorOut: TStrings=nil): TArrayOfString;

    function EqualsMethodNameOrGuid(idMethodNameOrGUID: string): boolean;
  end;

  TUD2IdentificationEntry = class(TObject)
  private
    FIdentificationString: WideString;
    FPlugin: TUD2Plugin;
    FDynamicDataUsed: boolean;
    FDynamicData: WideString;
  public
    property DynamicDataUsed: boolean read FDynamicDataUsed write FDynamicDataUsed;
    property DynamicData: WideString read FDynamicData write FDynamicData;
    property IdentificationString: WideString read FIdentificationString;
    property Plugin: TUD2Plugin read FPlugin;
    procedure GetIdNames(sl: TStrings);
    constructor Create(AIdentificationString: WideString; APlugin: TUD2Plugin);
  end;

  TUD2 = class(TObject)
  private
    {$IFDEF CHECK_FOR_SAME_PLUGIN_GUID}
    FGUIDLookup: TStrings;
    {$ENDIF}
  protected
    FLoadedPlugins: TObjectList{<TUD2Plugin>};
    FIniFile: TMemIniFile;
    FErrors: TStrings;
    FIniFileName: string;
  public
    property IniFileName: string read FIniFileName;
    property Errors: TStrings read FErrors;
    property LoadedPlugins: TObjectList{<TUD2Plugin>} read FLoadedPlugins;
    property IniFile: TMemIniFile read FIniFile;
    procedure GetAllDetectedIDs(outSL: TStrings);
    function FulfilsEverySubterm(conds: TUD2TDFConditionArray; slIdNames: TStrings=nil; AErrorOut: TStrings=nil): boolean; overload;
    function FulfilsEverySubterm(idTerm: WideString; slIdNames: TStrings=nil; AErrorOut: TStrings=nil): boolean; overload;
    function CheckTerm(idTermAndCmd: string; slIdNames: TStrings=nil; AErrorOut: TStrings=nil): TUD2CommandArray;
    function FindPluginByMethodNameOrGuid(idMethodName: string): TUD2Plugin;
    function GetCommandList(ShortTaskName: string; AErrorOut: TStrings=nil): TUD2CommandArray;
    procedure HandlePluginDir(APluginDir, AFileMask: string);
    procedure GetTaskListing(outSL: TStrings);
    constructor Create(AIniFileName: string);
    destructor Destroy; override;
    function TaskExists(ShortTaskName: string): boolean;
    function ReadMetatagString(ShortTaskName, MetatagName: string; DefaultVal: string): string;
    function ReadMetatagBool(ShortTaskName, MetatagName: string; DefaultVal: string): boolean;
    function GetTaskName(AShortTaskName: string): string;
    class function GenericErrorLookup(grStatus: UD2_STATUS): string;
  end;

implementation

uses
  Math;

const
  cchBufferSize = 32768;

type
  TUD2PluginLoader = class(TThread)
  protected
    dllFile: string;
    lngID: LANGID;
    useDynamicData: boolean;
    dynamicData: WideString;
    procedure Execute; override;
    function HandleDLL: boolean;
  public
    Plugin: TUD2Plugin;
    Errors: TStringList;
    ResultIdentifiers: TArrayOfString;
    constructor Create(Suspended: boolean; DLL: string; alngid: LANGID; useDynamicData: boolean; dynamicData: WideString);
    destructor Destroy; override;
  end;

class function TUD2.GenericErrorLookup(grStatus: UD2_STATUS): string;
resourcestring
  LNG_STATUS_OK_UNSPECIFIED               = 'Success (Unspecified)';
  LNG_STATUS_OK_SINGLELINE                = 'Success (One identifier returned)';
  LNG_STATUS_OK_MULTILINE                 = 'Success (Multiple identifiers returned)';
  LNG_UNKNOWN_SUCCESS                     = 'Success (Unknown status code %s)';

  LNG_STATUS_NOTAVAIL_UNSPECIFIED         = 'Not available (Unspecified)';
  LNG_STATUS_NOTAVAIL_OS_NOT_SUPPORTED    = 'Not available (Operating system not supported)';
  LNG_STATUS_NOTAVAIL_HW_NOT_SUPPORTED    = 'Not available (Hardware not supported)';
  LNG_STATUS_NOTAVAIL_NO_ENTITIES         = 'Not available (No entities to identify)';
  LNG_STATUS_NOTAVAIL_WINAPI_CALL_FAILURE = 'Not available (A Windows API call failed. Message: %s)';
  LNG_STATUS_NOTAVAIL_ONLY_ACCEPT_DYNAMIC = 'Not available (Arguments required)';
  LNG_STATUS_NOTAVAIL_INVALID_INPUT       = 'Not available (Plugin received invalid input)';
  LNG_STATUS_NOTAVAIL_DOES_NOT_ACCEPT_DYNAMIC_REQUESTS = 'Not available (Plugin does not allow dynamic requests)';
  LNG_UNKNOWN_NOTAVAIL                    = 'Not available (Unknown status code %s)';

  LNG_STATUS_FAILURE_UNSPECIFIED          = 'Error (Unspecified)';
  LNG_STATUS_FAILURE_BUFFER_TOO_SMALL     = 'Error (The provided buffer is too small!)';
  LNG_STATUS_FAILURE_INVALID_ARGS         = 'Error (An internal function received invalid arguments!)';
  LNG_STATUS_FAILURE_PLUGIN_NOT_LICENSED  = 'Error (The plugin is not licensed)';
  LNG_STATUS_FAILURE_NO_RETURNED_VALUE    = 'Error (Plugin did not return a status)';
  LNG_STATUS_FAILURE_CATCHED_EXCEPTION    = 'Error (Catched unexpected Exception)';
  LNG_UNKNOWN_FAILED                      = 'Error (Unknown status code %s)';

  LNG_UNKNOWN_STATUS                      = 'Unknown status code with unexpected category: %s';
begin
       if UD2_STATUS_Equal(grStatus, UD2_STATUS_OK_UNSPECIFIED, false)               then result := LNG_STATUS_OK_UNSPECIFIED
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_OK_SINGLELINE, false)                then result := LNG_STATUS_OK_SINGLELINE
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_OK_MULTILINE, false)                 then result := LNG_STATUS_OK_MULTILINE

  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_UNSPECIFIED, false)         then result := LNG_STATUS_NOTAVAIL_UNSPECIFIED
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED, false)    then result := LNG_STATUS_NOTAVAIL_OS_NOT_SUPPORTED
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_HW_NOT_SUPPORTED, false)    then result := LNG_STATUS_NOTAVAIL_HW_NOT_SUPPORTED
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_NO_ENTITIES, false)         then result := LNG_STATUS_NOTAVAIL_NO_ENTITIES
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_WINAPI_CALL_FAILURE, false) then result := Format(LNG_STATUS_NOTAVAIL_WINAPI_CALL_FAILURE, [FormatOSError(grStatus.dwExtraInfo)])
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_ONLY_ACCEPT_DYNAMIC, false) then result := LNG_STATUS_NOTAVAIL_ONLY_ACCEPT_DYNAMIC
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_INVALID_INPUT, false)       then result := LNG_STATUS_NOTAVAIL_INVALID_INPUT
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_NOTAVAIL_DOES_NOT_ACCEPT_DYNAMIC_REQUESTS, false) then result := LNG_STATUS_NOTAVAIL_DOES_NOT_ACCEPT_DYNAMIC_REQUESTS

  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_UNSPECIFIED, false)          then result := LNG_STATUS_FAILURE_UNSPECIFIED
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_BUFFER_TOO_SMALL, false)     then result := LNG_STATUS_FAILURE_BUFFER_TOO_SMALL
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_INVALID_ARGS, false)         then result := LNG_STATUS_FAILURE_INVALID_ARGS
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_PLUGIN_NOT_LICENSED, false)  then result := LNG_STATUS_FAILURE_PLUGIN_NOT_LICENSED
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_NO_RETURNED_VALUE, false)    then result := LNG_STATUS_FAILURE_NO_RETURNED_VALUE
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_CATCHED_EXCEPTION, false)    then result := LNG_STATUS_FAILURE_CATCHED_EXCEPTION

  else if grStatus.wCategory = UD2_STATUSCAT_SUCCESS   then result := Format(LNG_UNKNOWN_SUCCESS,  [UD2_STATUS_FormatStatusCode(grStatus)])
  else if grStatus.wCategory = UD2_STATUSCAT_NOT_AVAIL then result := Format(LNG_UNKNOWN_NOTAVAIL, [UD2_STATUS_FormatStatusCode(grStatus)])
  else if grStatus.wCategory = UD2_STATUSCAT_FAILED    then result := Format(LNG_UNKNOWN_FAILED,   [UD2_STATUS_FormatStatusCode(grStatus)])
  else                                                      result := Format(LNG_UNKNOWN_STATUS,   [UD2_STATUS_FormatStatusCode(grStatus)]);
end;

{ TUD2Plugin }

function TUD2Plugin.PluginGUIDString: string;
begin
  if PluginGUIDSet then
    result := UpperCase(GUIDToString(PluginGUID))
  else
    result := '';
end;

function TUD2Plugin.AddIdentification(IdStr: WideString): TUD2IdentificationEntry;
begin
  result := TUD2IdentificationEntry.Create(IdStr, Self);
  DetectedIdentifications.Add(result);
end;

destructor TUD2Plugin.Destroy;
begin
  DetectedIdentifications.Free;
  inherited;
end;

constructor TUD2Plugin.Create;
begin
  inherited Create;
  FDetectedIdentifications := TObjectList{<TUD2IdentificationEntry>}.Create(true);
end;

function TUD2Plugin.InvokeDynamicCheck(dynamicData: WideString; AErrorOut: TStrings; var outIDs: TArrayOfString): boolean;
var
  ude: TUD2IdentificationEntry;
  i: integer;
  id: string;
  l: integer;
begin
  result := false;

  SetLength(outIDs, 0);

  for i := 0 to FDetectedIdentifications.Count-1 do
  begin
    ude := FDetectedIdentifications.Items[i] as TUD2IdentificationEntry;
    if ude.dynamicDataUsed and (ude.dynamicData = dynamicData) then
    begin
      l := Length(outIDs);
      SetLength(outIDs, l+1);
      outIDs[l] := ude.FIdentificationString;
    end;
  end;

  // The dynamic content was already evaluated (and therefore is already added in FDetectedIdentifications).
  if Length(outIDs) > 0 then exit;

  outIDs := GetDynamicRequestResult(dynamicData, AErrorOut);

  for i := 0 to Length(outIDs)-1 do
  begin
    id := outIDs[i];

    ude := AddIdentification(id);
    ude.dynamicDataUsed := true;
    ude.dynamicData := dynamicData;

    result := true;
  end;
end;

function TUD2Plugin.GetDynamicRequestResult(dynamicData: WideString; AErrorOut: TStrings=nil): TArrayOfString;
var
  lngID: LANGID;
  loader: TUD2PluginLoader;
begin
  lngID := GetSystemDefaultLangID;

  loader := TUD2PluginLoader.Create(false, PluginDLL, lngid, true, dynamicData);
  try
    loader.WaitFor;
    result := loader.ResultIdentifiers;
    if Assigned(AErrorOut) then
    begin
      AErrorOut.AddStrings(loader.Errors);
    end;

    // TODO: Use assign() instead? or allow TUD2PluginLoader to write the TPlugin object directly?
    //       Should we even overwrite the current plugin data, or return the new plugin?
    FIdentificationProcedureStatusCode := loader.plugin.IdentificationProcedureStatusCode;
    FIdentificationProcedureStatusCodeDescribed := loader.plugin.IdentificationProcedureStatusCodeDescribed;
    FOSNotSupportedEnforced := loader.plugin.OSNotSupportedEnforced;
    FLoadingTime := loader.Plugin.LoadingTime;

  finally
    if Assigned(loader.Plugin) then FreeAndNil(loader.Plugin);
    loader.Free;
  end;
end;

function TUD2Plugin.EqualsMethodNameOrGuid(idMethodNameOrGUID: string): boolean;
begin
  result := SameText(IdentificationMethodName, idMethodNameOrGUID) or
            SameText(GUIDToString(PluginGUID), idMethodNameOrGUID)
end;

function TUD2Plugin.InvokeDynamicCheck(dynamicData: WideString; AErrorOut: TStrings): boolean;
var
  dummy: TArrayOfString;
begin
  result := InvokeDynamicCheck(dynamicData, AErrorOut, dummy)
end;

{ TUD2IdentificationEntry }

procedure TUD2IdentificationEntry.GetIdNames(sl: TStrings);
var
  cond: TUD2TDFCondition;
begin
  cond.idMethodName := Plugin.IdentificationMethodName;
  cond.idStr := IdentificationString;
  cond.dynamicDataUsed := DynamicDataUsed;
  cond.dynamicData := DynamicData;
  sl.Add(UD2_CondToStr(cond));

  cond.idMethodName := Plugin.PluginGUIDString;
  sl.Add(UD2_CondToStr(cond));
end;

constructor TUD2IdentificationEntry.Create(AIdentificationString: WideString;
  APlugin: TUD2Plugin);
begin
  inherited Create;

  // TODO: We need to do this, because ReadSectionValues strips the names of the name-value pairs...
  //       We should correct ReadSectionValues...
  // Example: DriveSerial(c:):2SHSWNHA010807 X    =calc.exe
  // ReadSectionValues will return "DriveSerial(c:):2SHSWNHA010807 X=calc.exe"
  AIdentificationString := Trim(AIdentificationString);

  FIdentificationString := AIdentificationString;
  FPlugin := APlugin;
end;

{ TUD2 }

procedure TUD2.HandlePluginDir(APluginDir, AFileMask: string);
Var
  SR: TSearchRec;
  path: string;
  pluginLoader: TUD2PluginLoader;
  tob: TObjectList{<TUD2PluginLoader>};
  i: integer;
  {$IFDEF CHECK_FOR_SAME_PLUGIN_GUID}
  sPluginID, prevDLL: string;
  {$ENDIF}
  lngid: LANGID;
resourcestring
  LNG_PLUGINS_SAME_GUID = 'Attention: The plugin "%s" and the plugin "%s" have the same identification GUID. The latter will not be loaded.';
begin
  tob := TObjectList{<TUD2PluginLoader>}.Create;
  try
    tob.OwnsObjects := false;

    lngID := GetSystemDefaultLangID;

    path := APluginDir;
    if path <> '' then path := IncludeTrailingPathDelimiter(path);

    if FindFirst(path + AFileMask, 0, SR) = 0 then
    begin
      try
        repeat
          try
            tob.Add(TUD2PluginLoader.Create(false, path + sr.Name, lngid, false, ''));
          except
            on E: Exception do
            begin
              MessageDlg(E.Message, mtError, [mbOK], 0);
            end;
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;

    for i := 0 to tob.count-1 do
    begin
      pluginLoader := tob.items[i] as TUD2PluginLoader;
      pluginLoader.WaitFor;
      Errors.AddStrings(pluginLoader.Errors);
      if Assigned(pluginLoader.Plugin) then
      begin
        {$IFDEF CHECK_FOR_SAME_PLUGIN_GUID}
        if pluginLoader.Plugin.PluginGUIDSet then
        begin
          sPluginID := GUIDToString(pluginLoader.Plugin.PluginGUID);
          prevDLL := FGUIDLookup.Values[sPluginID];
          if (prevDLL <> '') and (prevDLL <> pluginLoader.Plugin.PluginDLL) then
          begin
            Errors.Add(Format(LNG_PLUGINS_SAME_GUID, [prevDLL, pluginLoader.Plugin.PluginDLL]));
            pluginLoader.Plugin.Free;
          end
          else
          begin
            FGUIDLookup.Values[sPluginID] := pluginLoader.Plugin.PluginDLL;
            LoadedPlugins.Add(pluginLoader.Plugin);
          end;
        end
        else
        begin
          LoadedPlugins.Add(pluginLoader.Plugin);
        end;
        {$ELSE}
        LoadedPlugins.Add(pluginLoader.Plugin);
        {$ENDIF}
      end;
      pluginLoader.Free;
    end;
  finally
    tob.free;
  end;
end;

destructor TUD2.Destroy;
begin
  FIniFile.Free;
  FLoadedPlugins.Free;
  {$IFDEF CHECK_FOR_SAME_PLUGIN_GUID}
  FGUIDLookup.Free;
  {$ENDIF}
  FErrors.Free;
end;

constructor TUD2.Create(AIniFileName: string);
begin
  FIniFileName := AIniFileName;
  FLoadedPlugins := TObjectList{<TUD2Plugin>}.Create(true);
  FIniFile := TMemIniFile.Create(IniFileName);
  {$IFDEF CHECK_FOR_SAME_PLUGIN_GUID}
  FGUIDLookup := TStringList.Create;
  {$ENDIF}
  FErrors := TStringList.Create;
end;

function TUD2.GetTaskName(AShortTaskName: string): string;
resourcestring
  LNG_NO_DESCRIPTION = '(%s)';
begin
  result := FIniFile.ReadString(AShortTaskName, UD2_TagDescription, Format(LNG_NO_DESCRIPTION, [AShortTaskName]));
end;

procedure TUD2.GetTaskListing(outSL: TStrings);
var
  sl: TStringList;
  i: integer;
  desc: string;
begin
  sl := TStringList.Create;
  try
    FIniFile.ReadSections(sl);
    for i := 0 to sl.Count-1 do
    begin
      desc := GetTaskName(sl.Strings[i]);
      outSL.Values[sl.Strings[i]] := desc;
    end;
  finally
    sl.Free;
  end;
end;

function TUD2.TaskExists(ShortTaskName: string): boolean;
begin
  result := FIniFile.SectionExists(ShortTaskName);
end;

function TUD2.ReadMetatagString(ShortTaskName, MetatagName: string; DefaultVal: string): string;
begin
  result := IniFile.ReadString(ShortTaskName, MetatagName, DefaultVal);
end;

function TUD2.ReadMetatagBool(ShortTaskName, MetatagName: string; DefaultVal: string): boolean;
begin
  // DefaultVal is a string, because we want to allow an empty string, in case the
  // user wishes an Exception in case the string is not a valid boolean string
  result := BetterInterpreteBool(IniFile.ReadString(ShortTaskName, MetatagName, DefaultVal));
end;

(*

NAMING EXAMPLE: $CASESENSITIVE$ComputerName(dynXYZ):ABC&&User:John=calc.exe$RIOD$

        idTerm:       ComputerName(dynXYZ):ABC&&User:John
        idName:       ComputerName:ABC
        IdMethodName: ComputerName
        IdStr         ABC
        cmd:          calc.exe
        dynamicData:  dynXYZ

*)

procedure TUD2.GetAllDetectedIDs(outSL: TStrings);
var
  i, j: integer;
  pl: TUD2Plugin;
  ude: TUD2IdentificationEntry;
begin
  for i := 0 to LoadedPlugins.Count-1 do
  begin
    pl := LoadedPlugins.Items[i] as TUD2Plugin;
    for j := 0 to pl.DetectedIdentifications.Count-1 do
    begin
      ude := pl.DetectedIdentifications.Items[j] as TUD2IdentificationEntry;
      ude.GetIdNames(outSL);
    end;
  end;
end;

function TUD2.FulfilsEverySubterm(conds: TUD2TDFConditionArray; slIdNames: TStrings=nil; AErrorOut: TStrings=nil): boolean;
begin
  result := FulfilsEverySubterm(UD2_CondsToStr(conds), slIdNames, AErrorOut);
end;

function TUD2.FulfilsEverySubterm(idTerm: WideString; slIdNames: TStrings=nil; AErrorOut: TStrings=nil): boolean;
var
  i: integer;
  p: TUD2Plugin;
  cleanUpStringList: boolean;
  conds: TUD2TDFConditionArray;
  cond: TUD2TDFCondition;
  idName: string;
begin
  {$IFDEF NO_CONDITIONS_IS_FAILURE}
  if idTerm = '' then
  begin
    SetLength(conds, 0);
    result := false;
    Exit;
  end;
  {$ENDIF}

  cleanUpStringList := slIdNames = nil;
  try
    if cleanUpStringList then
    begin
      slIdNames := TStringList.Create;
      GetAllDetectedIDs(slIdNames);
    end;

    conds := UD2P_ParseConditions(idTerm);

    result := true;
    for i := Low(conds) to High(conds) do
    begin
      cond := conds[i];

      if cond.dynamicDataUsed then
      begin
        p := FindPluginByMethodNameOrGuid(cond.idMethodName);
        if Assigned(p) then
        begin
          if p.InvokeDynamicCheck(cond.dynamicData, AErrorOut) then
          begin
            // Reload the identifications
            slIdNames.Clear;
            GetAllDetectedIDs(slIdNames);
          end;
        end;
      end;

      idName := UD2_CondToStr(cond);

      if (not cond.caseSensitive and (slIdNames.IndexOf(idName) = -1)) or
         (cond.caseSensitive and (IndexOf_CS(slIdNames, idName) = -1)) then
      begin
        result := false;
        break;
      end;
    end;
  finally
    if cleanUpStringList and Assigned(slIdNames) then
      slIdNames.Free;
  end;
end;

function TUD2.FindPluginByMethodNameOrGuid(idMethodName: string): TUD2Plugin;
var
  i: integer;
  p: TUD2Plugin;
begin
  result := nil;
  for i := 0 to LoadedPlugins.Count-1 do
  begin
    p := LoadedPlugins.Items[i] as TUD2Plugin;

    if p.EqualsMethodNameOrGuid(idMethodName) then
    begin
      result := p;
      Exit;
    end;
  end;
end;

function TUD2.GetCommandList(ShortTaskName: string; AErrorOut: TStrings=nil): TUD2CommandArray;
var
  i, j, l: integer;
  slSV, slIdNames: TStrings;
  tmpCmds: TUD2CommandArray;
begin
  SetLength(result, 0);
  SetLength(tmpCmds, 0);

  slIdNames := TStringList.Create;
  try
    GetAllDetectedIDs(slIdNames);

    slSV := TStringList.Create;
    try
      FIniFile.ReadSectionValues(ShortTaskName, slSV);
      for i := 0 to slSV.Count-1 do
      begin
        tmpCmds := CheckTerm(slSV.Strings[i], slIdNames, AErrorOut);
        for j := Low(tmpCmds) to High(tmpCmds) do
        begin
          l := Length(result);
          SetLength(result, l+1);
          result[l] := tmpCmds[j];
        end;
      end;
    finally
      slSV.Free;
    end;
  finally
    slIdNames.Free;
  end;
end;

function TUD2.CheckTerm(idTermAndCmd: string; slIdNames: TStrings=nil; AErrorOut: TStrings=nil): TUD2CommandArray;
var
  slIdNamesCreated: boolean;
  ent: TUD2TDFEntry;
begin
  SetLength(result, 0);

  slIdNamesCreated := false;
  try
    if not Assigned(slIdNames) then
    begin
      slIdNamesCreated := true;
      slIdNames := TStringList.Create;
      GetAllDetectedIDs(slIdNames);
    end;

    if not UD2P_ParseTdfLine(idTermAndCmd, ent) then Exit;
    if FulfilsEverySubterm(ent.ids, slIdNames, AErrorOut) then
    begin
      result := ent.commands;
    end;
  finally
    if slIdNamesCreated then slIdNames.Free;
  end;
end;

{ TUD2PluginLoader }

procedure TUD2PluginLoader.Execute;
begin
  inherited;

  HandleDLL;
end;

constructor TUD2PluginLoader.Create(Suspended: boolean; DLL: string; alngid: LANGID; useDynamicData: boolean; dynamicData: WideString);
begin
  inherited Create(Suspended);
  dllfile := dll;
  Plugin := nil;
  Errors := TStringList.Create;
  lngid := alngid;
  self.useDynamicData := useDynamicData;
  Self.dynamicData := dynamicData;
end;

destructor TUD2PluginLoader.Destroy;
begin
  Errors.Free;
  inherited;
end;

function TUD2PluginLoader.HandleDLL: boolean;
var
  sIdentifier: WideString;
  buf: array[0..cchBufferSize-1] of WideChar;
  pluginInterfaceID: TGUID;
  dllHandle: Cardinal;
  fPluginInterfaceID: TFuncPluginInterfaceID;
  fPluginIdentifier: TFuncPluginIdentifier;
  fPluginNameW: TFuncPluginNameW;
  fPluginVendorW: TFuncPluginVendorW;
  fPluginVersionW: TFuncPluginVersionW;
  fIdentificationMethodNameW: TFuncIdentificationMethodNameW;
  fIdentificationStringW: TFuncIdentificationStringW;
  fDynamicIdentificationStringW: TFuncDynamicIdentificationStringW;
  fCheckLicense: TFuncCheckLicense;
  fDescribeOwnStatusCodeW: TFuncDescribeOwnStatusCodeW;
  statusCode: UD2_STATUS;
  i: integer;
  starttime, endtime, time: cardinal;
  bakErrorMode: DWORD;
  err: DWORD;

  function _ErrorLookup(statusCode: UD2_STATUS): WideString;
  var
    ret: BOOL;
    buf: array[0..cchBufferSize-1] of WideChar;
  begin
    if Assigned(fDescribeOwnStatusCodeW) then
    begin
      ZeroMemory(@buf, cchBufferSize);
      ret := fDescribeOwnStatusCodeW(@buf, cchBufferSize, statusCode, lngID);
      if ret then
      begin
        result := PWideChar(@buf);
        Exit;
      end;
    end;
    result := TUD2.GenericErrorLookup(statusCode);
  end;

  function _ApplyCompatibilityGUID: boolean;
  var
    iniConfig: TIniFile;
    sOverrideGUID: string;
    sPluginConfigFile: string;
  begin
    result := false;
    sPluginConfigFile := ChangeFileExt(dllFile, '.ini');
    if FileExists(sPluginConfigFile) then
    begin
      iniConfig := TIniFile.Create(sPluginConfigFile);
      try
        sOverrideGUID := iniConfig.ReadString('Compatibility', 'OverrideGUID', '');
        if sOverrideGUID <> '' then
        begin
          Plugin.FPluginGUIDSet := true;
          Plugin.FPluginGUID := StringToGUID(sOverrideGUID);
          result := true;
        end;
      finally
        iniConfig.Free;
      end;
    end;
  end;

  function _AutoOSNotSupportedMode: integer;
  var
    iniConfig: TIniFile;
    sPluginConfigFile: string;
  begin
    result := 0;
    sPluginConfigFile := ChangeFileExt(dllFile, '.ini');
    if FileExists(sPluginConfigFile) then
    begin
      iniConfig := TIniFile.Create(sPluginConfigFile);
      try
        result := iniConfig.ReadInteger('Compatibility', 'AutoOSNotSupported', 0);
      finally
        iniConfig.Free;
      end;
    end;
  end;

  procedure _OverwriteStatusToOSNotSupported;
  begin
    Plugin := TUD2Plugin.Create;
    Plugin.FPluginDLL := dllFile;
    statusCode := UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED;
    Plugin.FIdentificationProcedureStatusCode := statusCode;
    Plugin.FIdentificationProcedureStatusCodeDescribed := _ErrorLookup(statusCode);
    Plugin.FOSNotSupportedEnforced := true;
    result := true;
  end;

resourcestring
  LNG_DLL_NOT_LOADED = 'Plugin DLL "%s" could not be loaded: %s';
  LNG_METHOD_NOT_FOUND = 'Method "%s" not found in plugin "%s". The DLL is probably not a valid plugin DLL.';
  LNG_INVALID_PLUGIN = 'The plugin "%s" is not a valid plugin for this application.';
  LNG_METHOD_FAILURE = 'Error "%s" at method "%s" of plugin "%s".';
  LNG_EXCEPTION = 'Fatal error while loading "%s" (%s: %s)';
begin
  result := false;
  startTime := GetTickCount;

  try
    bakErrorMode := 0;
    UD2_SetThreadErrorMode(SEM_FAILCRITICALERRORS, Pointer(bakErrorMode));
    try
      dllHandle := LoadLibrary(PChar(dllFile));
      if dllHandle = 0 then
      begin
        err := GetLastError;

        if ((_AutoOSNotSupportedMode = 1) and ((err = ERROR_DLL_NOT_FOUND) or (err = ERROR_PROC_NOT_FOUND))) or
           (_AutoOSNotSupportedMode >= 2) then
        begin
          _OverwriteStatusToOSNotSupported;
          Exit;
        end;

        Errors.Add(Format(LNG_DLL_NOT_LOADED, [dllFile, SysErrorMessage(err)]));
        Exit;
      end;
      try
        @fPluginInterfaceID := GetProcAddress(dllHandle, mnPluginInterfaceID);
        if not Assigned(fPluginInterfaceID) then
        begin
          Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnPluginInterfaceID, dllFile]));
          Exit;
        end;
        pluginInterfaceID := fPluginInterfaceID();
        if not IsEqualGUID(pluginInterfaceID, GUID_USERDETECT2_IDPLUGIN_V1) then
        begin
          Errors.Add(Format(LNG_INVALID_PLUGIN, [dllFile]));
          Exit;
        end;

        Plugin := TUD2Plugin.Create;
        Plugin.FPluginDLL := dllFile;

        @fDynamicIdentificationStringW := GetProcAddress(dllHandle, mnDynamicIdentificationStringW);
        Plugin.FAcceptsDynamicRequests := Assigned(fDynamicIdentificationStringW);

        fIdentificationStringW := nil;
        if useDynamicData then
        begin
          if not Plugin.AcceptsDynamicRequests then
          begin
            // We should not output a fatal error here, because it is likely that the error is caused by the user writing a buggy INI file (specifying a parameter for a non-dynamic plugin)
            (*
            Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnDynamicIdentificationStringW, dllFile]));
            Exit;
            *)

            // But we just try to find out if the plugin seems to be "OK"
            if not Assigned(fIdentificationStringW) then
            begin
              Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnDynamicIdentificationStringW, dllFile]));
              Exit;
            end;

            Plugin.FIdentificationProcedureStatusCode := UD2_STATUS_NOTAVAIL_DOES_NOT_ACCEPT_DYNAMIC_REQUESTS;
            Plugin.FIdentificationProcedureStatusCodeDescribed := _ErrorLookup(statusCode);

            Exit;
          end;
        end
        else
        begin
          @fIdentificationStringW := GetProcAddress(dllHandle, mnIdentificationStringW);
          if not Assigned(fIdentificationStringW) then
          begin
            Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnIdentificationStringW, dllFile]));
            Exit;
          end;
        end;

        @fPluginNameW := GetProcAddress(dllHandle, mnPluginNameW);
        if not Assigned(fPluginNameW) then
        begin
          Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnPluginNameW, dllFile]));
          Exit;
        end;

        @fPluginVendorW := GetProcAddress(dllHandle, mnPluginVendorW);
        if not Assigned(fPluginVendorW) then
        begin
          Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnPluginVendorW, dllFile]));
          Exit;
        end;

        @fPluginVersionW := GetProcAddress(dllHandle, mnPluginVersionW);
        if not Assigned(fPluginVersionW) then
        begin
          Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnPluginVersionW, dllFile]));
          Exit;
        end;

        @fCheckLicense := GetProcAddress(dllHandle, mnCheckLicense);
        if not Assigned(fCheckLicense) then
        begin
          Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnCheckLicense, dllFile]));
          Exit;
        end;

        @fIdentificationMethodNameW := GetProcAddress(dllHandle, mnIdentificationMethodNameW);
        if not Assigned(fIdentificationMethodNameW) then
        begin
          Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnIdentificationMethodNameW, dllFile]));
          Exit;
        end;

        @fDescribeOwnStatusCodeW := GetProcAddress(dllHandle, mnDescribeOwnStatusCodeW);
        if not Assigned(fDescribeOwnStatusCodeW) then
        begin
          Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnDescribeOwnStatusCodeW, dllFile]));
          Exit;
        end;

        if not _ApplyCompatibilityGUID then
        begin
          @fPluginIdentifier := GetProcAddress(dllHandle, mnPluginIdentifier);
          if not Assigned(fPluginIdentifier) then
          begin
            Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnPluginIdentifier, dllFile]));
            Exit;
          end;
          Plugin.FPluginGUIDSet := true;
          Plugin.FPluginGUID := fPluginIdentifier();
        end;

        statusCode := fCheckLicense(nil);
        if statusCode.wCategory = UD2_STATUSCAT_FAILED then
        begin
          Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnCheckLicense, dllFile]));
          Exit;
        end;

        ZeroMemory(@buf, cchBufferSize);
        statusCode := fPluginNameW(@buf, cchBufferSize, lngID);
             if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then Plugin.FPluginName := PWideChar(@buf)
        else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then Plugin.FPluginName := ''
        else
        begin
          Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnPluginNameW, dllFile]));
          Exit;
        end;

        ZeroMemory(@buf, cchBufferSize);
        statusCode := fPluginVendorW(@buf, cchBufferSize, lngID);
             if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then Plugin.FPluginVendor := PWideChar(@buf)
        else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then Plugin.FPluginVendor := ''
        else
        begin
          Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnPluginVendorW, dllFile]));
          Exit;
        end;

        ZeroMemory(@buf, cchBufferSize);
        statusCode := fPluginVersionW(@buf, cchBufferSize, lngID);
             if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then Plugin.FPluginVersion := PWideChar(@buf)
        else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then Plugin.FPluginVersion := ''
        else
        begin
          Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnPluginVersionW, dllFile]));
          Exit;
        end;

        ZeroMemory(@buf, cchBufferSize);
        statusCode := fIdentificationMethodNameW(@buf, cchBufferSize);
             if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then Plugin.FIdentificationMethodName := PWideChar(@buf)
        else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then Plugin.FIdentificationMethodName := ''
        else
        begin
          Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnIdentificationMethodNameW, dllFile]));
          Exit;
        end;

        ZeroMemory(@buf, cchBufferSize);
        statusCode := UD2_STATUS_FAILURE_NO_RETURNED_VALUE; // This status will be used when the DLL does not return anything (which is an error by the developer)
        if useDynamicData then
        begin
          statusCode := fDynamicIdentificationStringW(@buf, cchBufferSize, PWideChar(dynamicData));
        end
        else
        begin
          statusCode := fIdentificationStringW(@buf, cchBufferSize);
        end;
        Plugin.FIdentificationProcedureStatusCode := statusCode;
        Plugin.FIdentificationProcedureStatusCodeDescribed := _ErrorLookup(statusCode);
        if statusCode.wCategory = UD2_STATUSCAT_SUCCESS then
        begin
          sIdentifier := PWideChar(@buf);
          if UD2_STATUS_Equal(statusCode, UD2_STATUS_OK_MULTILINE, false) then
          begin
            // Multiple identifiers (e.g. multiple MAC addresses are delimited via UD2_MULTIPLE_ITEMS_DELIMITER)
            SetLength(ResultIdentifiers, 0);
            ResultIdentifiers := SplitString(UD2_MULTIPLE_ITEMS_DELIMITER, sIdentifier);
            for i := Low(ResultIdentifiers) to High(ResultIdentifiers) do
            begin
              Plugin.AddIdentification(ResultIdentifiers[i]);
            end;
          end
          else
          begin
            Plugin.AddIdentification(sIdentifier);

            SetLength(ResultIdentifiers, 1);
            ResultIdentifiers[0] := sIdentifier;
          end;
        end
        else if statusCode.wCategory <> UD2_STATUSCAT_NOT_AVAIL then
        begin
          if _AutoOSNotSupportedMode >= 3 then
          begin
            _OverwriteStatusToOSNotSupported;
            Exit;
          end;

          // Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnIdentificationStringW, dllFile]));
          Errors.Add(Format(LNG_METHOD_FAILURE, [Plugin.IdentificationProcedureStatusCodeDescribed, mnIdentificationStringW, dllFile]));
          Exit;
        end;

        result := true;
      finally
        if not result and Assigned(Plugin) then FreeAndNil(Plugin);
        FreeLibrary(dllHandle);
      end;
    finally
      UD2_SetThreadErrorMode(bakErrorMode, nil);

      if result then
      begin
        endtime := GetTickCount;
        time := endtime - starttime;
        if endtime < starttime then time := High(Cardinal) - time;
        Plugin.FLoadingTime := time;
      end;
    end;
  except
    // TODO: when an exception happens in a cdecl DLL, then this code is somehow not
    // executed. Probably the memory is corrupted. Anyway, a cdecl DLL shall NEVER
    // raise an Exception.
    on E: Exception do
    begin
      Errors.Add(Format(LNG_EXCEPTION, [dllFile, E.ClassName, E.Message]));
      Exit;
    end;
  end;
end;

end.
