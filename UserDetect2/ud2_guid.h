#ifndef _UD2_GUID_H_
#define _UD2_GUID_H_

#include <assert.h>

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
    g->Data1 = strtoul(szGUID+1,&pEnd,16);
    g->Data2 = strtoul(szGUID+10,&pEnd,16);
    g->Data3 = strtoul(szGUID+15,&pEnd,16);
	char b[3]; b[2] = 0;	
	memcpy(&b[0], szGUID+20, 2*sizeof(b[0])); g->Data4[0] = strtoul(&b[0], &pEnd, 16);
	memcpy(&b[0], szGUID+22, 2*sizeof(b[0])); g->Data4[1] = strtoul(&b[0], &pEnd, 16);
	for (int i=0; i<6; ++i) {
		memcpy(&b[0], szGUID+25+i*2, 2*sizeof(b[0])); g->Data4[2+i] = strtoul(&b[0], &pEnd, 16);
	}
	return true;
}
const GUID _StringToGUID(const char* szGUID) {
	GUID g;
	assert(StringToGUID(szGUID, &g));
	return g;
}
#endif

#endif

