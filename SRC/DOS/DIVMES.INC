; THIS IS THE ONLY DOS "MESSAGE". IT DOES NOT NEED A TERMINATOR.
	PUBLIC	DIVMES
Public DIVM001S,DIVM001E
DIVM001S	label byte

;include divmes.inc
DIVMES	DB	13,10,"Divide overflow",13,10


	PUBLIC	DivMesLen
DivMesLen   DW	$-DivMes	; Length of the above message in bytes
DIVM001E	label byte
