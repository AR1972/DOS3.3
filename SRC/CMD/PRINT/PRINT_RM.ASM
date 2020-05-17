;	SCCSID = @(#)print_rmes.asm	4.1 85/07/17
	INCLUDE pridefs.inc


BREAK	<Resident Portion Messages>

;
;	MSDOS V3.00 PRINT
;
;	Resident Portion Messages
;
;	02/15/84	MAU	Created as a separate link module
;				from the include file. should
;				always be linked first!!
;

CodeR	Segment public para

	public	ERRMES, ERRMEST, BELMES, ErrMesT2, CanMes, CanFilNAm
	public	AllCan, ERR0, ERR1, ERR2, ERR3, ERR4, ERR5, ERR6,
	public	ERR7, ERR8, ERR9, ERR10, ERR11, ERR12, FATMES
	public	BADDRVM, BADMES, badmeslen, GOODMES, goodmeslen

;INT 24 messages A La COMMAND
Public PRMES001S, PRMES001E
PRMES001S	equ	$

include print_rm.inc

PRMES001E	equ $

CodeR	EndS

	End
