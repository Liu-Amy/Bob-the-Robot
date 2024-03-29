; middle.asm
; This program includes a basic movement API that allows the
; user to specify a desired heading and speed, and the API will
; attempt to control the robot in an appropriate way.

; This code uses the timer interrupt for the control code.
ORG 0                  ; Jump table is located in mem 0-4
; 	JUMP   Init        ; Reset vector
; 	RETI               ; Sonar interrupt (unused)
; 	JUMP   CTimer_ISR  ; Timer interrupt
; 	RETI               ; UART interrupt (unused)
; 	RETI               ; Motor stall interrupt (unused)

;***************************************************************
;* Initialization
;***************************************************************
Init:
	; Always a good idea to make sure the robot
	; stops in the event of a reset.
	LOAD   Zero
	OUT    LVELCMD     ; Stop motors
	OUT    RVELCMD
	OUT    SONAREN     ; Disable sonar (optional)
	OUT    BEEP        ; Stop any beeping (optional)
	
	CALL   SetupI2C    ; Configure the I2C to read the battery voltage
	CALL   BattCheck   ; Get battery voltage (and end if too low).
	OUT    LCD         ; Display battery voltage (hex, tenths of volts)

WaitForSafety:
	; This loop will wait for the user to toggle SW17.  Note that
	; SCOMP does not have direct access to SW17; it only has access
	; to the SAFETY signal contained in XIO.
	IN     XIO         ; XIO contains SAFETY signal
	AND    Mask4       ; SAFETY signal is bit 4
	JPOS   WaitForUser ; If ready, jump to wait for PB3
	IN     TIMER       ; We'll use the timer value to
	AND    Mask1       ;  blink LED17 as a reminder to toggle SW17
	SHIFT  8           ; Shift over to LED17
	OUT    XLEDS       ; LED17 blinks at 2.5Hz (10Hz/4)
	JUMP   WaitForSafety
	
