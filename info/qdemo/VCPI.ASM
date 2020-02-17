;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; VCPI Demonstration Program.
;; (C) Copyright 1992, Quarterdeck Office Systems.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	name	VCPI
	title	VCPI Demo Program
	.386				; enable 386 instructions.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; DATA STRUCTURE DEFINITIONS
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Define bit fields for Descriptor Access Rights and Page Table Entries
;
DescAccess	record DescPresent:1=1,DescDPL:2=0,DescClass:1=1,DescType:4=2
PageTableEntry	record PTE_D:1,PTE_A:1,X:2,PTE_US:1,PTE_RW:1,PTE_P:1

;
; Define the Descriptor Data Structure itself.
; Note: it contains the above DescAccess record.
;
DESCRIPTOR	struc
DescLimit	dw		-1
DescBase0_15	dw		?
DescBase16_23	db		?
DescAccessByte	DescAccess 	<,,,>	; 92h
DescGran	db		0
DescBase24_31	db		?
DESCRIPTOR ends

;
; Define MINIMUM Task Segment.  This will be the memory used by the 80386
; for its task segment structure.
;
TSS struc
	db	104 dup (0)
TSS ends

;
; Define (at assembly time) the minimum required descriptors to get us up
; and running after our transition from V86 to PROTECTED mode.
;
GDT struc
NulSel		db 8 dup (0)					; NOT USED
CodeSel		DESCRIPTOR <,,,DescAccess <,,,0ah>,,>		; Type 9ah
DataSel		DESCRIPTOR <,,,,,>				; Type 92h
TSSSel		DESCRIPTOR <TYPE TSS-1,,,DescAccess <,,0,9>,,>	; Type 89h
ZeroSel		DESCRIPTOR <-1,0,0,,8fh,0>			; 4 gig limit
ScreenSel	DESCRIPTOR <,,,,,>				; for VIDEO
VCPICodeSel	db 8 dup (0)					; VCPI code
VCPIOtherSels	db 16 dup (0)					; VCPI data
GDT ends

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; CODE STARTS HERE.  Define Code Segment as usual.
; We will be using 16 bit segments.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_seg segment use16 'code'
	assume cs:v_seg,ds:v_seg

	org 100h

entry_point:
	jmp	main

;
; V86 MODE Data Structures
;
GDTTable	GDT <>			; The actual GDT
TSSTable	TSS <>			; The actual TSS

;
; Define storage for copies of V86 mode SEGMENT registers.
;
RealModeCS			dw	?
RealModeDS			dw	?
RealModeES			dw	?
RealModeFS			dw	?
RealModeGS			dw	?
RealModeSS			dw	?

;
; Define storage for VCPI structure used for switching from V86 to
; PROTECTED mode.  These are actually elements of a structure as defined
; by the VCPI specification, and therefore must be contiguous.
;
RealToProtTable			label	dword
PageDirectoryPhysicalAddress	dd	?
GDTRLinearAddress		dd	?
IDTRLinearAddress		dd	?
LDTRValue			dw	0
TRValue				dw	TSSSel
ProtEIP				dw	ProtBegin,0
ProtCS				dw	CodeSel

;
; Define storage for the address of the VCPI structure used during the
; VCPI service 0DE0Ch transition into PROTECTED mode.
;
RealToProtLinearAddress 	dd	?
GDTR				dw	type GDT-1
				dd	?

;
; Needs to be set up if ints are enabled
;
IDTR				dw 	-1

ProtVCPIEntry			label	pword
ProtVCPIEIP			dd	?
ProtVCPICS			dw	VCPICodeSel

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
	mov	al, 'V'
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
;; EnterProtMode
;; =============
;;
;; Args:	V86 mode Machine State
;;
;; Returns:	PROTECTED mode Machine State
;;		Interrupts disabled.
;;
;; Description:	Sets up for, and then calls VCPI service 0DE0C:
;;		"Switch From V86 Mode to Protected Mode."
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
EnterProtMode proc
;
; First, save copies of all V86 mode register contents for return to
; real mode.
;
	mov	cs:RealModeGS,gs
	mov	cs:RealModeFS,fs
	mov	cs:RealModeES,es
	mov	cs:RealModeDS,ds
	mov	cs:RealModeSS,ss
	mov	cs:RealModeCS,cs

