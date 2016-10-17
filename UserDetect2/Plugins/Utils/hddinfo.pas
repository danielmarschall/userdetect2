// http://stackoverflow.com/questions/5202270/in-delphi7-how-can-i-retrieve-hard-disk-unique-serial-number

unit hddinfo;

interface

function GetDriveSerial(const Drive: AnsiChar):string;

implementation

uses
  SysUtils,
  StrUtils,
  ActiveX,
  ComObj,
  Variants;

// http://stackoverflow.com/questions/4292395/how-to-get-manufacturer-serial-number-of-an-usb-flash-drive
// Modified

function VarArrayToStr(const vArray: variant): string;

    function _VarToStr(const V: variant): string;
    var
    Vt: integer;
    begin
    Vt := VarType(V);
        case Vt of
          varSmallint,
          varInteger  : Result := IntToStr(integer(V));
          varSingle,
          varDouble,
          varCurrency : Result := FloatToStr(Double(V));
          varDate     : Result := VarToStr(V);
          varOleStr   : Result := WideString(V);
          varBoolean  : Result := VarToStr(V);
          varVariant  : Result := VarToStr(Variant(V));
          varByte     : Result := char(byte(V));
          varString   : Result := String(V);
          varArray    : Result := VarArrayToStr(Variant(V));
        end;
    end;

var
  i : integer;
begin
    Result := '[';
     if (VarType(vArray) and VarArray)=0 then
       Result := _VarToStr(vArray)
    else
    for i := VarArrayLowBound(vArray, 1) to VarArrayHighBound(vArray, 1) do
     if i=VarArrayLowBound(vArray, 1)  then
      Result := Result+_VarToStr(vArray[i])
     else
      Result := Result+'|'+_VarToStr(vArray[i]);

    Result:=Result+']';
end;

function VarStrNull(const V:OleVariant):string; //avoid problems with null strings
begin
  Result := '';
  if not VarIsNull(V) then
  begin
    Result := VarToStr(V);
  end;
end;

function GetWMIObject(const objectName: String): IDispatch; //create the Wmi instance
var
  chEaten: Integer;
  BindCtx: IBindCtx;
  Moniker: IMoniker;
begin
  OleCheck(CreateBindCtx(0, bindCtx));
  OleCheck(MkParseDisplayName(BindCtx, StringToOleStr(objectName), chEaten, Moniker));
  OleCheck(Moniker.BindToObject(BindCtx, nil, IDispatch, Result));
end;

function GetDriveSerial(const Drive:AnsiChar):string;
var
  FSWbemLocator  : OleVariant;
  objWMIService  : OLEVariant;
  colDiskDrives  : OLEVariant;
  colLogicalDisks: OLEVariant;
  colPartitions  : OLEVariant;
  objDiskDrive   : OLEVariant;
  objPartition   : OLEVariant;
  objLogicalDisk : OLEVariant;
  oEnumDiskDrive : IEnumvariant;
  oEnumPartition : IEnumvariant;
  oEnumLogical   : IEnumvariant;
  iValue         : LongWord;
  DeviceID       : string;
begin;
  Result:='';
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  objWMIService := FSWbemLocator.ConnectServer('.', 'root\CIMV2', '', '');
  colDiskDrives := objWMIService.ExecQuery('SELECT * FROM Win32_DiskDrive','WQL',0);
  oEnumDiskDrive:= IUnknown(colDiskDrives._NewEnum) as IEnumVariant;
  while oEnumDiskDrive.Next(1, objDiskDrive, iValue) = 0 do
  begin
     DeviceID        := StringReplace(VarStrNull(objDiskDrive.DeviceID),'\','\\',[rfReplaceAll]); //Escape the `\` chars in the DeviceID value because the '\' is a reserved character in WMI.
     colPartitions   := objWMIService.ExecQuery(Format('ASSOCIATORS OF {Win32_DiskDrive.DeviceID="%s"} WHERE AssocClass = Win32_DiskDriveToDiskPartition',[DeviceID]));//link the Win32_DiskDrive class with the Win32_DiskDriveToDiskPartition class
     oEnumPartition  := IUnknown(colPartitions._NewEnum) as IEnumVariant;
      while oEnumPartition.Next(1, objPartition, iValue) = 0 do
       begin
        colLogicalDisks := objWMIService.ExecQuery('ASSOCIATORS OF {Win32_DiskPartition.DeviceID="'+VarStrNull(objPartition.DeviceID)+'"} WHERE AssocClass = Win32_LogicalDiskToPartition'); //link the Win32_DiskPartition class with theWin32_LogicalDiskToPartition class.
        oEnumLogical  := IUnknown(colLogicalDisks._NewEnum) as IEnumVariant;
          while oEnumLogical.Next(1, objLogicalDisk, iValue) = 0 do
          begin
            if  SameText(VarStrNull(objLogicalDisk.DeviceID),Drive+':')  then //compare the device id
            begin
              Result := objDiskDrive.SerialNumber;
              if Result <> '' then exit;

              // Some drivers of the USB disks does not expose the manufacturer serial number on the Win32_DiskDrive.SerialNumber property, so on this cases we can extract the serial number from the PnPDeviceID property.
              Result:=VarStrNull(objDiskDrive.PnPDeviceID);
              if AnsiStartsText('USBSTOR', Result) then
              begin
               iValue:=LastDelimiter('\', Result);
                Result:=Copy(Result, iValue+1, Length(Result));
              end;
              objLogicalDisk:=Unassigned;
              Exit;
            end;
            objLogicalDisk:=Unassigned;
          end;
          objPartition:=Unassigned;
       end;
       objDiskDrive:=Unassigned;
  end;
end;

initialization
  CoInitialize(nil);
finalization
  CoUninitialize;
end.
