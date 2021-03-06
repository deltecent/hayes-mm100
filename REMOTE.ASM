TITLE	'REMOTE CONSOLE FOR CP/M AND THE MICROMODEM 100'

;WRITTEN BY DALE HEATHERINGTON

;COPYRIGHT 1979, D.C. HAYES ASSOCIATES, INC.



;THIS PROGRAM ALLOWS THE USER TO IMPLEMENT THE
;MICROMODEM 100 AS AN ADDITIONAL CONSOLE FOR CP/M.
;IT WILL ONLY WORK WITH VERSION 1.4 BECAUSE IT
;DEPENDS ON THE SPECIAL FEATURE WHICH CHECKS THE
;CONSOLE BUFFER FOR A COMMAND JUST AFTER WARM BOOT.
;THE NAME OF THIS PROGRAM MUST BE IN THIS BUFFER SO
;IT WILL EXECUTE EACH TIME CP/M BOOTS UP.  THE "INSTALL"
;PROGRAM TAKES CARE OF PUTTING THE NAME IN THE BUFFER.
;
;     ------ OPERATION -------
;
;WHEN CP/M BOOTS IT LOOKS IN ITS CONSOLE BUFFER.  IT
;FINDS "REMOTE" AND LOADS IT.  THIS PROGRAM THEN USES
;THE ADDRESS AT LOCATION 6 TO FIND OUT WHERE THE BOTTOM
;OF THE CCP (CONSOLE COMMAND PROCESSOR)  IS.  IT THEN
;RELOCATES ITSELF 512 BYTES BELOW THE CCP AND CHANGES
;THE ADDRESS AT LOCATION 6 TO INDICATE A NEW TOP OF USER
;MEMORY.  IT THEN GETS THE FIRST 5 JUMPS FROM THE CBIOS
;JUMP TABLE AND MOVES THEM INTO ITS OWN MEMORY SPACE.
;THESE JUMPS ARE ALL THE CONSOLE FUNCTIONS.  IT THEN
;PUTS JUMPS TO ITS OWN MICROMODEM 100 CONSOLE ROUTINES
;IN THE CBIOS JUMP TABLE.  IT THEN RETURNS TO CP/M
;WHICH PUTS UP THE PROMPT A>  .

;THE NEW CONSOLE STATUS ROUTINE CHECKS FOR PHONE RINGING
;AND CARRIER DETECT AS WELL AS MODEM CHARACTER RECEIVED.
;IT THEN USES THE OLD CBIOS CONSOLE STATUS VECTOR TO CONTINUE
;ON TO THE CBIOS ROUTINE.

;THE USER OF CP/M AT THE LOCAL CONSOLE WILL NOTICE NO 
;DIFFERENCE IN THE OPERATION OF CP/M EXCEPT THAT LESS
;MEMORY WILL BE AVALABLE FOR TRANSIENT PROGRAMS.  ALSO
;"STAT" WILL ALWAYS RETURN  0 K BYTES LEFT FOR SOME
;UNKNOWN REASON.  WHEN THE PHONE RINGS IT WILL ANSWER
;AND PUT A CARRIER ON THE LINE.  THEN IT WAITS 15 SECONDS
;FOR THE CALLER TO SEND A CARRIER.  IT HANGS UP IF NO
;CARRIER IS DETECTED.  WHEN IT DETECTS A CARRIER IT
;REBOOTS CP/M SO THE CALLER WILL GET THE PROMPT  A> .
;
;IF YOU WANT TO MAKE MODIFICATIONS TO THIS PROGRAM
;MAKE SURE YOU MARK ALL ADDRESS WHICH WILL BE RE-LOCATED
;WITH SOME LABEL AND PUT THAT LABEL IN THE RELOCATION TABLE.
;I USED "RL" FOLLOWED BY A DIGIT FOR LABELS WHOSE SOLE
;PURPOSE WAS TO MARK RELOCATED ADDRESSES.

	PAGE


BDOS	EQU	5	;CP/M DOS ENTRY

DATA	EQU	80H	;MODEM DATA PORT
CCR1	EQU	DATA+1	;CONTROL AND STAT. REGISTER
CCR2	EQU	DATA+2	;CONTROL REGISTER #2
TIMER	EQU	DATA+3	;STARTS TIMER


;BIT FUNCTIONS

EPE	EQU	1	;EVEN PARITY
LS1	EQU	2	;LENGTH SELECT
LS2	EQU	4	;LENGTH SELECT 2
SBS	EQU	8	;STOP BITS
PI	EQU	10H	;PARITY INHIBIT

RRF	EQU	1	;CHARACTER RECEIVED
TRE	EQU	2	;TRANSMITTER EMPTY
PE	EQU	4	;PARITY ERROR
FE	EQU	8	;FRAMING ERROR
OE	EQU	10H	;OVERRUN ERROR
TMR	EQU	20H	;TIMER STATUS 1=TIMED OUT
CD	EQU	40H	;CARRIER DETECT
RI	EQU	80H	;NOT RING DETECT


