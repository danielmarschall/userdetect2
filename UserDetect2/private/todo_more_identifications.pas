unit todo_more_identifications;

interface

function IsConnected: boolean;
function GetHostname: string;
function GetComputerName: String;
function GetUserName: String;
function GetSystemWinDir: string;
function GetSystemDrive: AnsiChar;
function GetOSVersion: string;
function GetRegisteredOrganisation: string;
function GetRegisteredOwner: string;
function LaufwerkBereit(root: string): boolean;
function GetMyDocuments: string;
function GetLocalAppData: string;
function GetWindowsDirectory: string;
// function GetWifiSSID: string;
function GetTempDirectory: String;

implementation

uses
  Windows, SysUtils, Registry, wininet, shlobj;

type
  EAPICallError = Exception;

function IsConnected: boolean;
{$IF defined(ANDROID)}
begin
  result := IsConnectedAndroid;
end;
{$ELSEIF defined(MACOS)}
//var
  //IPW: TIdHTTP;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := false;  // TODO: im zweifelsfall lieber true?

  // head verzögert den Programmfluss um 1-2 Sekunden...
  // Ip-Watch würde auch eine LAN-Adresse zeigen
  //TIdHTTP.Head('http://registration.rinntech.com');
  //response.code=200 -> true
end;
{$ELSEIF defined(MSWINDOWS)}
var
  origin: Cardinal;
begin
  result := InternetGetConnectedState(@origin, 0);
end;
{$ELSE}
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := false;
end;
{$IFEND}

var CacheHostname: string;
{$IFDEF MSWindows}
function GetHostname: string;
var
  reg: TRegistry;
begin
  if CacheHostname <> '' then
  begin
    result := CacheHostname;
    Exit;
  end;
  result := '';
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    if reg.OpenKeyReadOnly
      ('\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters') then
    begin
      result := reg.ReadString('Hostname');
      reg.CloseKey;
    end;
  finally
    reg.Free;
  end;
  CacheHostname := result;
