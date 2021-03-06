;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; DPMI Demonstration Program.
;; (C) Copyright 1992, Quarterdeck Office Systems.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	name	DPMI
	title	DPMI Demo Program

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; CODE STARTS HERE.  Define Code Segment as usual.
;; We will be using 16 bit segments.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
d_seg segment 'code'
	assume	cs:d_seg,ds:d_seg

	org	100h

entry_point:
	jmp	main

;
; Local Data Alloctions.
;
DPMIEntryPoint		dd	?	; REAL far address for Switch Entry.
FreeSeg			dw	?	; first free segment above program.
PrivateDataSeg		dw	?	; segment of allocated memory for DPMI
SegsRequired		dw	?	; number segs required by DPMI host.
VideoPad		dw	?	; Possibly DESQview virtualized video
ScreenSel		dw	?	; Selector for access to video.

MemErrorMessage		db	'Not enough memory to run',13,10,'$'
DPMIErrorMessage	db	'DPMI is not present.',13,10,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; GetScreenSel
;; ============
;;
;; Args:	none
;;
;; Returns:	cy=0:	ax = selector mapped to video screen.
;;		cy=1:	FAILURE
;;
;; Description:	Get a valid data selector pointing to video screen.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetScreenSel proc
	push	bx

	mov	ax, 0002h		; DPMI: Segment to Descriptor
	mov	bx, VideoPad		; We want to point at video pad
	int	31h			; Call DPMI.  (cy=1 if error)

	pop	bx
	ret
GetScreenSel endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; ProtModeRoutine
;; ===============
;;
;; Args:	None.
;;
;; Returns:	nothing.
;;
;; Description:	This is called from PROTECTED mode (after VCPI switch into
;;		PROTECTED mode), and displays the single character '!' in
;;		the upper-left corner of the display.  It uses the selector
;;		previously setup for accessing the virtual video PAD buffer.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ProtModeRoutine proc
	push	ax
	push	cx
	push	di
	push	ds

	cld

;
; Set up pointer to video.
;
	mov	ax,ScreenSel
	mov	es,ax
	xor	di, di			; ds:di -> Video Screen.
	mov	ah, 07h
	mov	al, 'D'
	mov	cx, 25*80

pmr_loop:
	stosw
	loop	pmr_loop

	pop	ds
	pop	di
	pop	cx
	pop	ax
	ret
ProtModeRoutine endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; GetScreenSeg
;; ============
;;
;; Args:	none
;;
;; Returns:	ax -> DESQview virtualized video PAD.
;;
;; Description:	Get possibly virtualized video PAD for direct writes to
;;		screen.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetScreenSeg proc
	push	di
	push	es

	xor	ax,ax			; es -> low 64K real segment
	mov	es,ax

	mov	ax,0b000h		; assume mono
	cmp	byte ptr es:[449h],7	; Mono?
	je	gss_dv_call

	mov	ax,0b800h		; Color.

gss_dv_call:
	mov	es,ax			; es -> video segment for BIOS call
	mov	ah,0feh			; get video PAD address
	int	10h			; Modifies ES:DI
	mov	ax,es			; return segment in ax

	pop	es
	pop	di
	ret
GetScreenSeg endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; AllocatePrivateData
;; ===================
;;
;; Args:	none.
;;
;; Returns:	cy=0:	Memory successfully allocated
;;		cy=1:	FAILURE: no memory available for DPMI private data.
;;
;; Description:	Allocate DPMI's private data area based on value in the
;;		variable SegsRequired, as set up by the procedure IsDPMI.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AllocatePrivateData proc
;
; As a .COM program, we have all available conventional memory allocated to
; us by DOS.  Reduce this requirement to our minimum value.
;
	mov	bx,FreeSeg		; get the first segment free above us.
	mov	ax,ds			; get the base of our code/data.
	sub	bx,ax			; bx = number of paragraphs required.
	mov	es,ax			; prepare for modify memory block call
	mov	ah,4ah			; DOS: Modify Memory Block
	int	21h			; Shrink to our minimum
	jc	apd_err			; Failure.

;
; We have returned unneeded memory back to DOS.  Now allocate what DPMI has
; told us it requires.
;
	mov	bx,SegsRequired		; get number of paragraphs required
	test	bx,bx			; if none, just return success.
	jz	apd_done
;
; Allocate private data area from DOS.
;
	mov	ah,48h			; DOS: Allocate Memory.
	int	21h
	jc	apd_err			; Failure.

