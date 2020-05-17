
;
; printed when there is a bad command in CONFIG.SYS. '$' TERMINATED, note
;   that this message includes crlfm.
;

PATHSTART	001,SYSMES						  ;3.30
BADOPM	DB	13,10,"Unrecognized command in CONFIG.SYS"

BADSIZ_POST LABEL   BYTE
BADLD_POST  LABEL   BYTE
CRLFM	DB	13,10,'$'


;
;PRINTED when installed device specifies too large a sector size.'$' terminated.
; FORM: 	<BADSIZ_PRE>device name<BADSIZ_POST>
;

BADSIZ_PRE  DB	    13,10,"Sector size too large in file $"

;
;PRINTED when installed device cannot be found. '$' terminated.
; FORM: 	<BADLD_PRE>device name<BADLD_POST>
;

BADLD_PRE   DB	    13,10,"Bad or missing $"

;
;PRINTED when command interpreter is not found. NUL terminated.
; FORM: 	<BADLD_PRE><BADCOM><BADLD_POST>
;

BADCOM	DB	"Command Interpreter",0

;PRINTED when country code, code page combination was not found 	  ;3.30
;  in country.sys file. '$' terminated.                                   ;3.30
; FORM: 	<BADCOUNTRY>						  ;3.30
BADCOUNTRY DB	13,10,"Invalid country code or code page",13,10,"$"       ;3.30
									  ;3.30
;PRINTED when code page id is missing or wrong syntax. - J.K.		  ;3.30
; FORM: 	<BADCOUNTRYCOM> 					  ;3.30
BADCOUNTRYCOM DB 13,10,"Error in COUNTRY command",13,10,"$"               ;3.30
									  ;3.30
;PRINTED when the memory left is not sufficient to handle COUTRY.SYS file ;3.30
; FORM: 	<INSUFMEMORY>						  ;3.30
INSUFMEMORY DB 13,10, "Insufficient memory for COUNTRY.SYS file",13,10,"$" ;3.30
									  ;3.30
;
; PRINTED when there is insufficient memory. '$' TERMINATED, note
;   that this message includes crlfm!
;

BADMEM	DB	13,10,"Configuration too large for memory",13,10,"$"

;
; PRINTED when the attempt is made to install a block device which would
;   have a drive letter > 'Z'
;

BADBLOCK DB	13,10,"Too many Block Devices",13,10,"$"


; PRINTED when the attempt is made to install a stack with invalid	  ;3.30
;   combinations of # of stacks, stack size.	- J.K. 5/23/86		  ;3.30
BADSTACK DB	13,10,"Invalid STACK parameters",13,10,"$"                ;3.30
									  ;3.30
