#ifndef _UD2_STATUS_H_
#define _UD2_STATUS_H_

#include <stdio.h>

#include "ud2_api.h"

typedef WORD  UD2_STATUSCAT;
typedef GUID  UD2_STATUSAUTH;
typedef DWORD UD2_STATUSMSG;
typedef DWORD UD2_STATUSEXTRAINFO;

#pragma pack(push, 1) // no alignment
typedef struct _UD2_STATUS {
    BYTE                cbSize;
    BYTE                bReserved;
    UD2_STATUSCAT       wCategory;
    UD2_STATUSAUTH      grAuthority;
    UD2_STATUSMSG       dwMessage;
    UD2_STATUSEXTRAINFO dwExtraInfo;
} UD2_STATUS;
#pragma pack(pop) // restore previous pack value

const UD2_STATUSCAT UD2_STATUSCAT_SUCCESS   = 0;
const UD2_STATUSCAT UD2_STATUSCAT_NOT_AVAIL = 1;
const UD2_STATUSCAT UD2_STATUSCAT_FAILED    = 2;

const UD2_STATUSAUTH UD2_STATUSAUTH_GENERIC = __GUID("{90F53368-1EFB-4350-A6BC-725C69938B9C}");

const UD2_STATUS UD2_STATUS_OK_UNSPECIFIED = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_SUCCESS, UD2_STATUSAUTH_GENERIC, 0, 0 };
const UD2_STATUS UD2_STATUS_OK_SINGLELINE  = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_SUCCESS, UD2_STATUSAUTH_GENERIC, 1, 0 };
const UD2_STATUS UD2_STATUS_OK_MULTILINE   = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_SUCCESS, UD2_STATUSAUTH_GENERIC, 2, 0 };
const UD2_STATUS UD2_STATUS_OK_LICENSED    = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_SUCCESS, UD2_STATUSAUTH_GENERIC, 3, 0 };

const UD2_STATUS UD2_STATUS_NOTAVAIL_UNSPECIFIED         = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_NOT_AVAIL, UD2_STATUSAUTH_GENERIC, 0, 0 };
const UD2_STATUS UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED    = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_NOT_AVAIL, UD2_STATUSAUTH_GENERIC, 1, 0 };
const UD2_STATUS UD2_STATUS_NOTAVAIL_HW_NOT_SUPPORTED    = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_NOT_AVAIL, UD2_STATUSAUTH_GENERIC, 2, 0 };
const UD2_STATUS UD2_STATUS_NOTAVAIL_NO_ENTITIES         = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_NOT_AVAIL, UD2_STATUSAUTH_GENERIC, 3, 0 };
const UD2_STATUS UD2_STATUS_NOTAVAIL_WINAPI_CALL_FAILURE = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_NOT_AVAIL, UD2_STATUSAUTH_GENERIC, 4, 0 };

const UD2_STATUS UD2_STATUS_FAILURE_UNSPECIFIED         = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_FAILED, UD2_STATUSAUTH_GENERIC, 0, 0 };
const UD2_STATUS UD2_STATUS_FAILURE_BUFFER_TOO_SMALL    = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_FAILED, UD2_STATUSAUTH_GENERIC, 1, 0 };
const UD2_STATUS UD2_STATUS_FAILURE_INVALID_ARGS        = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_FAILED, UD2_STATUSAUTH_GENERIC, 2, 0 };
const UD2_STATUS UD2_STATUS_FAILURE_PLUGIN_NOT_LICENSED = { sizeof(UD2_STATUS), 0, UD2_STATUSCAT_FAILED, UD2_STATUSAUTH_GENERIC, 3, 0 };

int UD2_STATUS_FormatStatusCode(char* szStr, size_t cchLen, UD2_STATUS grStatus) {
	// 00 0000 {44332211-1234-ABCD-EFEF-001122334455} 00000000 00000000
	if (cchLen < 73) szStr = NULL; // incl. null-terminator
	return sprintf(szStr, "%02x %04x {%08lX-%04hX-%04hX-%02hhX%02hhX-%02hhX%02hhX%02hhX%02hhX%02hhX%02hhX} %08x %08x",
		grStatus.bReserved,
		grStatus.wCategory,
		grStatus.grAuthority,
		grStatus.grAuthority.Data1, grStatus.grAuthority.Data2, grStatus.grAuthority.Data3, 
			grStatus.grAuthority.Data4[0], grStatus.grAuthority.Data4[1], grStatus.grAuthority.Data4[2], grStatus.grAuthority.Data4[3],
			grStatus.grAuthority.Data4[4], grStatus.grAuthority.Data4[5], grStatus.grAuthority.Data4[6], grStatus.grAuthority.Data4[7],
		grStatus.dwMessage,
		grStatus.dwExtraInfo);	
}

bool UD2_STATUS_Equal(UD2_STATUS grStatus1, UD2_STATUS grStatus2, bool compareExtraInfo) {
	return (grStatus1.bReserved == grStatus2.bReserved) &&
		(grStatus1.wCategory == grStatus2.wCategory) &&
		IsEqualGUID(grStatus1.grAuthority, grStatus2.grAuthority) &&
		(grStatus1.dwMessage == grStatus2.dwMessage);
		
	if (compareExtraInfo && (grStatus1.dwExtraInfo != grStatus2.dwExtraInfo)) return false;
}

#ifdef __cplusplus
bool operator==(const UD2_STATUS& lhs, const UD2_STATUS& rhs) {
	return UD2_STATUS_Equal(lhs, rhs, true);
}
#endif

UD2_STATUS UD2_STATUS_OSError(DWORD dwOSError) {
	UD2_STATUS ret = UD2_STATUS_NOTAVAIL_WINAPI_CALL_FAILURE;
	ret.dwExtraInfo = dwOSError;	
	return ret;
}

#endif
