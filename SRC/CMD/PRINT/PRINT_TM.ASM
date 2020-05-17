;	SCCSID = @(#)print_tmes.asm	4.1 85/07/17
	INCLUDE pridefs.inc


BREAK	<Transient Messages>

;
;	MSDOS V3.00 PRINT
;
;	Transient Portion Message
;
;	02/13/84	MAU	Fixed bug with BadCanMes
;


addr macro sym,name
     public name
     ifidn <name>,<>

	    dw offset dg:sym
     else

name	 dw  offset dg:sym
     endif
     endm


DATA	SEGMENT public BYTE

	extrn	namebuf:byte,arg_buf:byte
	public	whichmes,fstmes,secmes

Public PRNTMES001S, PRNTMES001E
PRNTMES001S	equ	$


include print_tm.inc

PRNTMES001E	equ	$

data ends
     end