;
; Memory was successfully allocated.  Save the segment for when we switch
; into PROTECTED mode.
;
	mov	PrivateDataSeg,ax

apd_done:
	clc				; return success.
	ret

apd_err:
	stc				; return failure.
	ret
AllocatePrivateData endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; IsDPMI
;; ======
;;
;; Args:	none.
;;
;; Returns:	cy=0:		DPMI Host is present.
;;		DPMIEntryPoint:	Set to V86 (or REAL) mode far address to call
;;				to cause the initial switch to PROTECTED mode.
;;		SegsRequired:	Set to the number of 16 byte paragraphs
;;				required by DPMI Host for its private data
;;				area.
;;
;;		cy=1:		FAILURE! DPMI host is not present.
;;
;; Description:	Determines whether a DPMI host is present, and if so, saves
;;		both the V86 (or REAL) mode far address to call to switch to
;;		protected mode, as well as the number of paragraphs of memory
;;		required by the DPMI host for its private data area.
;;		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IsDPMI proc
;
; Check to be sure INT 2Fh vector is not NULL.
;
	mov	ax,352fh
	int	21h
	mov	ax,es
	or	ax,bx
	jz	id_no_dpmi			; if NULL, no DPMI host.

;
; Use the DPMI: Obtain Switch Entry Point call to determine if DPMI host
; is present.
;
	mov	ax,1687h
	int	2fh
	test	ax,ax
	jnz	id_no_dpmi			; if ax != 0, no DPMI host.

;
; There is a DPMI host present.  Save its Switch Entry address, and its
; memory requirements, and return.
;
	mov	word ptr DPMIEntryPoint,di
	mov	word ptr DPMIEntryPoint+2,es
	mov	SegsRequired,si

	clc					; return success.
	ret

id_no_dpmi:
	stc					; return failure.
	ret
IsDPMI endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; main
;; ====
;;
;; Args:	ds = segment of PSP
;;		es = segment of PSP
;;		cs = segment of PSP
;;
;; Returns:
;;
;; Description:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
main proc
	cld				; set string moves forward.

;
; "Allocate" memory above program image for initial stack, and
; save segment to free memory.
;
	mov	si,offset end_of_program+500
	lea	ax,[si+15]		; si -> past top of local stack
	mov	cl,4			; convert address to segment
	shr	ax,cl
	mov	bx,cs
	add	ax,bx			; ax = first free segment past code.
	mov	FreeSeg,ax
	cmp	ax,ds:[2]		; check to see that there is free mem.
	jae	short m_out_of_mem	; .. nope.. failure.

;
; Set-up stack
;
	mov	sp,si			; sp -> top of stack
	call	IsDPMI			; check for DPMI support
	jc	short m_no_dpmi		; no DPMI, quit with message.

;
; Determine segment of video buffer (PAD)
;
	call	GetScreenSeg		; ax = segment of video pad.
	mov	VideoPad, ax		;

;
; Using return value of si (Number of paragraphs required by DPMI to switch
; into PROTECTED mode), allocate DPMI's private data area.
;
	call	AllocatePrivateData	; si = number of 16 byte paragraphs
	jc	short m_out_of_mem	; out of memory error.

;
; Set up registers for switch into protected mode:
;
; ax = flags.
; es = RM segment of DPMI private data area.
;
	mov	es,PrivateDataSeg	; es = segment of DPMI private data
	xor	ax,ax			; Initialize as a 16-bit application
	call	DPMIEntryPoint		; Switch into protected mode!

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; WE ARE NOW IN PROTECTED MODE!
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Get selector to access video memory directly.
;
	call	GetScreenSel		;
	jc	m_no_dpmi		; ERROR...

	mov	ScreenSel, ax		; save selector for "work" routines.

;
; Ok, now for the exciting part.
;
	call	ProtModeRoutine		; Do our "thang..."

;
; NOTE: No need to return to V86 (or REAL) mode to exit program, as with VCPI.
;
	mov	ax,4c00h
	int	21H

;
; Various ERROR exit points: display message and then exit.
;
; OUT OF MEMORY
;
m_out_of_mem:
	mov	dx,offset MemErrorMessage
m_err:
	mov	ah,9
	int	21H
	mov	ax,4c01h
	int	21h

;
; NO DPMI
;
m_no_dpmi:
	mov	dx,offset DPMIErrorMessage
	jmp	m_err
main endp

	even   	
end_of_program	label byte

d_seg	ends
	end	entry_point