;
; Save registers destroyed by us and the VCPI call.
;
	push	eax
	push	ebx
	push	esi

;
; Save the current stack pointer so we can use it after mode switch.
;
	mov	ebx,esp

;
; Set esi = linear address of VCPI data structure containing the
; necessary values required for VCPI to execute the switch to
; PROTECTED mode.
;
	mov	esi,cs:RealToProtLinearAddress

;
; Disable interrupts, and perform the actual mode switch.
;
	cli
	mov	ax,0de0ch
	int	67h

;
; Upon returning from the VCPI mode switch call, we will be in PROTECTED mode.
; At this point, it is necessary to re-establish the stack, and load all of
; our segment registers.
;
; NOTE: Interrupts are still disabled at this point.
;
ProtBegin:
	mov	ax,DataSel	; get selector set up for our data segment
	mov	ss,ax		; re-establish our stack (ss:esp)
	mov	esp,ebx		; (The value of ebx has our old esp value)

;
; Re-load segment registers to our data selector.
;
	mov	ds,ax
	mov	es,ax
	mov	fs,ax
	mov	gs,ax

	pop	esi
	pop	ebx
	pop	eax
	ret
EnterProtMode endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; LeaveProtMode
;; =============
;;
;; Args:	PROTECTED mode Machine State
;;
;; Returns:	V86 mode Machine State
;;
;; Description:	Sets up the stack as required for the PROTECTED VCPI service
;;		0DE0Ch, and then calls the PROTECTED mode entry point of the
;;		VCPI server to perform the switch back to V86 mode.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LeaveProtMode proc
	push	eax			; save eax

	mov	eax,esp			; save esp (before pushing registers)

;
; Prepare Top of Stack as per VCPI spec.
;
	push	ax			; 16 bit filler
	push	cs:RealModeGS		; gs
	push	ax			; 16 bit filler
	push	cs:RealModeFS		; fs
	push	ax			; 16 bit filler
	push	cs:RealModeDS		; ds
	push	ax			; 16 bit filler
	push	cs:RealModeES		; es
	push	ax			; 16 bit filler
	push	cs:RealModeSS		; ss
	push	eax			; esp (before pushing registers)
	pushfd				; eflags
	push	ax			; 16 bit filler
	push	cs:RealModeCS		; cs
	push	0			; high 16 bits of eip
	push	offset RealBegin	; low  16 bits of eip (ip)
	mov	ax,ZeroSel		; setup ds to a selector that maps
	mov	ds,ax			;   all linear memory.
	movzx	esp,sp			; Make sure high word is 0 for VCPI
	mov	ax,0de0ch		; VCPI: Switch from PM to V86 mode.
	call	cs:ProtVCPIEntry	; bye...

;
; After switch , we end up here in V86 mode.
;
RealBegin:
	sti				; enable interrupts
	pop	eax			; restore original eax.
	ret
LeaveProtMode endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;; The following procedures and data structures are used to set up the
;; various routines and data structures above for use by a VCPI client.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
EMSID			db	'EMMXXXX0'
EMSNoFrameID		db	'EMMQXXX0'
EMSHandle		dw	?
EMSHandleAllocated	db	0

FreeSeg			dw	?
PageDirectorySeg	dw	?
PageTableSeg		dw	?

MemErrorMessage		db	'Not enough memory to run',13,10,'$'
VCPIErrorMessage	db	'VCPI is not present.',13,10,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Clear4K
;; =======
;;
;; Args:	es -> V86 mode segment.
;;
;; Returns:	nothing.
;;
;; Description:	Clears the first 4K of the segment pointed to by es.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Clear4K proc
	push	ax
	push	cx
	push	di

	mov	cx,4*1024/2		; number of 16 bit words in 4K
	xor	ax,ax			; value to fill (0)
	xor	di,di			; starting offset of fill (0000)
	rep	stosw			; Zero out the memory

	pop	di
	pop	cx
	pop	ax
	ret
