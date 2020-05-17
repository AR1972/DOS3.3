	TITLE MSLPT - DOS 3.3						  ;3.30
;----------------------------------------------------------------
;								:
;	P R N - PRINTER DEVICE					:
;								:
;								:
;   This file contains the Printer Device Driver.  The		:
; printer driver handles calls to the printers.  Four devices	:
; use this code: PRN, LPT1, LPT2, and LPT3.  The beginning	:
; of the interrupt entry point for these device sets the	:
; variable AUXNUM in the msbio.asm module.  The number is	:
; in AUXNUM dictates which device will to written to: 0 for	:
; PRN and LPT1, 1 for LPT2, and 2 for LPT3.			:
;								:
;   The routines in this files are:				:
;								:
;	routine 		function			:
;	------- 		--------			:
;	PRN$WRIT		Write to printer device 	:
;	PRN$STAT		Printer status routine		:
;	PRN$TilBusy		Print spooler routine		:
;	Prn$GenIOCTL		Generic IOCTL routine		:
;								:
;  These routines are not called directly.  Call are made via	:
; the strategy and interrupt entry point (see Device Header).	:
;								:
;----------------------------------------------------------------

	test=0								  ;3.30
	INCLUDE MSGROUP.INC	;DEFINE CODE SEGMENT			  ;3.30
	INCLUDE MSEQU.INC						  ;3.30
	INCLUDE MSMACRO.INC						  ;3.30
	INCLUDE DEVSYM.INC						  ;3.30
	INCLUDE IOCTL.INC						  ;3.30
									  ;3.30
	EXTRN BUS$EXIT:NEAR		;MSBIO1 			  ;3.30
	EXTRN ERR$CNT:NEAR		;MSBIO1 			  ;3.30
	EXTRN CMDERR:NEAR		;MSBIO1 			  ;3.30
	EXTRN GETDX:NEAR		;MSBIO1 			  ;3.30
	EXTRN EXIT:NEAR 		;MSBIO1 			  ;3.30
	EXTRN ERR$EXIT:NEAR		;MSBIO1 			  ;3.30
;DATA									  ;3.30
	EXTRN PTRSAV:DWORD		;MSBIO1 			  ;3.30
	EXTRN TIMDEV:WORD		;MSCLOCK			  ;3.30
	EXTRN LPT2DEV:WORD		;MSBIO2 			  ;3.30
	EXTRN WAIT_COUNT:WORD		;MSDATA 			  ;3.30
	EXTRN PRINTDEV:BYTE		;MSDATA 			  ;3.30
									  ;3.30


