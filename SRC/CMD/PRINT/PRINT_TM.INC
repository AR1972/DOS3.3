
CONFLICTMES	DB	"Cannot use PRINT - Use NET PRINT",0
		addr	conflictmes,conflictmes_ptr

INVPARM 	DB	"Invalid parameter",0
		addr	invparm,invparm_ptr

FULLMES 	DB	"PRINT queue is full",0
		addr	fullmes,fullmes_ptr

NoFils		db	"PRINT queue is empty",0
		addr	nofils,nofils_ptr

Dispmes 	db	"    %s%s",0
		addr	dispmes,dispmes_ptr
		addr	arg_buf
whichmes	dw	?

FstMes		db	" is currently being printed",0
SecMes		db	" is in queue",0

BadNameMes	db	"%s File not found",0
		addr	badnamemes,badnamemes_ptr
		addr	namebuf

AccDen		db	"Access denied",0
		addr	AccDen,AccDen_ptr

InvDrvMes	db	"Invalid drive specification",0
		addr	invdrvmes,invdrvmes_ptr

NamTMes 	db	"%s Pathname too long",0
		addr	namtmes,namtmes_ptr
		addr	namebuf

BadCanMes	db	"%s File not in PRINT queue",0
		addr	badcanmes,badcanmes_ptr
		addr	namebuf

;This message must be $ terminated and printed using std_con_string_output
		public	badver
BADVER		DB	"Incorrect DOS version$"

CRLF		DB	13,10,0
		addr	crlf,crlf_ptr

CNTMES	DB	"Errors on list device indicate that it",13,10
	DB	"may be off-line. Please check it.",13,10,0
	addr	cntmes,cntmes_ptr

PROMPT	DB	"Name of list device [PRN]: ",0
	addr	prompt,prompt_ptr
