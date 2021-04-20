TITLE Project 6 - Designing low level I/O procedures     (Proj6_zierkb.asm)

; Author: Bryan Zierk
; Last Modified: 3/8/2021
; OSU email address: zierkb@oregonstate.edu
; Course number/section:   CS271 Section 400
; Project Number: 6               Due Date: 3/14/2021
; Description: This program contains a macro to get a string from the user and a second macro which displays a
; string at a given location in memory. These macros are used by ReadVal and WriteVal procedures. ReadVal prompts
; the user for a numeric value input, receives an ascii character representation of the number, validates that the input
; fits in a 32-bit register and does not contain any non-numeric characters (except for an allowed leading +/- sign), converts to a
; numeric representation and stores in memory. WriteVal takes a numeric value and converts it, character by character,
; into an ascii representation which can be displayed by the DisplayString macro. Main contains a procedure which
; puts these pieces together by prompting the user for 10 numeric value inputs, displays the 10 values which were entered,
; their sum, and the rounded average of the inputs.

INCLUDE Irvine32.inc

;***********************************************************************
; Name: mGetString
;
; Prompts the user for an input and stores a string up to a maximum
; length of 'maxLength' at the memory address 'inputLoc'. Stores the
; length of the string at the memory addres 'strLen'
; 
; Receives:
;		prompt = memory address for a desired prompt
;		inputLoc = memory address for storing input string
;		maxLength = value for upper limit of string length
;		strLen = stores length of the input string
; 
;***********************************************************************
  mGetString MACRO prompt, inputLoc:REQ, maxLength, strLen:REQ
  push eax
  push ecx
  push edx

  mov edx, prompt
  call WriteString
  mov edx, inputLoc
  mov ecx, maxLength
  call ReadString
  mov strLen, eax

  pop edx
  pop ecx
  pop eax
  ENDM

  ;***********************************************************************
; Name: mDisplayString
; 
; Prints a string which is located at a specified location in memory
;
; Receives:
;		strAddr = string address
;***********************************************************************
  mDisplayString MACRO strAddr:REQ
  push edx

  mov edx, strAddr
  call WriteString

  pop edx
  ENDM

MAXLENGTH = 12
ARRAYLEN  = 10
.data

	intro1		BYTE   "Project 6 - Designing Low Level I/O Procedures by Bryan Zierk",13,10,0
	intro2		BYTE   "Please enter 10 signed decimal integers.",13,10,
					   "Each number must fit within a 32 bit register. Once 10 integers have been",13,10,
					   "entered, this program will display the array of integers, their sum, and",13,10,
					   "their average (rounded down to the nearest integer.)",13,10,0

	prompt1		BYTE   " Please enter a signed number: ",0
	error1		BYTE   "ERROR: Your input contained non-numeric characters or was too large.",13,10,0

	report1		BYTE   "Your entered numbers were:",13,10,0
	reportSum	BYTE   "Their sum is: ",0
	reportAvg	BYTE   "Their rounded average is: ",0
	comma		BYTE   ", ",0
	repSubTot	BYTE   ". Subtotal: ",0

	numArr		SDWORD 10 DUP(?)
	arrSum		SDWORD ?
	strSum		BYTE   10 DUP(?)
	arrAvg		SDWORD ?
	strAvg		BYTE   10 DUP(?)

	userInput	BYTE   ?
	strLen		DWORD  ?
	numRepr		SDWORD ?
	strRepr		BYTE   10 DUP(?)
	lineStr		BYTE   10 DUP(?)
	lineNum		SDWORD  ?

	goodbye		BYTE   "Goodbye.",0
.code
main PROC

	; Introduce program and display instructions
	push OFFSET intro1
	push OFFSET intro2
	call introduction

	; Get 10 signed numbers from the user
	mov arrSum, 0
	mov ecx, ARRAYLEN
	mov edi, OFFSET numArr
_grabNum:
	push OFFSET lineStr
	push OFFSET lineNum
	push OFFSET error1
	push OFFSET numRepr
	push MAXLENGTH
	push OFFSET prompt1
	push OFFSET userInput
	push OFFSET strLen
	call ReadVal
	; Accumulate the numbers and determine their average
	mov  eax, numRepr
	mov  [edi], eax
	add  edi, TYPE numArr
	add  arrSum, eax
	loop _grabNum

	call Crlf

	; Display the array of numbers
	mDisplayString OFFSET report1
	mov  ecx, LENGTHOF numArr
	mov  esi, OFFSET numArr
	push OFFSET strRepr
	push esi
	call WriteVal
	add  esi, TYPE numArr
	dec  ecx
