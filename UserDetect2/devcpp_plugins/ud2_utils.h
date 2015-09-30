#ifndef _UD2_UTILS_H_
#define _UD2_UTILS_H_

#include <windows.h>
#include <assert.h>

#include "ud2_api.h"

// #define USE_OLE32

#ifdef USE_OLE32
#pragma comment(linker, "-lOle32")
#define __GUID(x) _StringToGUID(L ## x)
const GUID _StringToGUID(LPCWSTR lpcstrGUID) {
	GUID guid;
	assert(SUCCEEDED(CLSIDFromString(lpcstrGUID, &guid)));
	return guid;
}
#else
#define __GUID(x) _StringToGUID(x)
const bool StringToGUID(const char* szGUID, GUID* g) {
	// Check if string is a valid GUID
	if (strlen(szGUID) != 38) return false;
	for (int i=0; i<strlen(szGUID); ++i) {
		char g = szGUID[i];
		
		if (i == 0) {
			if (g != '{') return false;
		} else if (i == 37) {
			if (g != '}') return false;
		} else if ((i == 9) || (i == 14) || (i == 19) || (i == 24)) {
			if (g != '-') return false;
		} else {
			if (!((g >= '0') && (g <= '9')) && !((g >= 'A') && (g <= 'F')) && !((g >= 'a') && (g <= 'f'))) {
				return false;
			}
		}
	}
	
	char* pEnd;
    g->Data1 = strtol(szGUID+1,&pEnd,16);
    g->Data2 = strtol(szGUID+10,&pEnd,16);
    g->Data3 = strtol(szGUID+15,&pEnd,16);
	char b[3]; b[2] = 0;	
	memcpy(&b[0], szGUID+20, 2*sizeof(b[0])); g->Data4[0] = strtol(&b[0], &pEnd, 16);
	memcpy(&b[0], szGUID+22, 2*sizeof(b[0])); g->Data4[1] = strtol(&b[0], &pEnd, 16);
	for (int i=0; i<8; ++i) {
		memcpy(&b[0], szGUID+25+i*2, 2*sizeof(b[0])); g->Data4[2+i] = strtol(&b[0], &pEnd, 16);
	}
	return true;
}
const GUID _StringToGUID(const char* szGUID) {
	GUID g;
	assert(StringToGUID(szGUID, &g));
	return g;
}
#endif

BOOL UD2_IsMultilineW(LPCWSTR lpSrc) {
	return wcschr(lpSrc, UD2_MULTIPLE_ITEMS_DELIMITER) != NULL;
	// return wcspbrk(lpSrc, L"\r\n") != NULL;
}

UD2_STATUS UD2_WriteStrW(LPWSTR lpDest, DWORD cchDestSize, LPCWSTR lpSrc) {
	if (wcslen(lpSrc) > cchDestSize-1) return UD2_STATUS_ERROR_BUFFER_TOO_SMALL;
	wcscpy(lpDest, lpSrc);
	if (wcslen(lpSrc) == 0) return UD2_STATUS_NOTAVAIL_UNSPECIFIED;
	if (UD2_IsMultilineW(lpSrc)) return UD2_STATUS_OK_MULTILINE;
	return UD2_STATUS_OK_SINGLELINE;
}

#endif
