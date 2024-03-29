; SimpleRobotProgram.asm
; Created by Kevin Johnson
; (no copyright applied; edit freely, no attribution necessary)
; This program does basic initialization of the DE2Bot
; and provides an example of some robot control.

; Section labels are for clarity only.

ORG 0  ; Begin program at x000


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
Main: ; "Real" program starts here.
		OUT    RESETPOS    ; reset odometer in case wheels moved after programming

;/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
; All of this code ("EnableSonars" through "SimpleTask") is purely for example.
; It starts the robot moving forward and stops it when either something is
; detected in front of the robot or it has traveled four feet.

EnableSonars:
	; Many convenient constants are defined at the bottom of this file.
	LOAD 	Mask0			; ENABLES SENSOR0
  	OUT 	SONAREN 

  	
  	IN 		DIST0			; DISTANCE FROM ROBOT TO OBJECT
  	STORE	SENSOR0			; STORE IT TO SENSOR0
  	ADDI	-610			; IS THE OBJECT DETECTED WITHIN TWO FEET OF THE ROBOT?
  	JPOS	NOPE			; OBJECT IS FARTHER THAN TWO FEET AWAY FROM THE ROBOT
  	IN		YPOS			; GET Y POSITION OF ROBOT
  	ADD		SENSOR0			; GRIDY -> (YPOS+SENSOR0)/2
  	STORE	Y				; STORES THE Y COORDINATE OF THE OJBECT
  	SHIFT	-1				
  	STORE	GRIDY	

  		
 	IN	 	XPOS			; LOAD CURRENT X COORDINATE 
 	STORE	X				; STORES THE X COORDINATE OF THE OBJECT 
 	STORE	GRIDX			; GRIDX -> XPOS/2
 	SHIFT 	-1				 
 	STORE	GRIDX			

 	LOAD 	GRIDX			; OFFSETs -> (GRIDX-1)4+(GRIDY-1)
 	ADDI 	-1				
 	SHIFT	2
 	ADD		GRIDY
 	ADDI	-1
 	SHIFT	4
 	STORE	OFFSETs
 	
 	LOAD	OBJARRAY		; LOAD ADDRESS OF FIRST INDEX OF 2D ARRAY
 	ADD		OFFSETs			; INDEX TO THE CORRECT INDEX OF 2D ARRAY
 	STORE	ARRAYINDEX		; STORE ADDRESS OF CORRRECT INDEX OF 2D ARRAY
 	
 	LOAD	One				; AC -> 1
 	ISTORE 	ARRAYINDEX		; LOAD 1 TO THE CORRECT INDEX OF THE OCCUPANCY MAP
 	
 	LOAD 	OBJARRAY	
 	ADD 	OFFSETs
 	
 	ILOAD	ARRAYINDEX		; LOAD NUMBER IN THAT INDEX OF THE OCCUPANCY MAP
 	SUB		One				; CHECKS IF THERE IS 1
 	JZERO	OCC				; IF THERE IS A 1, GO TO OCC
 	JUMP	NOPE			; ELSE, GO TO NOPE
 	
	
OCC:	
	LOAD   	FMid			; MOVES IN A CIRCLE
	OUT		LVELCMD	
	JUMP	OCC
; 	IN 		YPOS			; HOW MUCH AS THE ROBOT MOVED IN THE Y DIRECTION
; 	SUB		Y				
; 	JPOS	OCC				; IF NOT, KEEP ON MOVING 
; 	JUMP	DIE				; IF YES (IT REACHED THE OBJECT), STOP

NOPE:
	OUT 	BEEP			; IF THERE IS NOTHING THERE IN THE MAP, BEEP
	LOAD   	FMid			; AND MOVE FORWARD
	OUT    	LVELCMD     
	OUT		RVELCMD			
	JUMP	EnableSonars	; GO BACK TO EnableSonars TO DETECT FOR A OBJECT AGAIN
	
ROTATE:
	LOAD   	FMid        	; defined below
	OUT    	LVELCMD     	; send velocity to left and right wheels
	IN 		THETA			;
	ADDI 	-265			;
	JPOS	ROTATE		
	RETURN			
		
; THIS WORKS PRAISE
; End example code
;/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

; End example code
;/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

	
Die:
; Sometimes it's useful to permanently stop execution.
; This will also catch the execution if it accidentally
; falls through from above.
	LOAD   Zero         ; Stop everything.
	OUT    LVELCMD
	OUT    RVELCMD
	OUT    SONAREN
	LOAD   DEAD         ; An indication that we are dead
	OUT    SSEG2        ; "dEAd" on the LEDs
Forever:
	JUMP   Forever      ; Do this forever.
	DEAD:  DW &HDEAD    ; Example of a "local" variable

	
;***************************************************************
;* Subroutines
;***************************************************************

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
	LOAD   Four
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
;NEW VARIABLES;
;*********************************************************************;
				ORG 	&H100
X:				DW 		1			; THE X COORDINATE OF THE OBJECT
Y: 				DW		1			; THE Y COORDINATE OF THE OBJECT
GRIDX:			DW		1			; THE X COORFINATE OF THE OBJECT ON THE GRID
GRIDY:			DW		1			; THE Y COORDINATE OF THE OBJECT ON THE GRID
OFFSETs:		DW		0			; OBJARRAY + OFFSETS = ARRAYINDEX
ARRAYINDEX:		DW		0			; ADDRESS OF THE CORRECT INDEX OF THE ARRAY
OBJARRAY:		DW		&H150		; ADDRESS OF THE FIRST INDEX OF THE 2D ARRAY/OCCUPANCY GRID

				ORG 	&H150		; START OF THE 2D ARRAY/OCCUPANCY GRID
A11:			DW		0				
A12:			DW		0
A13:			DW		0
A14:			DW		0

A21:			DW		0				
A22:			DW		0
A23:			DW		0
A24:			DW		0

A31:			DW		0				
A32:			DW		0
A33:			DW		0
A34:			DW		0

A41:			DW		0				
A42:			DW		0
A43:			DW		0
A44:			DW		0

A51:			DW		0				
A52:			DW		0
A53:			DW		0
A54:			DW		0

A61:			DW		0				
A62:			DW		0
A63:			DW		0
A64:			DW		0

				ORG 	&H350
SENSOR0:		DW		0
SENSOR1:		DW		0
SENSOR2:		DW		0
SENSOR3:		DW		0
SENSOR4:		DW		0
SENSOR5:		DW		0
SENSOR6:		DW		0
SENSOR7:		DW		0