unit UD2_Main;

// TODO: !!ud2 plugin: computer sid, win version, pc name, username, ... (RT)
// TODO (future): auch commandline tool das nur errorlevel zurückgibt
// TODO: alle funktionalitäten aus userdetect1 (is_user) übernehmen
// TODO (kleinigkeit): wie das aufblitzen des forms verhindern bei CLI?
// TODO (future): Editor, um alles in der GUI zu erledigen
// TODO (idee): argumente an die DLL stellen, z.B. FileAge(Letter.doc):20=calc.exe
// TODO: example ini file entwerfen
// TODO: geticon funktion in ud2_obj.pas?
// TODO (idee): ein plugin kann mehrere methodnames haben?
// TODO: möglichkeit, Task Definition File neu zu laden, nach änderungen die man durchgeführt hat

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Grids, ValEdit, UD2_Obj, ComCtrls, ImgList, ExtCtrls,
  CommCtrl, Menus, VTSListView, VTSCompat;

const
  DefaultIniFile = 'UserDetect2.ini';
  DefaultWarnIfNothingMatches = 'false';
  TagWarnIfNothingMatches = 'WarnIfNothingMatches';
  DefaultCloseAfterLaunching = 'false';
  TagCloseAfterLaunching = 'CloseAfterLaunching';
  TagIcon = 'Icon';

