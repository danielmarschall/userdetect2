unit UD2_Obj;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows, SysUtils, Classes, IniFiles, Contnrs, Dialogs;

const
  cchBufferSize = 2048;

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
    procedure HandleDLL(dllFile: string);
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

function UD2_ErrorLookup(ec: UD2_STATUSCODE): string;
resourcestring
  LNG_STATUS_OK               = 'Operation completed sucessfully';
  LNG_STATUS_BUFFER_TOO_SMALL = 'The provided buffer is too small!';
  LNG_STATUS_INVALID_ARGS     = 'The function received invalid arguments!';
  LNG_STATUS_INVALID          = 'Unexpected status code %s';
  LNG_STATUS_NOT_LICENSED     = 'The plugin is not licensed';
begin
       if ec = UD2_STATUS_OK               then result := LNG_STATUS_OK
  else if ec = UD2_STATUS_BUFFER_TOO_SMALL then result := LNG_STATUS_BUFFER_TOO_SMALL
  else if ec = UD2_STATUS_INVALID_ARGS     then result := LNG_STATUS_INVALID_ARGS
  else if ec = UD2_STATUS_NOT_LICENSED     then result := LNG_STATUS_NOT_LICENSED
  else result := Format(LNG_STATUS_INVALID, ['0x'+IntToHex(ec, 8)]);
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

procedure TUD2.HandleDLL(dllFile: string);

  procedure ReportError(AMsg: string);
  begin
    // MessageDlg(AMsg, mtError, [mbOk], 0);
    Errors.Add(AMsg)
  end;

var
  sIdentifier: array[0..cchBufferSize-1] of WideChar;
  sIdentifiers: TArrayOfString;
  sPluginName: array[0..cchBufferSize-1] of WideChar;
  sPluginVendor: array[0..cchBufferSize-1] of WideChar;
  sPluginVersion: array[0..cchBufferSize-1] of WideChar;
  sIdentificationMethodName: array[0..cchBufferSize-1] of WideChar;
  sPluginConfigFile: string;
  iniConfig: TINIFile;
  sOverrideGUID: string;
  pluginID: TGUID;
  sPluginID: string;
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
  statusCode: UD2_STATUSCODE;
  pl: TUD2Plugin;
  i: integer;
  lngID: LANGID;
resourcestring
  LNG_DLL_NOT_LOADED = 'Plugin DLL "%s" could not be loaded.';
  LNG_METHOD_NOT_FOUND = 'Method "%s" not found in plugin "%s". The DLL is probably not a valid plugin DLL.';
  LNG_INVALID_PLUGIN = 'The plugin "%s" is not a valid plugin for this program version.';
  LNG_METHOD_FAILURE = 'Error "%s" at method "%s" of plugin "%s".';
  LNG_PLUGINS_SAME_GUID = 'Attention: The plugin "%s" and the plugin "%s" have the same identification GUID. The latter will not be loaded.';
