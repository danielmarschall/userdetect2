unit UD2_Obj;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

{$INCLUDE 'UserDetect2.inc'}

uses
  Windows, SysUtils, Classes, IniFiles, Contnrs, Dialogs, UD2_PluginIntf,
  UD2_PluginStatus;

const
  cchBufferSize = 32768;

type
  TUD2Plugin = class(TObject)
  protected
    FDetectedIdentifications: TObjectList{<TUD2IdentificationEntry>};
  public
    PluginDLL: string;
    PluginGUID: TGUID;
    PluginName: WideString;
    PluginVendor: WideString;
    PluginVersion: WideString;
    IdentificationMethodName: WideString;

    // ONLY contains the non-failure status code of IdentificationStringW
    IdentificationProcedureStatusCode: UD2_STATUS;
    IdentificationProcedureStatusCodeDescribed: WideString;
    
    Time: Cardinal;
    function PluginGUIDString: string;
    property DetectedIdentifications: TObjectList{<TUD2IdentificationEntry>}
      read FDetectedIdentifications;
    destructor Destroy; override;
    constructor Create;
    procedure AddIdentification(IdStr: WideString);
  end;

  TUD2IdentificationEntry = class(TObject)
  private
    FIdentificationString: WideString;
    FPlugin: TUD2Plugin;
  public
    property IdentificationString: WideString read FIdentificationString;
    property Plugin: TUD2Plugin read FPlugin;
    function GetPrimaryIdName: WideString;
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
    procedure GetCommandList(ShortTaskName: string; outSL: TStrings);
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
  UD2_Utils;

type
  TUD2PluginLoader = class(TThread)
  protected
    dllFile: string;
    lngID: LANGID;
    procedure Execute; override;
    function HandleDLL: boolean;
  public
    pl: TUD2Plugin;
    Errors: TStringList;
    constructor Create(Suspended: boolean; DLL: string; alngid: LANGID);
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
  LNG_UNKNOWN_NOTAVAIL                    = 'Not available (Unknown status code %s)';

  LNG_STATUS_ERROR_UNSPECIFIED            = 'Error (Unspecified)';
  LNG_STATUS_ERROR_BUFFER_TOO_SMALL       = 'Error (The provided buffer is too small!)';
  LNG_STATUS_ERROR_INVALID_ARGS           = 'Error (The function received invalid arguments!)';
  LNG_STATUS_ERROR_PLUGIN_NOT_LICENSED    = 'Error (The plugin is not licensed)';
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

  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_UNSPECIFIED, false)          then result := LNG_STATUS_ERROR_UNSPECIFIED
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_BUFFER_TOO_SMALL, false)     then result := LNG_STATUS_ERROR_BUFFER_TOO_SMALL
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_INVALID_ARGS, false)         then result := LNG_STATUS_ERROR_INVALID_ARGS
  else if UD2_STATUS_Equal(grStatus, UD2_STATUS_FAILURE_PLUGIN_NOT_LICENSED, false)  then result := LNG_STATUS_ERROR_PLUGIN_NOT_LICENSED

  else if grStatus.wCategory = UD2_STATUSCAT_SUCCESS   then result := Format(LNG_UNKNOWN_SUCCESS,  [UD2_STATUS_FormatStatusCode(grStatus)])
  else if grStatus.wCategory = UD2_STATUSCAT_NOT_AVAIL then result := Format(LNG_UNKNOWN_NOTAVAIL, [UD2_STATUS_FormatStatusCode(grStatus)])
  else if grStatus.wCategory = UD2_STATUSCAT_FAILED    then result := Format(LNG_UNKNOWN_FAILED,   [UD2_STATUS_FormatStatusCode(grStatus)])
  else                                                      result := Format(LNG_UNKNOWN_STATUS,   [UD2_STATUS_FormatStatusCode(grStatus)]);
end;

{ TUD2Plugin }

function TUD2Plugin.PluginGUIDString: string;
begin
  result := UpperCase(GUIDToString(PluginGUID));
end;

procedure TUD2Plugin.AddIdentification(IdStr: WideString);
begin
  DetectedIdentifications.Add(TUD2IdentificationEntry.Create(IdStr, Self))
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