WaitForUser:
	; This loop will wait for the user to press PB3, to ensure that
	; they have a chance to prepare for any movement in the main code.
	IN     TIMER       ; We'll blink the LEDs above PB3
	AND    Mask1
	SHIFT  5           ; Both LEDG6 and LEDG7
	STORE  Temp        ; (overkill, but looks nice)
	SHIFT  1
	OR     Temp
	OUT    XLEDS
	IN     XIO         ; XIO contains KEYs
	AND    Mask2       ; KEY3 mask (KEY0 is reset and can't be read)
	JPOS   WaitForUser ; not ready (KEYs are active-low, hence JPOS)
	LOAD   Zero
	OUT    XLEDS       ; clear LEDs once ready to continue

;***************************************************************
;* Main code
;***************************************************************
MAIN:
; 	; configure timer interrupts
; 	LOADI  10          ; 10ms * 10 = 0.1s rate, or 10Hz.
; 	OUT    CTIMER      ; turn on timer peripheral
; 	SEI    &B0010      ; enable interrupts from source 2 (timer)
; 	; at this point, timer interrupts will be firing at 10Hz, and
; 	; code in that ISR will attempt to control the robot.
; 	; If you want to take manual control of the robot,
; 	; execute a CLI &B0010 to disable the interrupt.
	OUT		RESETPOS			; RESTORE VARIABLES 
	
	LOAD 	EEEE
	STORE	CURRENTSENSOR						

	LOAD	One
	STORE	LEFT
	
	LOAD	FFFF
	STORE	SENSOR0
	STORE	SENSOR1
	STORE	SENSOR2
	STORE	SENSOR3
	STORE	SENSOR4
	STORE	SENSOR5
	STORE 	TEMPDIST
	STORE	TEMPORARY 

	LOAD	Zero
	STORE	CURRENTANGLE	
	STORE	X
	STORE	Y
	STORE	TEMPVAR
	STORE	HOMEDIST
	STORE	HOMEANGLE
	STORE	CALCX
	STORE	CALCY
	STORE	TEMPTHETA
	STORE	GOHOMEX
	STORE	GOHOMEY
	STORE	TEMPHOME
	STORE	CALCTHETA
	STORE	TEMPX
	STORE	TEMPY
	STORE	CORRECTANGLE
	STORE	FOUND
	STORE	UPANGLE
	STORE	UP
	STORE	XLOCATION
	STORE	YLOCATION
	STORE	ADJUSTHOMEX
	STORE	ADJUSTHOMEY
	STORE 	GOHOMEVAR
	STORE	SETTHETA

	LOAD 	Mask0				; ENABLES SENSOR 0, 2, 3, 5
 	OR 		Mask2
 	OR		Mask3
	OR		Mask5	
  	OUT 	SONAREN 
  	JUMP	GO4FEET
  	
GO4FEET:						; GO FORWARD "4" FEET (2 FEET IN THE CODE)
	LOAD   	FMid        		; GO FORWARD
	OUT    	LVELCMD     
	OUT    	RVELCMD	
	
	IN		XPOS				; GET XPOS OF THE ROBOT
	SUB		TwoFeet				; SUBTRACT 4 FEET
	JNEG	GO4FEET				; IF YOU HAVE NOT GONE 4 FEET, JUMP UP
	JUMP	ROTATE				; IF YOU HAVE GONE 4 FEET, START ROTATION		

ROTATE:
	LOAD	FMid				; START CALCULATION FOR ROTATING 90 DEGREES TO THE LEFT
	OUT		RVELCMD
	IN 		THETA 
	STORE	CALCTHETA
	ADDI	-180
	JPOS	ADJUST				; ROBOT ROTATED SLIGHTLY TO THE RIGHT. NEED TO ADJUST THETA
	JUMP	ROTATE2				; DO NOT NEED TO ADJUST THETA. ROTATE
	
ADJUST:							; ADJUST THETA
	LOAD	CALCTHETA
	ADDI	-359
	STORE	CALCTHETA
	JUMP	ROTATE2			
	
ROTATE2:						; ROTATE 90 DEGREES TO THE LEFT
	LOAD	CALCTHETA			 
	ADDI	-60
	JNEG	ROTATE				; IF YOU HAVE NOT ROTATE ENOUGH, ROTATE AGAIN
	STORE	SETTHETA
	JUMP	FORWARD				; IF YOU HAVE ROTATED 90 DEGREES, GO FORWARD
	
FORWARD:						; GO FORWARD UNTIL YOU DETECT SOMETHING
	IN 		THETA
	OUT		SSEG2
	
	LOAD	FMid				
	OUT    	LVELCMD     		
	OUT    	RVELCMD	
	JUMP	SEARCH0			
	
SEARCH0:						; SEARCH FOR THINGS NEAR SONAR0
	LOAD	EEEE				; THIS IS THE "CLOSEST" OBJECT
	STORE	CURRENTSENSOR
	
	IN 		DIST0				; STORE THE VALUE OF DIST0 TO SENSOR0, IF THERE IS SOMETHING 4 FEET AWAY 
	STORE	TEMPDIST
	STORE	TEMPORARY
	LOAD	TEMPORARY
	SUB		TWOFEET
	SUB		TWOFEET		
 	JPOS	SEARCH2				; IF THERE IS NOTHING 4 FEET AWAY, MORE FORWARD
	JNEG	FOUND0				; THERE IS SOMETHING CLOSE BY, STORE IT TO SENSOR0

FOUND0:							; IT SENSES SOMETHING, THAT IS LESS THAN 4 FEET AWAY. STORE IT IN SENSOR0
	LOAD	One
	STORE	FOUND
	LOAD	TEMPDIST			
	STORE	SENSOR0
	JUMP 	FINDSMALL0		

FINDSMALL0:	
	LOAD	CURRENTSENSOR		; IS SONAR0 THE CLOSEST OBJECT?
	SUB		SENSOR0
	JPOS	CHOSE0				; IF SENSOR0 IS CLOSER THAN THE CLOSEST SENSOR, STORE SENSOR0 AS THE CLOSEST
 	JNEG	SEARCH2				; ELSE, DETECT OBJECTS IN SENSOR2

CHOSE0:							; UPDATE INFORMATION TO MAKE SENSOR0 AS THE CLOSEST OBJECT DETECTED
	LOAD	SENSOR0
	STORE	CURRENTSENSOR		; CURRENTSENSOR <= SENSOR0 VALUE
	LOAD	NINTY
	STORE	CURRENTANGLE		; CURRENTANGLE <= 90
	LOAD	One
	STORE	LEFT				; LEFT <= 0
 	JUMP	SEARCH2

SEARCH2:	
	IN 		DIST2				; DETECT FOR OBJECTS WITH SENSOR2
	STORE	TEMPDIST
	STORE	TEMPORARY
	LOAD	TEMPORARY
	SUB		TwoFeet				; 
	JPOS	SEARCH3				; IF MORE THAN 2 FEET AWAY, DO NOT STORE AND MOVE ON TO SEARCH FOR OBJECTS WITH SENSOR3
	JNEG	FOUND2				; IF LESS THAN 2 FEET AWAY
	
FOUND2:				
	LOAD	One					; ROBOT DETECTS SOMETHING WITH SENSOR2, STORE DISTANCE IN SENSOR2
	STORE	FOUND
	LOAD	TEMPDIST			
	STORE	SENSOR2
	JUMP 	FINDSMALL2
	
FINDSMALL2:	
	LOAD	CURRENTSENSOR		; IS SENSOR2 CLOSER THAN THE CURRENT SMALLEST?
	SUB		SENSOR2
	JPOS	CHOSE2				; OBJECT DETECTED WITH SENSOR2 IS THE SMALLEST CURRENTLY
	JNEG	SEARCH3				; OBJECT IS NOT THE SMALLEST

CHOSE2:
	LOAD	SENSOR2				; CURRENTSENSOR <= SENSOR2
	STORE	CURRENTSENSOR
	LOAD	Zero				; CURRENTANGLE <= 0
	STORE	CURRENTANGLE
	LOAD	One					; UP <= 1
	STORE	UP
	STORE	LEFT				; LEFT <= 1
	JUMP	SEARCH3				; LOOK FOR THIS WITH SENSOR3

SEARCH3:						; DETECT OBJECTS WTIH SENSOR3
	IN 		DIST3				
	STORE	TEMPDIST
	STORE	TEMPORARY
	LOAD	TEMPORARY
	SUB		TwoFeet				
	JPOS	SEARCH5				; IF MORE THAN 2 FEET AWAY, DO NOT STORE AND MOVE ON TO LOOK FOR THINGS WITH SENSOR 5
	JNEG	FOUND3				; DETECTED OBJECT IS CLOSER THAN 2 FEET
	
FOUND3:							; SENSOR3 <= DISTANCE TO DETECTED OBJECT 
	LOAD	One
	STORE	FOUND
	LOAD	TEMPDIST			
	STORE	SENSOR3
	JUMP 	FINDSMALL3

FINDSMALL3:						; IS SENSOR3 CLOSER THAN THE CURRENT SMALLEST?
	LOAD	CURRENTSENSOR		
	SUB		SENSOR3
	JPOS	CHOSE3				; OBJECT DETECTED WITH SENSOR3 IS THE SMALLEST CURRENTLY
	JNEG	SEARCH5				; OBJECT IS NOT THE SMALLEST
	
CHOSE3:							
	LOAD	SENSOR3				; CURRENTSENOR <= SENSOR3
	STORE	CURRENTSENSOR
	LOAD	Zero				; CURRENTANGLE <= 2
	STORE	CURRENTANGLE	
	LOAD 	One					; UP <= 1
	STORE	UP
	STORE	LEFT				; LEFT <= 1
	JUMP	SEARCH5	

SEARCH5:						; DETECT OBJECTS WTIH SENSOR5
	IN 		DIST5				
	STORE	TEMPDIST
	STORE	TEMPORARY
	LOAD	TEMPORARY
	SUB		TWOFEET
	SUB		TWOFEET		
	JNEG	FOUND5				; FOUND SOMETHING IN SENSOR5 LESS THAN 4 FEET AWAY WITH SENSOR5
	
	LOAD	FOUND				; DID NOT FIND ANYTHING IN SENSOR5, BUT THERE WAS SOMETHING FOUND PREVIOUSLY? 
	JZERO	FORWARD				; IF NO, MOVE FORWARD
	JPOS	ROTATETOWARDSOBJECT	; IF YES, ROTATE TOWARDS THE CLOSEST OBJECT

FOUND5:							; SENSOR5 <= DISTANCE TO DETECTED OBJECT
	LOAD	One
	STORE	FOUND
	LOAD	TEMPDIST			
	STORE	SENSOR5
	JUMP 	FINDSMALL5

FINDSMALL5:
	LOAD	CURRENTSENSOR 		; IS SENSOR5 CLOSER THAN THE CURRENT SMALLEST?
	SUB		SENSOR5
	JPOS	CHOSE5				; IF SENSOR5 IS CLOSER THAN THE CLOSEST SENSOR, STORE SENSOR5 AS THE CLOSEST
	JNEG	ROTATETOWARDSOBJECT	; ELSE, ROTATE TOWARDS THE CLOSEST OBJECT.

CHOSE5:
	LOAD	SENSOR5				; CURRENTSENSOR <= SENSOR5
	STORE	CURRENTSENSOR
	LOAD	NEGNINTY			; CURRENTANFLE <= -90
	STORE	CURRENTANGLE
	LOAD	Zero				; LEFT <= 0
	STORE	LEFT
	JUMP	ROTATETOWARDSOBJECT
			
ROTATETOWARDSOBJECT:			; ROTATE TO FACE TEH OBJECT
	LOAD	LEFT				; IF ON THE RIGHT OF THE ROBOT, TURN RIGHT; LEFT=0 MEANS THAT IT IS ON THE RIGHT
	JZERO	ROTATERIGHT
	ADDI	-1					; IF ON THE LEFT OF THE ROBOT, TURN LEFT
	JZERO	ROTATELEFT	
	
ROTATERIGHT:					; TURN RIGHT UNTIL YOU FACE THE OBJECT
	LOAD	FMid				
	OUT 	LVELCMD	
	IN 		THETA
	SUB		CURRENTANGLE
	JNEG	ROTATERIGHT
	JUMP	MOVESETUP

ROTATELEFT:						; TURN LEFT UNTIL YOU FACE THE OBJECT
	LOAD	FMid			
	OUT		RVELCMD
	IN 		THETA 
	SUB		CURRENTANGLE	
	JNEG	ROTATELEFT
	JUMP	MOVESETUP	
	
MOVESETUP:						; STORES THE XPOS AND YPOS BEFORE THE ROBOT MOVES TOWARDS THE CLOSEST OBJECT
	IN		XPOS				; STORE THE CURRENT X POSITION OF THE ROBOT
	STORE	X
	IN		YPOS				; STORE THE CURRENT Y POSITION OF THE ROBOT
	STORE	Y
	JUMP 	MOVETOWARDSOBJECT
	
MOVETOWARDSOBJECT:				; MOVE FORWARD TOWARDS THE CLOSEST OBJECT
	LOAD	FMid			
	OUT    	LVELCMD     
	OUT    	RVELCMD	
	
	LOAD	CURRENTSENSOR		; STORE THE DISTANCE OF CLOSEST OBJECT TO TEMPVAR
	STORE 	TEMPVAR
	IN 		XPOS
	STORE	TEMPX
	IN		YPOS
	STORE	TEMPY
	LOAD	X					; L2X <- (X-XPOS) 
	SUB		TEMPX				
	STORE	L2X
	LOAD	Y					; L2Y <- (Y-YPOS)
	SUB		TEMPY
	STORE	L2Y
	CALL	L2Estimate			; L2Estimate = SQRT((X-XPOS)^2+(Y-YPOS)^2)
	SUB		TEMPVAR				; DISTANCE TO CLOSEST OBJECT
	ADD		HALFFEET			; FOR CALIBRATION
	
	JNEG	MOVETOWARDSOBJECT	; IF ROBOT HAS NOT ROTATED FAR ENOUGH, REPEAT
	
	IN		XPOS				; XLOCATION = XPOS OF ROBOT AFTER IT REACHED THE OBJECT
	STORE	XLOCATION
	IN		YPOS				; YLOCATION = YPOS OF ROBOT AFTER IT REACHED THE OBJECT
	STORE	YLOCATION
	
	LOAD	UP					; IF THE ROBOT FOUND SOMETHING IN THE MIDDLE
	ADDI	-1
	JZERO	BACKUPUPSETUP
	
	LOAD	LEFT				; IF THE ROBOT FOUND SOMETHING TO ITS RIGHT 
	JZERO	BACKUPRIGHTSETUP
	
	LOAD	LEFT				; IF THE ROBOT FOUND SOMETHING TO ITS LEFT 
	ADDI	-1
	JZERO	BACKUPLEFTSETUP

BACKUPUPSETUP:					; CALCULATES THE LOCATION WHERE THE ROBOT NEEDS TO BACK UP TO 
	LOAD	YLOCATION
	SUB		TINYFEET
	STORE	YLOCATION
	JUMP	BACKUPUP

BACKUPUP:						; BACK UP BY MOVING DOWN 
	LOAD	RMid
	OUT		LVELCMD
	OUT		RVELCMD
	
	IN		YPOS
	SUB		YLOCATION
	JPOS	BACKUPUP
	IN		THETA					
	STORE	TEMPTHETA			; STORE THE THETA AFTER BACKING UP 
	JUMP	CALCHOMEANGLE		; THE ROBOT HAS ROTATED ENOUGH

BACKUPRIGHTSETUP:				; CALCULATES THE LOCATION WHERE THE ROBOT NEEDS TO BACK UP TO 
	LOAD	XLOCATION
	SUB		TINYFEET
	STORE	XLOCATION
	JUMP	BACKUPRIGHT

BACKUPRIGHT:					; BACK UP BY MOVING LEFT 
	LOAD	RMid
	OUT		LVELCMD
	OUT		RVELCMD
	
	IN		XPOS
	SUB		XLOCATION
	JPOS	BACKUPRIGHT
	IN		THETA					
	STORE	TEMPTHETA			; STORE THE THETA AFTER BACKING UP
	JUMP	CALCHOMEANGLE		; THE ROBOT HAS ROTATED ENOUGH

BACKUPLEFTSETUP:				; CALCULATES THE LOCATION WHERE THE ROBOT NEEDS TO BACK UP TO 	
	LOAD	XLOCATION			
	ADD		TINYFEET
	STORE	XLOCATION
	JUMP	BACKUPLEFT

BACKUPLEFT:						; BACK UP BY RIGHT
	LOAD	RMid
	OUT		LVELCMD
	OUT		RVELCMD
	
	IN		XPOS
	SUB		XLOCATION
	JNEG	BACKUPLEFT
	
	IN		THETA					
	STORE	TEMPTHETA			; STORE THE THETA AFTER BACKING UP 
 	JUMP	CALCHOMEANGLE		; THE ROBOT HAS ROTATED ENOUGH
	
CALCHOMEANGLE:					; ANGLE ROBOT NEEDS TO ROTATE TO FACE HOME	
	IN		XPOS				; HOMEANGLE = ARCTAN(YPOS/XPOS)
	STORE	AtanX 
	IN		YPOS
	STORE 	AtanY
	CALL	Atan2
	STORE	HOMEANGLE		

	LOAD	Deg180				; ANGLE FOR ROTATING RIGHT
	ADD		HOMEANGLE			; CORRECTANGLE = 180 + HOMEANGLE + 20
	STORE	CORRECTANGLE
	
	LOAD	Deg90				; ANGLE FOR WHEN THE ROBOT IS IN THE MIDDLE 
	ADD		HOMEANGLE			; UPANGLE = 90 + HOMEANGLE
	STORE	UPANGLE
	
	LOAD	UP					; IF THE ROBOT IS IN THE MIDDLE
	ADDI	-1
	JZERO	HOMEROTATEUP
	
	LOAD	LEFT				; IF THE OBJECT IS TO THE RIGHT OF THE ROBOT, TURN RIGHT TO FACE HOME
	JZERO	HOMEROTATERIGHT
	
	LOAD	LEFT				; IF THE OBJECT IS TO THE LEFT OF THE ROBOT, TURN LEFT TO FACE HOME
	ADDI	-1
	JZERO	HOMEROTATELEFT

HOMEROTATEUP:					; ROTATION FOR WHEN THE ROBOT IS IN THE MIDDLE TO FACE HOME	
	LOAD	FMid				; ROTATE CORRECT DEGREES TO THE LEFT
	OUT		RVELCMD
	
	IN 		THETA 
	SUB		TEMPTHETA
	SUB		UPANGLE	
	JNEG	HOMEROTATEUP
	
	IN 		XPOS				; X POSITION OF ROBOT AFTER IT ROTATES TOWARDS HOME 
	STORE	GOHOMEX				
	IN		YPOS				; Y POSITION OF ROBOT AFTER IT ROTATES TOWARDS HOME
	STORE	GOHOMEY	
	IN 		THETA				; STORE THE THETA OF THE ROBOT BEFORE IT ROTATES TOWARDS HOME
	STORE	TEMPTHETA
	JUMP	CALCHOMEDIST
	
HOMEROTATERIGHT:				; ROTATES CORRECT DEGREES TO THE RIGHT TO FACE HOME 
	LOAD	FMid
	OUT 	LVELCMD
	
	IN		THETA				
	SUB		CORRECTANGLE
	JPOS	HOMEROTATERIGHT
	
	IN 		XPOS				
	STORE	GOHOMEX				; X POSITION OF ROBOT AFTER IT ROTATES TOWARDS HOME 
	IN		YPOS
	STORE	GOHOMEY				; Y POSITION OF ROBOT AFTER IT ROTATES TOWARDS HOME 
	IN 		THETA				; STORE THE THETA OF THE ROBOT AFTER IT ROTATES TOWARDS HOME
	STORE	TEMPTHETA
	JUMP	CALCHOMEDIST

HOMEROTATELEFT:	
	LOAD	FMid				; ROTATE CORRECT DEGREES TO THE LEFT TO FACE HOME
	OUT		RVELCMD
	
	IN 		THETA 
	SUB		TEMPTHETA
	SUB		HOMEANGLE	
	JNEG	HOMEROTATELEFT
	
	IN 		XPOS				
	STORE	GOHOMEX				; X POSITION OF ROBOT AFTER IT ROTATES TOWARDS HOME 
	IN		YPOS
	STORE	GOHOMEY				; Y POSITION OF ROBOT AFTER IT ROTATES TOWARDS HOME 
	IN 		THETA				; STORE THE THETA OF THE ROBOT AFTER IT ROTATES TOWARDS HOME
	STORE	TEMPTHETA
	JUMP	CALCHOMEDIST
	
CALCHOMEDIST:					; CALCULATES THE DISTANCE FROM THE ROBOT TO HOMEBASE
	IN		XPOS
	STORE 	L2X
	IN		YPOS
	STORE	L2Y
	CALL	L2Estimate			
	STORE	HOMEDIST			; HOMEDIST = SQRT((RESETX-XPOS)^2+(RESETX-YPOS)^2)
	JUMP	GOHOME

GOHOME:
	LOAD	FMid				; MOVE FORWARD TO GO HOME 
	OUT    	LVELCMD     
	OUT    	RVELCMD	
	IN		XPOS
	STORE	TEMPX
	IN		YPOS
	STORE	TEMPY
	
	LOAD	HOMEDIST			; STORE THE DISTANCE OF CLOSEST OBJECT TO TEMPVAR
	STORE 	TEMPHOME
	LOAD	GOHOMEX				; L2X <- (GOHOMEX-XPOS) 
	SUB		TEMPX				
	STORE	L2X
	LOAD	GOHOMEY				; L2Y <- (GOHOMEY-YPOS)
	SUB		TEMPY
	STORE	L2Y
	CALL	L2Estimate			; L2Estimate = SQRT((XPOS-X)^2+(YPOS-Y)^2)
	SUB		TEMPHOME	
; 	ADD		HALFFEET	
	STORE	GOHOMEVAR
	
	IN		DIST2				
	SUB		TwoFeet
	OUT		SSEG2
	JNEG	ADJUSTHOME			; IF THE ROBOT IS TOO CLOSE TO THE WALL, ADJUST IT'S WAY HOME
	
	IN		DIST3				
	SUB		TwoFeet
	OUT		SSEG2
	JNEG	ADJUSTHOME
	
	LOAD	GOHOMEVAR
	JNEG	GOHOME				; HAS NOT REACHED HOME YET
	
	JUMP 	DIE

ADJUSTHOME:
	IN 		XPOS				; ADJUSTHOMEX <= XPOS
	STORE	ADJUSTHOMEX
	IN		YPOS				; ADJUSTHOMEY <= YPOS
	STORE	ADJUSTHOMEY
	
	LOAD	ADJUSTHOMEX
	SUB		ADJUSTHOMEY
	JPOS	ADJUSTHOMERIGHT		; XPOS > YPOS, ROTATE RIGHT
	JNEG	ADJUSTHOMELEFT		; XPOS < YPOS, ROTATE LEFT

ADJUSTHOMERIGHT:				; ROTATE RIGHT TO FACE LEFT WALL
	IN 		THETA
	OUT		SSEG2
	
	LOAD	FSlow
	OUT		LVELCMD
	IN 		THETA
	ADDI	-190
	JPOS	ADJUSTHOMERIGHT
	JNEG	TOHOMEBASERIGHT

TOHOMEBASERIGHT:				; KEEP ON GOING FORWARD UNTIL, ROBOT SENSES WALL WITH SENSOR2
	IN 		THETA
	OUT		SSEG2
	
	LOAD	FMid
	OUT		LVELCMD
	OUT		RVELCMD
	IN		DIST2
	SUB		TwoFeet
	JPOS	TOHOMEBASERIGHT
	IN		DIST3
	SUB		HALFFEET
	JPOS	TOHOMEBASERIGHT
	JNEG	DIE	

ADJUSTHOMELEFT: 				; ROTATE LEFT UNTIL ROBOT FACES BOTTOM WALL
	IN 		THETA
	OUT		SSEG2
	
	LOAD	FSlow
	OUT		RVELCMD
	IN 		THETA
	ADDI	-255
	JNEG	ADJUSTHOMELEFT
	JPOS	TOHOMEBASELEFT

TOHOMEBASELEFT:					; KEEP ON GOING FORWARD UNTIL, ROBOT SENSES WALL WITH SENSOR2
	IN 		THETA
	OUT		SSEG2
	
	LOAD	FMid
	OUT		LVELCMD
	OUT		RVELCMD
	IN		DIST2
	SUB		TwoFeet
	JPOS	TOHOMEBASELEFT
	IN		DIST3
	SUB		TwoFeet
	JPOS	TOHOMEBASELEFT
	JNEG	DIE

;***************************************************************
;* End main code
;***************************************************************
	
Die:
; Sometimes it's useful to permanently stop execution.
; This will also catch the execution if it accidentally
; falls through from above.
	CLI    &B1111       ; disable all interrupts
	LOAD   Zero         ; Stop everything.
	OUT    LVELCMD
	OUT    RVELCMD
	OUT    SONAREN
	LOAD   DEAD         ; An indication that we are dead
	OUT    SSEG2        ; "dEAd" on the LEDs
Forever:
	JUMP   Forever      ; Do this forever.
	DEAD:  DW &HDEAD    ; Example of a "local" variable


; Timer ISR.  Currently just calls the control code
CTimer_ISR:
	CALL   ControlMovement
	RETI   ; return from ISR
	
	
; Control code.  If called repeatedly, this code will attempt
; to control the robot to face the angle specified in DTheta
; and match the speed specified in DVel
DTheta:    DW 0
DVel:      DW 0
ControlMovement:
	; convenient way to get +/-180 angle error is
	; ((error + 180) % 360 ) - 180
	IN     THETA
	SUB    DTheta      ; actual - desired angle
	CALL   Neg         ; desired - actual angle
	ADDI   180
	CALL   Mod360
	ADDI   -180
	; A quick-and-dirty way to get a decent velocity value
	; for turning is to multiply the angular error by 4.
	SHIFT  2
	STORE  CMAErr      ; hold temporarily

	
	; For this basic control method, simply take the
	; desired forward velocity and add a differential
	; velocity for each wheel when turning is needed.
	LOAD   DVel
	ADD    CMAErr
	CALL   CapVel      ; ensure velocity is valid
	OUT    RVELCMD
	LOAD   CMAErr
	CALL   Neg         ; left wheel gets negative differential
	ADD    DVel
	CALL   CapVel
	OUT    LVELCMD
	
	RETURN
	CMAErr: DW 0       ; holds angle error velocity

CapVel:
	; cap velocity values for the motors
	ADDI    -500
	JPOS    CapVelHigh
	ADDI    500
	ADDI    500
	JNEG    CapVelLow
	ADDI    -500
	RETURN
CapVelHigh:
	LOADI   500
	RETURN
CapVelLow:
	LOADI   -500
	RETURN

;***************************************************************
;* Subroutines
;***************************************************************


;*******************************************************************************
; Mod360: modulo 360
; Returns AC%360 in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************
Mod360:
	; easy modulo: subtract 360 until negative then add 360 until not negative
	JNEG   M360N
	ADDI   -360
	JUMP   Mod360
M360N:
	ADDI   360
	JNEG   M360N
	RETURN

;*******************************************************************************
; Abs: 2's complement absolute value
; Returns abs(AC) in AC
; Neg: 2's complement negation
; Returns -AC in AC
; Written by Kevin Johnson.  No licence or copyright applied.
;*******************************************************************************
Abs:
	JPOS   Abs_r
Neg:
	XOR    NegOne       ; Flip all bits
	ADDI   1            ; Add one (i.e. negate number)
Abs_r:
	RETURN

;******************************************************************************;
; Atan2: 4-quadrant arctangent calculation                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Original code by Team AKKA, Spring 2015.                                     ;
; Based on methods by Richard Lyons                                            ;
; Code updated by Kevin Johnson to use software mult and div                   ;
; No license or copyright applied.                                             ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; To use: store dX and dY in global variables AtanX and AtanY.                 ;
; Call Atan2                                                                   ;
; Result (angle [0,359]) is returned in AC                                     ;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ;
; Requires additional subroutines:                                             ;
; - Mult16s: 16x16->32bit signed multiplication                                ;
; - Div16s: 16/16->16R16 signed division                                       ;
; - Abs: Absolute value                                                        ;
; Requires additional constants:                                               ;
; - One:     DW 1                                                              ;
; - NegOne:  DW 0                                                              ;
; - LowByte: DW &HFF                                                           ;
;******************************************************************************;
Atan2:
	LOAD   AtanY
	CALL   Abs          ; abs(y)
	STORE  AtanT
	LOAD   AtanX        ; abs(x)
	CALL   Abs
	SUB    AtanT        ; abs(x) - abs(y)
	JNEG   A2_sw        ; if abs(y) > abs(x), switch arguments.
	LOAD   AtanX        ; Octants 1, 4, 5, 8
	JNEG   A2_R3
	CALL   A2_calc      ; Octants 1, 8
	JNEG   A2_R1n
	RETURN              ; Return raw value if in octant 1
A2_R1n: ; region 1 negative
	ADDI   360          ; Add 360 if we are in octant 8
	RETURN
A2_R3: ; region 3
	CALL   A2_calc      ; Octants 4, 5            
	ADDI   180          ; theta' = theta + 180
	RETURN
A2_sw: ; switch arguments; octants 2, 3, 6, 7 
	LOAD   AtanY        ; Swap input arguments
	STORE  AtanT
	LOAD   AtanX
	STORE  AtanY
	LOAD   AtanT
	STORE  AtanX
	JPOS   A2_R2        ; If Y positive, octants 2,3
	CALL   A2_calc      ; else octants 6, 7
	CALL   Neg          ; Negatge the number
	ADDI   270          ; theta' = 270 - theta
	RETURN
A2_R2: ; region 2
	CALL   A2_calc      ; Octants 2, 3
	CALL   Neg          ; negate the angle
	ADDI   90           ; theta' = 90 - theta
	RETURN
A2_calc:
	; calculates R/(1 + 0.28125*R^2)
	LOAD   AtanY
	STORE  d16sN        ; Y in numerator
	LOAD   AtanX
	STORE  d16sD        ; X in denominator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  AtanRatio
	STORE  m16sA
	STORE  m16sB
	CALL   A2_mult      ; X^2
	STORE  m16sA
	LOAD   A2c
	STORE  m16sB
	CALL   A2_mult
	ADDI   256          ; 256/256+0.28125X^2
	STORE  d16sD
	LOAD   AtanRatio
	STORE  d16sN        ; Ratio in numerator
	CALL   A2_div       ; divide
	LOAD   dres16sQ     ; get the quotient (remainder ignored)
	STORE  m16sA        ; <= result in radians
	LOAD   A2cd         ; degree conversion factor
	STORE  m16sB
	CALL   A2_mult      ; convert to degrees
	STORE  AtanT
	SHIFT  -7           ; check 7th bit
	AND    One
	JZERO  A2_rdwn      ; round down
	LOAD   AtanT
	SHIFT  -8
	ADDI   1            ; round up
	RETURN
A2_rdwn:
	LOAD   AtanT
	SHIFT  -8           ; round down
	RETURN
A2_mult: ; multiply, and return bits 23..8 of result
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8            ; move high word of result up 8 bits
	STORE  mres16sH
	LOAD   mres16sL
	SHIFT  -8           ; move low word of result down 8 bits
	AND    LowByte
	OR     mres16sH     ; combine high and low words of result
	RETURN
A2_div: ; 16-bit division scaled by 256, minimizing error
	LOADI  9            ; loop 8 times (256 = 2^8)
	STORE  AtanT
A2_DL:
	LOAD   AtanT
	ADDI   -1
	JPOS   A2_DN        ; not done; continue shifting
	CALL   Div16s       ; do the standard division
	RETURN
A2_DN:
	STORE  AtanT
	LOAD   d16sN        ; start by trying to scale the numerator
	SHIFT  1
	XOR    d16sN        ; if the sign changed,
	JNEG   A2_DD        ; switch to scaling the denominator
	XOR    d16sN        ; get back shifted version
	STORE  d16sN
	JUMP   A2_DL
A2_DD:
	LOAD   d16sD
	SHIFT  -1           ; have to scale denominator
	STORE  d16sD
	JUMP   A2_DL
AtanX:      DW 0
AtanY:      DW 0
AtanRatio:  DW 0        ; =y/x
AtanT:      DW 0        ; temporary value
A2c:        DW 72       ; 72/256=0.28125, with 8 fractional bits
A2cd:       DW 14668    ; = 180/pi with 8 fractional bits

;*******************************************************************************
; Mult16s:  16x16 -> 32-bit signed multiplication
; Based on Booth's algorithm.
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: does not work with factor B = -32768 (most-negative number).
; To use:
; - Store factors in m16sA and m16sB.
; - Call Mult16s
; - Result is stored in mres16sH and mres16sL (high and low words).
;*******************************************************************************
Mult16s:
	LOADI  0
	STORE  m16sc        ; clear carry
	STORE  mres16sH     ; clear result
	LOADI  16           ; load 16 to counter
Mult16s_loop:
	STORE  mcnt16s      
	LOAD   m16sc        ; check the carry (from previous iteration)
	JZERO  Mult16s_noc  ; if no carry, move on
	LOAD   mres16sH     ; if a carry, 
	ADD    m16sA        ;  add multiplicand to result H
	STORE  mres16sH
Mult16s_noc: ; no carry
	LOAD   m16sB
	AND    One          ; check bit 0 of multiplier
	STORE  m16sc        ; save as next carry
	JZERO  Mult16s_sh   ; if no carry, move on to shift
	LOAD   mres16sH     ; if bit 0 set,
	SUB    m16sA        ;  subtract multiplicand from result H
	STORE  mres16sH
Mult16s_sh:
	LOAD   m16sB
	SHIFT  -1           ; shift result L >>1
	AND    c7FFF        ; clear msb
	STORE  m16sB
	LOAD   mres16sH     ; load result H
	SHIFT  15           ; move lsb to msb
	OR     m16sB
	STORE  m16sB        ; result L now includes carry out from H
	LOAD   mres16sH
	SHIFT  -1
	STORE  mres16sH     ; shift result H >>1
	LOAD   mcnt16s
	ADDI   -1           ; check counter
	JPOS   Mult16s_loop ; need to iterate 16 times
	LOAD   m16sB
	STORE  mres16sL     ; multiplier and result L shared a word
	RETURN              ; Done
c7FFF: DW &H7FFF
m16sA: DW 0 ; multiplicand
m16sB: DW 0 ; multipler
m16sc: DW 0 ; carry
mcnt16s: DW 0 ; counter
mres16sL: DW 0 ; result low
mres16sH: DW 0 ; result high

;*******************************************************************************
; Div16s:  16/16 -> 16 R16 signed division
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: results undefined if denominator = 0.
; To use:
; - Store numerator in d16sN and denominator in d16sD.
; - Call Div16s
; - Result is stored in dres16sQ and dres16sR (quotient and remainder).
; Requires Abs subroutine
;*******************************************************************************
Div16s:
	LOADI  0
	STORE  dres16sR     ; clear remainder result
	STORE  d16sC1       ; clear carry
	LOAD   d16sN
	XOR    d16sD
	STORE  d16sS        ; sign determination = N XOR D
	LOADI  17
	STORE  d16sT        ; preload counter with 17 (16+1)
	LOAD   d16sD
	CALL   Abs          ; take absolute value of denominator
	STORE  d16sD
	LOAD   d16sN
	CALL   Abs          ; take absolute value of numerator
	STORE  d16sN
Div16s_loop:
	LOAD   d16sN
	SHIFT  -15          ; get msb
	AND    One          ; only msb (because shift is arithmetic)
	STORE  d16sC2       ; store as carry
	LOAD   d16sN
	SHIFT  1            ; shift <<1
	OR     d16sC1       ; with carry
	STORE  d16sN
	LOAD   d16sT
	ADDI   -1           ; decrement counter
	JZERO  Div16s_sign  ; if finished looping, finalize result
	STORE  d16sT
	LOAD   dres16sR
	SHIFT  1            ; shift remainder
	OR     d16sC2       ; with carry from other shift
	SUB    d16sD        ; subtract denominator from remainder
	JNEG   Div16s_add   ; if negative, need to add it back
	STORE  dres16sR
	LOADI  1
	STORE  d16sC1       ; set carry
	JUMP   Div16s_loop
Div16s_add:
	ADD    d16sD        ; add denominator back in
	STORE  dres16sR
	LOADI  0
	STORE  d16sC1       ; clear carry
	JUMP   Div16s_loop
Div16s_sign:
	LOAD   d16sN
	STORE  dres16sQ     ; numerator was used to hold quotient result
	LOAD   d16sS        ; check the sign indicator
	JNEG   Div16s_neg
	RETURN
Div16s_neg:
	LOAD   dres16sQ     ; need to negate the result
	CALL   Neg
	STORE  dres16sQ
	RETURN	
d16sN: DW 0 ; numerator
d16sD: DW 0 ; denominator
d16sS: DW 0 ; sign value
d16sT: DW 0 ; temp counter
d16sC1: DW 0 ; carry value
d16sC2: DW 0 ; carry value
dres16sQ: DW 0 ; quotient result
dres16sR: DW 0 ; remainder result

;*******************************************************************************
; L2Estimate:  Pythagorean distance estimation
; Written by Kevin Johnson.  No licence or copyright applied.
; Warning: this is *not* an exact function.  I think it's most wrong
; on the axes, and maybe at 45 degrees.
; To use:
; - Store X and Y offset in L2X and L2Y.
; - Call L2Estimate
; - Result is returned in AC.
; Result will be in same units as inputs.
; Requires Abs and Mult16s subroutines.
;*******************************************************************************
L2Estimate:
	; take abs() of each value, and find the largest one
	LOAD   L2X
	CALL   Abs
	STORE  L2T1
	LOAD   L2Y
	CALL   Abs
	SUB    L2T1
	JNEG   GDSwap    ; swap if needed to get largest value in X
	ADD    L2T1
CalcDist:
	; Calculation is max(X,Y)*0.961+min(X,Y)*0.406
	STORE  m16sa
	LOADI  246       ; max * 246
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	STORE  L2T3
	LOAD   L2T1
	STORE  m16sa
	LOADI  104       ; min * 104
	STORE  m16sB
	CALL   Mult16s
	LOAD   mres16sH
	SHIFT  8
	STORE  L2T2
	LOAD   mres16sL
	SHIFT  -8        ; / 256
	AND    LowByte
	OR     L2T2
	ADD    L2T3     ; sum
	RETURN
GDSwap: ; swaps the incoming X and Y
	ADD    L2T1
	STORE  L2T2
	LOAD   L2T1
	STORE  L2T3
	LOAD   L2T2
	STORE  L2T1
	LOAD   L2T3
	JUMP   CalcDist
L2X:  DW 0
L2Y:  DW 0
L2T1: DW 0
L2T2: DW 0
L2T3: DW 0


; Subroutine to wait (block) for 1 second
Wait1:
	OUT    TIMER
Wloop:
	IN     TIMER
	OUT    XLEDS       ; User-feedback that a pause is occurring.
	ADDI   -10         ; 1 second at 10Hz.
	JNEG   Wloop
	RETURN

; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
; SetupI2C must be executed prior to this.
BattCheck:
	CALL   GetBattLvl
	JZERO  BattCheck   ; A/D hasn't had time to initialize
	SUB    MinBatt
	JNEG   DeadBatt
	ADD    MinBatt     ; get original value back
	RETURN
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	LOADI  &H20
	OUT    BEEP        ; start beep sound
	CALL   GetBattLvl  ; get the battery level
	OUT    SSEG1       ; display it everywhere
	OUT    SSEG2
	OUT    LCD
	LOAD   Zero
	ADDI   -1          ; 0xFFFF
	OUT    LEDS        ; all LEDs on
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	Load   Zero
	OUT    BEEP        ; stop beeping
	LOAD   Zero
	OUT    LEDS        ; LEDs off
	OUT    XLEDS
	CALL   Wait1       ; 1 second
	JUMP   DeadBatt    ; repeat forever
	
; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD   I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	IN     I2C_DATA    ; get the returned data
	RETURN

; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	CALL   BlockI2C    ; wait for idle
	LOAD   I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT    I2C_CMD     ; to I2C_CMD register
	LOAD   Zero        ; 0x0000 (A/D port 0, no increment)
	OUT    I2C_DATA    ; to I2C_DATA register
	OUT    I2C_RDY     ; start the communication
	CALL   BlockI2C    ; wait for it to finish
	RETURN
	
; Subroutine to block until I2C device is idle
BlockI2C:
	LOAD   Zero
	STORE  Temp        ; Used to check for timeout
BI2CL:
	LOAD   Temp
	ADDI   1           ; this will result in ~0.1s timeout
	STORE  Temp
	JZERO  I2CError    ; Timeout occurred; error
	IN     I2C_RDY     ; Read busy signal
	JPOS   BI2CL       ; If not 0, try again
	RETURN             ; Else return
I2CError:
	LOAD   Zero
	ADDI   &H12C       ; "I2C"
	OUT    SSEG1
	OUT    SSEG2       ; display error message
	JUMP   I2CError

;***************************************************************
;* Variables
;***************************************************************
Temp:     DW 0 ; "Temp" is not a great name, but can be useful

;***************************************************************
;* Constants
;* (though there is nothing stopping you from writing to these)
;***************************************************************
NegOne:   DW -1
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10

; Some bit masks.
; Masks of multiple bits can be constructed by ORing these
; 1-bit masks together.
Mask0:    DW &B00000001
Mask1:    DW &B00000010
Mask2:    DW &B00000100
Mask3:    DW &B00001000
Mask4:    DW &B00010000
Mask5:    DW &B00100000
Mask6:    DW &B01000000
Mask7:    DW &B10000000
LowByte:  DW &HFF      ; binary 00000000 1111111
LowNibl:  DW &HF       ; 0000 0000 0000 1111

; some useful movement values
OneMeter: DW 961       ; ~1m in 1.04mm units
HalfMeter: DW 481      ; ~0.5m in 1.04mm units
TwoFeet:  DW 586       ; ~2ft in 1.04mm units
Deg90:    DW 90        ; 90 degrees in odometer units
Deg180:   DW 180       ; 180
Deg270:   DW 270       ; 270
Deg360:   DW 360       ; can never actually happen; for math only
FSlow:    DW 100       ; 100 is about the lowest velocity value that will move
RSlow:    DW -100
FMid:     DW 350       ; 350 is a medium speed
RMid:     DW -350
FFast:    DW 500       ; 500 is almost max speed (511 is max)
RFast:    DW -500

MinBatt:  DW 140       ; 14.0V - minimum safe battery voltage
I2CWCmd:  DW &H1190    ; write one i2c byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190    ; write nothing, read one byte, addr 0x90

;***************************************************************
;* IO address space map
;***************************************************************
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
XLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEP:     EQU &H0A  ; Control the beep
CTIMER:   EQU &H0C  ; Configurable timer for interrupts
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
UART_DAT: EQU &H98  ; UART data
UART_RDY: EQU &H98  ; UART status
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONALARM: EQU &HB0  ; Write alarm distance; read alarm register
SONARINT: EQU &HB1  ; Write mask for sonar interrupts
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-359)
RESETPOS: EQU &HC3  ; write anything here to reset odometry to 0
RIN:      EQU &HC8
LIN:      EQU &HC9