; IBM ROM STATUS BITS (I DON'T TRUST THEM, NEITHER SHOULD YOU)            ;3.30
									  ;3.30
NOTBUSYSTATUS	=   10000000B		; NOT BUSY			  ;3.30
ACKSTATUS	=   01000000B		; ACKNOWLEDGE (FOR WHAT?)	  ;3.30
NOPAPERSTATUS	=   00100000B		; NO MORE PAPER 		  ;3.30
SELECTEDSTATUS	=   00010000B		; THE PRINTER SAID IT WAS SELECTED;3.30
IOERRSTATUS	=   00001000B		; SOME KINDA ERROR		  ;3.30
RESERVED	=   00000110B		; NOPS				  ;3.30
TIMEOUTSTATUS	=   00000001B		; TIME OUT.			  ;3.30
									  ;3.30
									  ;3.30
; WARNING!!!  THE IBM ROM DOES NOT RETURN JUST ONE BIT.  IT RETURNS A	  ;3.30
; WHOLE SLEW OF BITS, ONLY ONE OF WHICH IS CORRECT.			  ;3.30
									  ;3.30

;----------------------------------------------------------------
;								:
;		WRITE TO PRINTER DEVICE 			:
;								:
;   CX has count of bytes to be printed 			:
;   ES:DI point to source buffer contains characters		:
;   AuxNum (in msbio.asm) has printer number			:
;								:
;----------------------------------------------------------------
	PUBLIC PRN$WRIT 						  ;3.30
PRN$WRIT PROC	NEAR							  ;3.30
	ASSUME	DS:CODE 		; SET BY PRINTER DEVICE DRIVER ENT;3.30 RY

	jcxz	EXVEC3			; no chars to output, Get out
PRN$LOOP:
	mov	BX,2			; Initialize retry flag
PRN$out:
	mov	AL,ES:[DI]		; Get a character into AL
	inc	DI			; Point to next character
	XOR	AH,AH			; AH=0 => OUTPUT CHAR IN DL	  ;3.30
	call	PRNOP			; print character
	jnz	PrRetry 		; if error, try to print again
	loop	PRN$LOOP		; if more character, keep printing
EXVEC3:
	jmp	EXIT

PrRetry:
	dec	DI			; undo the inc above...
	dec	BX			; Decrement retry count
	jnz	PRN$out 		; See if done with retrys
PMESSG:
	JMP	ERR$CNT 		;   if so return with the error
PRN$WRIT ENDP								  ;3.30

;----------------------------------------------------------------
;								:
;		PRINTER STATUS ROUTINE				:
;								:
;----------------------------------------------------------------
;
	PUBLIC PRN$STAT 						  ;3.30
PRN$STAT PROC	NEAR							  ;3.30
	ASSUME	DS:CODE 		; SET BY PRINTER DEVICE DRIVER ENT;3.30 RY
									  ;3.30
	call	PRNSTAT 		; get the status
	jnz	PMESSG			; if error jump to error routine
	MOV	AL,9			; AGAIN, ASSUME OUT OF PAPER...   ;3.30
	TEST	AH,NOPAPERSTATUS					  ;3.30
	JNZ	PMESSG							  ;3.30
	TEST	AH,NOTBUSYSTATUS					  ;3.30
	jnz	EXVEC3			; if not busy return via EXVEC3
	JMP	BUS$EXIT		; else busy, return to busy exit  ;3.30
PRN$STAT ENDP								  ;3.30



;
;   PRNSTAT	get printer status
;   PRNOP	print a character
;
; PRNSTAT and PRNOP are two routines which call on the ROM-BIOS
; printer routines.  The routines share code which calls on the bios and
; then determines which, if any, error occured.  PRNSTAT and PRNOP differ
; only by the value put into AH before the ROM-BIOS call.
;
;   INPUT	if PRNOP then character in AL
;
;   OUTPUT	- AL holds error code
;		- AH status byte from printer
;		- flag NZ if error
PRNSTAT PROC	NEAR							  ;3.30
	mov	AH, 2			; set command for get status  ;3.30*
PRNOP:								      ;3.30*
	call	GETDX			; determine which printer     ;3.30*
	int	17h			; call ROM-BIOS printer routine ;3.30*

	TEST	AH,IOERRSTATUS		; I/O ERROR?			  ;3.30
	JZ	CHECKNOTREADY		; NO, TRY NOT READY		  ;3.30
									  ;3.30
; AT THIS POINT, WE KNOW WE HAVE AN ERROR.  THE CONVERSE IS NOT TRUE.	  ;3.30
									  ;3.30
	MOV	AL,9			; FIRST, ASSUME OUT OF PAPER	  ;3.30
	TEST	AH,NOPAPERSTATUS	; OUT OF PAPER SET?		  ;3.30
	JNZ	RET1			; YES, ERROR IS SET		  ;3.30
	INC	AL			; INDICATE I/O ERROR		  ;3.30
RET1:									  ;3.30
									  ;3.30
; WE HAVE TRIAGED NOW FOR OUT OF PAPER AND IO ERR (IGNORING TIME-OUT)	  ;3.30
									  ;3.30
	RET				; RETURN WITH ERROR		  ;3.30
									  ;3.30
; THE BITS SAID NO ERROR.  UNFORTUNATELY, THERE MAY BE OTHER THINGS AT WOR;3.30 K
; HERE. 								  ;3.30
									  ;3.30
CHECKNOTREADY:								  ;3.30
	MOV	AL,2			; ASSUME NOT-READY		  ;3.30
	TEST	AH,TIMEOUTSTATUS	; IS TIME-OUT SET?		  ;3.30
					; IF NZ THEN ERROR, ELSE OK???	  ;3.30
PRNOP2: 								  ;3.30
	RET								  ;3.30
PRNSTAT ENDP								  ;3.30


;----------------------------------------------------------------
;								:
;		Output until Busy				:
;								:
; Output until busy.  This entry point is used EXCLUSIVELY by	:
; the print spoolers.  Under no curcumstances should the device :
; driver block waiting for the device to become ready.		:
;								:
;   Inputs:	CX has count of bytes to output.		:
;		ES:DI points to source buffer			:
;   Outputs:	Set the number of bytes transferred		:
;		  appropriately.				:
;								:
;----------------------------------------------------------------

	PUBLIC	PRN$TILBUSY						  ;3.30
PRN$TILBUSY PROC NEAR							  ;3.30
	ASSUME	DS:CODE 		; SET BY PRINTER DEVICE DRIVER ENT;3.30 RY
									  ;3.30
	push	DS			; save DS
	push	ES			; copy ES to DS
	pop	DS
	ASSUME	DS:NOTHING						  ;3.30

	mov	SI,DI			; everything is set for LODSB
PRN$TilBLoop:
	push	CX
	push	BX
	xor	BX,BX
	mov	BL,CS:[PRINTDEV]
	shl	BX,1
	mov	CX,CS:WAIT_COUNT[BX]	; wait COUNT times to come ready
	pop	BX
PRN$GetStat:
	call	PrnStat 		; get status
	jnz	PRN$BPERR	; if error jump to error routine
	TEST	AH,10000000B		; READY YET?			  ;3.30
	loopz	PRN$GetStat	; if busy keep trying
	pop	CX			; get original count
	jz	PRN$BErr		; still not ready => done
	lodsb
	XOR	AH,AH							  ;3.30
	call	PrnOp			; print the character
	jnz	PRN$BErr		; error
	loop	PRN$TilBLoop		; go for more
PRN$B:
	pop	DS			; recover DS
	lds	BX,CS:[PTRSAV]		; get pointer to header
	ASSUME	DS:NOTHING						  ;3.30

	sub	WORD PTR [BX].COUNT,CX	; Determine number of succ. I/O's
	jmp	Exit			; all done, successful return
PRN$TILBUSY ENDP							  ;3.30

PRN$BPERR PROC	NEAR							  ;3.30
	ASSUME	DS:CODE 						  ;3.30

	pop	CX			; recover number of char left
PRN$BErr:
	pop	DS			; get pointer to header
	lds	BX,CS:[PTRSAV]
	ASSUME	DS:NOTHING						  ;3.30

	sub	WORD PTR [BX].COUNT,CX	; Determine number of succ. I/O's
	jmp	err$exit		; jump to error exit
PRN$BPERR ENDP								  ;3.30


;
; Prn$GenIOCTL:
;
; Manipulates the value in WAIT_COUNT depending on the value passed in the
; Generic IOCTL packet.
; It either sets or returns the current value for the retry count for the
; device.
;
	PUBLIC PRN$GENIOCTL						  ;3.30
PRN$GENIOCTL PROC NEAR							  ;3.30
	ASSUME	DS:CODE 		; SET BY PRINTER DEVICE DRIVER ENT;3.30 RY

	les	di,[PTRSAV]
	cmp	es:[di].MajorFunction,IOC_PC
	je	PrnFunc_OK
PrnFuncErr:
	jmp	CMDERR

PrnFunc_OK:
	mov	al,es:[di].MinorFunction
	les	di,es:[di].GenericIOCTL_Packet
	xor	bx,bx
	mov	bl,[PRINTDEV]		; get index into retry counts
	shl	bx,1
	mov	CX,WAIT_COUNT[BX]	; pull out retry count for device
	cmp	al,GET_RETRY_COUNT
	jz	PrnGetCount
	cmp	al,SET_RETRY_COUNT
	jnz	PrnFuncErr
	mov	cx,es:[di].RC_Count
PrnGetCount:
	mov	WAIT_COUNT[BX],CX	; place "new" retry count
	mov	es:[di].RC_Count,cx	; return current retry count
	jmp	EXIT

PRN$GENIOCTL ENDP							  ;3.30
CODE	ENDS								  ;3.30
	END								  ;3.30
