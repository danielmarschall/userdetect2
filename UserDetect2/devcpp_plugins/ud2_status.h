#ifndef _UD2_STATUS_H_
#define _UD2_STATUS_H_

#include <stdio.h>

typedef DWORD UD2_STATUS;
typedef BYTE UD2_STATUSCAT; // 0x0..0xF; only 1 nibble!
typedef WORD UD2_STATUSAUTH; // 0x000..0xFFF; only 3 nibbles!
typedef WORD UD2_STATUSMSG;

const UD2_STATUSCAT UD2_STATUSCAT_SUCCESS   = 0x8;
const UD2_STATUSCAT UD2_STATUSCAT_NOT_AVAIL = 0x9;
const UD2_STATUSCAT UD2_STATUSCAT_ERROR     = 0xA;

const UD2_STATUSAUTH UD2_STATUSAUTH_GENERIC = 0x100;

const UD2_STATUS UD2_STATUS_OK_UNSPECIFIED  = 0x81000000;
const UD2_STATUS UD2_STATUS_OK_SINGLELINE   = 0x81000001;
const UD2_STATUS UD2_STATUS_OK_MULTILINE    = 0x81000002;
const UD2_STATUS UD2_STATUS_OK_LICENSED     = 0x81000003;

const UD2_STATUS UD2_STATUS_NOTAVAIL_UNSPECIFIED       = 0x91000000;
const UD2_STATUS UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED  = 0x91000001;
const UD2_STATUS UD2_STATUS_NOTAVAIL_HW_NOT_SUPPORTED  = 0x91000002;
const UD2_STATUS UD2_STATUS_NOTAVAIL_NO_ENTITIES       = 0x91000003;
const UD2_STATUS UD2_STATUS_NOTAVAIL_API_CALL_FAILURE  = 0x91000004;

const UD2_STATUS UD2_STATUS_ERROR_UNSPECIFIED          = 0xA1000000;
const UD2_STATUS UD2_STATUS_ERROR_BUFFER_TOO_SMALL     = 0xA1000001;
const UD2_STATUS UD2_STATUS_ERROR_INVALID_ARGS         = 0xA1000002;
const UD2_STATUS UD2_STATUS_ERROR_PLUGIN_NOT_LICENSED  = 0xA1000003;

UD2_STATUS UD2_STATUS_Construct(UD2_STATUSCAT cat, UD2_STATUSAUTH auth, UD2_STATUSMSG msg) {
	return (cat << 28) + (auth << 16) + msg;
}

UD2_STATUSCAT UD2_STATUS_GetCategory(UD2_STATUS dwStatus) {
	return (dwStatus & 0xF0000000) >> 28;
}

UD2_STATUSAUTH UD2_STATUS_GetAuthority(UD2_STATUS dwStatus) {
	return (dwStatus & 0x0FFF0000) >> 16;
}

UD2_STATUSMSG UD2_STATUS_GetMessage(UD2_STATUS dwStatus) {
	return dwStatus & 0x0000FFFF;
}

BOOL UD2_STATUS_Successful(UD2_STATUS dwStatus) {
	return UD2_STATUS_GetCategory(dwStatus) == UD2_STATUSCAT_SUCCESS;
}

BOOL UD2_STATUS_NotAvail(UD2_STATUS dwStatus) {
	return UD2_STATUS_GetCategory(dwStatus) == UD2_STATUSCAT_NOT_AVAIL;
}

BOOL UD2_STATUS_Failed(UD2_STATUS dwStatus) {
	return UD2_STATUS_GetCategory(dwStatus) == UD2_STATUSCAT_ERROR;
}

int UD2_STATUS_FormatStatusCode(char* szStr, size_t cchLen, UD2_STATUS dwStatus) {
	if (cchLen < 11) szStr = NULL;
	return sprintf(szStr, "%01x %03x %04x", UD2_STATUS_GetCategory(dwStatus),
	                                        UD2_STATUS_GetAuthority(dwStatus),
	                                        UD2_STATUS_GetMessage(dwStatus));
}

BOOL UD2_STATUS_IsSpecific(UD2_STATUS dwStatus) {
	return (dwStatus & 0x0000FFFF) != 0;
}

#endif
