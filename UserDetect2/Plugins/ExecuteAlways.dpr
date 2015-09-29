library ExecuteAlways;

uses
  Windows,
  SysUtils, 
  Classes,
  UD2_PluginIntf in '..\UD2_PluginIntf.pas',
  UD2_PluginUtils in '..\UD2_PluginUtils.pas';

{$R *.res}

const
  PLUGIN_GUID: TGUID = '{7A1189CD-8F68-4068-9477-C50B9DCCCECC}';

function PluginIdentifier: TGUID; cdecl;
begin
  result := PLUGIN_GUID;
end;

function IdentificationStringW(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUSCODE; cdecl;
var
  stIdentifier: WideString;
begin
  stIdentifier := 'Always';
  result := WritePascalStringToPointerW(lpIdentifier, cchSize, stIdentifier);
end;

function PluginNameW(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUSCODE; cdecl;
var
  stPluginName: WideString;
  primaryLangID: Byte;
begin
  primaryLangID := wLangID and $00FF;
  if primaryLangID = LANG_GERMAN then
    stPluginName := 'Immer ausführen'
  else
    stPluginName := 'Execute always';
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
  stIdentificationMethodName := 'Execute';
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
