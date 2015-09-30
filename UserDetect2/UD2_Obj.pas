unit UD2_Obj;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows, SysUtils, Classes, IniFiles, Contnrs, Dialogs;

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
    FGUIDLookup: TStrings;
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
    procedure HandlePluginDir(APluginDir: string);
    procedure GetTaskListing(outSL: TStrings);
    constructor Create(AIniFileName: string);
    destructor Destroy; override;
    function TaskExists(ShortTaskName: string): boolean;
    function ReadMetatagString(ShortTaskName, MetatagName: string;
      DefaultVal: string): string;
    function ReadMetatagBool(ShortTaskName, MetatagName: string;
      DefaultVal: string): boolean;
    function GetTaskName(AShortTaskName: string): string;
  end;

implementation

uses
  UD2_PluginIntf, UD2_Utils;

type
  TUD2PluginLoader = class(TThread)
  protected
    dllFile: string;
    lngID: LANGID;
    procedure Execute; override;
    procedure HandleDLL;
  public
    pl: TUD2Plugin;
    Errors: TStringList;
    constructor Create(Suspended: boolean; DLL: string; alngid: LANGID);
    destructor Destroy; override;
  end;

function UD2_ErrorLookup(dwStatus: UD2_STATUS): string;
resourcestring
  LNG_STATUS_OK_UNSPECIFIED            = 'Unspecified generic success';
  LNG_STATUS_OK_SINGLELINE             = 'Operation successful; one identifier returned';
  LNG_STATUS_OK_MULTILINE              = 'Operation successful; multiple identifiers returned';

  LNG_STATUS_NOTAVAIL_UNSPECIFIED      = 'Unspecified generic "not available" status';
  LNG_STATUS_NOTAVAIL_OS_NOT_SUPPORTED = 'Operating system not supported';
  LNG_STATUS_NOTAVAIL_HW_NOT_SUPPORTED = 'Hardware not supported';
  LNG_STATUS_NOTAVAIL_NO_ENTITIES      = 'No entities to identify';
  LNG_STATUS_NOTAVAIL_API_CALL_FAILURE = 'An API call failed';

  LNG_STATUS_ERROR_UNSPECIFIED         = 'Unspecified generic error';
  LNG_STATUS_ERROR_BUFFER_TOO_SMALL    = 'The provided buffer is too small!';
  LNG_STATUS_ERROR_INVALID_ARGS        = 'The function received invalid arguments!';
  LNG_STATUS_ERROR_PLUGIN_NOT_LICENSED = 'The plugin is not licensed';

  LNG_UNKNOWN_SUCCESS                  = 'Unknown "success" status code %s';
  LNG_UNKNOWN_NOTAVAIL                 = 'Unknown "not available" status code %s';
  LNG_UNKNOWN_FAILED                   = 'Unknown "failed" status code %s';
  LNG_UNKNOWN_STATUS                   = 'Unknown status code with unexpected category: %s';
begin
       if dwStatus = UD2_STATUS_OK_UNSPECIFIED            then result := LNG_STATUS_OK_UNSPECIFIED
  else if dwStatus = UD2_STATUS_OK_SINGLELINE             then result := LNG_STATUS_OK_SINGLELINE
  else if dwStatus = UD2_STATUS_OK_MULTILINE              then result := LNG_STATUS_OK_MULTILINE

  else if dwStatus = UD2_STATUS_NOTAVAIL_UNSPECIFIED      then result := LNG_STATUS_NOTAVAIL_UNSPECIFIED
  else if dwStatus = UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED then result := LNG_STATUS_NOTAVAIL_OS_NOT_SUPPORTED
  else if dwStatus = UD2_STATUS_NOTAVAIL_HW_NOT_SUPPORTED then result := LNG_STATUS_NOTAVAIL_HW_NOT_SUPPORTED
  else if dwStatus = UD2_STATUS_NOTAVAIL_NO_ENTITIES      then result := LNG_STATUS_NOTAVAIL_NO_ENTITIES
  else if dwStatus = UD2_STATUS_NOTAVAIL_API_CALL_FAILURE then result := LNG_STATUS_NOTAVAIL_API_CALL_FAILURE

  else if dwStatus = UD2_STATUS_ERROR_UNSPECIFIED         then result := LNG_STATUS_ERROR_UNSPECIFIED
  else if dwStatus = UD2_STATUS_ERROR_BUFFER_TOO_SMALL    then result := LNG_STATUS_ERROR_BUFFER_TOO_SMALL
  else if dwStatus = UD2_STATUS_ERROR_INVALID_ARGS        then result := LNG_STATUS_ERROR_INVALID_ARGS
  else if dwStatus = UD2_STATUS_ERROR_PLUGIN_NOT_LICENSED then result := LNG_STATUS_ERROR_PLUGIN_NOT_LICENSED

  else if UD2_STATUS_Successful(dwStatus) then result := Format(LNG_UNKNOWN_SUCCESS,  [UD2_STATUS_FormatStatusCode(dwStatus)])
  else if UD2_STATUS_NotAvail(dwStatus)   then result := Format(LNG_UNKNOWN_NOTAVAIL, [UD2_STATUS_FormatStatusCode(dwStatus)])
  else if UD2_STATUS_Failed(dwStatus)     then result := Format(LNG_UNKNOWN_FAILED,   [UD2_STATUS_FormatStatusCode(dwStatus)])
  else                                         result := Format(LNG_UNKNOWN_STATUS,   [UD2_STATUS_FormatStatusCode(dwStatus)]);
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

procedure TUD2.HandlePluginDir(APluginDir: string);
Var
  SR: TSearchRec;
  path: string;
  x: TUD2PluginLoader;
  tob: TObjectList;
  i: integer;
  sPluginID, v: string;
  lngid: LANGID;