{ TUD2IdentificationEntry }

function TUD2IdentificationEntry.GetPrimaryIdName: WideString;
begin
  result := Plugin.IdentificationMethodName+':'+IdentificationString;
end;

procedure TUD2IdentificationEntry.GetIdNames(sl: TStrings);
begin
  sl.Add(GetPrimaryIdName);
  sl.Add(UpperCase(Plugin.IdentificationMethodName)+':'+IdentificationString);
  sl.Add(LowerCase(Plugin.IdentificationMethodName)+':'+IdentificationString);
  sl.Add(UpperCase(Plugin.PluginGUIDString)+':'+IdentificationString);
  sl.Add(LowerCase(Plugin.PluginGUIDString)+':'+IdentificationString);
end;

constructor TUD2IdentificationEntry.Create(AIdentificationString: WideString;
  APlugin: TUD2Plugin);
begin
  inherited Create;
  FIdentificationString := AIdentificationString;
  FPlugin := APlugin;
end;

{ TUD2 }

procedure TUD2.HandlePluginDir(APluginDir, AFileMask: string);
Var
  SR: TSearchRec;
  path: string;
  pluginLoader: TUD2PluginLoader;
  tob: TObjectList;
  i: integer;
  {$IFDEF CHECK_FOR_SAME_PLUGIN_GUID}
  sPluginID, prevDLL: string;
  {$ENDIF}
  lngid: LANGID;
  maskpath: string;
resourcestring
  LNG_PLUGINS_SAME_GUID = 'Attention: The plugin "%s" and the plugin "%s" have the same identification GUID. The latter will not be loaded.';
begin
  tob := TObjectList.Create;
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
            tob.Add(TUD2PluginLoader.Create(false, path + sr.Name, lngid));
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
      {$IFDEF CHECK_FOR_SAME_PLUGIN_GUID}
      if Assigned(pluginLoader.pl) then
      begin
        sPluginID := GUIDToString(pluginLoader.pl.PluginGUID);
        prevDLL := FGUIDLookup.Values[sPluginID];
        if (prevDLL <> '') and (prevDLL <> pluginLoader.pl.PluginDLL) then
        begin
          Errors.Add(Format(LNG_PLUGINS_SAME_GUID, [prevDLL, pluginLoader.pl.PluginDLL]));
          pluginLoader.pl.Free;
        end
        else
        begin
          FGUIDLookup.Values[sPluginID] := pluginLoader.pl.PluginDLL;
          LoadedPlugins.Add(pluginLoader.pl);
        end;
      end;
      {$ENDIF}
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
  result := FIniFile.ReadString(AShortTaskName, 'Description', Format(LNG_NO_DESCRIPTION, [AShortTaskName]));
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

function TUD2.ReadMetatagString(ShortTaskName, MetatagName: string;
  DefaultVal: string): string;
begin
  result := IniFile.ReadString(ShortTaskName, MetatagName, DefaultVal);
end;

function TUD2.ReadMetatagBool(ShortTaskName, MetatagName: string;
  DefaultVal: string): boolean;
begin
  // DefaultVal is a string, because we want to allow an empty string, in case the
  // user wishes an Exception in case the string is not a valid boolean string
  result := BetterInterpreteBool(IniFile.ReadString(ShortTaskName, MetatagName, DefaultVal));
end;

(*

NAMING EXAMPLE: ComputerName:ABC&&User:John=calc.exe

        idTerm:       ComputerName:ABC&&User:John
        idName:       ComputerName:ABC
        IdMethodName: ComputerName
        IdStr         ABC
        cmd:          calc.exe

*)

procedure TUD2.GetCommandList(ShortTaskName: string; outSL: TStrings);
var
  i, j: integer;
  cmd: string;
  idTerm, idName: WideString;
  slSV, slIdNames: TStrings;
  x: TArrayOfString;
  nameVal: TArrayOfString;
  FulfilsEverySubterm: boolean;
  pl: TUD2Plugin;
  ude: TUD2IdentificationEntry;