begin
  lngID := GetSystemDefaultLangID;

  dllHandle := LoadLibrary(PChar(dllFile));
  if dllHandle = 0 then
  begin
    ReportError(Format(LNG_DLL_NOT_LOADED, [dllFile]));
  end;
  try
    @fPluginInterfaceID := GetProcAddress(dllHandle, mnPluginInterfaceID);
    if not Assigned(fPluginInterfaceID) then
    begin
      ReportError(Format(LNG_METHOD_NOT_FOUND, [mnPluginInterfaceID, dllFile]));
      Exit;
    end;
    pluginInterfaceID := fPluginInterfaceID();
    if not IsEqualGUID(pluginInterfaceID, GUID_USERDETECT2_IDPLUGIN_V1) then
    begin
      ReportError(Format(LNG_INVALID_PLUGIN, [dllFile]));
      Exit;
    end;

    @fIdentificationStringW := GetProcAddress(dllHandle, mnIdentificationStringW);
    if not Assigned(fIdentificationStringW) then
    begin
      ReportError(Format(LNG_METHOD_NOT_FOUND, [mnIdentificationStringW, dllFile]));
      Exit;
    end;

    @fPluginNameW := GetProcAddress(dllHandle, mnPluginNameW);
    if not Assigned(fPluginNameW) then
    begin
      ReportError(Format(LNG_METHOD_NOT_FOUND, [mnPluginNameW, dllFile]));
      Exit;
    end;

    @fPluginVendorW := GetProcAddress(dllHandle, mnPluginVendorW);
    if not Assigned(fPluginVendorW) then
    begin
      ReportError(Format(LNG_METHOD_NOT_FOUND, [mnPluginVendorW, dllFile]));
      Exit;
    end;

    @fPluginVersionW := GetProcAddress(dllHandle, mnPluginVersionW);
    if not Assigned(fPluginVersionW) then
    begin
      ReportError(Format(LNG_METHOD_NOT_FOUND, [mnPluginVersionW, dllFile]));
      Exit;
    end;

    @fCheckLicense := GetProcAddress(dllHandle, mnCheckLicense);
    if not Assigned(fCheckLicense) then
    begin
      ReportError(Format(LNG_METHOD_NOT_FOUND, [mnCheckLicense, dllFile]));
      Exit;
    end;

    @fIdentificationMethodNameW := GetProcAddress(dllHandle, mnIdentificationMethodNameW);
    if not Assigned(fIdentificationMethodNameW) then
    begin
      ReportError(Format(LNG_METHOD_NOT_FOUND, [mnIdentificationMethodNameW, dllFile]));
      Exit;
    end;

    sPluginID := '';

    sPluginConfigFile := ChangeFileExt(dllFile, '.ini');
    if FileExists(sPluginConfigFile) then
    begin
      iniConfig := TIniFile.Create(sPluginConfigFile);
      try
        sOverrideGUID := iniConfig.ReadString('Compatibility', 'OverrideGUID', '');
        if sOverrideGUID <> '' then
        begin
          sPluginID := sOverrideGUID;
          pluginID := StringToGUID(sPluginID);
        end;
      finally
        iniConfig.Free;
      end;
    end;

    if sPluginID = '' then
    begin
      @fPluginIdentifier := GetProcAddress(dllHandle, mnPluginIdentifier);
      if not Assigned(fPluginIdentifier) then
      begin
        ReportError(Format(LNG_METHOD_NOT_FOUND, [mnPluginIdentifier, dllFile]));
        Exit;
      end;
      pluginID := fPluginIdentifier();
      sPluginID := GUIDToString(pluginID);
    end;

    if (FGUIDLookup.Values[sPluginID] <> '') and (FGUIDLookup.Values[sPluginID] <> dllFile) then
    begin
      ReportError(Format(LNG_PLUGINS_SAME_GUID, [FGUIDLookup.Values[sPluginID], dllFile]));
      Exit;
    end
    else
    begin
      FGUIDLookup.Values[GUIDToString(pluginID)] := dllFile;
    end;

    statusCode := fCheckLicense(nil);
    if statusCode <> UD2_STATUS_OK then
    begin
      ReportError(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnCheckLicense, dllFile]));
      Exit;
    end;

    statusCode := fPluginNameW(@sPluginName, cchBufferSize, lngID);
    if statusCode <> UD2_STATUS_OK then
    begin
      ReportError(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnPluginNameW, dllFile]));
      Exit;
    end;

    statusCode := fPluginVendorW(@sPluginVendor, cchBufferSize, lngID);
    if statusCode <> UD2_STATUS_OK then
    begin
      ReportError(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnPluginVendorW, dllFile]));
      Exit;
    end;

    statusCode := fPluginVersionW(@sPluginVersion, cchBufferSize, lngID);
    if statusCode <> UD2_STATUS_OK then
    begin
      ReportError(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnPluginVersionW, dllFile]));
      Exit;
    end;

    statusCode := fIdentificationMethodNameW(@sIdentificationMethodName, cchBufferSize);
    if statusCode <> UD2_STATUS_OK then
    begin
      ReportError(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnIdentificationMethodNameW, dllFile]));
      Exit;
    end;

    pl := TUD2Plugin.Create;
    pl.PluginDLL     := dllFile;
    pl.PluginGUID    := pluginID;
    pl.PluginName    := sPluginName;
    pl.PluginVendor  := sPluginVendor;
    pl.PluginVersion := sPluginVersion;
    pl.IdentificationMethodName := sIdentificationMethodName;
    LoadedPlugins.Add(pl);

    statusCode := fIdentificationStringW(@sIdentifier, cchBufferSize);
    if statusCode <> UD2_STATUS_OK then
    begin
      ReportError(Format(LNG_METHOD_FAILURE, [UD2_ErrorLookup(statusCode), mnIdentificationStringW, dllFile]));
      Exit;
    end;

    if sIdentifier = '' then Exit;

    // Multiple identifiers (e.g. multiple MAC addresses are delimited via #10 )
    SetLength(sIdentifiers, 0);
    sIdentifiers := SplitString(UD2_MULTIPLE_ITEMS_DELIMITER, sIdentifier);
    for i := Low(sIdentifiers) to High(sIdentifiers) do
    begin
      pl.AddIdentification(sIdentifiers[i]);
    end;
  finally
    FreeLibrary(dllHandle);
  end;
end;

procedure TUD2.HandlePluginDir(APluginDir: string);
Var
  SR: TSearchRec;
  path: string;
begin
  path := IncludeTrailingPathDelimiter(APluginDir);
  if FindFirst(path + '*.dll', 0, SR) = 0 then
  begin
    repeat
      try
        HandleDLL(path + sr.Name);
      except
        on E: Exception do
        begin
          MessageDlg(E.Message, mtError, [mbOK], 0);
        end;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
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
begin
  result := FIniFile.ReadString(AShortTaskName, 'Description', '('+AShortTaskName+')');
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

end.