Clear4K endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; GetPhysicalAddressOfSeg
;; =======================
;;
;; Args:	ax  = Segment number
;;
;; Returns:	edx = the physical address
;;
;; Description:	Uses VCPI service 0DE06h to determine the physical address
;;		of a given (V86 mode accessible) linear address.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetPhysicalAddressOfSeg proc
	push	ax
	push	cx

	mov	cx,ax
	shr	cx,8				; Convert segment to page no.
	mov	ax,0de06h
	int	67h

	pop	cx
	pop	ax
	ret
GetPhysicalAddressOfSeg endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; SetupPageTable
;; ==============
;;
;; Args:	none.
;;
;; Returns:	cy=0:	Success.  Page Directory and first Page Table are
;;			initialized.
;;		cy=1:	Failure.  Nothing initialized.  VCPI error.
;;
;; Description:	Clears the Page Directory and the first Page Table, then calls
;;		VCPI service 0DE01h to initialize the PROTECTED mode
;;		interface.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetupPageTable proc
	mov	es,PageDirectorySeg		; Clear Page Directory
	call	Clear4K

	mov	es,PageTableSeg			; Clear Page Table
	call	Clear4K

	xor	di,di				; es:di -> 4K page table.
	mov	si,offset GDTTable.VCPICodeSel	; ds:si -> first of three GDT
						; descriptors for use by VCPI.
	mov	ax,0de01h			; VCPI: Get Protected Mode
	int	67h				;       Interface.
	test	ah,ah				; Test for success.
	jnz	short supt_err			; Failure.

;
; VCPI Protected Mode Inteface successfully initialized.
;
	mov	ProtVCPIEIP,ebx			; Save PROTECTED mode entry.

;
; Get Physical address of Page Directory and save it in the VCPI mode switch
; data structure.
;
	mov	ax,PageDirectorySeg
	mov	es,ax				; es:0 -> Page Directory.
	call	GetPhysicalAddressOfSeg
	mov	PageDirectoryPhysicalAddress,edx

;
; Get Physical address of first Page Table and save it as the first page
; directory entry.
;
	mov	ax,PageTableSeg
	call	GetPhysicalAddressOfSeg
	or	dl,mask PTE_US or mask PTE_RW or mask PTE_P
	mov	es:[0],edx

	clc					; return success.
	ret

supt_err:
	stc					; return failure.
	ret
SetupPageTable endp

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
;; PointDescriptor
;; ===============
;;
;; Args:	eax        =  linear address
;;		edx        =  the length (<= one meg)
;;		ds:[si+bx] -> descriptor field
;;
;; Returns:	nothing
;;
;;
;; Description:	Points the descriptor (ds:[si+bx]) to a linear address (eax).
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PointDescriptor proc
	push	edx

	dec	edx
	mov	DescLimit[si+bx],dx
	shr	edx,16
	and	DescGran[si+bx],040h	; Preserve Default bit
	or	DescGran[si+bx],dl	; Set limit 19..16
	mov	edx,eax
	mov	DescBase0_15[si+bx],dx
	shr	edx,16
	mov	DescBase16_23[si+bx],dl
	mov	DescBase24_31[si+bx],dh

	pop	edx
	ret
PointDescriptor endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; SetupAdresses
;; =============
;;
;; Args:	none.
;;
;; Returns:	none.
;;
;; Description:	Initialize key selectors in GDT to provide access to required
;;		memory once in PROTECTED mode.  Also, initialize the VCPI
;;		mode switching data structure required for switching into
;;		PROTECTED mode.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetupAddresses proc
	mov	si,offset GDTTable	; ds:si -> GDT
	xor	eax,eax			; make sure high 16 bits are 0.

;
; Initialize Code Selector.
;
	mov	ax,cs			; convert code segment to linear addr.
	shl	eax,4			; eax = linear address (Selector base)
	mov	edx,64*1024		; edx = 64K (Selector Limit)
	mov	bx,CodeSel		; bx  = Selector to initialize.
	call	PointDescriptor		; Initialize descriptor.