begin
  SetLength(x, 0);
  SetLength(nameVal, 0);

  slIdNames := TStringList.Create;
  try
    for i := 0 to LoadedPlugins.Count-1 do
    begin
      pl := LoadedPlugins.Items[i] as TUD2Plugin;
      for j := 0 to pl.DetectedIdentifications.Count-1 do
      begin
        ude := pl.DetectedIdentifications.Items[j] as TUD2IdentificationEntry;
        ude.GetIdNames(slIdNames);
      end;
    end;

    slSV := TStringList.Create;
    try
      FIniFile.ReadSectionValues(ShortTaskName, slSV);
      for j := 0 to slSV.Count-1 do
      begin
        // We are doing the interpretation of the line ourselves, because
        // TStringList.Values[] would not allow multiple command lines with the
        // same key (idTerm)
        nameVal := SplitString('=', slSV.Strings[j]);
        idTerm := nameVal[0];
        cmd    := nameVal[1];

        if Pos(':', idTerm) = 0 then Continue;
        x := SplitString('&&', idTerm);
        FulfilsEverySubterm := true;
        for i := Low(x) to High(x) do
        begin
          idName := x[i];

          if slIdNames.IndexOf(idName) = -1 then
          begin
            FulfilsEverySubterm := false;
            break;
          end;
        end;

        if FulfilsEverySubterm then outSL.Add(cmd);
      end;
    finally
      slSV.Free;
    end;
  finally
    slIdNames.Free;
  end;
end;

{ TUD2PluginLoader }

procedure TUD2PluginLoader.Execute;
begin
  inherited;

  HandleDLL;
end;

constructor TUD2PluginLoader.Create(Suspended: boolean; DLL: string; alngid: LANGID);
begin
  inherited Create(Suspended);
  dllfile := dll;
  pl := nil;
  Errors := TStringList.Create;
  lngid := alngid;
end;

destructor TUD2PluginLoader.Destroy;
begin
  Errors.Free;
  inherited;
end;

function TUD2PluginLoader.HandleDLL: boolean;
var
  sIdentifier: WideString;
  sIdentifiers: TArrayOfString;
  buf: array[0..cchBufferSize-1] of WideChar;
  sPluginConfigFile: string;
  iniConfig: TINIFile;
  sOverrideGUID: string;
  pluginIDfound: boolean;
  pluginInterfaceID: TGUID;
  dllHandle: Cardinal;
  fPluginInterfaceID: TFuncPluginInterfaceID;
  fPluginIdentifier: TFuncPluginIdentifier;
  fPluginNameW: TFuncPluginNameW;
  fPluginVendorW: TFuncPluginVendorW;
  fPluginVersionW: TFuncPluginVersionW;
  fIdentificationMethodNameW: TFuncIdentificationMethodNameW;
  fIdentificationStringW: TFuncIdentificationStringW;
  fCheckLicense: TFuncCheckLicense;
  fDescribeOwnStatusCodeW: TFuncDescribeOwnStatusCodeW;
  statusCode: UD2_STATUS;
  i: integer;
  starttime, endtime, time: cardinal;

  function _ErrorLookup(statusCode: UD2_STATUS): WideString;
  var
    ret: BOOL;
  begin
    ret := fDescribeOwnStatusCodeW(@buf, cchBufferSize, statusCode, lngID);
    if ret then
    begin
      result := PWideChar(@buf);
      Exit;
    end;
    result := TUD2.GenericErrorLookup(statusCode);
  end;

resourcestring
  LNG_DLL_NOT_LOADED = 'Plugin DLL "%s" could not be loaded.';
  LNG_METHOD_NOT_FOUND = 'Method "%s" not found in plugin "%s". The DLL is probably not a valid plugin DLL.';
  LNG_INVALID_PLUGIN = 'The plugin "%s" is not a valid plugin for this application.';
  LNG_METHOD_FAILURE = 'Error "%s" at method "%s" of plugin "%s".';
