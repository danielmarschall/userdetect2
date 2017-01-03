unit VTSCompat;

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

interface

uses
  Dialogs, Windows, Controls, Graphics, SysUtils, CommDlg, Classes;

function AddTransparentIconToImageList(ImageList: TImageList; Icon: TIcon; DoGreyscale: boolean=False): integer;
function CompatOpenDialogExecute(OpenDialog: TOpenDialog): boolean;
function CompatSaveDialogExecute(SaveDialog: TSaveDialog): boolean;

function ToGray(PixelColor: Longint): Longint;

implementation

uses
  PatchU, ShlObj, ShellAPI;

var
  pp: TPatchMethod;

// --- CompatOpenDialogExecute

type
  TExtOpenDialogAccessor = class(TOpenDialog);

  TExtOpenDialog = class(TOpenDialog)
  protected
    function TaskModalDialog(DialogFunc: Pointer; var DialogData): Bool; override;
  end;

function TExtOpenDialog.TaskModalDialog(DialogFunc: Pointer; var DialogData): Bool;
begin
  TOpenFileName(DialogData).Flags :=
  TOpenFileName(DialogData).Flags and not OFN_ENABLETEMPLATE;

  TOpenFileName(DialogData).Flags :=
  TOpenFileName(DialogData).Flags and not OFN_ENABLEHOOK;

  if pp.IsPatched then pp.Restore;

  result := inherited TaskModalDialog(DialogFunc, DialogData);
end;

function CompatOpenDialogExecute(OpenDialog: TOpenDialog): boolean;
{$IF CompilerVersion < 18.5} // prior to Delphi 2007
var
  x: TExtOpenDialog;
  MethodPtr, MethodPtr2: function(DialogFunc: Pointer; var DialogData): Bool of object;
begin
  MethodPtr := TExtOpenDialogAccessor(OpenDialog).TaskModalDialog;

  x := TExtOpenDialog.Create(nil);
  try
    MethodPtr2 := x.TaskModalDialog;
    pp := TPatchMethod.Create(@MethodPtr, @MethodPtr2);
    try
      result := OpenDialog.Execute;
      if pp.IsPatched then pp.Restore;
    finally
      pp.Free;
    end;
  finally
    x.Free;
  end;
{$ELSE}
begin
  result := OpenDialog.Execute;
{$IFEND}
end;

// --- CompatSaveDialogExecute

type
  TExtSaveDialogAccessor = class(TSaveDialog);

  TExtSaveDialog = class(TSaveDialog)
  protected
    function TaskModalDialog(DialogFunc: Pointer; var DialogData): Bool; override;
  end;

function TExtSaveDialog.TaskModalDialog(DialogFunc: Pointer; var DialogData): Bool;
begin
  // Remove the two flags which let the File Dialog GUI fall back to the old design.
  TOpenFileName(DialogData).Flags :=
  TOpenFileName(DialogData).Flags and not OFN_ENABLETEMPLATE;

  TOpenFileName(DialogData).Flags :=
  TOpenFileName(DialogData).Flags and not OFN_ENABLEHOOK;

  // It is important to restore TaskModalDialog, so we don't get a stack
  // overflow when calling the inherited method.
  if pp.IsPatched then pp.Restore;

  result := inherited TaskModalDialog(DialogFunc, DialogData);
end;

function CompatSaveDialogExecute(SaveDialog: TSaveDialog): boolean;
{$IF CompilerVersion < 18.5} // prior to Delphi 2007
var
  x: TExtSaveDialog;
  MethodPtr, MethodPtr2: function(DialogFunc: Pointer; var DialogData): Bool of object;
begin
  MethodPtr := TExtSaveDialogAccessor(SaveDialog).TaskModalDialog;

  x := TExtSaveDialog.Create(nil);
  try
    MethodPtr2 := x.TaskModalDialog;
    pp := TPatchMethod.Create(@MethodPtr, @MethodPtr2);
    try
      result := SaveDialog.Execute;
    finally
      pp.Free;
    end;
  finally
    x.Free;
  end;
{$ELSE}
begin
  result := SaveDialog.Execute;
{$IFEND}
end;

// --- AddTransparentIconToImageList

function RealIconSize(H: HIcon): TPoint;
// http://www.delphipages.com/forum/showthread.php?t=183999
var
  IconInfo: TIconInfo;
  bmpmask: TBitmap;
begin
  result := Point(0, 0);

  if H <> 0 then
  begin
    bmpmask := TBitmap.Create;
    try
      IconInfo.fIcon := true;
      try
        GetIconInfo(H, IconInfo);
        bmpmask.Handle := IconInfo.hbmMask;
        bmpmask.Dormant; //lets us free the resource without 'losing' the bitmap
      finally
        DeleteObject(IconInfo.hbmMask);
        DeleteObject(IconInfo.hbmColor)
      end;
      result := Point(bmpmask.Width, bmpmask.Height);
    finally
      bmpmask.Free;
    end;
  end;
end;

function ToGray(PixelColor: Longint): Longint;
var
  Red, Green, Blue, Gray: Byte;
begin
  Red    := PixelColor;
  Green  := PixelColor shr 8;
  Blue   := PixelColor shr 16;
  Gray   := Round(0.299 * Red + 0.587 * Green + 0.114 * Blue);
  result := Gray + Gray shl 8 + Gray shl 16;
end;

function AddTransparentIconToImageList(ImageList: TImageList; Icon: TIcon; DoGreyscale: boolean=False): integer;
// http://www.delphipages.com/forum/showthread.php?t=183999
var
  buffer, mask: TBitmap;
  p: TPoint;
  x, y: integer;
begin
  // result := ImageList.AddIcon(ico);
  // --> In Delphi 6, Icons with half-transparency have a black border (e.g. in ListView)

  p := RealIconSize(icon.handle);

  buffer := TBitmap.Create;
  mask := TBitmap.Create;
  try
    buffer.PixelFormat := pf24bit;
    mask.PixelFormat := pf24bit;

    buffer.Width := p.X;
    buffer.Height := p.Y;
    buffer.Canvas.Draw(0, 0, icon);
    buffer.Transparent := true;
    buffer.TransparentColor := buffer.Canvas.Pixels[0,0];

    if (ImageList.Width <> p.X) or (ImageList.Height <> p.Y) then
    begin
      ImageList.Width := p.X;
      ImageList.Height := p.Y;
    end;

    // create a mask for the icon.
    mask.Assign(buffer);
    mask.Canvas.Brush.Color := buffer.Canvas.Pixels[0, buffer.Height -1];
    mask.Monochrome := true;

    if DoGreyscale then
    begin
      for x := 0 to buffer.Width - 1 do
      begin
        for y := 0 to buffer.Height - 1 do
        begin
          buffer.Canvas.Pixels[x, y] := ToGray(buffer.Canvas.Pixels[x, y]);
        end;
      end;
    end;

    result := ImageList.Add(buffer, mask);
  finally
    mask.Free;
    buffer.Free;
  end;
end;

end.
