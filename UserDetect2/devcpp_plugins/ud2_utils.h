#ifndef _UD2_UTILS_H_
#define _UD2_UTILS_H_

#include <windows.h>

#include "ud2_api.h"

BOOL UD2_IsMultilineW(LPCWSTR lpSrc) {
	return wcschr(lpSrc, UD2_MULTIPLE_ITEMS_DELIMITER) != NULL;
	// return wcspbrk(lpSrc, L"\r\n") != NULL;
}

UD2_STATUS UD2_WriteStrW(LPWSTR lpDest, DWORD cchDestSize, LPCWSTR lpSrc) {
	if (wcslen(lpSrc) > cchDestSize-1) return UD2_STATUS_FAILURE_BUFFER_TOO_SMALL;
	wcscpy(lpDest, lpSrc);
	if (wcslen(lpSrc) == 0) return UD2_STATUS_NOTAVAIL_UNSPECIFIED;
	if (UD2_IsMultilineW(lpSrc)) return UD2_STATUS_OK_MULTILINE;
	return UD2_STATUS_OK_SINGLELINE;
}

#endif
