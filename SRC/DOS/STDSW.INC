;	SCCSID = @(#)stdsw.asm	1.1 85/04/10
TRUE	EQU	0FFFFH
FALSE	EQU	0

; Use the switches below to produce the standard Microsoft version of the IBM
; version of the operating system
;MSVER		EQU	FALSE
;IBM		EQU	TRUE
WANG		EQU	FALSE
;ALTVECT 	EQU	FALSE

include version.inc

; Set this switch to cause DOS to move itself to the end of memory
HIGHMEM EQU	FALSE

; Turn on switch below to allow testing disk code with DEBUG. It sets
; up a different stack for disk I/O (functions > 11) than that used for
; character I/O which effectively makes the DOS re-entrant.

	IF	IBM
ESCCH	EQU	0			; character to begin escape seq.
CANCEL	EQU	27			;Cancel with escape
TOGLPRN EQU	TRUE			;One key toggles printer echo
ZEROEXT EQU	TRUE
	ELSE
ESCCH	EQU	1BH
CANCEL	EQU	"X"-"@" 		;Cancel with Ctrl-X
TOGLPRN EQU	FALSE			;Separate keys for printer echo on
					;and off
ZEROEXT EQU	TRUE
	ENDIF
