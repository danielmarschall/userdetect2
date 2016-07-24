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
  UD2_Utils, UD2_Main, UD2_Parsing, ShellAPI;

procedure TUD2TaskPropertiesForm.LoadExecutableFilesList;
resourcestring
  LNG_RIOD = 'Run in own directory';
  LNG_ADMIN = 'Run as admin';
var
  i: integer;
  flags: string;
  cmds: TUD2CommandArray;
  cmd: TUD2Command;
begin
  //fud2.GetCommandList(AShortTaskName, ListBox1.Items);

  ListBox1.Clear;
  cmds := fud2.GetCommandList(FShortTaskName); // TODO: What to do with AErrorOut (errors from dynamic queries?)

  for i := Low(cmds) to High(cmds) do
  begin
    cmd := cmds[i];

    flags := '';

    if cmd.runAsAdmin then
    begin
      if flags <> '' then flags := flags + ', ';
      flags := flags + LNG_ADMIN;
    end;

    if cmd.runInOwnDirectory then
    begin
      if flags <> '' then flags := flags + ', ';
      flags := flags + LNG_RIOD;
    end;

    if flags <> '' then
    begin
      flags := ' [' + flags + ']';
    end;

    ListBox1.Items.Add(cmd.executable + flags);
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
var
  cmd: TUD2Command;
begin
  cmd.executable := fud2.IniFileName;
  cmd.runAsAdmin := false;
  cmd.runInOwnDirectory := false;
  cmd.windowMode := SW_NORMAL;
  UD2_RunCMD(cmd);
end;

end.
