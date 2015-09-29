unit UD2_PluginIntf;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows;

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

{$IF not Declared(LPVOID)}
type
  LPVOID = Pointer;
{$IFEND}

type
  UD2_STATUSCODE = DWORD;

const
  // We have chosen these numbers, to avoid that people use
  // "return FALSE" ("return 0") to declare an error, and
  // "return TRUE" ("return 1") to declare a successful operation.
  // TODO: visible und invisible module errors, z.b. unavailable wegen winapi etc.
  // --> mask machen: sucessful, failed, failed hard, official oder userdefined
  UD2_STATUS_OK               : UD2_STATUSCODE = $10000000;
  UD2_STATUS_BUFFER_TOO_SMALL : UD2_STATUSCODE = $00001000;
  UD2_STATUS_INVALID_ARGS     : UD2_STATUSCODE = $00001001;
  UD2_STATUS_NOT_LICENSED     : UD2_STATUSCODE = $00001002;

type
  TFuncPluginInterfaceID = function(): TGUID; cdecl;
  TFuncPluginIdentifier = function(): TGUID; cdecl;
  TFuncPluginNameW = function(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUSCODE; cdecl;
  TFuncPluginVersionW = function(lpPluginVersion: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUSCODE; cdecl;
  TFuncPluginVendorW = function(lpPluginVendor: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUSCODE; cdecl;
  TFuncCheckLicense = function(lpReserved: LPVOID): UD2_STATUSCODE; cdecl;
  TFuncIdentificationMethodNameW = function(lpIdentificationMethodName: LPWSTR; cchSize: DWORD): UD2_STATUSCODE; cdecl;
  TFuncIdentificationStringW = function(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUSCODE; cdecl;

const
  UD2_MULTIPLE_ITEMS_DELIMITER = #10;

function PluginInterfaceID: TGUID; cdecl;

implementation

function PluginInterfaceID: TGUID; cdecl;
begin
  result := GUID_USERDETECT2_IDPLUGIN_V1;
end;

end.