;*********************************************************************;
;NEW CONSTANTS;
;*********************************************************************;
NINTY:			DW		150
FOURTYFOUR:		DW		44
TWELVE:			DW		12
NEGNINTY:		DW		270
NEGFOURTYFOUR:	DW		316
NEGTWELVE:		DW		348
EEEE:			DW		9999
AAAA:			DW		&HAAAA
FFFF:			DW		&HFFFF
HALFFEET:		DW		100      	; 146
THREEFIVENINE:	DW		359
TINYFEET:		DW		50
WALLSTOP:		DW		300

;*********************************************************************;
;NEW VARIABLES;
;*********************************************************************;
				ORG 	&H450
CURRENTSENSOR:	DW		9999		; CURRENT SENSOR USED FOR CALCULATIONS
CURRENTANGLE:	DW		0			; CURRENT ANGLE OF THE SENSOR
LEFT:			DW		1			; 1 == LEFT; 0 = RIGHT
UP:				DW		0			; 1 == UP; 0 == LEFT/RIGHT
SENSOR0:		DW		&HFFFF
SENSOR1:		DW		&HFFFF
SENSOR2:		DW		&HFFFF
SENSOR3:		DW		&HFFFF
SENSOR4:		DW		&HFFFF
SENSOR5:		DW		&HFFFF
TEMPDIST:		DW		&HFFFF		; USED FOR CALCULATIONS
TEMPORARY:		DW		&HFFFF	

