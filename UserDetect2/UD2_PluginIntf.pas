unit UD2_PluginIntf;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

{$WARN UNSAFE_TYPE OFF}

uses
  Windows, SysUtils, UD2_PluginStatus;

const
  GUID_USERDETECT2_IDPLUGIN_V1: TGUID = '{6C26245E-F79A-416C-8C73-BEA3EC18BB6E}';

const
  mnPluginInterfaceID         = 'PluginInterfaceID';
  mnPluginIdentifier          = 'PluginIdentifier';
  mnPluginNameW               = 'PluginNameW';
  mnPluginVersionW            = 'PluginVersionW';
  mnPluginVendorW             = 'PluginVendorW';
  mnCheckLicense              = 'CheckLicense';
  mnIdentificationMethodNameW = 'IdentificationMethodNameW';
  mnIdentificationStringW     = 'IdentificationStringW';
  mnDescribeOwnStatusCodeW    = 'DescribeOwnStatusCodeW';

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

const
  UD2_MULTIPLE_ITEMS_DELIMITER = #10;

function PluginInterfaceID: TGUID; cdecl;

implementation

function PluginInterfaceID: TGUID; cdecl;
begin
  result := GUID_USERDETECT2_IDPLUGIN_V1;
end;

end.
