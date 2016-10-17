library DriveSerial;

uses
  Windows,
  SysUtils,
  Classes,
  ActiveX,
  UD2_PluginIntf in '..\UD2_PluginIntf.pas',
  UD2_PluginUtils in '..\UD2_PluginUtils.pas',
  UD2_PluginStatus in '..\UD2_PluginStatus.pas',
  hddinfo in 'Utils\hddinfo.pas';

{$R *.res}

const
  PLUGIN_GUID: TGUID = '{2978C8D6-02A8-4D29-83D7-62EA5252F807}';

function PluginIdentifier: TGUID; cdecl;
begin
  result := PLUGIN_GUID;
end;

function IdentificationStringW(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
begin
  result := UD2_STATUS_NOTAVAIL_ONLY_ACCEPT_DYNAMIC;
end;

function PluginNameW(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
var
  stPluginName: WideString;
  primaryLangID: Byte;
begin
  primaryLangID := wLangID and $00FF;
  if primaryLangID = LANG_GERMAN then
    stPluginName := 'Datenträger-Seriennummer'
  else
    stPluginName := 'Drive Serial Number';
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
  stIdentificationMethodName := 'DriveSerial';
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

function DynamicIdentificationStringW(lpIdentifier: LPWSTR; cchSize: DWORD; lpDynamicData: LPWSTR): UD2_STATUS; cdecl;
var
  stIdentifier: WideString;
  driveletter: AnsiChar;
begin
  try
    if Copy(string(lpDynamicData), 2, 1) <> ':' then
    begin
      result := UD2_STATUS_NOTAVAIL_INVALID_INPUT;
      exit;
    end;

    driveletter := AnsiChar(Copy(UpperCase(lpDynamicData), 1, 1)[1]);

    if not (driveletter in ['A'..'Z']) then
    begin
      result := UD2_STATUS_NOTAVAIL_INVALID_INPUT;
      exit;
    end;

    CoInitialize(nil);
    try
      stIdentifier := GetDriveSerial(driveletter); // driveletter must be upper case
    finally
      CoUninitialize;
    end;
    result := UD2_WritePascalStringToPointerW(lpIdentifier, cchSize, stIdentifier);
  except
    on E: Exception do result := UD2_STATUS_HandleException(E);
  end;
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
  DescribeOwnStatusCodeW    name mnDescribeOwnStatusCodeW,
  DynamicIdentificationStringW name mnDynamicIdentificationStringW;

end.
