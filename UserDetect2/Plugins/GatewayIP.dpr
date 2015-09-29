library GatewayIP;

uses
  Windows,
  SysUtils,
  Classes,
  UD2_PluginIntf in '..\UD2_PluginIntf.pas',
  UD2_PluginUtils in '..\UD2_PluginUtils.pas',
  NetworkUtils in 'NetworkUtils.pas';

{$R *.res}

const
  PLUGIN_GUID: TGUID = '{F45C87FF-3A82-4AC8-AA19-C9DC0C6AAF7B}';

function PluginIdentifier: TGUID; cdecl;
begin
  result := PLUGIN_GUID;
end;

function IdentificationStringW(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUSCODE; cdecl;
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    GetGatewayIPAddressList(sl);
    result := WriteStringListToPointerW(lpIdentifier, cchSize, sl);
  finally
    sl.Free;
  end;
end;

function PluginNameW(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUSCODE; cdecl;
var
  stPluginName: WideString;
  primaryLangID: Byte;
begin
  primaryLangID := wLangID and $00FF;
  if primaryLangID = LANG_GERMAN then
    stPluginName := 'IP-Adressen der Gateways'
  else
    stPluginName := 'Gateway IP addresses';
  result := WritePascalStringToPointerW(lpPluginName, cchSize, stPluginName);
end;

function PluginVendorW(lpPluginVendor: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUSCODE; cdecl;
begin
  result := WritePascalStringToPointerW(lpPluginVendor, cchSize, 'ViaThinkSoft');
end;

function PluginVersionW(lpPluginVersion: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUSCODE; cdecl;
begin
  result := WritePascalStringToPointerW(lpPluginVersion, cchSize, '1.0');
end;

function IdentificationMethodNameW(lpIdentificationMethodName: LPWSTR; cchSize: DWORD): UD2_STATUSCODE; cdecl;
var
  stIdentificationMethodName: WideString;
begin
  stIdentificationMethodName := 'GatewayIP';
  result := WritePascalStringToPointerW(lpIdentificationMethodName, cchSize, stIdentificationMethodName);
end;

function CheckLicense(lpReserved: LPVOID): UD2_STATUSCODE; cdecl;
begin
  result := UD2_STATUS_OK;
end;

exports
  PluginInterfaceID         name mnPluginInterfaceID,
  PluginIdentifier          name mnPluginIdentifier,
  PluginNameW               name mnPluginNameW,
  PluginVendorW             name mnPluginVendorW,
  PluginVersionW            name mnPluginVersionW,
  IdentificationMethodNameW name mnIdentificationMethodNameW,
  IdentificationStringW     name mnIdentificationStringW,
  CheckLicense              name mnCheckLicense;

end.
