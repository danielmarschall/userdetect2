unit PatchU;

{$WARN UNSAFE_CODE OFF}
{$WARN UNSAFE_TYPE OFF}

interface

type
  pPatchEvent = ^TPatchEvent;

  // "Asm" opcode hack to patch an existing routine
  TPatchEvent = packed record
    Jump: Byte;
    Offset: Integer;
  end;

  TPatchMethod = class
  private
    PatchedMethod, OriginalMethod: TPatchEvent;
    PatchPositionMethod: pPatchEvent;
    FIsPatched: boolean;
  public
    property IsPatched: boolean read FIsPatched;
    constructor Create(const aSource, aDestination: Pointer);
    destructor Destroy; override;
    procedure Restore;
    procedure Hook;
  end;

implementation

uses
  Windows, Sysutils;

{ TPatchMethod }

constructor TPatchMethod.Create(const aSource, aDestination: Pointer);
var
  OldProtect: Cardinal;
begin
  PatchPositionMethod := pPatchEvent(aSource);
  OriginalMethod := PatchPositionMethod^;
  PatchedMethod.Jump := $E9;
  PatchedMethod.Offset := Integer(PByte(aDestination)) - Integer(PByte(PatchPositionMethod)) - SizeOf(TPatchEvent);

  if not VirtualProtect(PatchPositionMethod, SizeOf(TPatchEvent), PAGE_EXECUTE_READWRITE, OldProtect) then
    RaiseLastOSError;

  Hook;
end;

destructor TPatchMethod.Destroy;
begin
  Restore;
  inherited;
end;

procedure TPatchMethod.Hook;
begin
  if FIsPatched then Exit;
  FIsPatched := true;
  PatchPositionMethod^ := PatchedMethod;
end;

procedure TPatchMethod.Restore;
begin
  if not FIsPatched then Exit;
  FIsPatched := false;
  PatchPositionMethod^ := OriginalMethod;
end;

end.

