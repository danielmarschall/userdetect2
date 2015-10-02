unit NetworkUtils;

interface

uses
  Windows, SysUtils, Classes;

function GetLocalIPAddressList(outsl: TStrings): DWORD;
function GetLocalMACAddressList(outSL: TStrings): DWORD;
function GetDHCPIPAddressList(outsl: TStrings): DWORD;
function GetGatewayIPAddressList(outsl: TStrings): DWORD;
function GetMACAddress(const IPAddress: string; var outAddress: string): DWORD;
function FormatMAC(s: string): string;

implementation

uses
  iphlp, WinSock;

// TODO: Replace GetAdaptersInfo()? A comment at MSDN states that there might be problems with IPv6
//           "GetAdaptersInfo returns ERROR_NO_DATA if there are only IPv6 interfaces
//            configured on system. In that case GetAdapterAddresses has to be used!"

function GetLocalIPAddressList(outsl: TStrings): DWORD;
var
  pAdapterInfo: PIP_ADAPTER_INFO;
  addr: string;
  addrStr: IP_ADDR_STRING;
  BufLen: Cardinal;
begin
  BufLen := SizeOf(IP_ADAPTER_INFO);
  Result := GetAdaptersInfo(nil, @BufLen);
  if Result <> ERROR_SUCCESS then Exit;
  pAdapterInfo := AllocMem(BufLen);
  try
    Result := GetAdaptersInfo(pAdapterInfo, @BufLen);
    if Result <> ERROR_SUCCESS then Exit;
    while pAdapterInfo <> nil do
    begin
      addrStr := pAdapterInfo^.IpAddressList;
      repeat
        addr := addrStr.IpAddress.S;
        if (addr <> '') and (outsl.IndexOf(addr) = -1) then
          outsl.Add(addr);
        if addrStr.Next = nil then break;
        AddrStr := addrStr.Next^;
      until false;
      pAdapterInfo := pAdapterInfo^.next;
    end;
  finally
    Freemem(pAdapterInfo);
  end;
end;

function GetDHCPIPAddressList(outsl: TStrings): DWORD;
var
  pAdapterInfo: PIP_ADAPTER_INFO;
  addr: string;
  addrStr: IP_ADDR_STRING;
  BufLen: Cardinal;
begin
  BufLen := SizeOf(IP_ADAPTER_INFO);
  Result := GetAdaptersInfo(nil, @BufLen);
  if Result <> ERROR_SUCCESS then Exit;
  pAdapterInfo := AllocMem(BufLen);
  try
    Result := GetAdaptersInfo(pAdapterInfo, @BufLen);
    if Result <> ERROR_SUCCESS then Exit;
    while pAdapterInfo <> nil do
    begin
      addrStr := pAdapterInfo^.DhcpServer;
      repeat
        addr := addrStr.IpAddress.S;
        if (addr <> '') and (outsl.IndexOf(addr) = -1) then
          outsl.Add(addr);
        if addrStr.Next = nil then break;
        AddrStr := addrStr.Next^;
      until false;
      pAdapterInfo := pAdapterInfo^.next;
    end;
  finally
    Freemem(pAdapterInfo);
  end;
end;

function GetGatewayIPAddressList(outsl: TStrings): DWORD;
var
  pAdapterInfo: PIP_ADAPTER_INFO;
  addr: string;
  addrStr: IP_ADDR_STRING;
  BufLen: Cardinal;
begin
  BufLen := SizeOf(IP_ADAPTER_INFO);
  Result := GetAdaptersInfo(nil, @BufLen);
  if Result <> ERROR_SUCCESS then Exit;
  pAdapterInfo := AllocMem(BufLen);
  try
    Result := GetAdaptersInfo(pAdapterInfo, @BufLen);
    if Result <> ERROR_SUCCESS then Exit;
    while pAdapterInfo <> nil do
    begin
      addrStr := pAdapterInfo^.GatewayList;
      repeat
        addr := addrStr.IpAddress.S;
        if (addr <> '') and (outsl.IndexOf(addr) = -1) then
          outsl.Add(addr);
        if addrStr.Next = nil then break;
        AddrStr := addrStr.Next^;
      until false;
      pAdapterInfo := pAdapterInfo^.next;
    end;
  finally
    Freemem(pAdapterInfo);
  end;
end;

function GetMACAddress(const IPAddress: string; var outAddress: string): DWORD;
// http://stackoverflow.com/questions/4550672/delphi-get-mac-of-router
var
  MacAddr    : Array[0..5] of Byte;
  DestIP     : ULONG;
  PhyAddrLen : ULONG;
  WSAData    : TWSAData;
  j: integer;
begin
  outAddress := '';
  WSAStartup($0101, WSAData);
  try
    ZeroMemory(@MacAddr, SizeOf(MacAddr));
    DestIP     := inet_addr(PAnsiChar(IPAddress));
    PhyAddrLen := SizeOf(MacAddr); // TODO: more ?
    Result     := SendArp(DestIP, 0, @MacAddr, @PhyAddrLen);
    if Result = S_OK then
    begin
      outAddress := '';
      for j := 0 to PhyAddrLen-1 do
      begin
        outAddress := outAddress + format('%.2x', [MacAddr[j]]);
      end;
      outAddress := FormatMAC(outAddress);
    end;
  finally
    WSACleanup;
  end;
end;

function GetLocalMACAddressList(outSL: TStrings): DWORD;
const
  _MAX_ROWS_ = 100;
type
  _IfTable = Record
    nRows: LongInt;
    ifRow: Array[1.._MAX_ROWS_] of MIB_IFROW;
  end;
var
  pIfTable: ^_IfTable;
  TableSize: LongInt;
  tmp: String;
  i, j: Integer;
begin
  pIfTable := nil;
  try
    // First: just get the buffer size.
    // TableSize returns the size needed.
    TableSize := 0; // Set to zero so the GetIfTabel function
    // won't try to fill the buffer yet,
    // but only return the actual size it needs.
    GetIfTable(pIfTable, TableSize, 1);
    if (TableSize < SizeOf(MIB_IFROW)+SizeOf(LongInt)) then
    begin
      Result := ERROR_NO_DATA;
      Exit; // less than 1 table entry?!
    end;

    // Second:
    // allocate memory for the buffer and retrieve the
    // entire table.
    GetMem(pIfTable, TableSize);
    Result := GetIfTable(pIfTable, TableSize, 1);
    if Result <> NO_ERROR then Exit;

    // Read the ETHERNET addresses.
    for i := 1 to pIfTable^.nRows do
    begin
      //if pIfTable^.ifRow[i].dwType=MIB_IF_TYPE_ETHERNET then
      begin
        tmp := '';
        for j := 0 to pIfTable^.ifRow[i].dwPhysAddrLen-1 do
        begin
          tmp := tmp + format('%.2x', [pIfTable^.ifRow[i].bPhysAddr[j]]);
        end;
        tmp := FormatMAC(tmp);
        if (tmp <> '') and (outSL.IndexOf(tmp) = -1) then
          outSL.Add(tmp);
      end;
    end;
  finally
    if Assigned(pIfTable) then FreeMem(pIfTable, TableSize);
  end;
end;

function FormatMAC(s: string): string;
var
  m: integer;
begin
  result := '';
  m := 1;
  s := UpperCase(s);
  repeat
    if m > 1 then result := result + '-';
    result := result + Copy(s, m, 2);
    inc(m, 2);
  until m > Length(s);
end;

end.