;
; Initialize Data Selector (same as Code Selector)
;
	mov	bx,DataSel
	call	PointDescriptor		; Initialize descriptor.

;
; Initialize the TSS
;
	push	eax			; Save base linear address
	add	eax,offset TSSTable	; eax = linear address of TSS
	mov	edx,type TSS		; edx = Selector Limit
	mov	bx,TSSSel		; bx  = Selector to initialize.
	call	PointDescriptor		; Initialize descriptor.

;
; Initialize a selector to access video memory.
;
	call	GetScreenSeg		; returns with video segment in ax
	movzx	eax,ax			; clear high 16 bits of eax
	shl	eax,4			; eax = linear address of screen
	mov	edx,25*80*2		; edx = size of video (Selector Limit)
	mov	bx,ScreenSel		; bx  = Selector to initialize.
	call	PointDescriptor		; Initialize descriptor.
	pop	eax			; restore base linear address

;
; Calculate the linear address of VCPI data structure used for V86 to
; PROTECTED mode transitions, and save it in a variable for use by
; mode switch routines.
;
	push	eax
	add	eax,offset RealToProtTable
	mov	RealToProtLinearAddress,eax
	pop	eax

;
; Calculate the linear address of the GDT, and save it in the VCPI mode switch
; data structure.
;
	push	eax
	add	eax,offset GDTTable
	mov	dword ptr GDTR+2,eax
	pop	eax

;
; Calculate the linear address of the pointer to the GDT (GDTR), and save it
; in the VCPI mode switch data structure.
;
	push	eax
	add	eax,offset GDTR
	mov	GDTRLinearAddress,eax
	pop	eax

;
; Calculate the linear address of the IDT, and save it in the VCPI mode switch
; data structure.
;
	push	eax
	add	eax,offset IDTR
	mov	IDTRLinearAddress,eax
	pop	eax

	ret
SetupAddresses endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; AllocatePageTables
;; ==================
;;
;; Args:	none.
;;
;; Returns:	cy=0:	Page Directory and Page Table 0 allocated.
;;			PageDirectorySeg set up to segment of Page Directory
;;			PageTableSeg set up to segment of first Page Table.
;;		cy=1:	Failure: Page Tables are not set up.  OUT OF MEMORY.
;;
;; Description:	Allocate and initialize pointers to Page Directory and first
;;		page table.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AllocatePageTables proc
	mov	ax,FreeSeg			; get beginning of free mem.
	add	ax,0ffh
	xor	al,al				; Round up to 4K boundary
	mov	PageDirectorySeg,ax		; Set up segment for Page Dir.
	inc	ah				; Use next 4K page for
	mov	PageTableSeg,ax			;   first page table (PT0).
	inc	ah				; Next 4K page is new Free Mem
	cmp	ax,ds:[2]			; Check for out of memory
	jae	short apt_err			; ... if no mem, exit w/cy=1

	clc					; return success.
	ret

apt_err:
	stc					; return failure.
	ret
AllocatePageTables endp

.8086

Cascade67	dd ?

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Int67Stub
;; =========
;;
;; Args:	none.
;;
;; Returns:	nothing, or cascades to previous interrupt.
;;
;; Description: NOP stub to assure that an INT 67h handler exists.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Int67Stub proc
	cmp	ax,0de00h
	jne	i67_casc
	iret

i67_casc:
	jmp	cs:Cascade67
Int67Stub endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; IsVCPI
;; ======
;;
;; Args:	none.
;;
;; Returns:	All registers except ds are destroyed
;;		cy = 0: VCPI is present.
;;		cy = 1: VCPI is NOT present.
;;
;; Description:	Performs the recommended procedure for determining whether
;;		VCPI services are available on a given machine.  This
;;		procedure takes into consideration the possibility of a VCPI
;;		implementation that does NOT support EMS, for one reason or
;;		another.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IsVCPI proc
;
; Test for the validity of the INT 67h vector.
;
	mov	ax,3567h		; DOS get RM vector
	int	21h