BRS	EQU	1	;BAUD RATE (300)
TXE	EQU	2	;TRANSMITTER ON
MS	EQU	4	;MODE SELECT (ORIG)
OH	EQU	80H	;OFF HOOK





ORG 100H


	JMP	START
	DB	0,0,0
XBDOS:	DB	0C3H,0,0	;BDOS VECTOR PLACED HERE
START:	CALL	SIGNON
	IN	CCR1
	ANI	CD		;LOOK FOR CARRIER DETECT
	CNZ	ANSBAK		;SIGNON MESSAGE TO MODEM IF CD
	LHLD	BDOS+1		;GET BASE OF BDOS
	LXI	D,-0A00H	;LENGTH OF CCP+512
	DAD	D
	XCHG			;BASE OF CCP -512 TO DE
	LHLD	BDOS+1
	PUSH	H
	XCHG
	SHLD	BDOS+1		;NEW JUMP VECTOR FOR BDOS
	POP	H		;RECOVER OLD VECTOR
	SHLD	XBDOS+1

;ADD THE RELOCATION CONSTANT TO ALL ADDRESSES IN TABLE

	LHLD	6		;GET NEW BDOS ENTRY
	LXI	D,-6
	DAD	D		;SUBTRACT 6
	LXI	D,-256
	DAD	D
	SHLD	OFFSET		;STORE IT
	LXI	H,TABLE	
	SHLD	TBLPNT		;STORE TABLE POINTER
ADD1:	LHLD	TBLPNT		;GET POINTER
	MOV	E,M		;GET LOW BYTE
	INX	H
	MOV	D,M		;GET HIGH BYTE
	MOV	A,E
	ORA	D		;TEST FOR 0 (END OF TABLE)
	JZ	MOVIT
	INX	H		;INC. POINTER
	SHLD	TBLPNT		;SAVE TABLE POINTER
	XCHG			;ADDRESS TO MODIFY TO HL
	INX	H		;POINT TO ADDRESS FIELD
	MOV	E,M		;GET ADDRESS
	INX	H
	MOV	D,M
	PUSH	H		;SAVE POINTER
	LHLD	OFFSET		;GET OFFSET
	DAD	D		;ADD IT TO ADDRESS
	XCHG			;MODIFIED ADR. BACK TO DE
	POP	H		;RECOVER POINTER
	MOV	M,D		;PUT ADDRESS BACK IN MEM.
	DCX	H
	MOV	M,E
	JMP	ADD1		;LOOP
	
;MOVE THIS PROGRAM UP UNDER THE CCP

MOVIT:	LXI	B,512
	LHLD	OFFSET
	LXI	D,256
	DAD	D
	SHLD	SADDR	;RELOCATED STARTING ADDRESS
MV1:	LDAX	D
	MOV	M,A
	INX	H
	INX	D
	DCX	B
	MOV	A,C
	ORA	B
	JNZ	MV1	;MOVE 512 BYTES

RL1:	JMP	$+3	;START EXECUTING RELOCATED CODE

;EXCHANGE THE CBIOS JUMP TABLE WITH OUR SPECIAL TABLE.

	LHLD	1	;GET CBIOS ADDRESS
	DCX	H
	DCX	H
	DCX	H
RL2:	LXI	D,XBOOT
	MVI	B,15	;15 BYTES OF JUMP TABLE TO MOVE
MV3:	MOV	C,M	;GET A CBIOS BYTE
	LDAX	D	;GET OUR BYTE
	MOV	M,A	;PUT OUR BYTE IN CBIOS
	MOV	A,C
	STAX	D	;PUT CBIOS BYTE IN OUR TABLE
	INX	D
	INX	H
	DCR	B
RL3:	JNZ	MV3	;LOOP 15 TIMES
	RET		;BACK TO CPM

BOOT:	CALL	RL1	;EXCHANGE JUMP TABLES
	LHLD	1
	DCX	H
	DCX	H
	DCX	H
	PCHL	;DO CPM BOOT

WBOOT:	CALL	RL1
	JMP	0



;THIS IS THE CONSOLE STATUS CHECK ROUTINE FOR THE
;MODEM.  IT ALSO CHECKS FOR CARRIER DETECT AND RINGING.
;WHEN FINISHED IT GOES TO THE ORIGINAL CBIOS ROUTINE.

CONST:	IN	CCR1		;CHECK FOR CHAR. IN MODEM
	ANI	RRF
	MVI	A,255
	RNZ			;RET. 255 IF TRUE
	IN	CCR1		;CHECK FOR CARRIER
	ANI	CD
