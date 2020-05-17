
ERRMES		DB	13,10,13,10,"**********",13,10,"$"
ERRMEST 	DB	" error reading file",13,10,"$"
BELMES		DB	13,0CH,7,"$"

ErrMesT2	db	"File not found",13,10,"$"

CanMes		DB	13,10,13,10,"File $"
CanFilNam	DB	" canceled by operator$"

AllCan		DB	13,10,13,10,"All files canceled by operator$"

ERR0		DB	"Write protect$"
ERR1		DB	"Bad unit$"
ERR2		DB	"Not ready$"
ERR3		DB	"Bad command$"
ERR4		DB	"Data$"
ERR5		DB	"Bad call format$"
ERR6		DB	"Seek$"
ERR7		DB	"Non-DOS disk$"
ERR8		DB	"Sector not found$"
ERR9		DB	"No paper$"
ERR10		DB	"Write fault$"
ERR11		DB	"Read fault$"
ERR12		DB	"Disk$"

FATMES		DB     "File allocation table bad drive "
BADDRVM 	DB     "A.",13,10,"$"

BADMES		DB	"List output is not assigned to a device",13,10
badmeslen	dw	$-badmes
GOODMES 	DB	"Resident part of PRINT installed",13,10
goodmeslen	dw	$-goodmes
