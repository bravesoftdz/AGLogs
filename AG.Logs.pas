unit AG.Logs;

interface

//{$UNDEF MSWINDOWS}

uses
  {$IFDEF MSWINDOWS}{$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF},{$ENDIF}
  {$IFDEF FPC}FGL{$ELSE}System.Generics.Collections,{$ENDIF}
  {$IFDEF FPC}System.SysUtils{$ELSE}SysUtils{$ENDIF},
  {$IFDEF FPC}System.Classes{$ELSE}Classes{$ENDIF},
  {$IFDEF FPC}System.DateUtils{$ELSE}DateUtils{$ENDIF},
  {$IFDEF FPC}System.SyncObjs{$ELSE}SyncObjs{$ENDIF};

type
  TAGLog=class abstract
    strict protected
      tabs:cardinal;
      tabstr:widestring;
      constructor Create();
    const
      CBaseTab='--------------------------';  
    public
      class function SisebleWordtoStr(i:word;size:int8):widestring;static;inline;
      class function GenerateLogString(s:widestring;o:TObject=nil):widestring;static;inline;
      procedure Tab();virtual;
      procedure UnTab();virtual;
      procedure Write(Text:WideString;o:TObject=nil);overload;virtual;abstract;
      procedure Write(const data);overload;virtual;abstract;
      destructor Destroy();override;
  end;

  TAGRamLog=class(TAGLog)
    public
      buf:WideString;
      constructor Create();overload;
      procedure Write(Text:WideString;o:TObject=nil);overload;override;
  end;

  TAGDiskLog=class(TAGLog)
    strict protected
      LogHandle,ThreadHandle:NativeUInt;
      ThreadID:cardinal;
      buf1:WideString;
      onbuf:boolean;
      Lock:TCriticalSection;
      WantTerminate:Boolean;
    public
      constructor Create(FileName:WideString);overload;
      procedure Init();{override;}stdcall;
      procedure Write(Text:WideString;o:TObject=nil);overload;override;
      destructor Destroy();overload;override;
  end;

  TAGNullLog=class(TAGLog)
    public
      constructor Create();overload;
      procedure Write(Text:WideString;o:TObject=nil);overload;override;
  end;

  {$IFDEF MSWINDOWS}
  TAGCommandLineLog=class(TAGLog)
    strict protected
      CommandLine:THandle;
    public
      constructor Create(Handele:THandle);overload;
      procedure Write(Text:WideString;o:TObject=nil);overload;override;
      destructor Destroy();overload;override;
  end;
  {$ENDIF}

  TAGStreamLog=class(TAGLog)
    strict protected
      stream:TStream;
    public
      constructor Create(stream:TStream);overload;
      procedure Write(Text:WideString;o:TObject=nil);overload;override;
  end;

  TAGCallBackLog=class(TAGLog)
    strict protected type
      TCallBack=procedure(s:string);
      var
        CallBack:TCallBack;
    public
      constructor Create(CallBack:TCallBack);overload;
      procedure Write(Text:WideString;o:TObject=nil);overload;override;
  end;

  TAGMultiLog=class(TAGLog)
    public
      type
        TLogsList=TList<TAGLog>;
      var
        Logs:TLogsList;
      constructor Create(Default:TLogsList);overload;
      procedure Write(Text:WideString;o:TObject=nil);overload;override;
      procedure Tab();override;
      procedure UnTab();override;
      destructor Destroy();overload;override;
  end;

const 
  SisebleWordtoStr:function(i:word;size:int8):widestring=TAGLog.SisebleWordtoStr;
  
Implementation

constructor TAGLog.Create();
begin
Self.Write(sLineBreak+CBaseTab+'Logging init'+CBaseTab+sLineBreak);
end;                  

class function TAGLog.SisebleWordtoStr(i:word;size:int8):widestring;
begin
  Result:=inttostr(i);
  size:=size-Length(Result);
  case size of
  0:Result:=Result;
  1:Result:='0'+Result;
  2:Result:='00'+Result;
  3:Result:='000'+Result;
  4:Result:='0000'+Result;
  end;
end;

class function TAGLog.GenerateLogString(s:widestring;o:TObject=nil):widestring;
var
  D:TDateTime;
begin
D:=Time;
if o<>nil then
  Result:=o.QualifiedClassName+'['+IntToStr(o.GetHashCode)+']:'
else
  Result:='';
Result:='['+Siseblewordtostr(DayOfTheMonth(D),2)+'.'+Siseblewordtostr(MonthOfTheYear(D),2)+'.'+
  Siseblewordtostr(YearOf(D),4)+' '+Siseblewordtostr(HourOfTheDay(D),2)+':'+
  Siseblewordtostr(MinuteOfTheHour(D),2)+':'+Siseblewordtostr(SecondOfTheMinute(D),2)+'.'
  +Siseblewordtostr(MilliSecondOfTheSecond(D),3)+'] '+Result+s+#13#10;
end;

