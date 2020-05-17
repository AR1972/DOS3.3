;	SCCSID = @(#)nprintf.asm	4.1 85/07/17
	INCLUDE pridefs.inc


BREAK	<Message Printing Routine>

;
;	MSDOS V3.00 PRINT
;
;	Message Printing Routine
;


DATA	    SEGMENT PUBLIC BYTE

	    extrn   crlf_ptr:word

Public NPR001S, NPR001E
NPR001S 	equ	$

PRINTF_LEFT	DB  0
PRINTF_LONG	DB  0
PRINTF_HEX	DB  0
TABLE_INDEX	DB  0
S_FLAG		DB  0
PRINTF_WIDTH	DW  0
PRINTF_BASE	DW  0
PAD_CHAR	DB  " "

PRINTF_TABLE DB "0123456789ABCDEFabcdef"

PRINTF_STACK   STRUC
OLDES	DW  ?
OLDDS	DW  ?
OLDSI	DW  ?
OLDDI	DW  ?
OLDAX	DW  ?
OLDBX	DW  ?
OLDCX	DW  ?
OLDBP	DW  ?
STRING	DW  ?
OLDCS	DW  ?
PRINTF_STACK   ENDS

PRINTF_ARGS    STRUC
CONSTR	DW ?
ARG	DW ?
PRINTF_ARGS    ENDS

BUFSIZ	EQU    20
PRINTF_BUF DB  BUFSIZ DUP (?)
	db	0			;This buffer is always nul terminated
BUFEND DW   $-PRINTF_BUF

NPR001E 	equ	$

DATA	    ENDS


Code	Segment public para

ASSUME	CS:DG,DS:nothing,ES:nothing,SS:Stack

	PUBLIC	PRINTF,STD_PRINTF,PRINTF_CRLF

PRINTF_CRLF:
	CALL	STD_PRINTF
crlf2:
	mov	dx,offset dg:crlf_ptr
STD_PRINTF:
	PUSH	DX
PRINTF:
	PUSH	BP			;Save the callers' registers
	PUSH	CX
	PUSH	BX
	PUSH	AX
	PUSH	DI
	PUSH	SI
	PUSH	ES
	PUSH	DS
	MOV	BP,SP
	PUSH	CS
	POP	ES			;ES points to Printf segment
	CALL	Clear_flags		; initialize the world

	MOV	DI,DS
	MOV	SI,ES
	CMP	SI,DI
	JZ	S
	HLT
S:

	MOV	DI,OFFSET DG:PRINTF_BUF ;DI points to the output buffer
	MOV	BP,[BP.STRING]		;BP points to the argument list
	MOV	SI,DS:[BP]		;SI points to the control string
	XOR	BX,BX			;BX is the index into the arg list
GET_CHAR:
	LODSB				;Get a character
	CMP	AL,"%"                  ;Is it a conversion specifier?
	JZ	CONV_CHAR		;Yes - find out which one
	OR	AL,AL			;Is it the end of the control string?
	JZ	PRINTF_DONE		;Yes - then we're done
	CALL	OUTCHR			;Otherwise store the character
	JMP	SHORT GET_CHAR		;And go get another

PRINTF_DONE:
	CALL	FLUSH
	POP	DS
	POP	ES
	POP	SI
	POP	DI
	POP	AX
	POP	BX
	POP	CX
	POP	BP
	POP	DX
	RET

PRINTF_PERCENT:
	CALL	OUTCHR
	JMP	GET_CHAR

CONV_CHAR:
	;Look for any format specifiers preceeding the conversion character
	LODSB
	CMP	AL,"%"                      ;Just print the %
	JZ	PRINTF_PERCENT
	CMP	AL,"-"                      ;Right justify the field
	JZ	LEFT_ADJ
	CMP	AL,"+"                      ;Left justify the field
	JZ	NXT_CONV_CHAR
	CMP	AL,"L"                      ;Is it a long integer
	JZ	LONG_INT
	CMP	AL,"l"
	JZ	LONG_INT
	CMP	AL,"0"                      ;Is it a precision specification
	JB	LOOK_CONV_CHAR
	CMP	AL,"9"
	JA	LOOK_CONV_CHAR
	CMP	AL,"0"
	JNZ	NOT_PAD
	CMP	CS:[PRINTF_WIDTH],0
	JNZ	NOT_PAD
	MOV	CS:BYTE PTR [PAD_CHAR],"0"
NOT_PAD:
	PUSH	AX			    ;Adjust decimal place on precision
	MOV	AX,10
	MUL	CS:[PRINTF_WIDTH]
	MOV	CS:[PRINTF_WIDTH],AX
	POP	AX
	XOR	AH,AH
	SUB	AL,"0"
	ADD	CS:[PRINTF_WIDTH],AX	       ;And save the total
	JMP	SHORT NXT_CONV_CHAR

	;Set the correct flags for the options in a conversion

LEFT_ADJ:
	INC	CS:BYTE PTR[PRINTF_LEFT]
	JMP	SHORT NXT_CONV_CHAR

LONG_INT:
	INC	CS:BYTE PTR[PRINTF_LONG]
NXT_CONV_CHAR:
	JMP	CONV_CHAR

	;Look for a conversion character

LOOK_CONV_CHAR:
	CMP	AL,"X"
	JZ	HEX_UP

	;Make all other conversion characters upper case

	CMP	AL,"a"
	JB	CAPS
	CMP	AL,"z"
	JG	CAPS
	AND	AL,0DFH
CAPS:
	CMP	AL,"X"
	JZ	HEX_LO
	CMP	AL,"D"
	JZ	DECIMAL
	CMP	AL,"C"
	JZ	C_PUT_CHAR
	CMP	AL,"S"
	JZ	S_PUT_STRG

	;Didn't find any legal conversion character - IGNORE it

	call	clear_flags
	jmp	get_char

HEX_LO:
	MOV	CS:[TABLE_INDEX],6		;Will print lower case hex digits
HEX_UP:
	MOV	CS:[PRINTF_BASE],16    ;Hex conversion
	JMP	CONV_TO_NUM

DECIMAL:
	MOV	CS:[PRINTF_BASE],10    ;Decimal conversion
	JMP	CONV_TO_NUM

S_PUT_STRG:
	INC	CS:[S_FLAG]	       ;It's a string specifier
C_PUT_CHAR:
	PUSH	SI		       ;Save pointer to control string
	MOV	SI,BX
	ADD	BX,2
	MOV	SI,ds:[BP+SI.ARG]      ;Point to the % string or character
	CMP	BYTE PTR CS:[S_FLAG],0
	JNZ	S_PUT_1
	LODSB
	cmp	al,0
	jz	short c_s_end
	CALL	OUTCHR		       ;Put it into our buffer
	JMP	SHORT C_S_END

S_PUT_1:
	mov	cx,cs:[printf_width]
	or	cx,cx
	jz	s_put_2
	cmp	cs:byte ptr[printf_left],0
	jnz	s_put_2
	push	si
	call	Pad_string
	pop	si
s_put_2:
	push	si
s_put_3:
	LODSB			       ;Put them all in our buffer
	CMP	AL,0
	jz	s_put_4
	CALL	OUTCHR
	jmp	short S_PUT_3
s_put_4:
	pop	si
	cmp	byte ptr[printf_left],0
	jz	c_s_end
	mov	cx,cs:[printf_width]
	or	cx,cx
	jz	c_s_end
	call	Pad_string
C_S_END:
	call	clear_flags
	POP	SI		       ;Restore control string pointer
	JMP	GET_CHAR	       ;Go get another character

pad_string:
	xor	dx,dx
count_loop:
	lodsb
	or	al,al
	jz	count_done
	inc	dx
	jmp	short count_loop
count_done:
	sub	cx,dx
	jbe	count_ret
	call	pad
count_ret:
	ret

CONV_TO_NUM:

	PUSH	SI		    ;Save pointer to control string
	MOV	SI,BX		    ;Get index into argument list
	ADD	BX,2		    ;Increment the index
	MOV	AX,ds:[BP+SI.ARG]   ;Lo word of number in SI
	CMP	BYTE PTR CS:[PRINTF_LONG],0	;Is this is a short or long integer?
	JZ	NOT_LONG_INT
	MOV	SI,BX			     ;Copy index
	ADD	BX,2			     ;Increment the index
	MOV	DX,ds:[BP+SI.ARG]	     ;Hi word of number in BP
	JMP	SHORT DO_CONV
NOT_LONG_INT:
	XOR	DX,DX			     ;Hi word is zero
DO_CONV:
	PUSH	BX			     ;Save index into arguemnt list
	MOV	si,CS:[PRINTF_BASE]
	MOV	cx,CS:[PRINTF_WIDTH]
	CALL	PNUM
	CALL	PAD
CONV_DONE:
	call	clear_flags
	POP	BX
	POP	SI
	jmp	get_char

PNUM:
	DEC	CX
	PUSH	AX
	MOV	AX,DX
	XOR	DX,DX
	DIV	SI
	MOV	BX,AX
	POP	AX
	DIV	SI
	XCHG	BX,DX
	PUSH	AX
	OR	AX,DX
	POP	AX
	JZ	DO_PAD
	PUSH	BX
	CALL	PNUM
	POP	BX
	JMP	SHORT REM
DO_PAD:
	CMP	CS:BYTE PTR[PRINTF_LEFT],0
	JNZ	REM
	CALL	PAD
REM:
	MOV	AX,BX
	CMP	AL,10
	JB	NOT_HEX
	CMP	CS:BYTE PTR [PRINTF_HEX],0
	JNZ	NOT_HEX
	ADD	AL,CS:BYTE PTR [TABLE_INDEX]
NOT_HEX:
	MOV	BX,OFFSET dg:PRINTF_TABLE
	PUSH	DS
	PUSH	CS
	POP	DS
	XLAT	0
	POP	DS
	push	cx
	CALL	OUTCHR
	pop	cx
	RET

PAD:
	OR	CX,CX
	JLE	PAD_DONE
	MOV	AL,CS:BYTE PTR [PAD_CHAR]
PAD_LOOP:
	push	cx
	CALL	OUTCHR
	pop	cx
	LOOP	PAD_LOOP
PAD_DONE:
	RET

OUTCHR:
	STOSB
	CMP	DI,offset dg:bufend-1	   ;Don't count the nul
	jz	foob2
	ret
foob2:
	MOV	CX,BUFSIZ
WRITE_CHARS:
	push	bx
	MOV	BX,1
	push	ds
	PUSH	CS
	POP	DS
	MOV	DX,OFFSET dg:PRINTF_BUF
	MOV	AH,WRITE
	INT	21H
	pop	ds
	pop	bx
	MOV	DI,OFFSET dg:PRINTF_BUF
	RET

FLUSH:
	CMP	DI,OFFSET dg:PRINTF_BUF
	jnz	foob1
	ret
foob1:
	SUB	DI,OFFSET dg:PRINTF_BUF
	MOV	CX,DI
	call	write_chars
	ret

CLEAR_FLAGS:
	XOR	ax,ax
	MOV	BYTE PTR CS:[PRINTF_LEFT],al	   ;Reset justifing flag
	MOV	BYTE PTR CS:[PRINTF_LONG],al	   ;Reset long flag
	MOV	BYTE PTR CS:[TABLE_INDEX],al	   ;Reset hex table index
	MOV	CS:[PRINTF_WIDTH],ax		   ;Reinitialize width to 0
	MOV	BYTE PTR CS:[PAD_CHAR]," "         ;Reset padding character
	MOV	BYTE PTR CS:[S_FLAG],al 	   ;Clear the string flag
	ret

Code	Ends
	End
