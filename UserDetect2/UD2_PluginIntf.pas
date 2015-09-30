unit UD2_PluginIntf;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows, SysUtils;

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
  UD2_STATUS = DWORD;
  UD2_STATUSCAT = $0..$F;
  UD2_STATUSAUTH = $000..$FFF;
  UD2_STATUSMSG = $0000..$FFFF;

const
  UD2_STATUSCAT_SUCCESS   : UD2_STATUSCAT = $8;
  UD2_STATUSCAT_NOT_AVAIL : UD2_STATUSCAT = $9;         
  UD2_STATUSCAT_ERROR     : UD2_STATUSCAT = $A;

  UD2_STATUSAUTH_GENERIC : UD2_STATUSAUTH = $100;

  UD2_STATUS_OK_UNSPECIFIED : UD2_STATUS = $81000000;
  UD2_STATUS_OK_SINGLELINE  : UD2_STATUS = $81000001;
  UD2_STATUS_OK_MULTILINE   : UD2_STATUS = $81000002;
  UD2_STATUS_OK_LICENSED    : UD2_STATUS = $81000003;

  UD2_STATUS_NOTAVAIL_UNSPECIFIED      : UD2_STATUS = $91000000;
  UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED : UD2_STATUS = $91000001;
  UD2_STATUS_NOTAVAIL_HW_NOT_SUPPORTED : UD2_STATUS = $91000002;
  UD2_STATUS_NOTAVAIL_NO_ENTITIES      : UD2_STATUS = $91000003;
  UD2_STATUS_NOTAVAIL_API_CALL_FAILURE : UD2_STATUS = $91000004;

  UD2_STATUS_ERROR_UNSPECIFIED         : UD2_STATUS = $A1000000;
  UD2_STATUS_ERROR_BUFFER_TOO_SMALL    : UD2_STATUS = $A1000001;
  UD2_STATUS_ERROR_INVALID_ARGS        : UD2_STATUS = $A1000002;
  UD2_STATUS_ERROR_PLUGIN_NOT_LICENSED : UD2_STATUS = $A1000003;

function UD2_STATUS_Construct(cat: UD2_STATUSCAT;
  auth: UD2_STATUSAUTH; msg: UD2_STATUSMSG): UD2_STATUS;
function UD2_STATUS_GetCategory(dwStatus: UD2_STATUS): UD2_STATUSCAT;
function UD2_STATUS_GetAuthority(dwStatus: UD2_STATUS): UD2_STATUSAUTH;
function UD2_STATUS_GetMessage(dwStatus: UD2_STATUS): UD2_STATUSMSG;
function UD2_STATUS_Successful(dwStatus: UD2_STATUS): boolean;
function UD2_STATUS_NotAvail(dwStatus: UD2_STATUS): boolean;
function UD2_STATUS_Failed(dwStatus: UD2_STATUS): boolean;
function UD2_STATUS_FormatStatusCode(dwStatus: UD2_STATUS): string;
function UD2_STATUS_IsSpecific(dwStatus: UD2_STATUS): boolean;

type
  TFuncPluginInterfaceID = function(): TGUID; cdecl;
  TFuncPluginIdentifier = function(): TGUID; cdecl;
  TFuncPluginNameW = function(lpPluginName: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
  TFuncPluginVersionW = function(lpPluginVersion: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
  TFuncPluginVendorW = function(lpPluginVendor: LPWSTR; cchSize: DWORD; wLangID: LANGID): UD2_STATUS; cdecl;
  TFuncCheckLicense = function(lpReserved: LPVOID): UD2_STATUS; cdecl;
  TFuncIdentificationMethodNameW = function(lpIdentificationMethodName: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;
  TFuncIdentificationStringW = function(lpIdentifier: LPWSTR; cchSize: DWORD): UD2_STATUS; cdecl;

const
  UD2_MULTIPLE_ITEMS_DELIMITER = #10;

function PluginInterfaceID: TGUID; cdecl;

implementation

function UD2_STATUS_Construct(cat: UD2_STATUSCAT;
  auth: UD2_STATUSAUTH; msg: UD2_STATUSMSG): UD2_STATUS;
begin
  result := (cat shl 28) + (auth shl 16) + msg;
end;

function UD2_STATUS_GetCategory(dwStatus: UD2_STATUS): UD2_STATUSCAT;
begin
  result := (dwStatus and $F0000000) shr 28;
end;

function UD2_STATUS_GetAuthority(dwStatus: UD2_STATUS): UD2_STATUSAUTH;
begin
  result := (dwStatus and $0FFF0000) shr 16;
end;

function UD2_STATUS_GetMessage(dwStatus: UD2_STATUS): UD2_STATUSMSG;
begin
  result := dwStatus and $0000FFFF;
end;

function UD2_STATUS_Successful(dwStatus: UD2_STATUS): boolean;
begin
  result := UD2_STATUS_GetCategory(dwStatus) = UD2_STATUSCAT_SUCCESS;
end;

function UD2_STATUS_NotAvail(dwStatus: UD2_STATUS): boolean;
begin
  result := UD2_STATUS_GetCategory(dwStatus) = UD2_STATUSCAT_NOT_AVAIL;
end;

function UD2_STATUS_Failed(dwStatus: UD2_STATUS): boolean;
begin
  result := UD2_STATUS_GetCategory(dwStatus) = UD2_STATUSCAT_ERROR;
end;

function UD2_STATUS_FormatStatusCode(dwStatus: UD2_STATUS): string;
begin
  result := IntToHex(UD2_STATUS_GetCategory(dwStatus), 1) + ' ' +
            IntToHex(UD2_STATUS_GetAuthority(dwStatus), 3) + ' ' +
            IntToHex(UD2_STATUS_GetMessage(dwStatus), 4);
end;

function UD2_STATUS_IsSpecific(dwStatus: UD2_STATUS): boolean;
begin
  result := (dwStatus and $0000FFFF) <> 0;
end;

function PluginInterfaceID: TGUID; cdecl;
begin
  result := GUID_USERDETECT2_IDPLUGIN_V1;
end;

end.
