program UserDetect2;

uses
  Forms,
  UD2_Main in 'UD2_Main.pas' {UD2MainForm},
  UD2_TaskProperties in 'UD2_TaskProperties.pas' {UD2TaskPropertiesForm},
  UD2_PluginIntf in 'UD2_PluginIntf.pas',
  UD2_PluginUtils in 'UD2_PluginUtils.pas',
  UD2_Obj in 'UD2_Obj.pas',
  UD2_Utils in 'UD2_Utils.pas',
  UD2_PluginStatus in 'UD2_PluginStatus.pas';

{$R WindowsXP.res}

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TUD2MainForm, UD2MainForm);
  Application.Run;
end.
