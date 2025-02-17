' Berlinda's Maximite
' Dryer Timer Project
Cls

Rem 7 segment digit data
Data 1,1,1,1,1,1,0  ' 0
Data 0,0,1,0,0,1,0  ' 1
Data 1,0,1,1,1,0,1  ' 2
Data 1,0,1,0,1,1,1  ' 3
Data 0,1,1,0,0,1,1  ' 4
Data 1,1,0,0,1,1,1  ' 5
Data 1,1,0,1,1,1,1  ' 6
Data 1,0,1,0,0,1,0  ' 7
Data 1,1,1,1,1,1,1  ' 8
Data 1,1,1,0,1,1,1  ' 9

' **** SET-UP *****
' Set pins 1 to 11 as digital outputs
For p=1 To 14 : SetPin p,8 : Next p

' temperature selection switch input pin (warm/hot)
tempSwitchPin=15
SetPin tempSwitchPin, 2

' Up/Down button inputs
upButtonPin=16
downButtonPin=17
SetPin upButtonPin, 2
SetPin downButtonPin, 2

' Heater ON LED output
heaterStatusLedPin=18
SetPin heaterStatusLedPin, 8

' Assign relay pins
' NOTE: Give actual function names, once known
relay1Pin=12
relay2Pin=13
relay3Pin=14

Dim relay(4)
Dim status$(1)
status$(0)="OFF"
status$(1)="ON"

' Read segment data into an array
Dim segData(9,6)
For digit=0 To 9
  For seg=0 To 6
    Read bit
    segData(digit,seg)=bit
  Next
Next

' Set up some digit value holders
Dim digit(3)
digit(0)=0
digit(1)=0
digit(2)=0
digit(3)=0

' Initialise mainTimer. This is decremented
' by 0.005 in each displayTickerInt
setTimerSeconds(0) ' in seconds

' Set up display ticker interrupt
SetTick 5, displayTickerInt ' 1/200th second/digit => 50Hz screen updates

' *** MAIN LOOP ***
Do
  setDisplayTimeTo(timerSeconds())

  ' replace below with external buttons instead of keyboard
  k$=Inkey$
  If k$="" Then ' check our H/W buttons
    If Pin(upButtonPin)=0 Then
      k$="+"
      Do While Pin(upButtonPin)=0:Loop
    ElseIf Pin(downButtonPin)=0 Then
      k$="-"
      Do While Pin(downButtonPin)=0:Loop
    EndIf
  EndIf

  If k$="-" Then ' adjust time display down 10 minutes
    If timerSeconds() >= 600 Then ' if at least 10 minutes on the clock
      newTime=Int((timerSeconds()+599)/600)*600-599 ' round up to next whole 10 min
      setTimerSeconds(newTime)
    Else
      setTimerSeconds(0)
    EndIf
  ElseIf k$="=" Or k$="+" Then ' adjust time display up 10 minutes
    If timerSeconds() = 0 Then
      newTime=90*60
      setTimerSeconds(newTime)
    ElseIf timerSeconds() < (90*60) Then
      newTime= (Int(timerSeconds()/600)+1) * 600 + 0.99 ' nearly 1 more second
      setTimerSeconds(newTime)
    EndIf
  ElseIf k$="*" Then ' minus 10 seconds, for debugging
      newTime=timerSeconds()-10
      setTimerSeconds(newTime)
  Else
    For i=1 To 4
      If Asc(k$)=48+i Then
        toggleRelayNumState(i)
      EndIf
    Next
  EndIf

  '********************************
  '* Output control state machine *
  '********************************

  ' Inputs are:
  ' Hot/Warm switch
  ' Timer value
  '    < 5 minutes HEATER=OFF (cold air)
  '    > 5 minutes HEATER=ON (warm or hot air)
  ' Relay Assignments:
  '   Relay 1 = Drum Tumble Motor
  '   Relay 2 = Reserved for possible periodic reverse mode
  '   Relay 3 = Heater 1 (warm)
  '   Relay 4 = Heater 2 (hot)

  ' Drum Tumble Motor on/off
  If timerSeconds() > 0 Then
    setRelayNumToState(1, 1) ' tumble motor on

    ' heater control
    ts=timerSeconds()
    If ts > 300 Then
      setRelayNumToState(2, 1) ' heater 1 on
      Pin(heaterStatusLedPin)=1
      If Pin(tempSwitchPin)=1 Then
        setRelayNumToState(3, 1) ' heater 2 on
      Else
        setRelayNumToState(3, 0) ' heater 2 off
      EndIf
    ElseIf ts < 300 Then ' anti-hysteresis by excluding =300
      setRelayNumToState(2, 0) ' heater 1 off
      setRelayNumToState(3, 0) ' heater 2 off
      Pin(heaterStatusLedPin)=0
    EndIf

  Else
    setRelayNumToState(1, 0) ' tumble motor off
    setRelayNumToState(2, 0) ' heater 1 off
    setRelayNumToState(3, 0) ' heater 2 off
    Pin(heaterStatusLedPin)=0
  EndIf

Loop

' **** END ****

Sub setRelayNumToState(num, state) ' state = 1 or 0
  relay(num) = state
  Pin(relay1Pin+num-1)=state
End Sub

Sub toggleRelayNumState(num)
  relay(num) = Not relay(num)
  Pin(relay1Pin+num-1) = relay(num)
End Sub

Function getRelayNumState(num)
  getRelayState=relay(num)
End Function

Sub setDisplayTimeTo(seconds)
    mins = Int(seconds / 60)
    secs = seconds - (mins * 60)

    digit(0)=Int(mins/10)
    digit(1)=mins-(digit(0)*10)
    digit(2)=Int(secs/10)
    digit(3)=secs-(digit(2)*10)
End Sub

Sub setTimerSeconds(seconds)
  mainTimer200=seconds*200
End Sub

Function timerSeconds()
  timerSeconds = Int(mainTimer200/200)
End Function

' Display Ticker Interrupt
' This int called 200 times a second
displayTickerInt:
  tickerIntActive=1

  ' Decrement our second(x200) counter -- 200 ticks = 1 second
  If mainTimer200 > 199 Then
    mainTimer200 = mainTimer200 - 1
  EndIf

  Pin(curDigit+8)=0       ' turn last displayed digit OFF
  curDigit=curDigit+1     ' increment curDigit
  If curDigit > 3 Then curDigit=0

  ' set up LED segments for this digit(curDigit)
  For seg=0 To 6
    Pin(seg+1)=segData(digit(curDigit), seg)
  Next

  Pin(curDigit+8)=1       ' turn current digit ON

  tickerIntActive=0
IReturn

                                               