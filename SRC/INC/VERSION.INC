TRUE	   EQU	   0FFFFh
TRUEBYTE   EQU     0FFh
FALSE	   EQU	   0
;
; Use the following switches to control cmacros.inc
;
?PLM       =       0
?WIN       =       0

memS       EQU     1			; Small model
;
; Use the switches below to produce the standard Microsoft version or the IBM
; version of the operating system
;
; The below chart will indicate how to set the switches to build the various
; versions
;
;                     IBMVER          IBMCOPYRIGHT
; --------------------------------------------------------
;  IBM Version   |     TRUE              TRUE
; --------------------------------------------------------
;  MS Version    |     FALSE             FALSE
; --------------------------------------------------------
;  Clone Version |     TRUE              FALSE
;
IBMVER     EQU     TRUE
IBMCOPYRIGHT EQU   FALSE
	
MSVER      EQU     NOT IBMVER
IBM	   EQU	   IBMVER
;
;
  IF1
	IF IBMVER
	    IF IBMCOPYRIGHT
              %OUT ... IBM version build switch on ...
	    ELSE
	      %OUT ... CLONE version build switch on ...
	    ENDIF
	ELSE
	    IF NOT IBMCOPYRIGHT
	      %OUT ... MS version build switch on ...
	    ELSE
	      %OUT !!!!!!!!!  VERSION SWITCHES SET INCORECTLY  !!!!!!!!!
	      %OUT !!!!!!!!! CHECK SETTINGS IN INC\VERSION.INC !!!!!!!!!
	    ENDIF
	ENDIF   
  ENDIF
;
;
;***************************************************************************
;*          The following switches are for DBCS or SBCS support            *
;*                                                                         *
;*                     Set INTERNAT EQU TRUE FOR DBCS                      *
;*                     Set INTERNAT EQU FALSE FOR SBCS                     *
;*                                                                         *
;***************************************************************************
;
IBMJAPVER  EQU	   FALSE		;If TRUE set KANJI true also

;
; Switch INTERNAT for DBCS support
;
INTERNAT   EQU	   FALSE
;
	IF INTERNAT
ALTVECT    EQU	   FALSE		;Switch to build ALTVECT version
KANJI	   EQU	   TRUE
IBMJAPAN   EQU	   TRUE
	ELSE
ALTVECT    EQU	   FALSE		;Switch to build ALTVECT version
KANJI	   EQU	   FALSE
IBMJAPAN   EQU	   FALSE
	ENDIF
;
; Country code switches
; The default contry code is assumed as USA.
;
	IF INTERNAT
 KOREA	   EQU	   TRUE
 JAPAN	   EQU	   FALSE
	ELSE
 KOREA	   EQU	   FALSE
 JAPAN	   EQU	   FALSE
	ENDIF
;
	IF1
		IF INTERNAT
%OUT	Internat(ECS) version build switch on
		ENDIF
	ENDIF
