	TITLE MSCON - DOS 3.3

;----------------------------------------------------------------
;								:
;	      C O N - CONSOLE DEVICE DRIVER			:
;								:
;								:
;   This file contains the Console Device Driver.  The		:
; console device driver sends characters to the moniter and	:
; gets characters from the keyboard.				:
;								:
;----------------------------------------------------------------

;;Rev 3.30 Modification
	test=0
	INCLUDE MSGROUP.INC	;DEFINE CODE SEGMENT
	INCLUDE JUMPMAC.INC
	INCLUDE MSEQU.INC
	INCLUDE MSMACRO.INC

	EXTRN EXIT:NEAR 	;MSBIO1
	EXTRN BUS$EXIT:NEAR	;MSBIO1

;DATA
	EXTRN PTRSAV:DWORD	;MSBIO1
	EXTRN FHAVEK09:BYTE	;MSDISK
	EXTRN ALTAH:BYTE	;MSDATA
;;End of Modification


;----------------------------------------------------------------
;								:
;		    Console read routine			:
;								:
;----------------------------------------------------------------
;
	ASSUME DS:CODE		    ; THIS WAS SET BY THE CON DD ENTRY PT
	PUBLIC	CON$READ
CON$READ PROC	NEAR
					; if CX is zero, no characters
	jcxz	CON$EXIT		;   to be read -- just exit
CON$LOOP:
	call	CHRIN			; get char in AL
	stosb				; store char at ES:DI, specified buffer
	loop	CON$LOOP		; if CX is non-zero more char to read
CON$EXIT:
	Jump	EXIT			; all done, successful return
CON$READ ENDP


;----------------------------------------------------------------
;								:
;	    Input single character into AL			:
;								:
;----------------------------------------------------------------
CHRIN	PROC	NEAR
					; set command to read character
	xor	AX, AX			;  and clear AL
	xchg	AL,ALTAH		; get character & zero ALTAH
	or	AL, AL			; see if buffer has a character
	jnz	KEYRET			; if so - return this character
					; if not - read single character
	int	16h			; call ROM-Bios keyboard routine
ALT10:
	or	AX,AX			; Check for non-key after BREAK
	jz	CHRIN
	cmp	AX,7200h		; Check for CTRL-PRTSC
	jnz	ALT15
	mov	AL,16			; indicate prtsc
ALT15:
	or	AL,AL			; special case?
	jnz	KEYRET			; no, return with character
	mov	ALTAH, AH		; yes, store special key
KEYRET:
	RET
CHRIN	ENDP

;----------------------------------------------------------------
;								:
;	   Keyboard non destructive read, no wait		:
;								:
; If bit 10 is set by the DOS in the status word of the request :
; packet, and there is no character in the input buffer, the	:
; driver issues a system WAIT request to the ROM. On return	:
; from the ROM, it returns a 'char-not-found' to the DOS.       :
;								:
;----------------------------------------------------------------

CONBUSJ:
	ASSUME	DS:NOTHING
	JMP	CONBUS

	ASSUME DS:CODE		    ; THIS WAS SET BY THE CON DD ENTRY PT
	PUBLIC	CON$RDND
CON$RDND:
	mov	AL,[ALTAH]		; first see if there is a
	or	AL,AL			; character in the buffer?
	jz	RD1			; with debugging code it is
	jmp	RDEXIT			;    too far for conditional jump

RD1:
			     		; set command to 'see if
	mov	AH, 1	     		;  character available'
	int	16h	     		; call ROM-BIOS keyboard routine
	jz	nochr			; with debugging code it is
	jmp	gotchr			;    to far for conditional jump
nochr:
	cmp	fHaveK09, 0
	jz	CONBUSJ
	lds	bx,[PTRSAV]		; get pointer to request header
	ASSUME	DS:NOTHING
	test	[bx].STATUS,0400H	; System WAIT enabled?
	jz	CONBUSJ 		; no, get out

	message ftestcon,<"System WAIT stage",cr,lf>
			      
	mov	AX, 4100h     		; set command for Wait on External
			      		; event and condition type to
			      		; any external event
	xor	BL,BL	      		; no timeout value
	int	15h	      		; call rom-bios sleep function
	message ftestcon,<"Out of wait. AX is ">
	mnum	ftestcon,ax
	message ftestcon,<cr,lf>
	jmp	CONBUS			; after wait exit to con busy

	ASSUME	DS:CODE
gotchr:
	or	AX, AX			; check for null after break
	JNZ	NOTBRK			; no, skip down
; note: AH is already zero, no need to set command
	int	16h ;SB 		; yes, read the null
	Jump	CON$RDND		; and get a real status

NOTBRK:
	cmp	AX, 7200H		; check for ctrl-prtsc
	jnz	RDEXIT			; no
	mov	AL, 16			; yes, indicate ctrl-prtsc

	PUBLIC	RDEXIT
RDEXIT:
	lds	BX, [PTRSAV]		; get pointer to request header
	ASSUME	DS:NOTHING
	mov	[BX].MEDIA, AL		; move character into req. header
EXVEC:
	Jump	EXIT			; all done -- successful return
CONBUS:
	ASSUME	DS:NOTHING
	Jump	BUS$EXIT		; done -- con device is busy


;----------------------------------------------------------------
;								:
;		Keyboard flush routine				:
;								:
;----------------------------------------------------------------
	ASSUME DS:CODE		    ; THIS WAS SET BY THE CON DD ENTRY PT
	PUBLIC	CON$FLSH
CON$FLSH:
	call	FLUSH
	Jump	Exit


PUBLIC	FLUSH
FLUSH:
	mov	[ALTAH], 0	; clear out holding buffer

FlLoop:
;;Rev 3.30 Modification
			 	; Is there a char there?
	mov	AH, 1	 	; command code for check status
	int	16h	 	; call rom-bios keyboard routine
				; if z flag is set then no character
	jz	FlDone		;   is ready, buffer is empty -- get out
	xor	AH, AH	 	; if zf is nof set, get character
	int	16h	 	; call rom-bios to get character
	jmp	FlLoop	       ; repeat until buffer is empty
FlDone:
	ret
;;Rev 3.30 Modification


;----------------------------------------------------------------
;								:
;	       Console Write Routine				:
;								:
;----------------------------------------------------------------
	ASSUME DS:CODE		    ; THIS WAS SET BY THE CON DD ENTRY PT
	PUBLIC	CON$WRIT
CON$WRIT:
	jcxz	EXVEC			; if CX is zero, get out
CON$LP:
	mov	AL,ES:[DI]		; get character
	inc	DI			; point to next character
	int	CHROUT			; Output character
	loop	CON$LP			; repeat until all through
	Jump	Exit



;-----------------------------------------------
;
;	BREAK KEY HANDLING
;
Public CBREAK
CBREAK:
	mov	CS:ALTAH, 3		; indicate break key set



Public INTRET
INTRET:
	IRET

CODE	ENDS
	END
