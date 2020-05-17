;	SCCSID = @(#)stddosmes.asm	1.1 85/04/10
;
; Standard device IO for MSDOS (first 12 function calls)
;
debug=0
.xlist
.xcref
include stdsw.inc
include dosseg.inc
.cref
.list

TITLE   STDDOSMES - DOS OEM dependancies
NAME    STDDOSMES

include dosmes.inc
