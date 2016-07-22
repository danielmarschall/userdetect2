unit UD2_PluginIntf;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows, SysUtils, UD2_PluginStatus;

const
  GUID_USERDETECT2_IDPLUGIN_V1: TGUID = '{6C26245E-F79A-416C-8C73-BEA3EC18BB6E}';

const
  mnPluginInterfaceID            = 'PluginInterfaceID';
  mnPluginIdentifier             = 'PluginIdentifier';
  mnPluginNameW                  = 'PluginNameW';
  mnPluginVersionW               = 'PluginVersionW';
  mnPluginVendorW                = 'PluginVendorW';
  mnCheckLicense                 = 'CheckLicense';
  mnIdentificationMethodNameW    = 'IdentificationMethodNameW';
  mnIdentificationStringW        = 'IdentificationStringW';
  mnDescribeOwnStatusCodeW       = 'DescribeOwnStatusCodeW';
  mnDynamicIdentificationStringW = 'DynamicIdentificationStringW';

{$IF not Declared(LPVOID)}
type
  LPVOID = Pointer;
{$IFEND}

type
  TFuncPluginInterfaceID = function(): TGUID; cdecl;
  TFuncPluginIdentifier = function(): TGUID; cdecl;
  TFuncPluginNameW = function(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
  TFuncPluginVersionW = function(lpPluginVersion: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
  TFuncPluginVendorW = function(lpPluginVendor: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
  TFuncCheckLicense = function(lpReserved: LPVOID): UD2_STATUS; cdecl;
  TFuncIdentificationMethodNameW = function(lpIdentificationMethodName: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
  TFuncIdentificationStringW = function(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
  TFuncDescribeOwnStatusCodeW = function(lpErrorDescription: LPWSTR; cchSize: DWORD; statusCode: UD2_STATUS; wLangID: LANGID): BOOL; cdecl;

  // Extension of the plugin API starting with version v2.2.
  // We don't assign a new PluginIdentifier GUID since the methods of the old API
  // are still valid, so an UserDetect2 v2.0/v2.1 plugin can be still used with UserDetect2 v2.2.
  // Therefore, this function *MUST* be optional and therefore it may only be imported dynamically.
  TFuncDynamicIdentificationStringW = function(lpIdentifier: LPWSTR; cchSize: DWORD; lpDynamicData: LPWSTR): UD2_STATUS; cdecl;

const
  UD2_MULTIPLE_ITEMS_DELIMITER = #10;

function PluginInterfaceID: TGUID; cdecl;

implementation

function PluginInterfaceID: TGUID; cdecl;
begin
  result := GUID_USERDETECT2_IDPLUGIN_V1;
end;

end.
