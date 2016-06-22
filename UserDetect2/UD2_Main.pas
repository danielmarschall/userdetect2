unit UD2_Main;

interface

{$IF CompilerVersion >= 25.0}
{$LEGACYIFEND ON}
{$IFEND}

{$INCLUDE 'UserDetect2.inc'}

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
    TasksListView: TVTSListView;
    TasksImageList: TImageList;
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
    LoadedPluginsListView: TVTSListView;
    IdentificationsListView: TVTSListView;
    ErrorsTabSheet: TTabSheet;
    ErrorsMemo: TMemo;
    Memo1: TMemo;
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    TasksPopupMenu: TPopupMenu;
    Run1: TMenuItem;
    Properties1: TMenuItem;
    IdentificationsPopupMenu: TPopupMenu;
    CopyTaskDefinitionExample1: TMenuItem;
    Button3: TButton;
    VersionLabel: TLabel;
    LoadedPluginsPopupMenu: TPopupMenu;
    MenuItem1: TMenuItem;
    Panel2: TPanel;
    Image2: TImage;
    Button5: TButton;
    procedure FormDestroy(Sender: TObject);
    procedure TasksListViewDblClick(Sender: TObject);
    procedure TasksListViewKeyPress(Sender: TObject; var Key: Char);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure URLLabelClick(Sender: TObject);
    procedure TasksPopupMenuPopup(Sender: TObject);
    procedure Run1Click(Sender: TObject);
    procedure Properties1Click(Sender: TObject);
    procedure IdentificationsPopupMenuPopup(Sender: TObject);
    procedure CopyTaskDefinitionExample1Click(Sender: TObject);
    procedure ListViewCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
    procedure Button3Click(Sender: TObject);
    procedure LoadedPluginsPopupMenuPopup(Sender: TObject);
    procedure MenuItem1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  protected
    ud2: TUD2;
    procedure LoadTaskList;
    procedure LoadDetectedIDs;
    procedure LoadINITemplate;
    procedure LoadLoadedPluginList;
    function GetIniFileName: string;
    procedure DoRun(ShortTaskName: string);
    procedure CheckForErrors;
  public
    procedure Run;
  end;

var
  UD2MainForm: TUD2MainForm;

implementation

{$R *.dfm}

uses
  ShellAPI, Clipbrd, Math, AlphaNumSort, UD2_Utils, UD2_TaskProperties;

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
  if (ParamCount >= 1) and not CheckBoolParam(1, 'C') then
  begin
    if FileExists(ParamStr(1)) then
    begin
      result := ParamStr(1);
    end
    else
    begin
      ExitCode := EXITCODE_INI_NOT_FOUND;
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
  TasksListView.Clear;
  sl := TStringList.Create;
  try
    ud2.GetTaskListing(sl);
    for i := 0 to sl.Count-1 do
    begin
      ShortTaskName := sl.Names[i];

      Obj := TUD2ListViewEntry.Create;
      Obj.ShortTaskName := ShortTaskName;
      Obj.CloseAfterLaunching := ud2.ReadMetatagBool(ShortTaskName, TagCloseAfterLaunching, DefaultCloseAfterLaunching);

      TasksListView.AddItem(sl.Values[ShortTaskName], TObject(Obj));

      iconString := ud2.ReadMetatagString(ShortTaskName, TagIcon, '');
      if iconString <> '' then
      begin
        iconIndex := AddIconRecToImageList(SplitIconString(iconString), TasksImageList);
        if iconIndex <> -1 then
        begin
          TasksListView.Items.Item[TasksListView.Items.Count-1].ImageIndex := iconIndex;
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
    ExitCode := EXITCODE_TASK_NOT_EXISTS;
    Exit;
  end;

  slCmds := TStringList.Create;
  try
    ud2.GetCommandList(ShortTaskName, slCmds);

    if (slCmds.Count = 0) and ud2.ReadMetatagBool(ShortTaskName, TagWarnIfNothingMatches, DefaultWarnIfNothingMatches) then
    begin
      MessageDlg(LNG_NOTHING_MATCHES, mtWarning, [mbOK], 0);
      ExitCode := EXITCODE_TASK_NOTHING_MATCHES;
    end;

    for i := 0 to slCmds.Count-1 do
    begin
      cmd := slCmds.Strings[i];
      if cmd = '' then continue;
      UD2_RunCMD(cmd, SW_NORMAL); // Idea: Let SW_NORMAL be configurable by the user?
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
  for i := 0 to TasksListView.Items.Count-1 do
  begin
    TUD2ListViewEntry(TasksListView.Items.Item[i].Data).Free;
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
  IdentificationsListView.Clear;
  for i := 0 to ud2.LoadedPlugins.Count-1 do
  begin
    pl := ud2.LoadedPlugins.Items[i] as TUD2Plugin;
    for j := 0 to pl.DetectedIdentifications.Count-1 do
    begin
      ude := pl.DetectedIdentifications.Items[j] as TUD2IdentificationEntry;
      with IdentificationsListView.Items.Add do
      begin
        Caption := pl.PluginName;
        if ude.DynamicDataUsed then
          SubItems.Add(ude.DynamicData)
        else
          SubItems.Add('');
        SubItems.Add(pl.IdentificationMethodName);
        SubItems.Add(ude.IdentificationString);
        SubItems.Add(GUIDToString(pl.PluginGUID));
      end;
    end;
  end;

  for i := 0 to IdentificationsListView.Columns.Count-1 do
  begin
    IdentificationsListView.Columns.Items[i].Width := LVSCW_AUTOSIZE_USEHEADER;
  end;
