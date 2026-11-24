TITLE Project 6: String Primitives and Macros     (Proj6_bishopdy.asm)

; Author: Dylan Bishop
; Last Modified: 8/5/26
; OSU email address: bishopdy@oregonstate.edu
; Course number/section:   CS271 Section 400
; Project Number: 6               Due Date: 8/14/26
; Description: Takes in a file name from the user, the file containing ASCII-formatted integers.
;			   The ASCII-formatted numbers are converted into signed integers and then printed in
;			   reverse order to print in the desired order.

INCLUDE Irvine32.inc

; ---------------------------------------------------------------------------------
; Name: mGetString
;
; Displays a prompt, then gets the user's input and stores it in memory. 
;
; Preconditions: 
;	promptString is an address to a string.
;	inputStore is an address to a memory location
;
; Postconditions: 
;	inputStore contains the user's input.
;	inputLenStore contains the length of the user's input.
;
; Receives: 
;	promptString	= address of the string with which to prompt the user with
;	maxStringLen	= maximum size of string that the storage destination can accomodate
;	inputStore		= memory location the user's input is to be stored in
;	inputLenStore	= memory location the length of the user's input (in bytes) is to be stored in
;
; Returns: 
;	The user's input in inputStore
;	Length of the user's input (characters/bytes) in inputLenStore
; ---------------------------------------------------------------------------------
mGetString		MACRO	promptString, maxStringLen, inputStore, inputLenStore
	PUSH	EDX
	PUSH	ECX
	PUSH	EAX
	PUSH	EBX

	; Display prompt
	MOV		EDX, promptString
	CALL	WriteString

	; Receive user input
	MOV		ECX, maxStringLen	
	MOV		EDX, inputStore		; destination for input string
	CALL	ReadString

	; Store length of input string
	MOV		EBX, inputLenStore
	MOV		[EBX], EAX

	POP		EBX
	POP		EAX
	POP		ECX
	POP		EDX
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayString
;
; Prints a string from a memory location.
;
; Preconditions: stringAddress is the address of the string to print.
;
; Receives: 
;	stringAddress	= the address of the string to print
; ---------------------------------------------------------------------------------
mDisplayString	MACRO	stringAddress
	PUSH	EDX

	MOV		EDX, stringAddress
	CALL	WriteString

	POP		EDX
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayChar
;
; Prints an ASCII-formatted character, provided to the MACRO as an immediate, constant, or register.
;
; Preconditions: The character is provided as an immediate, constant, or register.
;
; Receives: 
;	inputChar		= the character to print out
; ---------------------------------------------------------------------------------
mDisplayChar	MACRO	inputChar
	PUSH	EAX

	MOV		AL, inputChar
	CALL	WriteChar

	POP		EAX
ENDM

TEMPS_PER_DAY	= 24
DELIMITER		= ','

.data

programTitle		BYTE	"Intern Mistake Corrector by Dylan Bishop",13,10,0
programIntro		BYTE	"Did your interns reverse your data? Look no further! This program will detangle and correct their mess.",13,10,\
							"Provide the name of a file containing a series of delimited ASCII values, and I will both correct",13,10,\
							"the ordering and print out the values in numeric form. Let's get to work!",13,10,13,10,0
fileNamePrompt		BYTE	"Please enter the name of the file to read (32 characters or less): ",0
userFileName		BYTE	33 DUP (?)
userFileNameLen		DWORD	?	
fileHandle			DWORD	?
fileOpenError		BYTE	13,10,"Sorry, there was an error opening the file. Ensure you typed the name correctly.",13,10,0
fileReadError		BYTE	13,10,"Sorry, there was an error reading the file. Please check the file and try again.",13,10,0
arrayIntro			BYTE	"Here's the corrected data set:",13,10,0
tempArray			SDWORD	TEMPS_PER_DAY DUP (?)
bufferArray			BYTE	(TEMPS_PER_DAY * 12) DUP (?)
farewell			BYTE	13,10,"Hopefully that looks a lot cleaner now. Farewell!",13,10,0

.code
main PROC

	; Introduce program
	mDisplayString	OFFSET programTitle
	mDisplayString	OFFSET programIntro

	; Get the name of the file to open (and length of the file name)
	mGetString		OFFSET fileNamePrompt, LENGTHOF userFileName, OFFSET userFileName, OFFSET userFileNameLen

	; Open the file
	MOV				EDX, OFFSET	userFileName
	CALL			OpenInputFile
	MOV				fileHandle, EAX

	; Check for any errors
	CMP				EAX, INVALID_HANDLE_VALUE
	JNE				_fileOpen
	mDisplayString	OFFSET fileOpenError
	JMP				_quitMain

_fileOpen:

	; Read from the file and store in buffer
	MOV				EAX, fileHandle
	MOV				ECX, (TEMPS_PER_DAY * 12)
	MOV				EDX, OFFSET bufferArray
	CALL			ReadFromFile

	JC				_readError
	JMP				_closeFile