RL5:	JNZ	CK1
	MVI	A,0
	OUT	CCR2		;NO CARRIER, HANG UP
CK1:	IN	CCR1		;TEST FOR RING
	ANI	RI
RL0:	JNZ	XCONST		;IF NO RING GO TO LOCAL CONSOLE
	MVI	A,OH+TXE+BRS	;ANSWER THE PHONE
	OUT	CCR2
	MVI	A,PI+LS1+LS2
	OUT	CCR1		;8 DATA, 1 STOP, NO PARITY
	IN	DATA		;CLEAR OUT UART
	IN	DATA
	MVI	B,150		;WAIT 15 SECONDS FOR CARRIER
RL7:	CALL	WAIT100		;100 MS WAIT
	IN	CCR1		
	ANI	CD		;LOOK FOR CARRIER
	JNZ	0		;WARM BOOT CP/M
	DCR	B
RL9:	JNZ	RL7
	XRA	A
	OUT	CCR2		;NO CARRIER, HANG UP
RL10:	JMP	XCONST


;THIS ROUTINE SENDS THE SIGN ON MESSAGE TO THE MODEM.
;IT IS ONLY CALLED ONCE BEFORE IT IS MOVED AND NEVER
;AGAIN.  ITS ADDRESSES ARE NOT RELOCATED.

ANSBAK:	LXI	H,MSG		;POINT TO MESSAGE
ANSB1:	MOV	A,M		;GET CHAR.
	CPI	'$'		;END?
	RZ			;QUIT WHEN DONE
	MOV	C,A
	CALL	CO1		;SEND TO MODEM
	INX	H
	JMP	ANSB1


;WAIT  100 MS BEFORE RETURNING

WAIT100: CALL	WAIT50
WAIT50: OUT	TIMER	;START 50 MS TIMER
	PUSH	PSW
WA1:	IN	CCR1
	ANI	TMR	;IS TIME UP?
RL11:	JZ	WA1	;LOOP IF NOT
	POP	PSW
	RET


CONIN:	CALL	CONST	;SEE IF ANY DATA READY
	ORA	A
RL14:	JZ	CONIN	;NO, WAIT UNTIL IT IS
	IN	CCR1
	ANI	RRF	;FROM MODEM?
RL15:	JZ	XCONIN	;NO,MUST BE LOCAL CONSOLE
	IN	DATA
	RET










;THIS IS THE CONSOLE OUTPUT ROUTINE.  FOR THE
;USERS WHO MAY CALL IN WITH PRINTERS IT WILL
;DELAY 100 MS AFTER ALL LINE FEEDS.

CONOUT:	MOV	A,C
	CMA
	OUT	255
	IN	CCR1		;LOOK FOR CARRIER
	ANI	CD
RL12:	JZ	XCONOUT		;BYPASS IF NO CARRIER
RL16:	CALL	CO1		;OUTPUT THE CHARACTER
	CPI	0AH		;WAS IT A LINE FEED
RL17:	CZ	WAIT100		;WAIT 100 MS IF LINE FEED
RL6:	JMP	XCONOUT		;OUT TO LOCAL CONSOLE
CO1:	IN	CCR1
	ANI	TRE
RL13:	JZ	CO1		;LOOP UNTIL TX EMPTY
	MOV	A,C		;GET CHARACTER
	OUT	DATA		;TO MODEM
	RET





;THESE 5 JUMPS ARE EXCHANGED WITH THE FIRST 5 JUMPS
;IN THE CBIOS JUMP TABLE.




XBOOT:	JMP	BOOT
XWBOOT:	JMP	WBOOT
XCONST:	JMP	CONST
XCONIN:	JMP	CONIN
XCONOUT:JMP	CONOUT




;SOME STORAGE LOCATIONS

OFFSET:	DS	2
TBLPNT:	DS	2
SADDR:	DS	2

;TABLE OF ADDRESSES TO ADD RELOCATION CONSTANT TO.

TABLE:	DW	RL0,RL1
	DW	RL2,RL3,RL5,RL6,RL7,RL9,RL10
	DW	RL11,RL12,RL13
	DW	RL14,RL15
	DW	RL16,RL17
	DW	BOOT,WBOOT,WAIT100
	DW	CONIN
	DW	XBOOT,XWBOOT,XCONST
	DW	XCONIN,XCONOUT
	DW	0

;PRINTS SIGN ON MESSAGE.  THIS CODE IS NOT RELOCATED


SIGNON:	LXI	D,MSG	;POINT TO MESSAGE
	MVI	C,9	;PRINT BUFFER CODE
	CALL	5	;CALL BDOS
	RET

MSG:	DB	'D.C. HAYES ASSOCIATES, INC.',0DH,0AH
	DB	'MICROMODEM 100 REMOTE CONSOLE VER. 1.0',0DH,0AH,'$'

	END 100H	;GOOD LUCK
