
NotNetM db	"Cannot SYS to a Network drive",0
	addr	NotNetM,NotNetM_ptr

	IF	IBMJAPVER
BadDisk db	"Destination disk cannot be booted",0
	addr	baddisk,baddisk_ptr
	ENDIF

;This message must be terminated by a $ and printed with std_con_output
BADVER	DB	"Incorrect DOS version",13,10,"$"

BadDrv	db	"Invalid drive specification",0
	addr	Baddrv,baddrv_ptr

BadParm db	"Invalid parameter",0
	addr	BadParm,BadParm_ptr

NoDest	db	"No room for system on destination disk",0
	addr	NoDest,NoDest_ptr

BadSiz	db	"Incompatible system size",0
	addr	BadSiz,BadSiz_ptr

Done	db	"System transferred",13,10,0
	addr	done,done_ptr

NoSys	db	"No system on default drive",13,10,0
	addr	NoSys,NoSys_ptr

GETSYS	DB	"Insert system disk in drive %c",13,10
	db	"and strike any key when ready",0
	addr	getsys,getsys_ptr
	addr	sysdrv

SYSDRV	DB	"A",0

GetTarg DB	"Insert destination disk in drive %c",13,10
	db	"and strike any key when ready",0
	addr	GetTarg,GetTarg_ptr
	addr	Targdrv

TargDrv DB	"B",0

crlf	db	13,10,0
	addr	crlf,crlf_ptr

