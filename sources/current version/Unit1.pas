unit Unit1;

interface

uses
  inifiles,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, XPMan, StdCtrls, ExtCtrls, Spin;

type
  TForm1 = class(TForm)
    EditPathXmrigNvidia: TEdit;
    Label1: TLabel;
    XPManifest1: TXPManifest;
    Memo1: TMemo;
    ButtonStart: TButton;
    ButtonStop: TButton;
    EditTemperature: TEdit;
    Label4: TLabel;
    TimerStartDelayed: TTimer;
    SpinEditTemperatureLimit: TSpinEdit;
    Label5: TLabel;
    OpenDialog1: TOpenDialog;
    ButtonOpenDialog: TButton;
    procedure RunDos(Que:String);
    procedure StopDos();
    procedure OnDosOutput(line:String);
    procedure OnDosStart();
    procedure OnDosStop();
    procedure TrackDosTemperatureOutput(line:String);
    procedure OnDosTemperatureOutput(Temperature:Integer);
    procedure OnDosTemperatureExceed(Temperature:Integer);
    procedure OnDosTemperatureAllowed(Temperature:Integer);
    function getCharsBetween(line, startChars, endChars:String):String;
    function RemoveNewlineAtEnd(line: String): String;
    procedure CloseProcessPID(pid: Integer);
    procedure LoadConfig();
    procedure SaveConfig();
    procedure ButtonStartClick(Sender: TObject);
    procedure ButtonStopClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure TimerStartDelayedTimer(Sender: TObject);
    procedure ButtonOpenDialogClick(Sender: TObject);
    procedure SpinEditTemperatureLimitChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  pid: Integer;
implementation

{$R *.dfm}

procedure TForm1.LoadConfig();
var  Setup: TIniFile;
begin
  Setup := TIniFile.Create(ExtractFileDir(Application.ExeName) + '\Setup.ini');
  EditPathXmrigNvidia.Text := Setup.ReadString('Application', 'PathXmrigNvidia', '');
  SpinEditTemperatureLimit.Value := Setup.ReadInteger('Application', 'TemperatureLimit', 84);
  Setup.Free;
end;

procedure TForm1.SaveConfig();
var  Setup: TIniFile;
begin
  Setup := TIniFile.Create(ExtractFileDir(Application.ExeName) + '\Setup.ini');
  Setup.WriteString('Application', 'PathXmrigNvidia', EditPathXmrigNvidia.Text);
  Setup.WriteInteger('Application', 'TemperatureLimit', SpinEditTemperatureLimit.Value);
  Setup.Free;
end;

procedure TForm1.RunDos(Que:String);
const
  CUANTOBUFFER = 2000;
var
  Seguridades         : TSecurityAttributes;
  PaLeer,PaEscribir   : THandle;
  start               : TStartUpInfo;
  ProcessInfo         : TProcessInformation;
  Buffer              : Pchar;
  BytesRead           : DWord;
  CuandoSale          : DWord;
  tb                  : PDWord;

  procedure readFromPipe;
  begin
    repeat
      BytesRead := 0;
      PeekNamedPipe(PaLeer, nil, 0, nil, tb, nil);
      if tb^=0 then
        break;
      ReadFile(PaLeer,Buffer[0],CUANTOBUFFER,BytesRead,nil);
      Buffer[BytesRead]:= #0;
      OemToAnsi(Buffer,Buffer);
      OnDosOutput(String(Buffer));
    until (BytesRead < CUANTOBUFFER);
  end;