end;
{$ELSE}
function GetHostname: string;
{$IFDEF MACOS}
var
  buff: array [0 .. 255] of AnsiChar;
{$ENDIF}
begin
  if CacheHostname <> '' then
  begin
    result := CacheHostname;
    Exit;
  end;
  {$IFDEF MACOS}
  Posix.Unistd.gethostname(buff,sizeof(buff));
  SetString(result, buff, AnsiStrings.strlen(buff));
  CacheHostname := result;
  {$ELSE}
    {$IFDEF ANDROID}
    result := '';
    {$ELSE}
    {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
    {$ENDIF}
  {$ENDIF}
end;
{$ENDIF}

{$IFDEF MSWindows}
function GetComputerName: String;
var
  buffer: array [0 .. MAX_PATH] of Char;
  Size: dWord;
begin
  Size := SizeOf(buffer);
  Windows.GetComputerName(buffer, Size);
  SetString(result, buffer, lstrlen(buffer));
end;
{$ELSE}
function GetComputerName: String;
{$IFDEF MACOS}
var
  Pool: NSAutoreleasePool;
  h : NSHost;
{$ENDIF}
begin
  {$IFDEF MACOS}
  NSDefaultRunLoopMode;
  Pool := TNSAutoreleasePool.Create;
    try
    h := TNSHost.Wrap(TNSHost.OCClass.currentHost);
    result := Format('%s',[h.localizedName.UTF8String]);
  finally
    Pool.drain;
  end;
  {$ELSE}
    {$IFDEF ANDROID}
    //TODO: anderer/richtiger name ... AccountManager for email adress, Telephony mngr etc.
    result := JStringToString(TJBuild.JavaClass.SERIAL);
    {$ELSE}
    {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
    result := '';
    {$ENDIF}
  {$ENDIF}
end;
{$ENDIF}

{$IFDEF MACOS}
function NSUserName: Pointer; cdecl; external '/System/Library/Frameworks/Foundation.framework/Foundation' name _PU +'NSUserName';
function NSFullUserName: Pointer; cdecl; external '/System/Library/Frameworks/Foundation.framework/Foundation' name _PU + 'NSFullUserName';
{$ENDIF}

{$IFDEF MSWindows}
function GetUserName: String;
var
  buffer: array [0 .. MAX_PATH] of Char;
  Size: dWord;
begin
  Size := SizeOf(buffer);

  if Windows.GetUserName(Buffer, Size) then
  begin
    // SetString(result, buffer, lstrlen(buffer));
    Result := StrPas(Buffer);
  end
  else
  begin
    Result := '';
  end;
end;
{$ELSE}
function GetUserName: String;
begin
  {$IFDEF MACOS}
  result := Format('%s',[TNSString.Wrap(NSUserName).UTF8String]);
  {$ELSE}
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := '';
  {$ENDIF}
end;
{$ENDIF}







{$IFDEF MSWindows}
function GetSystemWinDir: string;
var
  h: HModule;
  {$IFDEF UNICODE}
  f: function(lpBuffer: LPWSTR; uSize: UINT): UINT; stdcall;
  {$ELSE}
  f: function(lpBuffer: LPSTR; uSize: UINT): UINT; stdcall;
  {$ENDIF}
  res: string;
  cnt: UINT;
begin
  h := LoadLibrary(kernel32);
  if h = 0 then RaiseLastOSError;

  {$IFDEF UNICODE}
  @f := GetProcAddress(h, 'GetSystemWindowsDirectoryW');
  {$ELSE}
  @f := GetProcAddress(h, 'GetSystemWindowsDirectoryA');
  {$ENDIF}

  SetLength(res, MAX_PATH);
  if @f = nil then  // Assigned?
  begin
    // We are probably on Win9x where GetSystemWindowsDirectory* does not exist.
    cnt := Windows.GetWindowsDirectory(PChar(res), MAX_PATH);
  end
  else
  begin
    // We are on a modern system where GetSystemWindowsDirectory* does exist.
    // http://objectmix.com/delphi/402836-getting-hard-drive-letter-windows-runs.html
    // Im Gegensatz zu GetWindowsDirectory zeigt GetSystemWindowsDirectory bei
    // Terminalservern das System-Windows-Verzeichnis und nicht das "private"
    // Windows-Verzeichnis des Users.
    cnt := f(PChar(res), MAX_PATH);
  end;

  if cnt <= 0 then RaiseLastOSError;
  result := res;
end;
{$ELSE}
function GetSystemWinDir: string;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := '';
end;
{$ENDIF}

function GetSystemDrive: AnsiChar;
var
  res: string;
begin
  res := ExtractFileDrive(GetSystemWinDir);
  Assert(Length(res) >= 1);
  result := AnsiChar(res[1]);
end;

function GetOSVersion: string;
{$IF Declared(TOSVersion)}
begin
  result := TOSVersion.ToString;
{$ELSE}
var
  VersionInfo: TOSVersionInfo;
begin
  VersionInfo.dwOSVersionInfoSize := SizeOf(VersionInfo);
  GetVersionEx(VersionInfo);
  result := IntToStr(VersionInfo.dwPlatformId) + '-' +
    IntToStr(VersionInfo.dwMajorVersion) + '.' +
    IntToStr(VersionInfo.dwMinorVersion) + '-' +
    IntToStr(VersionInfo.dwBuildNumber)
{$IFEND}
end;

{$IFDEF MSWindows}
function GetRegisteredOrganisation: string;
var
  reg: TRegistry;
  k: string;
  VersionInfo: TOSVersionInfo;
begin
  result := '';
  reg := TRegistry.Create;
  try
    reg.rootkey := HKEY_LOCAL_MACHINE;

    VersionInfo.dwOSVersionInfoSize := SizeOf(VersionInfo);
    GetVersionEx(VersionInfo);

    if VersionInfo.dwPlatformId = VER_PLATFORM_WIN32_NT then
    begin
      k := '\Software\Microsoft\Windows NT\CurrentVersion';
    end
    else
    begin
      k := '\Software\Microsoft\Windows\CurrentVersion';
    end;
    if reg.OpenKeyReadOnly(k) then
    begin
      result := reg.ReadString('RegisteredOrganization');
      reg.CloseKey;
    end;
  finally
    reg.Free;
  end;
end;
{$ELSE}
function GetRegisteredOrganisation: string;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := '';
end;
{$ENDIF}

{$IFDEF MSWindows}
function GetRegisteredOwner: string;
var
  reg: TRegistry;
  k: string;
  VersionInfo: TOSVersionInfo;
begin
  result := '';
  reg := TRegistry.Create;
  try
    reg.rootkey := HKEY_LOCAL_MACHINE;

    VersionInfo.dwOSVersionInfoSize := SizeOf(VersionInfo);
    GetVersionEx(VersionInfo);

    if VersionInfo.dwPlatformId = VER_PLATFORM_WIN32_NT then
    begin
      k := '\Software\Microsoft\Windows NT\CurrentVersion';
    end
    else
    begin
      k := '\Software\Microsoft\Windows\CurrentVersion';
    end;
    if reg.OpenKeyReadOnly(k) then
    begin
      result := reg.ReadString('RegisteredOwner');
      reg.CloseKey;
    end;
  finally
    reg.Free;
  end;
end;
{$ELSE}
function GetRegisteredOwner: string;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := '';
end;
{$ENDIF}

{$IFDEF MSWindows}
function LaufwerkBereit(root: string): boolean;
var
  Oem: cardinal;
  Dw1, Dw2: DWORD;
begin
  // http://www.delphi-treff.de/tipps/system/hardware/feststellen-ob-ein-laufwerk-bereit-ist/
  Oem := SetErrorMode(SEM_FAILCRITICALERRORS);
  result := GetVolumeInformation(PCHAR(Root), nil, 0, nil, Dw1, Dw2, nil, 0);
  SetErrorMode(Oem) ;
end;
{$ELSE}
function LaufwerkBereit(root: string): boolean;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := false;
end;
{$ENDIF}

{$IFDEF MSWindows}
function GetMyDocuments: string;
var
  r: Bool;
  path: array[0..Max_Path] of Char;
begin
  // TODO: Stattdessen ShGetFolderPath verwenden?
  r := ShGetSpecialFolderPath(0, path, CSIDL_Personal, False);
  if not r then
    raise EAPICallError.Create('Could not find MyDocuments folder location.');
  Result := Path;
end;
{$ELSE}
function GetMyDocuments: string;
begin
  result := TPath.GetDocumentsPath;
end;
{$ENDIF}

{$IF not Defined(CSIDL_LOCAL_APPDATA)}
const
  CSIDL_LOCAL_APPDATA = $001c;
{$IFEND}

{$IFDEF MSWindows}
function GetLocalAppData: string;
var
  r: Bool;
  path: array[0..Max_Path] of Char;
begin
  // TODO: Stattdessen ShGetFolderPath verwenden?
  r := ShGetSpecialFolderPath(0, path, CSIDL_LOCAL_APPDATA, False);
  if not r then
    raise EAPICallError.Create('Could not find LocalAppData folder location.');
  Result := Path;
end;
{$ELSE}
function GetLocalAppData: string;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := '';
end;
{$ENDIF}

{$IFDEF MSWindows}
function GetWindowsDirectory: string;
var
  WinDir: PChar;
begin
  WinDir := StrAlloc(MAX_PATH);
  try
    Windows.GetWindowsDirectory(WinDir, MAX_PATH);
    result := string(WinDir);
  finally
    StrDispose(WinDir);
  end;
end;
{$ELSE}
function GetWindowsDirectory: string;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := '';
end;
{$ENDIF}

{$IFDEF MSWindows}
function GetTempDirectory: String;
var
  tempFolder: array [0 .. MAX_PATH] of Char;
begin
  GetTempPath(MAX_PATH, @tempFolder);
  result := StrPas(tempFolder);
end;
{$ELSE}
function GetTempDirectory: String;
begin
  {$MESSAGE Warn 'Nicht implementiert für dieses OS'}
  result := '';
end;
{$ENDIF}

end.