resourcestring
  LNG_PLUGINS_SAME_GUID = 'Attention: The plugin "%s" and the plugin "%s" have the same identification GUID. The latter will not be loaded.';
begin
  tob := TObjectList.Create;
  try
    tob.OwnsObjects := false;

    lngID := GetSystemDefaultLangID;

    path := IncludeTrailingPathDelimiter(APluginDir);
    if FindFirst(path + '*.dll', 0, SR) = 0 then
    begin
      try
        repeat
          try
            tob.Add(TUD2PluginLoader.Create(false, path+sr.Name, lngid));
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
      x := tob.items[i] as TUD2PluginLoader;
      x.WaitFor;
      Errors.AddStrings(x.Errors);
      if Assigned(x.pl) then
      begin
        sPluginID := GUIDToString(x.pl.PluginGUID);
        v := FGUIDLookup.Values[sPluginID];
        if (v <> '') and (v <> x.pl.PluginDLL) then
        begin
          Errors.Add(Format(LNG_PLUGINS_SAME_GUID, [v, x.pl.PluginDLL]));
          x.pl.Free;
        end
        else
        begin
          FGUIDLookup.Values[sPluginID] := x.pl.PluginDLL;
          LoadedPlugins.Add(x.pl);
        end;
      end;
      x.Free;
    end;
  finally
    tob.free;
  end;
end;

destructor TUD2.Destroy;
begin
  FIniFile.Free;
  FLoadedPlugins.Free;
  FGUIDLookup.Free;
  FErrors.Free;
end;

constructor TUD2.Create(AIniFileName: string);
begin
  FIniFileName := AIniFileName;
  FLoadedPlugins := TObjectList{<TUD2Plugin>}.Create(true);
  FIniFile := TMemIniFile.Create(IniFileName);
  FGUIDLookup := TStringList.Create;
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

procedure TUD2PluginLoader.HandleDLL;
var
  sIdentifier: WideString;
  sIdentifiers: TArrayOfString;
  buf: array[0..cchBufferSize-1] of WideChar;
  sPluginConfigFile: string;
  iniConfig: TINIFile;
  sOverrideGUID: string;
  pluginIDfound: boolean;
  pluginInterfaceID: TGUID;
  dllHandle: cardinal;
  fPluginInterfaceID: TFuncPluginInterfaceID;
  fPluginIdentifier: TFuncPluginIdentifier;
  fPluginNameW: TFuncPluginNameW;
  fPluginVendorW: TFuncPluginVendorW;
  fPluginVersionW: TFuncPluginVersionW;
  fIdentificationMethodNameW: TFuncIdentificationMethodNameW;
  fIdentificationStringW: TFuncIdentificationStringW;
  fCheckLicense: TFuncCheckLicense;
  statusCode: UD2_STATUS;
  i: integer;
  starttime, endtime, time: cardinal;
  loadSuccessful: boolean;
resourcestring
  LNG_DLL_NOT_LOADED = 'Plugin DLL "%s" could not be loaded.';
  LNG_METHOD_NOT_FOUND = 'Method "%s" not found in plugin "%s". The DLL is probably not a valid plugin DLL.';
  LNG_INVALID_PLUGIN = 'The plugin "%s" is not a valid plugin for this program version.';
  LNG_METHOD_FAILURE = 'Error "%s" at method "%s" of plugin "%s".';
begin
  loadSuccessful := false;
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
    if UD2_STATUS_Failed(statusCode) then
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnCheckLicense, dllFile]));
      Exit;
    end;

    statusCode := fPluginNameW(@buf, cchBufferSize, lngID);
         if UD2_STATUS_Successful(statusCode) then pl.PluginName := PWideChar(@buf)
    else if UD2_STATUS_NotAvail(statusCode)   then pl.PluginName := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnPluginNameW, dllFile]));
      Exit;
    end;

    statusCode := fPluginVendorW(@buf, cchBufferSize, lngID);
         if UD2_STATUS_Successful(statusCode) then pl.PluginVendor := PWideChar(@buf)
    else if UD2_STATUS_NotAvail(statusCode)   then pl.PluginVendor := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnPluginVendorW, dllFile]));
      Exit;
    end;

    statusCode := fPluginVersionW(@buf, cchBufferSize, lngID);
         if UD2_STATUS_Successful(statusCode) then pl.PluginVersion := PWideChar(@buf)
    else if UD2_STATUS_NotAvail(statusCode)   then pl.PluginVersion := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnPluginVersionW, dllFile]));
      Exit;
    end;

    statusCode := fIdentificationMethodNameW(@buf, cchBufferSize);
         if UD2_STATUS_Successful(statusCode) then pl.IdentificationMethodName := PWideChar(@buf)
    else if UD2_STATUS_NotAvail(statusCode)   then pl.IdentificationMethodName := ''
    else
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnIdentificationMethodNameW, dllFile]));
      Exit;
    end;

    statusCode := fIdentificationStringW(@buf, cchBufferSize);
    if UD2_STATUS_Successful(statusCode) then
    begin
      sIdentifier := PWideChar(@buf);
      if statusCode = UD2_STATUS_OK_MULTILINE then
      begin
        // Multiple identifiers (e.g. multiple MAC addresses are delimited via #10 )
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
    else if not UD2_STATUS_NotAvail(statusCode) then
    begin
      Errors.Add(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnIdentificationStringW, dllFile]));
      Exit;
    end;

    endtime := GetTickCount;
    time := endtime - starttime;
    if endtime < starttime then time := High(Cardinal) - time;
    pl.time := time;

    loadSuccessful := true;
  finally
    if not loadSuccessful and Assigned(pl) then FreeAndNil(pl);
    FreeLibrary(dllHandle);
  end;
end;

end.