type
  TUD2MainForm = class(TForm)
    OpenDialog1: TOpenDialog;
    PageControl1: TPageControl;
    TasksTabSheet: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    IniTemplateMemo: TMemo;
    TabSheet4: TTabSheet;
    ListView1: TVTSListView;
    ImageList1: TImageList;
    SaveDialog1: TSaveDialog;
    TabSheet5: TTabSheet;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    ListView2: TVTSListView;
    ListView3: TVTSListView;
    ErrorsTabSheet: TTabSheet;
    ErrorsMemo: TMemo;
    Memo1: TMemo;
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    PopupMenu1: TPopupMenu;
    Run1: TMenuItem;
    Properties1: TMenuItem;
    PopupMenu2: TPopupMenu;
    CopyTaskDefinitionExample1: TMenuItem;
    Button3: TButton;
    VersionLabel: TLabel;
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
    procedure ListView1KeyPress(Sender: TObject; var Key: Char);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure URLLabelClick(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure Run1Click(Sender: TObject);
    procedure Properties1Click(Sender: TObject);
    procedure PopupMenu2Popup(Sender: TObject);
    procedure CopyTaskDefinitionExample1Click(Sender: TObject);
    procedure ListViewCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure Button3Click(Sender: TObject);
  protected
    ud2: TUD2;
    procedure LoadTaskList;
    procedure LoadDetectedIDs;
    procedure LoadINITemplate;
    procedure LoadLoadedPluginList;
    function GetIniFileName: string;
    procedure DoRun(ShortTaskName: string);
    procedure CheckForErrors;
  end;

var
  UD2MainForm: TUD2MainForm;

implementation

{$R *.dfm}

uses
  ShellAPI, Clipbrd, UD2_Utils, UD2_TaskProperties;

type
  TUD2ListViewEntry = class(TObject)
    ShortTaskName: string;
    CloseAfterLaunching: boolean;
    TaskPropertiesForm: TForm;
  end;

function AddIconRecToImageList(rec: TIconFileIdx; ImageList: TImageList): integer;
var
  icon: TIcon;
begin
  icon := TIcon.Create;
  try
    icon.Handle := ExtractIcon(Application.Handle, PChar(rec.FileName), rec.IconIndex);

    // result := ImageList.AddIcon(ico);
    result := AddTransparentIconToImageList(ImageList, icon);
  finally
    icon.Free;
  end;
end;

{ TUD2MainForm }

function TUD2MainForm.GetIniFileName: string;
resourcestring
  LNG_FILE_NOT_FOUND = 'File "%s" not found.';
begin
  if ParamCount >= 1 then
  begin
    if FileExists(ParamStr(1)) then
    begin
      result := ParamStr(1);
    end
    else
    begin
      MessageDlg(Format(LNG_FILE_NOT_FOUND, [ParamStr(1)]), mtError, [mbOK], 0);
      result := '';
    end;
    Exit;
  end
  else
  begin
    if FileExists(DefaultIniFile) then
    begin
      result := DefaultIniFile;
      Exit;
    end;

    if FileExists(GetOwnCmdName + '.ini') then
    begin
      result := GetOwnCmdName + '.ini';
      Exit;
    end;

    if CompatOpenDialogExecute(OpenDialog1) then
    begin
      result := OpenDialog1.FileName;
      Exit;
    end;

    result := '';
    Exit;
  end;
end;

procedure TUD2MainForm.LoadTaskList;
var
  sl: TStringList;
  i: integer;
  ShortTaskName, iconString: string;
  iconIndex: integer;
  obj: TUD2ListViewEntry;
begin
  ListView1.Clear;
  sl := TStringList.Create;
  try
    ud2.GetTaskListing(sl);
    for i := 0 to sl.Count-1 do
    begin
      ShortTaskName := sl.Names[i];

      Obj := TUD2ListViewEntry.Create;
      Obj.ShortTaskName := ShortTaskName;
      Obj.CloseAfterLaunching := ud2.ReadMetatagBool(ShortTaskName, TagCloseAfterLaunching, DefaultCloseAfterLaunching);

      ListView1.AddItem(sl.Values[ShortTaskName], TObject(Obj));

      iconString := ud2.ReadMetatagString(ShortTaskName, TagIcon, '');
      if iconString <> '' then
      begin
        iconIndex := AddIconRecToImageList(SplitIconString(iconString), ImageList1);
        if iconIndex <> -1 then
        begin
          ListView1.Items.Item[ListView1.Items.Count-1].ImageIndex := iconIndex;
        end;
      end;
    end;
  finally
    sl.Free;
  end;
end;

procedure TUD2MainForm.DoRun(ShortTaskName: string);
resourcestring
  LNG_TASK_NOT_EXISTS = 'The task "%s" does not exist in the INI file.';
  LNG_NOTHING_MATCHES = 'No identification string matches to your environment. No application was launched. Please check the Task Definition File.';
var
  slCmds: TStringList;
  i: integer;
  cmd: string;
begin
  if not ud2.TaskExists(ShortTaskName) then
  begin
    // This can happen if the task name is taken from command line
    MessageDlg(Format(LNG_TASK_NOT_EXISTS, [ShortTaskName]), mtError, [mbOK], 0);
    Exit;
  end;

  slCmds := TStringList.Create;
  try
    ud2.GetCommandList(ShortTaskName, slCmds);

    if (slCmds.Count = 0) and
      ud2.ReadMetatagBool(ShortTaskName,
      TagWarnIfNothingMatches, DefaultWarnIfNothingMatches) then
    begin
      MessageDlg(LNG_NOTHING_MATCHES, mtWarning, [mbOK], 0);
    end;

    for i := 0 to slCmds.Count-1 do
    begin
      cmd := slCmds.Strings[i];
      if cmd = '' then continue;
      UD2_RunCMD(cmd, SW_NORMAL); // TODO: SW_NORMAL konfigurieren?
    end;
  finally
    slCmds.Free;
  end;
end;

procedure TUD2MainForm.FormDestroy(Sender: TObject);
var
  i: integer;
begin
  if Assigned(ud2) then ud2.Free;
  for i := 0 to ListView1.Items.Count-1 do
  begin
    TUD2ListViewEntry(ListView1.Items.Item[i].Data).Free;
  end;
end;

procedure TUD2MainForm.CheckForErrors;
begin
  ErrorsTabSheet.TabVisible := ud2.Errors.Count > 0;
  if ErrorsTabSheet.TabVisible then
  begin
    ErrorsMemo.Lines.Assign(ud2.Errors);
    PageControl1.ActivePage := ErrorsTabSheet;
  end;
end;

procedure TUD2MainForm.LoadDetectedIDs;
var
  i, j: integer;
  pl: TUD2Plugin;
  ude: TUD2IdentificationEntry;
begin
  ListView3.Clear;
  for i := 0 to ud2.LoadedPlugins.Count-1 do
  begin
    pl := ud2.LoadedPlugins.Items[i] as TUD2Plugin;
    for j := 0 to pl.DetectedIdentifications.Count-1 do
    begin
      ude := pl.DetectedIdentifications.Items[j] as TUD2IdentificationEntry;
      with ListView3.Items.Add do
      begin
        Caption := pl.PluginName;
        SubItems.Add(pl.IdentificationMethodName);
        SubItems.Add(ude.IdentificationString);
        SubItems.Add(GUIDToString(pl.PluginGUID));
      end;
    end;
  end;

  for i := 0 to ListView3.Columns.Count-1 do
  begin
    ListView3.Columns.Items[i].Width := LVSCW_AUTOSIZE_USEHEADER;
  end;
end;

procedure TUD2MainForm.LoadINITemplate;
var
  i, j: integer;
  pl: TUD2Plugin;
  ude: TUD2IdentificationEntry;
begin
  IniTemplateMemo.Clear;
  IniTemplateMemo.Lines.Add('[ExampleTask1]');
  IniTemplateMemo.Lines.Add('; Description: Optional but recommended');
  IniTemplateMemo.Lines.Add('Description=Run Task #1');
  IniTemplateMemo.Lines.Add('; WarnIfNothingMatches: Warns when no application was launched. Default: false.');
  IniTemplateMemo.Lines.Add('WarnIfNothingMatches=false');
  IniTemplateMemo.Lines.Add('; Optional: IconDLL + IconIndex');
  IniTemplateMemo.Lines.Add('Icon=%SystemRoot%\system32\Shell32.dll,3');
  IniTemplateMemo.Lines.Add('; Optional: Can be true or false');
  IniTemplateMemo.Lines.Add(TagCloseAfterLaunching+'=true');

  for i := 0 to ud2.LoadedPlugins.Count-1 do
  begin
    pl := ud2.LoadedPlugins.Items[i] as TUD2Plugin;
    for j := 0 to pl.DetectedIdentifications.Count-1 do
    begin
      ude := pl.DetectedIdentifications.Items[j] as TUD2IdentificationEntry;
      IniTemplateMemo.Lines.Add(Format('; %s', [ude.Plugin.PluginName]));
      IniTemplateMemo.Lines.Add(ude.GetPrimaryIdName+'=calc.exe');
    end;
  end;
end;

procedure TUD2MainForm.LoadLoadedPluginList;
var
  i: integer;
  pl: TUD2Plugin;
begin
  ListView2.Clear;
  for i := 0 to ud2.LoadedPlugins.Count-1 do
  begin
    pl := ud2.LoadedPlugins.Items[i] as TUD2Plugin;
    with ListView2.Items.Add do
    begin
      Caption := pl.PluginDLL;
      SubItems.Add(pl.PluginVendor);
      SubItems.Add(pl.PluginName);
      SubItems.Add(pl.PluginVersion);
      SubItems.Add(pl.IdentificationMethodName);
      SubItems.Add(pl.PluginGUIDString);
    end;
  end;

  for i := 0 to ListView2.Columns.Count-1 do
  begin
    ListView2.Columns.Items[i].Width := LVSCW_AUTOSIZE_USEHEADER;
  end;
end;

procedure TUD2MainForm.FormShow(Sender: TObject);
resourcestring
  LNG_SYNTAX = 'Syntax: %s [TaskDefinitionFile [TaskName]]';
var
  LoadedIniFile: string;
begin
  // To avoid accidental changes from the GUI designer
  PageControl1.ActivePage := TasksTabSheet;

  if ((ParamCount = 1) and (ParamStr(1) = '/?')) or (ParamCount >= 3) then
  begin
    MessageDlg(Format(LNG_SYNTAX, [GetOwnCmdName]), mtInformation, [mbOK], 0);
    Close;
    Exit;
  end;

  LoadedIniFile := GetIniFileName;
  if LoadedIniFile = '' then
  begin
    Close;
    Exit;
  end;
  ud2 := TUD2.Create(LoadedIniFile);

  ud2.HandlePluginDir('Plugins\');

  if ParamCount >= 2 then
  begin
    DoRun(ParamStr(2));
    Close;
    Exit;
  end
  else
  begin
    LoadTaskList;
    LoadDetectedIDs;
    LoadINITemplate;
    LoadLoadedPluginList;
    CheckForErrors;
  end;
end;

procedure TUD2MainForm.ListView1DblClick(Sender: TObject);
var
  obj: TUD2ListViewEntry;
begin
  if ListView1.ItemIndex = -1 then exit;
  obj := TUD2ListViewEntry(ListView1.Selected.Data);
  DoRun(obj.ShortTaskName);
  if obj.CloseAfterLaunching then Close;
end;

procedure TUD2MainForm.ListView1KeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    ListView1DblClick(Sender);
  end;
end;

procedure TUD2MainForm.Button1Click(Sender: TObject);
begin
  UD2_RunCMD(ud2.IniFileName, SW_NORMAL);
end;

procedure TUD2MainForm.Button2Click(Sender: TObject);
begin
  if CompatSaveDialogExecute(SaveDialog1) then
  begin
    IniTemplateMemo.Lines.SaveToFile(SaveDialog1.FileName);
  end;
end;

procedure TUD2MainForm.URLLabelClick(Sender: TObject);
var
  s: string;
begin
  s := TLabel(Sender).Caption;
  if Pos('@', s) > 0 then
    s := 'mailto:' + s
  else
    s := 'http://' + s;
  UD2_RunCMD(s, SW_NORMAL);
end;

procedure TUD2MainForm.PopupMenu1Popup(Sender: TObject);
begin
  Run1.Enabled := ListView1.ItemIndex <> -1;
  Properties1.Enabled := ListView1.ItemIndex <> -1;
end;

procedure TUD2MainForm.Run1Click(Sender: TObject);
begin
  ListView1DblClick(Sender);
end;

procedure TUD2MainForm.Properties1Click(Sender: TObject);
var
  obj: TUD2ListViewEntry;
begin
  if ListView1.ItemIndex = -1 then exit;
  obj := TUD2ListViewEntry(ListView1.Selected.Data);
  if obj.TaskPropertiesForm = nil then
  begin
    obj.TaskPropertiesForm := TUD2TaskPropertiesForm.Create(Self, ud2, obj.ShortTaskName);
  end;
  obj.TaskPropertiesForm.Show;
end;

procedure TUD2MainForm.PopupMenu2Popup(Sender: TObject);
begin
  CopyTaskDefinitionExample1.Enabled := ListView3.ItemIndex <> -1;
end;

procedure TUD2MainForm.CopyTaskDefinitionExample1Click(Sender: TObject);
var
  s: string;
begin
  s := '; '+ListView3.Selected.Caption+#13#10+
       ListView3.Selected.SubItems[0] + ':' + ListView3.Selected.SubItems[1] + '=calc.exe'+#13#10+
       #13#10+
       '; Alternatively:'+#13#10+
       ListView3.Selected.SubItems[2] + ':' + ListView3.Selected.SubItems[1] + '=calc.exe'+#13#10;
  Clipboard.AsText := s;
end;

procedure TUD2MainForm.ListViewCompare(Sender: TObject; Item1,
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

procedure TUD2MainForm.Button3Click(Sender: TObject);
begin
  VTS_CheckUpdates('userdetect2', VersionLabel.Caption);
end;

end.