CALCTHETA:		DW		0
X:				DW		0			; X POSITION OF ROBOT AFTER IT GOES UP THE MIDDLE
Y:				DW		0			; Y POSITION OF ROBOT AFTER IT FOES UP THE MIDDLE 
TEMPVAR:		DW		0			; DISTANCE FROM ROBOT TO CLOSEST OBJECT
HOMEDIST:		DW		0			; DISTANCE FROM THE ROBOT TO HOMEBASE

HOMEANGLE:		DW		0			; ANGLE FROM ROBOT TO HOMEBASE
CALCX:			DW		0		
CALCY:			DW		0
TEMPTHETA:		DW		0			; THE THETA OF THE ROBOT BEFORE IT ROTATES TOWARDS HOME
GOHOMEX:		DW		0			; X POSITION OF ROBOT AFTER IT GOES UP THE MIDDLE

GOHOMEY:		DW		0			; Y POSITION OF ROBOT AFTER IT GOES UP THE MIDDLE
TEMPHOME:		DW		0
FOUND:			DW		0			; IF SOMETHING IS FOUND, FOUND=1. ELSE, FOUND=0
TEMPX:			DW		0
TEMPY:			DW		0

XLOCATION:		DW		0
YLOCATION:		DW		0
CORRECTANGLE:	DW		0
UPANGLE:		DW		0
GOHOMEVAR:		DW 		0

ADJUSTHOMEX:	DW		0
ADJUSTHOMEY:	DW		0
SETTHETA:		DW		0