procedure TAGLog.Tab();
begin
inc(tabs);
tabstr:=tabstr+'  ';
end;

procedure TAGLog.UnTab();
begin
dec(tabs);
Delete(tabstr,1,2);
end;

destructor TAGLog.Destroy();
begin
Self.Write(sLineBreak+CBaseTab+'Logging ended'+CBaseTab+sLineBreak);
inherited;
end;

constructor TAGRamLog.Create();
begin
buf:='';
tabs:=0;
tabstr:='';
inherited Create;
end;

procedure TAGRamLog.Write(Text:WideString;o:TObject=nil);
begin
buf:=buf+GenerateLogString(tabstr+Text,o);
end;

constructor TAGDiskLog.Create(FileName:WideString);
begin
{}
Lock:=TCriticalSection.Create;
WantTerminate:=False;
tabs:=0;
tabstr:='';
buf1:='';
LogHandle:=CreateFileW(Pwidechar(FileName),GENERIC_WRITE,0,nil,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
SetFilePointer(LogHandle,0,nil,FILE_END);
ThreadHandle:=CreateThread(nil,0,addr(TAGDiskLog.Init),self,0,ThreadID);
inherited Create;
{}
end;

procedure TAGDiskLog.Init();stdcall;
var
  n:cardinal;
  buf:PWideChar;
begin
buf:='';
while Lock<>nil do
begin
  Lock.Enter;
  if buf<>'' then
    WriteFile(LogHandle,buf^,2*n,n,nil);
  n:=Length(buf1);
  buf:=Pwidechar(Copy(buf1,0,n));
  buf1:='';
  Lock.Leave;
  if WantTerminate then
  begin
    Sleep(0);
    Lock.Enter;
    if buf<>'' then
      WriteFile(LogHandle,buf^,2*n,n,nil);
    n:=Length(buf1);
    buf:=Pwidechar(Copy(buf1,0,n));
    buf1:='';
    Lock.Leave;
    WantTerminate:=False;
    exit;
  end;
  sleep(0);
end;
end;

procedure TAGDiskLog.Write(Text:WideString;o:TObject=nil);
begin
Lock.Enter;
buf1:=buf1+GenerateLogString(tabstr+text,o);
Lock.Leave;
end;

destructor TAGDiskLog.Destroy();
begin
inherited;
WantTerminate:=True;
While WantTerminate do
  sleep(0);
FreeAndNil(Lock);
TerminateThread(ThreadID,0);
CloseHandle(ThreadHandle);
CloseHandle(LogHandle);
end;

constructor TAGNullLog.Create();
begin
inherited;
end;

procedure TAGNullLog.Write(Text:WideString;o:TObject=nil);
begin
end;

{TAGCommandLineLog}

{$IFDEF MSWINDOWS}
constructor TAGCommandLineLog.Create(Handele:THandle);
begin
CommandLine:=Handele;
inherited Create;
end;

procedure TAGCommandLineLog.Write(Text:WideString;o:TObject=nil); 
var
  p:PWideChar;
  a,b:cardinal;   
begin
Text:=GenerateLogString(tabstr+text,o);
p:=addr(Text[1]);
a:=length(Text);
while a<>0 do
begin
  b:=0;
  WriteConsoleW(CommandLine,p,a,b,nil);
  inc(p,b);
  dec(a,b);
end;
end;

destructor TAGCommandLineLog.Destroy();
begin
inherited;
CloseHandle(CommandLine);
end;
{$ENDIF}

{TAGStreamLog}

constructor TAGStreamLog.Create(stream:TStream);
begin
Self.stream:=stream;
inherited Create;
end;

procedure TAGStreamLog.Write(Text:WideString;o:TObject=nil);
var
  s:string;
begin
s:=GenerateLogString(Text,o);
stream.Write(PWideChar(s)^,2*length(s));
end;

{TAGCallBackLog}

constructor TAGCallBackLog.Create(CallBack:TCallBack);
begin
Self.CallBack:=CallBack;
inherited Create;
end;

procedure TAGCallBackLog.Write(Text:WideString;o:TObject=nil);
begin
CallBack(GenerateLogString(Text,o));
end;

{TAGMultiLog}

constructor TAGMultiLog.Create(Default:TList<TAGLog>);
begin
//inherited Create;
if Default<>nil then
  Logs:=Default
else
  Logs:=TList<TAGLog>.Create;
end;

procedure TAGMultiLog.Write(Text:WideString;o:TObject=nil);
var
  i:TAGLog;
begin
for i in Logs.List do
  i.Write(Text,o);
end;

procedure TAGMultiLog.Tab();
var
  i:TAGLog;
begin
for i in Logs.List do
  i.Tab();
end;

procedure TAGMultiLog.UnTab();
var
  i:TAGLog;
begin
for i in Logs.List do
  i.UnTab();
end;

destructor TAGMultiLog.Destroy();
var
  i:TAGLog;
begin
for i in Logs.List do
  i.Free();
FreeAndNil(Logs);
//inherited;
end;

initialization
finalization
end.