end;

procedure TUD2MainForm.LoadINITemplate;
var
  i, j: integer;
  pl: TUD2Plugin;
  ude: TUD2IdentificationEntry;
  idNames: TStringList;
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

      idNames := TStringList.Create;
      try
        ude.GetIdNames(idNames);
        if idNames.Count >= 1 then
          IniTemplateMemo.Lines.Add(idNames.Strings[0]+'=calc.exe');
      finally
        idNames.Free;
      end;

    end;
  end;
end;

procedure TUD2MainForm.LoadLoadedPluginList;
resourcestring
  LNG_MS = '%dms';
var
  i: integer;
  pl: TUD2Plugin;
begin
  LoadedPluginsListView.Clear;
  for i := 0 to ud2.LoadedPlugins.Count-1 do
  begin
    pl := ud2.LoadedPlugins.Items[i] as TUD2Plugin;
    with LoadedPluginsListView.Items.Add do
    begin
      Caption := pl.PluginDLL;
      SubItems.Add(pl.PluginVendor);
      SubItems.Add(pl.PluginName);
      SubItems.Add(pl.PluginVersion);
      SubItems.Add(pl.IdentificationMethodName);
      SubItems.Add(IntToStr(pl.DetectedIdentifications.Count));
      SubItems.Add(Format(LNG_MS, [Max(1,pl.time)])); // at least show 1ms, otherwise it would be unloggical
      SubItems.Add(pl.IdentificationProcedureStatusCodeDescribed);
      SubItems.Add(pl.PluginGUIDString);
    end;
  end;

  for i := 0 to LoadedPluginsListView.Columns.Count-1 do
  begin
    LoadedPluginsListView.Columns.Items[i].Width := LVSCW_AUTOSIZE_USEHEADER;
  end;
end;

procedure TUD2MainForm.TasksListViewDblClick(Sender: TObject);
var
  obj: TUD2ListViewEntry;
begin
  if TasksListView.ItemIndex = -1 then exit;
  obj := TUD2ListViewEntry(TasksListView.Selected.Data);
  DoRun(obj.ShortTaskName);
  if obj.CloseAfterLaunching then Close;
end;

procedure TUD2MainForm.TasksListViewKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    TasksListViewDblClick(Sender);
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

procedure TUD2MainForm.TasksPopupMenuPopup(Sender: TObject);
begin
  Run1.Enabled := TasksListView.ItemIndex <> -1;
  Properties1.Enabled := TasksListView.ItemIndex <> -1;
end;

procedure TUD2MainForm.Run1Click(Sender: TObject);
begin
  TasksListViewDblClick(Sender);
end;

procedure TUD2MainForm.Properties1Click(Sender: TObject);
var
  obj: TUD2ListViewEntry;
begin
  if TasksListView.ItemIndex = -1 then exit;
  obj := TUD2ListViewEntry(TasksListView.Selected.Data);
  if obj.TaskPropertiesForm = nil then
  begin
    obj.TaskPropertiesForm := TUD2TaskPropertiesForm.Create(Self, ud2, obj.ShortTaskName);
  end;
  obj.TaskPropertiesForm.Show;
end;

procedure TUD2MainForm.IdentificationsPopupMenuPopup(Sender: TObject);
begin
  CopyTaskDefinitionExample1.Enabled := IdentificationsListView.ItemIndex <> -1;
