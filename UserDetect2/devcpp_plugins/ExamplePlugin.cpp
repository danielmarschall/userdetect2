#define BUILDING_DLL

#include "ud2_api.h"

UD2_API GUID PluginIdentifier() {
	return __GUID("{7576BD8F-A0C4-436F-B953-B137CBFD9FC7}");
}

UD2_API UD2_STATUS PluginNameW(LPWSTR lpPluginName, DWORD cchSize, LANGID wLangID) {
	 LPCWSTR str = L"Test-Plugin in C++";
	 return UD2_WriteStrW(lpPluginName, cchSize, str);
}

UD2_API UD2_STATUS PluginVersionW(LPWSTR lpPluginVersion, DWORD cchSize, LANGID wLangID) {
	 LPCWSTR str = L"1.0";
	 return UD2_WriteStrW(lpPluginVersion, cchSize, str);
}

UD2_API UD2_STATUS PluginVendorW(LPWSTR lpPluginVendor, DWORD cchSize, LANGID wLangID) {
	 LPCWSTR str = L"ViaThinkSoft";
	 return UD2_WriteStrW(lpPluginVendor, cchSize, str);
}

UD2_API UD2_STATUS CheckLicense(LPVOID lpReserved) {
	return UD2_STATUS_OK_LICENSED;
}

UD2_API UD2_STATUS IdentificationMethodNameW(LPWSTR lpIdentificationMethodName, DWORD cchSize) {
	 return UD2_WriteStrW(lpIdentificationMethodName, cchSize, L"TEST");
}

UD2_API UD2_STATUS IdentificationStringW(LPWSTR lpIdentifier, DWORD cchSize) {
	 return UD2_WriteStrW(lpIdentifier, cchSize, L"Example");
}

UD2_API BOOL DescribeOwnStatusCodeW(LPWSTR lpErrorDescription, DWORD cchSize, UD2_STATUS statusCode, LANGID wLangID) {
	  // This function does not use non-generic status codes
	return FALSE;
}