;
; look for DEVICE name for EMS driver.
;
	mov	di,10			; es:di -> potential DRIVER string
	mov	si,offset EMSID		; ds:si -> our copy to match
	mov	cx,8			; match 8 bytes
	repe	cmpsb			; compare...
	je	short iv_ems		; if a match, we have an EMS driver.

;
; No standard EMS device string found.
; Now check for NOFRAME driver.
;
	mov	di,10			; es:di -> potential DRIVER string
	mov	si,offset EMSNoFrameID	; ds:si -> our copy to match
	mov	cx,8			; match 8 bytes
	repe	cmpsb			; compare...
	je	iv_ems			; if a match, we have an EMS driver.

;
; This test failed as well.
; Check to see if it is QEMM and NOEMS
;
iv_check_noems:
	xor	ax,ax			; set up es to V86 interrupt table
	mov	es,ax
	mov	dx,offset Int67Stub
	mov	cx,cs		   	; cx:dx -> our local INT 67h stub.
	mov	ax,0de00h		; setup for XDI

;
; We want to be sure that we have a valid (non-zero) INT 67h interrupt vector
; before attempting to test for QEMM through the XDI interface.  To this end,
; we temporarily insert a valid INT 67h stub into the interrupt chain that
; passes through
;
	cli
	xchg	cx,es:[67h*4+2]		; temp
	xchg	dx,es:[67h*4]
	mov	word ptr cs:Cascade67+2,cx
	mov	word ptr cs:Cascade67,dx
	int	67h

	cli				; Just in case they got enabled
	mov	es:[67h*4+2],cx
	mov	es:[67h*4],dx
	sti
	jmp	short iv_after_detect

;
; We have detected an EMS driver of some sort.  We now know it is OK
; to use the INT 67h EMS interface.
;
iv_ems:
	mov	ah,46h
	int	67h
	test	ah,ah
	jnz	short iv_err

	cmp	al,40h
	jb	short iv_err

	mov	ah,43h
	mov	bx,1
	int	67h			; Allocate some EMS to turn manager ON
	test	ah,ah
	jnz	iv_err

	mov	EMSHandle,dx		; keep track of handle to free later.
	mov	EMSHandleAllocated,1	; indicate that memory has been taken.
	mov	ax,0de00h		; do the detection call again
	int	67h

iv_after_detect:
	test	ah,ah
	jnz	short iv_err

	clc				; return success.  VCPI available.
	ret	

iv_err:
	stc				; return failure.  NO VCPI available.
	ret
IsVCPI endp

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
	call	IsVCPI			; check for VCPI support
	jc	short m_no_vcpi		; no VCPI, quit with message.

;
; Initialize page tables.
;
	call	AllocatePageTables
	jc	short m_out_of_mem

	call	SetupPageTable
	jc	short m_no_vcpi

;
; Initialize linear adress space.
;
	call	SetupAddresses

;
; Switch to protected mode.
;
	call	EnterProtMode

;
; Do our "thang..."
;
	call	ProtModeRoutine

;
; NOTE: We must return to V86 (or REAL) mode to terminate.
;
	call	LeaveProtMode
	mov	al,0

;
; Prepare to terminate.  If we allocated an EMS page in setting up
; for VCPI, then free it now.
;
m_term:
	cmp	EMSHandleAllocated,0	; Did we allocate an EMS page?
	je	m_4c			; ... no... just exit.
;
; Free our EMS handle.
;
	push	ax
	mov	dx,EMSHandle
	mov	ah,45h
	int	67h
	pop	ax

;
; Exit!
;
m_4c:
	mov	ah,4ch
	int	21h

;
; Various ERROR exit points: display message and then exit.
;
; OUT OF MEMORY
;
m_out_of_mem:
	mov	dx,offset MemErrorMessage

m_err:
	mov	ah,9
	int	21h
	mov	al,1
	jmp	m_term

;
; NO VCPI
;
m_no_vcpi:
	mov	dx,offset VCPIErrorMessage
	jmp	m_err
main endp

	even   	
end_of_program	label byte

v_seg	ends
	end entry_point
