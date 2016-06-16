library EnvironmentString;

uses
  Windows,
  SysUtils,
  Classes,
  MiscUtils,
  UD2_PluginIntf in '..\UD2_PluginIntf.pas',
  UD2_PluginUtils in '..\UD2_PluginUtils.pas',
  UD2_PluginStatus in '..\UD2_PluginStatus.pas';

{$R *.res}

const
  PLUGIN_GUID: TGUID = '{145EEB93-8170-4220-8959-09253881E4B6}';

function PluginIdentifier: TGUID; cdecl;
begin
  result := PLUGIN_GUID;
end;

function IdentificationStringW(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    EnvironmentStringsToStrings(sl);
    result := UD2_WriteStringListToPointerW(lpIdentifier, cchSize, sl);
  finally
    sl.Free;
  end;
end;

function PluginNameW(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
var
  stPluginName: WideString;
  primaryLangID: Byte;
begin
  primaryLangID := wLangID and $00FF;
  if primaryLangID = LANG_GERMAN then
    stPluginName := 'Umgebungsvariable'
  else
    stPluginName := 'Environment variable';
  result := UD2_WritePascalStringToPointerW(lpPluginName, cchSize, stPluginName);
end;

function PluginVendorW(lpPluginVendor: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
begin
  result := UD2_WritePascalStringToPointerW(lpPluginVendor, cchSize, 'ViaThinkSoft');
end;

function PluginVersionW(lpPluginVersion: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
begin
  result := UD2_WritePascalStringToPointerW(lpPluginVersion, cchSize, '1.0');
end;

function IdentificationMethodNameW(lpIdentificationMethodName: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
var
  stIdentificationMethodName: WideString;
begin
  stIdentificationMethodName := 'EnvironmentString';
  result := UD2_WritePascalStringToPointerW(lpIdentificationMethodName, cchSize, stIdentificationMethodName);
end;

function CheckLicense(lpReserved: LPVOID): UD2_STATUS; cdecl;
begin
  result := UD2_STATUS_OK_LICENSED;
end;

function DescribeOwnStatusCodeW(lpErrorDescription: LPWSTR; cchSize: DWORD; statusCode: UD2_STATUS; wLangID: LANGID): BOOL; cdecl;
begin
  // This function does not use non-generic status codes
  result := FALSE;
end;

exports
  PluginInterfaceID         name mnPluginInterfaceID,
  PluginIdentifier          name mnPluginIdentifier,
  PluginNameW               name mnPluginNameW,
  PluginVendorW             name mnPluginVendorW,
  PluginVersionW            name mnPluginVersionW,
  IdentificationMethodNameW name mnIdentificationMethodNameW,
  IdentificationStringW     name mnIdentificationStringW,
  CheckLicense              name mnCheckLicense,
  DescribeOwnStatusCodeW    name mnDescribeOwnStatusCodeW;

end.
