library DomainName;

uses
  Windows,
  SysUtils,
  Classes,
  Registry,
  networkutils in 'networkutils.pas',
  UD2_PluginIntf in '..\UD2_PluginIntf.pas',
  UD2_PluginUtils in '..\UD2_PluginUtils.pas',
  UD2_PluginStatus in '..\UD2_PluginStatus.pas';

{$R *.res}

const
  PLUGIN_GUID: TGUID = '{6D7AABD7-C4A8-43ED-99E3-3AF4723DD7B2}';

function PluginIdentifier: TGUID; cdecl;
begin
  result := PLUGIN_GUID;
end;

function IdentificationStringW(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
var
  stIdentifier: WideString;
begin
  if not GetDomainName(stIdentifier) then
  begin
    result := UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED;
    Exit;
  end;
  result := UD2_WritePascalStringToPointerW(lpIdentifier, cchSize, stIdentifier);
end;

function PluginNameW(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
var
  stPluginName: WideString;
  primaryLangID: Byte;
begin
  primaryLangID := wLangID and $00FF;
  if primaryLangID = LANG_GERMAN then
    stPluginName := 'Domänen-Name'
  else
    stPluginName := 'Domain name';
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
  stIdentificationMethodName := 'DomainName';
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