_printArray:
	mDisplayString offset comma
	; clear strRepr to hold the next string (prevents appending numbers from previous iteration to printed number)
	push ecx
	cld
	lea  edi, strRepr
	mov  ecx, LENGTHOF strRepr
	mov  al,  0
	rep  stosb
	pop  ecx

	; print each value
	push OFFSET strRepr
	push esi
	call WriteVal
	add  esi, TYPE numArr
	loop _printArray

	call CrLf
	call CrLf

	; Display their sum
	mDisplayString OFFSET reportSum
	push OFFSET strSum
	push OFFSET arrSum
	call WriteVal
	call CrLf
	call CrLf
	
	; Display their average
	mDisplayString OFFSET reportAvg
	mov  eax, arrSum
	mov  ebx, LENGTHOF numArr
	cdq
	idiv ebx
	cmp  eax, 0
	jge  _showAvg
	cmp  edx, 0
	jz   _showAvg
	dec  eax
_showAvg:
	mov  arrAvg, eax
	push OFFSET strAvg
	push OFFSET arrAvg
	call WriteVal
	call CrLf
	call CrLf

	; Say goodbye to the user
	mDisplayString offset goodbye
	call CrLf


	Invoke ExitProcess,0	; exit to operating system
main ENDP

;***********************************************************************
; Introduces the program by displaying the title, author, and instructions
; to the user.
; receives: memory addresses of intros
; returns: none
; preconditions: none
;***********************************************************************
Introduction PROC
	push ebp
	mov  ebp, esp
	push edx
	mov  edx, [ebp + 12]
	call WriteString
	call CrLf
	mov  edx, [ebp + 8]
	call WriteString

	pop edx
	pop ebp

	ret 8
	
Introduction ENDP


;***********************************************************************
; Procedure takes a string of number characters and converts them
; into their numeric value representation
;
; receives: memory address for storing numeric repesentation, a max
;	length for the string, memory address for a prompt to the user,
;	memory address for a string of numbers, memory address for the length
;	of the string
; returns: Memory offset for numeric value representation
; preconditions: string contains only numeric values (may contain a
;				leading +/- symbol)
;***********************************************************************
ReadVal PROC
	LOCAL temp:SDWORD, numVal:SDWORD
	pushad

	; Get user input to string
_invalidJump:
	mGetString [ebp + 16], [ebp + 12], [ebp + 20], [ebp + 8]

	; validate that the input is only valid numbers, first character may be a sign (+/-)
	xor  eax, eax
	cld
	mov  ecx, [ebp + 8]						; string length to counter
	mov  esi, [ebp + 12]					; user string to esi
	mov  edi, [ebp + 24]
	mov  eax, 0
	mov  numVal, eax

	lodsb
	; check if first character is a sign
	cmp  al, 45
	je   _negSign
	cmp  al, 43
	je   _posSign
	jmp  _firstChar

	; validate and accumulate positive numbers
_nextPosChar:
	mov  eax, 0
	lodsb
_firstChar:
	cmp  al, 48
	jl	 _notValid
	cmp  al, 57
	jg   _notValid
	; convert ascii to numeric value
	sub  al, 48
	mov  temp, eax
	mov  eax, numVal
	mov  ebx, 10
	imul ebx
	jo   _notValid						; multiplication exceeds 32 bit register
	add  eax, temp
	jo   _notValid						; addition carries over
	mov  numVal, eax
_posSign:
	loop _nextPosChar
	jmp  _exit

	; validate and accumulate negative numbers
_nextNegChar:
	mov  eax, 0
	lodsb
	cmp  al, 48
	jl	 _notValid
	cmp  al, 57
	jg   _notValid
	; convert ascii to numeric value
	sub  al, 48
	mov  temp, eax
	mov  eax, numVal
	mov  ebx, 10
	imul ebx
	jo   _notValid						; multiplication exceeds 32 bit register
	sub  eax, temp
	jo   _notValid						; subtraction carries over
	mov  numVal, eax
_negSign:
	loop _nextNegChar
	jmp  _exit

_notValid:
	mov  edx, [ebp + 28]
	call WriteString

	jmp  _invalidJump

_exit:
	mov  eax, numVal
	mov  [edi], eax

	popad
	ret 36

ReadVal ENDP

;***********************************************************************
; Procedure takes a numeric value and converts it into a string of
;		ascii representation values.
;
; receives: a memory offset for storing a converted string of ascii
;			characters, memory offset for a numeric value
; returns: Memory offset for ascii character representation
; preconditions: numeric value fits in a 32-bit register
;***********************************************************************
WriteVal PROC
	LOCAL digitCount:SDWORD

	pushad

	mov  esi, [ebp + 8]								; number representation of string to esi
	mov  edi, [ebp + 12]							; string represenation offset to edi
	mov  eax, [esi]
	mov  ebx, 10
	mov  digitCount, 0

	cmp  eax, 0
	jl   _negValue

_Loop:
	xor  edx, edx
	div  ebx
	push edx
	inc  digitCount
	cmp  eax, 0
	jg   _Loop
	mov  ecx, digitCount
_incString:

	pop  eax
	add  al,  48
	cld
	stosb
	loop _incString
	jmp  _exit

_negValue:
	push eax
	mov  al, 45
	cld
	stosb
	pop  eax
	neg  eax
	jmp  _Loop

_exit:
	mDisplayString [ebp + 12]							; Display string representation

	popad
	ret 12
WriteVal ENDP

END main
