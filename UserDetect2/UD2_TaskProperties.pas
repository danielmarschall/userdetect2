unit UD2_TaskProperties;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, UD2_Obj, StdCtrls, ExtCtrls, Grids, ValEdit;

type
  TUD2TaskPropertiesForm = class(TForm)
    ValueListEditor1: TValueListEditor;
    LabeledEdit1: TLabeledEdit;
    Image1: TImage;
    ListBox1: TListBox;
    Label1: TLabel;
    Button1: TButton;
    Label2: TLabel;
    Button2: TButton;
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    FUD2: TUD2;
    FShortTaskName: string;
    procedure LoadExecutableFilesList;
    procedure LoadIcon;
  public
    constructor Create(AOwner: TComponent; AUD2: TUD2; AShortTaskName: string); reintroduce;
  end;

(*
var
  UD2TaskPropertiesForm: TTaskPropertiesForm;
*)

implementation

{$R *.dfm}

uses
  UD2_Utils, UD2_Main, ShellAPI;

procedure TUD2TaskPropertiesForm.LoadExecutableFilesList;
resourcestring
  LNG_RIOD = '%s [Run in own directory]';
var
  sl: TStringList;
  i: integer;
  s: string;
begin
  //fud2.GetCommandList(AShortTaskName, ListBox1.Items);
  
  ListBox1.Clear;
  sl := TStringList.Create;
  try
    fud2.GetCommandList(FShortTaskName, sl);
    for i := 0 to sl.Count-1 do
    begin
      s := sl.Strings[i];
      if Copy(s, 1, Length(UD2_RUN_IN_OWN_DIRECTORY_PREFIX)) = UD2_RUN_IN_OWN_DIRECTORY_PREFIX then
      begin
        s := Copy(s, 1+Length(UD2_RUN_IN_OWN_DIRECTORY_PREFIX), Length(s)-Length(UD2_RUN_IN_OWN_DIRECTORY_PREFIX));
        s := Format(LNG_RIOD, [s]);
      end;
      ListBox1.Items.Add(s);
    end;
  finally
    sl.Free;
  end;
end;

procedure TUD2TaskPropertiesForm.LoadIcon;
var
  ico: TIcon;
  icoSplit: TIconFileIdx;
  iconString: string;
begin
  iconString := fud2.ReadMetatagString(FShortTaskName, UD2_Main.TagIcon, '');
  if iconString <> '' then
  begin
    icoSplit := SplitIconString(iconString);
    ico := TIcon.Create;
    try
      ico.Handle := ExtractIcon(Application.Handle, PChar(icoSplit.FileName), icoSplit.IconIndex);
      Image1.Picture.Icon.Assign(ico);
    finally
      ico.Free;
    end;
  end
  else
  begin
    UD2MainForm.TasksImageList.GetIcon(0, Image1.Picture.Icon);
  end;
end;

constructor TUD2TaskPropertiesForm.Create(AOwner: TComponent; AUD2: TUD2; AShortTaskName: string);
resourcestring
  LNG_TASK_PROPS = 'Task properties of "%s"';
var
  Description: string;
begin
  inherited Create(AOwner);
  FUD2 := AUD2;
  FShortTaskName := AShortTaskName;

  FUD2.IniFile.ReadSectionValues(AShortTaskName, ValueListEditor1.Strings);

  Description := FUD2.GetTaskName(AShortTaskName);
  Caption := Format(LNG_TASK_PROPS, [Description]);
  LabeledEdit1.Text := AShortTaskName;
  LoadExecutableFilesList;
  LoadIcon;
end;

procedure TUD2TaskPropertiesForm.Button2Click(Sender: TObject);
begin
  Close;
end;

procedure TUD2TaskPropertiesForm.Button1Click(Sender: TObject);
begin
  UD2_RunCMD(fud2.IniFileName, SW_NORMAL);
end;

end.
