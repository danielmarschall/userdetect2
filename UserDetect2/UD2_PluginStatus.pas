unit UD2_PluginStatus;

interface

uses
  Windows, SysUtils;

type
  UD2_STATUSCAT       = WORD;
  UD2_STATUSAUTH      = TGUID;
  UD2_STATUSMSG       = DWORD;
  UD2_STATUSEXTRAINFO = DWORD;

  UD2_STATUS = packed record
    cbSize: BYTE;
    bReserved: BYTE;
    wCategory: UD2_STATUSCAT;
    grAuthority: UD2_STATUSAUTH;
    dwMessage: UD2_STATUSMSG;
    dwExtraInfo: UD2_STATUSEXTRAINFO;
  end;

const
  // Note: we need to declare non-typed constants first, because we cannot use
  // typed constants in constant records.
  // http://stackoverflow.com/questions/2714365/delphi-all-constants-are-constant-but-some-are-more-constant-than-others
  UD2_STATUSAUTH_GENERIC_ = '{90F53368-1EFB-4350-A6BC-725C69938B9C}';
  UD2_STATUSAUTH_GENERIC : UD2_STATUSAUTH = UD2_STATUSAUTH_GENERIC_;

  UD2_STATUSCAT_SUCCESS   = 0;
  UD2_STATUSCAT_NOT_AVAIL = 1;
  UD2_STATUSCAT_FAILED    = 2;

  (* Success codes *)

  UD2_STATUS_OK_UNSPECIFIED: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_SUCCESS;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 0;
    dwExtraInfo: 0
  );
  UD2_STATUS_OK_SINGLELINE: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_SUCCESS;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 1;
    dwExtraInfo: 0
  );
  UD2_STATUS_OK_MULTILINE: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_SUCCESS;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 2;
    dwExtraInfo: 0
  );
  UD2_STATUS_OK_LICENSED: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_SUCCESS;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 3;
    dwExtraInfo: 0
  );

  (* "Not available" codes *)

  UD2_STATUS_NOTAVAIL_UNSPECIFIED: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_NOT_AVAIL;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 0;
    dwExtraInfo: 0
  );
  UD2_STATUS_NOTAVAIL_OS_NOT_SUPPORTED: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_NOT_AVAIL;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 1;
    dwExtraInfo: 0
  );
  UD2_STATUS_NOTAVAIL_HW_NOT_SUPPORTED: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_NOT_AVAIL;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 2;
    dwExtraInfo: 0
  );
  UD2_STATUS_NOTAVAIL_NO_ENTITIES: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_NOT_AVAIL;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 3;
    dwExtraInfo: 0
  );
  UD2_STATUS_NOTAVAIL_WINAPI_CALL_FAILURE: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_NOT_AVAIL;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 4;
    dwExtraInfo: 0
  );

  (* Failure codes *)

  UD2_STATUS_FAILURE_UNSPECIFIED: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_FAILED;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 0;
    dwExtraInfo: 0
  );
  UD2_STATUS_FAILURE_BUFFER_TOO_SMALL: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_FAILED;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 1;
    dwExtraInfo: 0
  );
  UD2_STATUS_FAILURE_INVALID_ARGS: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_FAILED;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 2;
    dwExtraInfo: 0
  );
  UD2_STATUS_FAILURE_PLUGIN_NOT_LICENSED: UD2_STATUS = (
    cbSize: SizeOf(UD2_STATUS);
    bReserved: 0;
    wCategory: UD2_STATUSCAT_FAILED;
    grAuthority: UD2_STATUSAUTH_GENERIC_;
    dwMessage: 3;
    dwExtraInfo: 0
  );

function UD2_STATUS_FormatStatusCode(grStatus: UD2_STATUS): string;
function UD2_STATUS_Equal(grStatus1, grStatus2: UD2_STATUS; compareExtraInfo: boolean): boolean;
function UD2_STATUS_OSError(OSError: DWORD): UD2_STATUS;

implementation

function UD2_STATUS_FormatStatusCode(grStatus: UD2_STATUS): string;
begin
  // 00 0000 {44332211-1234-ABCD-EFEF-001122334455} 00000000 00000000
  result := Format('%.2x %.4x %s %.8x %.8x', [
                grStatus.bReserved,
		grStatus.wCategory,
		GUIDTostring(grStatus.grAuthority),
		grStatus.dwMessage,
		grStatus.dwExtraInfo]);
end;

function UD2_STATUS_Equal(grStatus1, grStatus2: UD2_STATUS; compareExtraInfo: boolean): boolean;
begin
  result := (grStatus1.bReserved = grStatus2.bReserved) and
            (grStatus1.wCategory = grStatus2.wCategory) and
            IsEqualGUID(grStatus1.grAuthority, grStatus2.grAuthority) and
            (grStatus1.dwMessage = grStatus2.dwMessage);
  if compareExtraInfo and (grStatus1.dwExtraInfo <> grStatus2.dwExtraInfo) then result := false;
end;

function UD2_STATUS_OSError(OSError: DWORD): UD2_STATUS;
begin
  result := UD2_STATUS_NOTAVAIL_WINAPI_CALL_FAILURE;
  result.dwExtraInfo := OSError;
end;

end.
