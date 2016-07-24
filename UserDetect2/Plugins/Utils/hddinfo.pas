// http://stackoverflow.com/questions/5202270/in-delphi7-how-can-i-retrieve-hard-disk-unique-serial-number

unit hddinfo;

interface

function GetDiskSerial(const Drive:AnsiChar):string;

implementation

uses
  SysUtils,
  ActiveX,
  ComObj,
  Variants;

function GetDiskSerial(const Drive:AnsiChar):string;
var
  FSWbemLocator  : OLEVariant;
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
  objWMIService := FSWbemLocator.ConnectServer('localhost', 'root\CIMV2', '', ''); //Connect to the WMI
  colDiskDrives := objWMIService.ExecQuery('SELECT * FROM Win32_DiskDrive','WQL',0);
  oEnumDiskDrive:= IUnknown(colDiskDrives._NewEnum) as IEnumVariant;
  while oEnumDiskDrive.Next(1, objDiskDrive, iValue) = 0 do
  begin
   DeviceID        := StringReplace(objDiskDrive.DeviceID,'\','\\',[rfReplaceAll]); //Escape the `\` chars in the DeviceID value because the '\' is a reserved character in WMI.
   colPartitions   := objWMIService.ExecQuery(Format('ASSOCIATORS OF {Win32_DiskDrive.DeviceID="%s"} WHERE AssocClass = Win32_DiskDriveToDiskPartition',[DeviceID]));//link the Win32_DiskDrive class with the Win32_DiskDriveToDiskPartition class
   oEnumPartition  := IUnknown(colPartitions._NewEnum) as IEnumVariant;
    while oEnumPartition.Next(1, objPartition, iValue) = 0 do
     begin
        colLogicalDisks := objWMIService.ExecQuery('ASSOCIATORS OF {Win32_DiskPartition.DeviceID="'+objPartition.DeviceID+'"} WHERE AssocClass = Win32_LogicalDiskToPartition'); //link the Win32_DiskPartition class with theWin32_LogicalDiskToPartition class.
        oEnumLogical  := IUnknown(colLogicalDisks._NewEnum) as IEnumVariant;
          while oEnumLogical.Next(1, objLogicalDisk, iValue) = 0 do
          begin
            if objLogicalDisk.DeviceID=(Drive+':')  then //compare the device id
            begin
                Result:=objDiskDrive.SerialNumber;
                Exit;
            end;
           objLogicalDisk:=Unassigned;
          end;
        objPartition:=Unassigned;
     end;
  end;
end;

end.
