unit VTSListView;

{$WARN UNSAFE_CODE OFF}
{$WARN UNSAFE_TYPE OFF}

interface

// This ListView adds support for sorting arrows

// Recommended usage for the OnCompare event:
(*
procedure TForm1.ListViewCompare(Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer);
var
  ListView: TVTSListView;
begin
  ListView := Sender as TVTSListView;
  if ListView.CurSortedColumn = 0 then
  begin
    Compare := CompareText(Item1.Caption, Item2.Caption);
  end
  else
  begin
    Compare := CompareText(Item1.SubItems[ListView.CurSortedColumn-1],
                           Item2.SubItems[ListView.CurSortedColumn-1]);
  end;
  if ListView.CurSortedDesc then Compare := -Compare;
end;
*)

uses
  Windows, Messages, SysUtils, Classes, Controls, ComCtrls, CommCtrl;

type
  TVTSListView = class(TListView)
  private
    FDescending: Boolean;
    FSortedColumn: Integer;
    procedure WMNotifyMessage(var msg: TWMNotify); message WM_NOTIFY;
  protected
    procedure ShowArrowOfListViewColumn;
    procedure ColClick(Column: TListColumn); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property CurSortedColumn: integer read FSortedColumn;
    property CurSortedDesc: boolean read FDescending;
  end;

procedure Register;

implementation

// The arrows require a XP Manifest

{$IF not Declared(HDF_SORTUP)}
const
  { For Windows >= XP }
  {$EXTERNALSYM HDF_SORTUP}
  HDF_SORTUP              = $0400;
  {$EXTERNALSYM HDF_SORTDOWN}
  HDF_SORTDOWN            = $0200;
{$IFEND}

{ TVTSListView }

constructor TVTSListView.Create(AOwner: TComponent);
begin
  inherited;
  FSortedColumn := -1;
end;

procedure TVTSListView.ShowArrowOfListViewColumn;
var
  Header: HWND;
  Item: THDItem;
  i: integer;
begin
  Header := ListView_GetHeader(Handle);
  ZeroMemory(@Item, SizeOf(Item));
  Item.Mask := HDI_FORMAT;

  // Remove arrows
  for i := 0 to Columns.Count-1 do
  begin
    Header_GetItem(Header, i, Item);
    Item.fmt := Item.fmt and not (HDF_SORTUP or HDF_SORTDOWN);
    Header_SetItem(Header, i, Item);
  end;

  // Add arrow
  Header_GetItem(Header, FSortedColumn, Item);
  if FDescending then
    Item.fmt := Item.fmt or HDF_SORTDOWN
  else
    Item.fmt := Item.fmt or HDF_SORTUP;
  Header_SetItem(Header, FSortedColumn, Item);
end;

procedure TVTSListView.WMNotifyMessage(var msg: TWMNotify);
begin
  try
    inherited;
  except
    // Workaround for Delphi 6, which raises an EAccessViolation in
    // CallWindowProc at TWinControl.DefaultHandler, when the code executed
    // on Windows Server 2008. 
  end;
  if (Msg.NMHdr^.code = HDN_ENDTRACK) and (FSortedColumn > -1) then
  begin
    ShowArrowOfListViewColumn;
  end;
end;

procedure TVTSListView.ColClick(Column: TListColumn);
begin
  if not Assigned(OnCompare) then Exit;
  SortType := stNone;
  if Column.Index <> FSortedColumn then
  begin
    FSortedColumn := Column.Index;
    FDescending := False;
  end
  else
  begin
    FDescending := not FDescending;
  end;
  ShowArrowOfListViewColumn;
  SortType := stText;
  inherited;
end;

procedure Register;
begin
  RegisterComponents('ViaThinkSoft', [TVTSListView]);
end;

end.