_readError:
	
	mDisplayString	OFFSET fileReadError
	MOV				EAX, fileHandle
	CALL			CloseFile				; In the case of an error, still close the file
	JMP				_quitMain

_closeFile:

	MOV				EAX, fileHandle
	CALL			CloseFile

	; Parse through the buffer and convert the ASCII values into integers, storing them in tempArray
	PUSH			OFFSET tempArray
	PUSH			OFFSET bufferArray
	CALL			parseTempsFromString

	; Print out the values from the tempArray in reverse, correcting the order
	CALL			CrLf
	mDisplayString	OFFSET arrayIntro			
	PUSH			OFFSET tempArray
	CALL			writeTempsReverse
	CALL			CrLf

	; Program outro
	mDisplayString	OFFSET farewell

_quitMain:

	Invoke ExitProcess,0	; exit to operating system
main ENDP

; ---------------------------------------------------------------------------------
; Name: parseTempsFromString
;
; Parses through a string of ASCII-formatted values, converting them into signed
; integers and storing the results in an SDWORD array.
;
; Preconditions: 
;	[EBP+8] points to a buffer string with TEMPS_PER_DAY ASCII values
;	[EBP+12] points to an SDWORD array with enough space to fit TEMPS_PER_DAY values
;
; Postconditions: The destination SDWORD array contains the converted values.
;
; Receives: 
;	[EBP+8]		= address of the buffer of ASCII temps to read from
;	[EBP+12]	= address of the SDWORD array to store the integer values in
;
; Returns: The array pointed to by [EBP+12] is filled with signed integer values
; ---------------------------------------------------------------------------------
parseTempsFromString PROC
	PUSH	EBP
	MOV		EBP, ESP
	PUSH	ESI
	PUSH	EDI
	PUSH	EBX
	PUSH	ECX
	PUSH	EAX
	PUSH	EDX

	; Point to both the source buffer and the destination array
	MOV		ESI, [EBP+8]
	MOV		EDI, [EBP+12]

	MOV		ECX, TEMPS_PER_DAY

_checkValueLoop:
	PUSH	ECX			; Preserve loop counter to prevent overwrite from IMUL
	MOV		EBX, 0		; Clear EBX, so it can be used for negative flag
	MOV		EDX, 0		; Clear EDX, so it can store accumulated conversion value

	; Check first value in the byte to see if value is negative
	MOV		AL, [ESI]
	CMP		AL, '-'
	JNE		_conversionLoop
	MOV		EBX, 1		; Flag value as negative
	INC		ESI

_conversionLoop:
	LODSB				; Load current byte into AL, then increment forward in the string

	; Check for delimiter (signaling end of value)
	CMP		AL, DELIMITER
	JE		_negativeCheck

	; Convert the ASCII value into an integer: 10 * numInt + (numChar - 48)
	SUB		AL, 48
	MOVZX	EAX, AL		; Must zero extend to match size
	
	IMUL	EDX, 10
	ADD		EDX, EAX

	; Continue until a delimiter is reached
	JMP		_conversionLoop	

_negativeCheck:
	CMP		EBX, 1
	JNE		_storeValue
	NEG		EDX

_storeValue:
	MOV		[EDI], EDX
	ADD		EDI, TYPE SDWORD

	POP		ECX
	LOOP	_checkValueLoop

	POP		EDX
	POP		EAX
	POP		ECX
	POP		EBX
	POP		EDI
	POP		ESI
	POP		EBP
	RET		8
parseTempsFromString ENDP

; ---------------------------------------------------------------------------------
; Name: writeTempsReverse
;
; Prints out the array in reverse order using string primitives, with values 
; separated by delimiter characters.
;
; Preconditions: [EBP+8] is the address of an array of signed integers
;
; Receives: 
;	[EBP+8]		= address of the array to print out in reverse
; ---------------------------------------------------------------------------------
writeTempsReverse PROC
	PUSH	EBP
	MOV		EBP, ESP
	PUSH	ESI
	PUSH	ECX
	PUSH	EAX

	MOV		ESI, [EBP+8]
	ADD		ESI, (TEMPS_PER_DAY - 1) * TYPE SDWORD		; point to the end of array

	; Initialize loop counter
	MOV		ECX, TEMPS_PER_DAY

_printLoop:
	; Set direction flag, then load the value then increment backwards
	; WriteInt possibly alters direction flag and causes it to print strangely if STD is set out of the loop
	STD
	LODSD

	; Print the value and a delimiter
	CALL			WriteInt
	mDisplayChar	DELIMITER

	LOOP	_printLoop

	; Clear direction flag
	CLD

	POP		EAX
	POP		ECX
	POP		ESI
	POP		EBP
	RET		4
writeTempsReverse ENDP

END main