library LAN_MAC;

uses
  Windows,
  SysUtils,
  Classes,
  UD2_PluginIntf in '..\UD2_PluginIntf.pas',
  UD2_PluginUtils in '..\UD2_PluginUtils.pas',
  UD2_PluginStatus in '..\UD2_PluginStatus.pas',
  NetworkUtils in 'NetworkUtils.pas';

{$R *.res}

const
  PLUGIN_GUID: TGUID = '{8E1AA598-67A6-4128-BB9F-7E624647F584}';

function PluginIdentifier: TGUID; cdecl;
begin
  result := PLUGIN_GUID;
end;

function IdentificationStringW(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
var
  sl, sl2: TStringList;
  i: integer;
  ip, mac: string;
  ec: DWORD;
begin
  sl := TStringList.Create;
  sl2 := TStringList.Create;
  try
    ec := GetLocalMACAddressList(sl2);
    if ec = ERROR_NOT_SUPPORTED then
    begin
      result := UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED;
      Exit;
    end
    else if ec <> ERROR_SUCCESS then
    begin
      result := UD2_STATUS_OSError(ec);
      Exit;
    end;

    // This procedure should not find any more MAC addresses...
    GetLocalIPAddressList(sl);
    for i := 0 to sl.Count-1 do
    begin
      ip := sl.Strings[i];
      ec := GetMACAddress(ip, mac);
      if ec = ERROR_NOT_SUPPORTED then
      begin
        result := UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED;
        Exit;
      end
      else if (ec = S_OK) and
              (mac <> '') and
              (sl2.IndexOf(mac) = -1) then
      begin
        sl2.add(mac);
      end;
    end;
    result := UD2_WriteStringListToPointerW(lpIdentifier, cchSize, sl2);
  finally
    sl.Free;
    sl2.Free;
  end;
end;

function PluginNameW(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
var
  stPluginName: WideString;
  primaryLangID: Byte;
begin
  primaryLangID := wLangID and $00FF;
  if primaryLangID = LANG_GERMAN then
    stPluginName := 'MAC-Adressen'
  else
    stPluginName := 'MAC addresses';
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
  stIdentificationMethodName := 'LAN_MAC';
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