end;

procedure TUD2MainForm.CopyTaskDefinitionExample1Click(Sender: TObject);
var
  s: string;
begin
  s := '; '+IdentificationsListView.Selected.Caption+#13#10+
       IdentificationsListView.Selected.SubItems[0] + ':' + IdentificationsListView.Selected.SubItems[1] + '=calc.exe'+#13#10+
       #13#10+
       '; Alternatively:'+#13#10+
       IdentificationsListView.Selected.SubItems[2] + ':' + IdentificationsListView.Selected.SubItems[1] + '=calc.exe'+#13#10;
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
    Compare := AlphaNumCompare(Item1.Caption, Item2.Caption);
  end
  else
  begin
    Compare := AlphaNumCompare(Item1.SubItems[ListView.CurSortedColumn-1],
                               Item2.SubItems[ListView.CurSortedColumn-1]);
  end;
  if ListView.CurSortedDesc then Compare := -Compare;
end;

procedure TUD2MainForm.Button3Click(Sender: TObject);
begin
  VTS_CheckUpdates('userdetect2', VersionLabel.Caption);
end;

procedure TUD2MainForm.LoadedPluginsPopupMenuPopup(Sender: TObject);
begin
  MenuItem1.Enabled := LoadedPluginsListView.ItemIndex <> -1;
end;

procedure TUD2MainForm.MenuItem1Click(Sender: TObject);
var
  s: string;
begin
  s := '; ' + LoadedPluginsListView.Selected.SubItems.Strings[6];
  Clipboard.AsText := s;
end;

procedure TUD2MainForm.Run;
resourcestring
  LNG_SYNTAX = 'Syntax: %s [TaskDefinitionFile [/T TaskName] | /C IdentificationTerm [Command] | /?]';
var
  LoadedIniFile: string;
begin
  ExitCode := EXITCODE_OK;

  if ((ParamCount = 1) and CheckBoolParam(1, '?')) or
     (CheckBoolParam(2, 'T') and (ParamCount > 3)) or
     (CheckBoolParam(1, 'C') and (ParamCount > 3)) or
     (not CheckBoolParam(2, 'T') and not CheckBoolParam(1, 'C') and (ParamCount > 1)) then
  begin
    ExitCode := EXITCODE_SYNTAX_ERROR;
    MessageDlg(Format(LNG_SYNTAX, [GetOwnCmdName]), mtInformation, [mbOK], 0);

    Visible := false;
    Close;
    Exit;
  end;

  LoadedIniFile := GetIniFileName;
  if LoadedIniFile = '' then
  begin
    Visible := false;
    Close;
    Exit;
  end;
  ud2 := TUD2.Create(LoadedIniFile);

  ud2.HandlePluginDir('',        '*.udp');
  ud2.HandlePluginDir('Plugins', '*.udp');
  ud2.HandlePluginDir('Plugins', '*.dll');

  if CheckBoolParam(1, 'C') then
  begin
    if ud2.FulfilsEverySubterm(ParamStr(2)) then
    begin
      ExitCode := EXITCODE_OK;

      if ParamStr(3) <> '' then UD2_RunCMD(ParamStr(3), SW_NORMAL); // Idea: SW_NORMAL changeable via parameter
    end
    else
    begin
      ExitCode := EXITCODE_TASK_NOTHING_MATCHES;
    end;

    Visible := false;
    Close;
    Exit;
  end
  else if CheckBoolParam(2, 'T') then
  begin
    DoRun(ParamStr(3));

    Visible := false;
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

    Visible := true;
    Exit;
  end;
end;

procedure TUD2MainForm.FormCreate(Sender: TObject);
begin
  // To avoid accidental change of the default tab from the IDE VCL Designer
  PageControl1.ActivePage := TasksTabSheet;
end;

procedure TUD2MainForm.Button5Click(Sender: TObject);
var
  idTerm: string;
  slCmd: TStrings;
begin
  if InputQuery('Enter example term', 'Example: abc|||Testecho:abc=calc.exe', idTerm) then
  begin
    slCmd := TStringList.Create;
    try
      ud2.CheckTerm(idTerm, slCmd);
      if slCmd.Count = 0 then
        ShowMessage('No commands would be executed.')
      else
        showmessage('Following commands would be executed:' + #13#10#13#10 + slCmd.Text);
    finally
      slCmd.Free;
    end;
  end;
  LoadDetectedIDs;
end;

end.
