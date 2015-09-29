#ifndef _UD2_API_H_
#define _UD2_API_H_

#include <windows.h>

#include "ud2_utils.h"

#define GUID_USERDETECT2_IDPLUGIN_V1 __GUID("{6C26245E-F79A-416C-8C73-BEA3EC18BB6E}")

const char UD2_MULTIPLE_ITEMS_DELIMITER = 0x10;

typedef DWORD UD2_STATUSCODE;

// We have chosen these numbers, to avoid that people use
// "return FALSE" ("return 0") to declare an error, and
// "return TRUE" ("return 1") to declare a successful operation.
const UD2_STATUSCODE UD2_STATUS_OK               = 0x10000000;
const UD2_STATUSCODE UD2_STATUS_BUFFER_TOO_SMALL = 0x00001000;
const UD2_STATUSCODE UD2_STATUS_INVALID_ARGS     = 0x00001001;
const UD2_STATUSCODE UD2_STATUS_NOT_LICENSED     = 0x00001002;

// ---

#ifdef BUILDING_DLL
#define UD2_API extern "C" __cdecl __declspec(dllexport)
#else
#define UD2_API extern "C" __cdecl __declspec(dllimport)
#endif

UD2_API GUID PluginIdentifier();
UD2_API UD2_STATUSCODE PluginNameW(LPWSTR lpPluginName, DWORD cchSize, LANGID wLangID);
UD2_API UD2_STATUSCODE PluginVersionW(LPWSTR lpPluginVersion, DWORD cchSize, LANGID wLangID);
UD2_API UD2_STATUSCODE PluginVendorW(LPWSTR lpPluginVendor, DWORD cchSize, LANGID wLangID);
UD2_API UD2_STATUSCODE CheckLicense(LPVOID lpReserved);
UD2_API UD2_STATUSCODE IdentificationMethodNameW(LPWSTR lpIdentificationMethodName, DWORD cchSize);
UD2_API UD2_STATUSCODE IdentificationStringW(LPWSTR lpIdentifier, DWORD cchSize);

#ifdef BUILDING_DLL
UD2_API GUID PluginInterfaceID() {
	return GUID_USERDETECT2_IDPLUGIN_V1;	
}
#else
UD2_API GUID PluginInterfaceID();
#endif

#endif