begin
  with Seguridades do
  begin
    nlength              := SizeOf(TSecurityAttributes);
    binherithandle       := true;
    lpsecuritydescriptor := nil;
  end;

  if Createpipe (PaLeer, PaEscribir, @Seguridades, 0) then
  begin
    Buffer  := AllocMem(CUANTOBUFFER + 1);
    FillChar(Start,Sizeof(Start),#0);
    start.cb          := SizeOf(start);
    start.hStdOutput  := PaEscribir;
    start.hStdInput   := PaLeer;
    start.hStdError   := PaEscribir;
    start.dwFlags     := STARTF_USESTDHANDLES +
                         STARTF_USESHOWWINDOW;
    start.wShowWindow := SW_HIDE;

    if CreateProcess(nil,
      PChar(Que),
      @Seguridades,
      @Seguridades,
      true,
      NORMAL_PRIORITY_CLASS,
      nil,
      nil,
      start,
      ProcessInfo)
    then
    begin
      try
        pid := ProcessInfo.dwProcessId;

        OnDosStart();
        new(tb);
        repeat
          CuandoSale := WaitForSingleObject( ProcessInfo.hProcess,100);
          readFromPipe;
          Application.ProcessMessages;
        until (CuandoSale <> WAIT_TIMEOUT);
        dispose(tb);
      except
        On E : EOSError do exit;
        On E : EAccessViolation do exit;
      end;
    end;
    FreeMem(Buffer);
    OnDosStop();
  end;

end;


procedure TForm1.CloseProcessPID(pid: Integer);
var
  processHandle: THandle;
begin
  try
    processHandle := OpenProcess(PROCESS_TERMINATE or PROCESS_QUERY_INFORMATION, False, pid);
    if processHandle <> 0 then
    begin
      TerminateProcess(processHandle, 0);
      CloseHandle(ProcessHandle);
    end;
  except
    On E : EOSError do exit;
    On E : EAccessViolation do exit;
  end;
end;

procedure TForm1.StopDos();
begin
  CloseProcessPID(pid);
end;


procedure TForm1.OnDosStart();
begin
  Memo1.Lines.Add('Start mining');
end;

procedure TForm1.OnDosStop();
begin
  StopDos();
  Memo1.Lines.Add('Stop mining');
end;


procedure TForm1.OnDosOutput(line:String);
begin
  Memo1.Lines.Add(RemoveNewlineAtEnd(line));
  TrackDosTemperatureOutput(line);
end;

function TForm1.RemoveNewlineAtEnd(line: String): String;
begin
  result := line;
  if line[Length(line)-1] <> #13 then exit;
  result := Copy(line, 1, Length(line) - 2);
end;

function TForm1.getCharsBetween(line, startChars, endChars:String):String;
var
  startPos, endPos: Integer;
begin
  if Pos(startChars, line) = 0 then exit;
  if Pos(endChars, line) = 0 then exit;
  startPos := Pos(startChars, line) + Length(startChars);
  endPos := Pos(endChars, line) - startPos;
  result := Copy(line, startPos, endPos);
end;

procedure TForm1.TrackDosTemperatureOutput(line:String);
var
  startPos: String;
  Temperature, p: Integer;
begin
  // [2000-01-01 00:00:00]  * GPU #0: 80C FAN 50%
  p := Pos(' GPU ', line);
  if p = 0 then exit;
  line := copy(line, p, Length(line) - p + 1);

  p := Pos(':', line);
  if p = 0 then exit;
  startPos := copy(line, p, Length(line) - p + 1);

  line := getCharsBetween(line, ': ', 'C FAN');
  if line = '' then Exit;

  Temperature := -100;
  TryStrToInt(line, Temperature);
  if Temperature = -100 then Exit;
  
  OnDosTemperatureOutput(Temperature);
end;

procedure TForm1.OnDosTemperatureOutput(Temperature:Integer);
begin
  EditTemperature.Text := IntToStr(Temperature);
  if Temperature > SpinEditTemperatureLimit.Value then
    OnDosTemperatureExceed(Temperature)
  else
    OnDosTemperatureAllowed(Temperature);
end;

procedure TForm1.OnDosTemperatureExceed(Temperature:Integer);
begin
  Memo1.Lines.Add('Temperature limit exceeded! Stop mining for 2 minutes.');
  StopDos();
  TimerStartDelayed.Interval := 2 * 60 * 1000;
  TimerStartDelayed.Enabled := True;
end;

procedure TForm1.OnDosTemperatureAllowed(Temperature:Integer);
begin
  //EditTemperature.Text := IntToStr(Temperature);
end;



procedure TForm1.TimerStartDelayedTimer(Sender: TObject);
begin
  TTimer(Sender).Enabled := False;
  ButtonStartClick(nil);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  TimerStartDelayed.Enabled := False;
  Memo1.Clear;
  EditPathXmrigNvidia.Clear;
  EditTemperature.Text := '?';                                          
  LoadConfig;
  //TrackDosTemperatureOutput('[2000-01-01 00:00:00]  * GPU #0: 85C FAN 50%');
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  StopDos();
end;

procedure TForm1.ButtonStartClick(Sender: TObject);
begin
  if TimerStartDelayed.Enabled then
  begin
    TimerStartDelayed.Enabled := False;
    Memo1.Lines.Add('Cancel restart mining');
  end;
  StopDos();
  if not FileExists(EditPathXmrigNvidia.Text) then
  begin
    Memo1.Lines.Add('Error: Path to xmrig-nvidia.exe is not valid!');
  end;
  RunDos(EditPathXmrigNvidia.Text);
end;

procedure TForm1.ButtonStopClick(Sender: TObject);
begin
  if TimerStartDelayed.Enabled then
  begin
    TimerStartDelayed.Enabled := False;
    Memo1.Lines.Add('Cancel restart mining');
  end;
  StopDos();
end;

procedure TForm1.ButtonOpenDialogClick(Sender: TObject);
begin
  OpenDialog1.InitialDir := ExtractFileDir(Application.ExeName);
  if not OpenDialog1.Execute then Exit;
  EditPathXmrigNvidia.Text := OpenDialog1.FileName;
  SaveConfig;
end;

procedure TForm1.SpinEditTemperatureLimitChange(Sender: TObject);
begin
  SaveConfig;
end;

end.
