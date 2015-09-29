#define BUILDING_DLL

#include "ud2_api.h"

UD2_API GUID PluginIdentifier() {
	return __GUID("{7576BD8F-A0C4-436F-B953-B137CBFD9FC7}");
}

UD2_API DWORD PluginNameW(LPWSTR lpPluginName, DWORD cchSize, LANGID wLangID) {
	 LPCWSTR str = L"Test-Plugin in C++";
	 return __WRITESTR_W(lpPluginName, cchSize, str);
}

UD2_API UD2_STATUSCODE PluginVersionW(LPWSTR lpPluginVersion, DWORD cchSize, LANGID wLangID) {
	 LPCWSTR str = L"1.0";
	 return __WRITESTR_W(lpPluginVersion, cchSize, str);
}

UD2_API UD2_STATUSCODE PluginVendorW(LPWSTR lpPluginVendor, DWORD cchSize, LANGID wLangID) {
	 LPCWSTR str = L"ViaThinkSoft";
	 return __WRITESTR_W(lpPluginVendor, cchSize, str);
}

UD2_API UD2_STATUSCODE CheckLicense(LPVOID lpReserved) {
	return UD2_STATUS_OK;
}

UD2_API UD2_STATUSCODE IdentificationMethodNameW(LPWSTR lpIdentificationMethodName, DWORD cchSize) {
	 return __WRITESTR_W(lpIdentificationMethodName, cchSize, L"TEST");
}

UD2_API UD2_STATUSCODE IdentificationStringW(LPWSTR lpIdentifier, DWORD cchSize) {
	 return __WRITESTR_W(lpIdentifier, cchSize, L"Example");
}
