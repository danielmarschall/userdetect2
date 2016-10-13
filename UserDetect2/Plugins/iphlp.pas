unit iphlp;

interface

uses
  Windows;

const
  MAX_INTERFACE_NAME_LEN = $100;
  ERROR_SUCCESS = 0;
  MAXLEN_IFDESCR = $100;
  MAXLEN_PHYSADDR = 8;

  MIB_IF_OPER_STATUS_NON_OPERATIONAL = 0 ;
  MIB_IF_OPER_STATUS_UNREACHABLE = 1;
  MIB_IF_OPER_STATUS_DISCONNECTED = 2;
  MIB_IF_OPER_STATUS_CONNECTING = 3;
  MIB_IF_OPER_STATUS_CONNECTED = 4;
  MIB_IF_OPER_STATUS_OPERATIONAL = 5;

  MIB_IF_TYPE_OTHER = 1;
  MIB_IF_TYPE_ETHERNET = 6;
  MIB_IF_TYPE_TOKENRING = 9;
  MIB_IF_TYPE_FDDI = 15;
  MIB_IF_TYPE_PPP = 23;
  MIB_IF_TYPE_LOOPBACK = 24;
  MIB_IF_TYPE_SLIP = 28;

  MIB_IF_ADMIN_STATUS_UP = 1;
  MIB_IF_ADMIN_STATUS_DOWN = 2;
  MIB_IF_ADMIN_STATUS_TESTING = 3;

type
  MIB_IFROW = packed record
    wszName: Array[0 .. (MAX_INTERFACE_NAME_LEN*2-1)] of AnsiChar;
    dwIndex: LongInt;
    dwType: LongInt;
    dwMtu: LongInt;
    dwSpeed: LongInt;
    dwPhysAddrLen: LongInt;
    bPhysAddr: Array[0 .. (MAXLEN_PHYSADDR-1)] of Byte;
    dwAdminStatus: LongInt;
    dwOperStatus: LongInt;
    dwLastChange: LongInt;
    dwInOctets: LongInt;
    dwInUcastPkts: LongInt;
    dwInNUcastPkts: LongInt;
    dwInDiscards: LongInt;
    dwInErrors: LongInt;
    dwInUnknownProtos: LongInt;
    dwOutOctets: LongInt;
    dwOutUcastPkts: LongInt;
    dwOutNUcastPkts: LongInt;
    dwOutDiscards: LongInt;
    dwOutErrors: LongInt;
    dwOutQLen: LongInt;
    dwDescrLen: LongInt;
    bDescr: Array[0 .. (MAXLEN_IFDESCR - 1)] of AnsiChar;
  end;

const
  MAX_HOSTNAME_LEN    = 128;
  MAX_DOMAIN_NAME_LEN = 128;
  MAX_SCOPE_ID_LEN    = 256;

  MAX_ADAPTER_NAME_LENGTH        = 256;
  MAX_ADAPTER_DESCRIPTION_LENGTH = 128;
  MAX_ADAPTER_ADDRESS_LENGTH     = 8;

  IPHelper = 'iphlpapi.dll';

type
  PIPAddressString = ^TIPAddressString;
  PIPMaskString    = ^TIPAddressString;
  TIPAddressString = packed record
    _String: array[0..(4 * 4) - 1] of AnsiChar;
  end;
  TIPMaskString = TIPAddressString;
  PIPAddrString = ^TIPAddrString;
  TIPAddrString = packed record
    Next: PIPAddrString;
    IpAddress: TIPAddressString;
    IpMask: TIPMaskString;
    Context: DWORD;
  end;
  PFixedInfo = ^TFixedInfo;
  TFixedInfo = packed record
    HostName: array[0..MAX_HOSTNAME_LEN + 4 - 1] of AnsiChar;
    DomainName: array[0..MAX_DOMAIN_NAME_LEN + 4 - 1] of AnsiChar;
    CurrentDnsServer: PIPAddrString;
    DnsServerList: TIPAddrString;
    NodeType: UINT;
    ScopeId: array[0..MAX_SCOPE_ID_LEN + 4 - 1] of AnsiChar;
    EnableRouting,
    EnableProxy,
    EnableDns: UINT;
  end;

  IP_ADDRESS_STRING = packed record
    S: array [0..15] of AnsiChar;
  end;
  IP_MASK_STRING = IP_ADDRESS_STRING;
  PIP_MASK_STRING = ^IP_MASK_STRING;

  PIP_ADDR_STRING = ^IP_ADDR_STRING;
  IP_ADDR_STRING = packed record
    Next: PIP_ADDR_STRING;
    IpAddress: IP_ADDRESS_STRING;
    IpMask: IP_MASK_STRING;
    Context: DWORD;
  end;

  PIP_ADAPTER_INFO = ^IP_ADAPTER_INFO;
  IP_ADAPTER_INFO = packed record
    Next: PIP_ADAPTER_INFO;
    ComboIndex: DWORD;
    AdapterName: array [0..MAX_ADAPTER_NAME_LENGTH + 3] of AnsiChar;
    Description: array [0..MAX_ADAPTER_DESCRIPTION_LENGTH + 3] of AnsiChar;
    AddressLength: UINT;
    Address: array [0..MAX_ADAPTER_ADDRESS_LENGTH - 1] of BYTE;
    Index: DWORD;
    Type_: UINT;
    DhcpEnabled: UINT;
    CurrentIpAddress: PIP_ADDR_STRING;
    IpAddressList: IP_ADDR_STRING;
    GatewayList: IP_ADDR_STRING;
    DhcpServer: IP_ADDR_STRING;
    HaveWins: BOOL;
    PrimaryWinsServer: IP_ADDR_STRING;
    SecondaryWinsServer: IP_ADDR_STRING;
    LeaseObtained: Cardinal;
    LeaseExpires: Cardinal;
  end;

const
  ANY_SIZE = 1;
  {$EXTERNALSYM ANY_SIZE}

type
  PMIB_IFTABLE = ^MIB_IFTABLE;
  {$EXTERNALSYM PMIB_IFTABLE}
  _MIB_IFTABLE = record
    dwNumEntries: DWORD;
    table: array [0..ANY_SIZE - 1] of MIB_IFROW;
  end;
  {$EXTERNALSYM _MIB_IFTABLE}
  MIB_IFTABLE = _MIB_IFTABLE;
  {$EXTERNALSYM MIB_IFTABLE}
  TMibIftable = MIB_IFTABLE;
  PMibIftable = PMIB_IFTABLE;

function GetAdaptersInfo(pAdapterInfo: PIP_ADAPTER_INFO; var pOutBufLen: {P}ULONG): DWORD; stdcall;
function GetNetworkParams(pFixedInfo: PFixedInfo; var pOutBufLen: {P}ULONG): DWORD; stdcall;
function SendArp(DestIP, SrcIP: {IPAddr}Cardinal; pMacAddr: PULONG; var PhyAddrLen: {P}ULONG) : DWORD; stdcall;
function GetIfTable(pIfTable: PMIB_IFTABLE; var pdwSize: {P}ULONG; bOrder: BOOL): DWORD; stdcall;

implementation

function GetAdaptersInfo; external IPHelper Name 'GetAdaptersInfo';
function GetNetworkParams; external IPHelper Name 'GetNetworkParams';
function SendArp; external IPHelper name 'SendARP';
function GetIfTable; external IPHelper Name 'GetIfTable';

end.

