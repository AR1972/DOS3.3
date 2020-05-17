
							;;Rev 3.30 Modification
; SINGLE DRIVE MESSAGE FOR BIOS. NUL TERMINATED.			  
IFNDEF	PATHSTART							  
PATHSTART MACRO INDEX,ABBR						  
	IFDEF	PATHGEN 						  
	    PUBLIC  ABBR&INDEX&S,ABBR&INDEX&E				  
	    ABBR&INDEX&S LABEL	 BYTE					  
	ENDIF								  
	ENDM								  
ENDIF									  
									  
IFNDEF	PATHEND 							  
PATHEND MACRO	INDEX,ABBR						  
	IFDEF	PATHGEN 						  
	    ABBR&INDEX&E LABEL	 BYTE					  
	ENDIF								  
	ENDM								  
ENDIF									  
									  
	PATHSTART 001,BIOMS						  
									  
;
; Single drive message for msbio.com. Nul terminated.	;;End of Modification
;

SNGMSG	DB	CR,LF,"Insert diskette for drive "
DRVLET	DB	"A: and strike",CR,LF,"any key when ready",CR,LF,LF,0

	PATHEND 001,BIOMS
