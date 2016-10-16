object UD2TaskPropertiesForm: TUD2TaskPropertiesForm
  Left = 318
  Top = 140
  Caption = 'Task properties'
  ClientHeight = 444
  ClientWidth = 481
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  DesignSize = (
    481
    444)
  PixelsPerInch = 96
  TextHeight = 13
  object Image1: TImage
    Left = 16
    Top = 16
    Width = 32
    Height = 32
  end
  object Label1: TLabel
    Left = 64
    Top = 56
    Width = 62
    Height = 13
    Caption = 'Configuration'
  end
  object Label2: TLabel
    Left = 64
    Top = 331
    Width = 313
    Height = 13
    Anchors = [akLeft, akRight, akBottom]
    Caption = 'Following commands will be executed in your environment:'
  end
  object ValueListEditor1: TValueListEditor
    Left = 64
    Top = 72
    Width = 405
    Height = 242
    Anchors = [akLeft, akTop, akRight, akBottom]
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect, goThumbTracking]
    TabOrder = 3
    ColWidths = (
      205
      194)
    RowHeights = (
      18
      18)
  end
  object LabeledEdit1: TLabeledEdit
    Left = 64
    Top = 24
    Width = 217
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    EditLabel.Width = 102
    EditLabel.Height = 13
    EditLabel.Caption = 'Section Name (intern)'
    ReadOnly = True
    TabOrder = 2
  end
  object ListBox1: TListBox
    Left = 64
    Top = 347
    Width = 405
    Height = 78
    Anchors = [akLeft, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 4
  end
  object Button1: TButton
    Left = 306
    Top = 9
    Width = 163
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Open Task Definition File'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 306
    Top = 41
    Width = 163
    Height = 25
    Anchors = [akTop, akRight]
    Cancel = True
    Caption = 'Close'
    TabOrder = 0
    OnClick = Button2Click
  end
end