begin
  result := false;
  startTime := GetTickCount;

  dllHandle := LoadLibrary(PChar(dllFile));
  if dllHandle = 0 then
  begin
    Errors.Add(Format(LNG_DLL_NOT_LOADED, [dllFile]));
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

    @fIdentificationStringW := GetProcAddress(dllHandle, mnIdentificationStringW);
    if not Assigned(fIdentificationStringW) then
    begin
      Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnIdentificationStringW, dllFile]));
      Exit;
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

    pl := TUD2Plugin.Create;
    pl.PluginDLL := dllFile;

    pluginIDfound := false;
    sPluginConfigFile := ChangeFileExt(dllFile, '.ini');
    if FileExists(sPluginConfigFile) then
    begin
      iniConfig := TIniFile.Create(sPluginConfigFile);
      try
        sOverrideGUID := iniConfig.ReadString('Compatibility', 'OverrideGUID', '');
        if sOverrideGUID <> '' then
        begin
          pl.PluginGUID := StringToGUID(sOverrideGUID);
          pluginIDfound := true;
        end;
      finally
        iniConfig.Free;
      end;
    end;

    if not pluginIDfound then
    begin
      @fPluginIdentifier := GetProcAddress(dllHandle, mnPluginIdentifier);
      if not Assigned(fPluginIdentifier) then
      begin
        Errors.Add(Format(LNG_METHOD_NOT_FOUND, [mnPluginIdentifier, dllFile]));
        Exit;
      end;
      pl.PluginGUID := fPluginIdentifier();
    end;

    statusCode := fCheckLicense(nil);
    if statusCode.wCategory = UD2_STATUSCAT_FAILED then
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnCheckLicense, dllFile]));
      Exit;
    end;

    statusCode := fPluginNameW(@buf, cchBufferSize, lngID);
         if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then pl.PluginName := PWideChar(@buf)
    else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then pl.PluginName := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnPluginNameW, dllFile]));
      Exit;
    end;

    statusCode := fPluginVendorW(@buf, cchBufferSize, lngID);
         if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then pl.PluginVendor := PWideChar(@buf)
    else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then pl.PluginVendor := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnPluginVendorW, dllFile]));
      Exit;
    end;

    statusCode := fPluginVersionW(@buf, cchBufferSize, lngID);
         if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then pl.PluginVersion := PWideChar(@buf)
    else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then pl.PluginVersion := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnPluginVersionW, dllFile]));
      Exit;
    end;

    statusCode := fIdentificationMethodNameW(@buf, cchBufferSize);
         if statusCode.wCategory = UD2_STATUSCAT_SUCCESS   then pl.IdentificationMethodName := PWideChar(@buf)
    else if statusCode.wCategory = UD2_STATUSCAT_NOT_AVAIL then pl.IdentificationMethodName := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnIdentificationMethodNameW, dllFile]));
      Exit;
    end;

    statusCode := fIdentificationStringW(@buf, cchBufferSize);
    pl.IdentificationProcedureStatusCode := statusCode;
    pl.IdentificationProcedureStatusCodeDescribed := _ErrorLookup(statusCode);
    if statusCode.wCategory = UD2_STATUSCAT_SUCCESS then
    begin
      sIdentifier := PWideChar(@buf);
      if UD2_STATUS_Equal(statusCode, UD2_STATUS_OK_MULTILINE, false) then
      begin
        // Multiple identifiers (e.g. multiple MAC addresses are delimited via UD2_MULTIPLE_ITEMS_DELIMITER)
        SetLength(sIdentifiers, 0);
        sIdentifiers := SplitString(UD2_MULTIPLE_ITEMS_DELIMITER, sIdentifier);
        for i := Low(sIdentifiers) to High(sIdentifiers) do
        begin
          pl.AddIdentification(sIdentifiers[i]);
        end;
      end
      else
      begin
        pl.AddIdentification(sIdentifier);
      end;
    end
    else if statusCode.wCategory <> UD2_STATUSCAT_NOT_AVAIL then
    begin
      // Errors.Add(Format(LNG_METHOD_FAILURE, [_ErrorLookup(statusCode), mnIdentificationStringW, dllFile]));
      Errors.Add(Format(LNG_METHOD_FAILURE, [pl.IdentificationProcedureStatusCodeDescribed, mnIdentificationStringW, dllFile]));
      Exit;
    end;

    endtime := GetTickCount;
    time := endtime - starttime;
    if endtime < starttime then time := High(Cardinal) - time;
    pl.time := time;

    result := true;
  finally
    if not result and Assigned(pl) then FreeAndNil(pl);
    FreeLibrary(dllHandle);
  end;
end;

end.
