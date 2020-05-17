	PUBLIC FATAL_MSG						  ;3.30
FATAL_MSG	DB	0DH,0AH 					  ;3.30
		DB	7,0DH,0AH					  ;3.30
		DB	"Internal stack overflow",0DH,0AH                 ;3.30
		DB	"System halted",0DH,0AH,"$"                       ;3.30
;
