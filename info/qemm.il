--------m-673F--CX5145-----------------------
INT 67 U - QEMM-386 v4.23+ - INSTALLATION CHECK
        AH = 3Fh
        CX = 5145h ("QE")
        DX = 4D4Dh ("MM")
Return: AH = 00h if installed
            ES:DI -> QEMM API entry point (see #2131,#2134,#2245)
Notes:  if no other program has hooked INT 67, an alternate installation
          check is to test for the string
          "QUARTERDECK EXPANDED MEMORY MANAGER 386" at offset 14h in the INT 67
          handler's segment; the word at offset 12h contains the offset in
          the handler's segment of the API entry point
        although this function is still undocumented, Quarterdeck has recently
          documented two alternate methods for determining the QEMM API entry
          point, as well as several of the API functions
        MICEMM (Micronics Expanded Memory Manager) versions 2.0C and 4D support
          the alternate QEMM installation check and entry point functions 00h,
          02h, and 03h; version 4D only provides the signature string if the
          commandline argument "DV" is provided
        386MAX v6.01 responds to this call, but DESQview 2.42 does not
          recognize the returned entry point as providing QEMM's capabilities
          because a) only functions 0Ch (different from QEMM 0Ch) and
                        1000h-1009h are supported,
                  b) status is returned as for EMS functions, not QEMM funcs
                  c) the protected-mode entry point returned by function 1000h
                        only supports functions 0Ch, 1004h, 1005h, and 100Ah
        the string check mentioned above is not supported by 386MAX
SeeAlso: AX=5BF0h,AH=DDh,AX=FFA5h,INT 15/AX=11DEh,INT 21/AX=4402h/SF=01h
SeeAlso: INT 21/AX=4402h"QEMM",INT 21/AX=4402h"386MAX",INT 2F/AX=D201h/BX=5145h

(Table 2131)
Values for calling QEMM "QPI_GetStatus" function:
        AH = 00h get QEMM state
Return: CF clear
        AL = QEMM state
            bit 0 set if QEMM turned OFF
            bit 1 set if in "Auto" mode
Note:   this function is officially documented
SeeAlso: #2132,#2133,#2134,#2245

(Table 2132)
Values for calling QEMM "QPI_SetStatus" function:
        AH = 01h set QEMM state
        AL = new state
            bit 0 set: place QEMM in OFF state
Return: CF clear if successful
        CF set on error
Note:   this function is officially documented
SeeAlso: #2131

(Table 2133)
Values for calling QEMM QPI function 02h:
        AH = 02h get ???
Return: CF clear
        AX = segment of ??? data structure
        Data Structure
        Offset  Size    Description
         00h    DWORD   page table entry for ???
                ???
SeeAlso: #2134

(Table 2134)
Values for calling QEMM "QPI_GetVersion" function:
        AH = 03h get QEMM version
Return: CF clear
        AX = BX = version in BCD
Notes:  this function is officially documented.  The most recent official docs
          state that the version is returned in both AX and BX; older
          documentation only mentions BX
        MICEMM returns AX=0001h, BX unchanged
SeeAlso: #2131,#2135

(Table 2135)
Values for calling QEMM QPI function 04h:
        AH = 04h allocate 4K page and set AUTO/ON mode
Return: CF clear if successful
            DX = page number of a 4K page
        CF set if unable to allocate page
Note:   QEMM mode unchanged if not AUTO/OFF
SeeAlso: #2136

(Table 2136)
Values for calling QEMM QPI function 05h:
        AH = 05h free 4K page and turn QEMM off
        DX = page number returned by function 04h
Return: CF clear
Note:   QEMM mode unchanged if not AUTO/ON
SeeAlso: #2135,#2137

(Table 2137)
Values for calling QEMM QPI function 06h:
        AH = 06h make new mapping context???
        DX = page number of 4K page to hold page table
Return: CF clear
Note:   copies page table into given page and then sets ??? page table entry
          to point at copy
SeeAlso: #2138,#2139

(Table 2138)
Values for calling QEMM QPI function 07h:
        AH = 07h get mapping context
Return: CF clear
        DX = page number of page table for current mapping context
SeeAlso: #2134,#2137,#2139

(Table 2139)
Values for calling QEMM QPI function 08h:
        AH = 08h set mapping context???
        DX = linear page number of page table
Return: CF clear
SeeAlso: #2134,#2137,#2138,#2140,#2142

(Table 2140)
Values for calling QEMM QPI function 09h:
        AH = 09h get linear page number for page table entry
        CX = page table index
Return: CF clear
        DX = linear page number
SeeAlso: #2141

(Table 2141)
Values for calling QEMM QPI function 0Ah:
        AH = 0Ah set linear page number for page table entry
        CX = page table index
        DX = linear page number
Return: CF clear
SeeAlso: #2140

(Table 2142)
Values for calling QEMM QPI function 0Bh:
        AH = 0Bh map 4K pages
        BX = number of pages
        CX = first page number (must be 0100h to allocate HMA)
        DX = EMS handle (memory belonging to EMS handle will be mapped
              into the address space beginning with the first page
              allocated to the handle)
Return: AH = 00h
SeeAlso: #2139,#2143

(Table 2143)
Values for calling QEMM QPI function 0Ch:
        AH = 0Ch get available memory
Return: CF clear
        BX = 0001h
        CX = total 4K pages???
        DX = number of 4K pages free
SeeAlso: #2142,#2144

(Table 2144)
Values for calling QEMM QPI function 0Dh:
        AH = 0Dh CRT controller I/O port trapping
        AL = mode
            00h only trap on I/O ports 03C0h-03C5h, 03C7h, 03CAh-03CFh
            01h trap on ports 03B4h, 03B5h, 03B8h, 03C6h, 03C8h, 03C9h,
                  03D4h, and 03D5h
            02h only trap on I/O ports 03C6h, 03C8h, and 03C9h
Return: CF clear

(Table 2145)
Values for calling QEMM QPI function 0Eh:
        AH = 0Eh set cursor virtualization callbacks
        DS:BX -> FAR routine for getting hardware cursor address
        ES:DX -> FAR routine for setting hardware cursor address
Return: CF clear
Note:   both callbacks are invoked with CL indicating which
          CRT controller register to access (0Eh for high
          byte of cursor address, 0Fh for low byte)
        the DS:BX callback should return BX=cursor address;
          ES:DX is called with BL or BH (depending on CL)
          set to the appropriate half of the cursor's address

(Table 2146)
Values for calling QEMM QPI function 0Fh:
        AH = 0Fh unmap 4K pages
        CX = first page number
        DX = number of pages
Return: CF clear
        AL = 00h/01h if ???
Note:   if CX=0100h and DX=0010h, the HMA is remapped to
          simulate a disabled A20

(Table 2147)
Values for calling QEMM QPI function 1000h:
        AX = 1000h get protected-mode interface
        DS:SI -> 16-byte buffer for two GDT entries
        ES:DI -> buffer for 4K page table
Return: CF clear
        EAX = offset of protected-mode API entry point
        DS:SI buffer filled with two GDT descriptors
                first is QEMM code segment, second is data???
        ES:DI buffer filled with 4K page table
        DI points to first unused page table entry
SeeAlso: INT 67/AX=DE01h

(Table 2148)
Values for calling QEMM QPI function 1001h:
        AX = 1001h get CPU debug registers
        ES:DI -> buffer for debug registers (8 DWORDs)
Return: CF clear
        BL = INT01 handling (see function 1002h)
        ES:DI buffer filled

(Table 2149)
Values for calling QEMM QPI function 1002h:
        AX = 1002h set CPU debug registers
        BL = INT01 handling
            00h  reflect all debugging exceptions as V86-mode INT 01's
            else convert debugging exceptions other than single-step
                  into V86-mode INT 03's, single-step to INT 01's
        ES:DI -> buffer containing debug registers (8 DWORDs)
Return: CF clear
Notes:  identical to INT 67/AX=DE09h if BL=01h
        the INT01 handling flag is set to 01h by the general-protection
          violation handler for certain privileged instructions

(Table 2150)
Values for calling QEMM QPI function 1003h:
        AX = 1003h get machine status word CR0
Return: CF clear
        EAX = contents of CR0
SeeAlso: INT 67/AX=DE07h

(Table 2151)
Values for calling QEMM QPI function 1004h:
        AX = 1004h allocate a 4K page
Return: CF clear if successful
            EDX = linear address of allocated page
        CF set on error
SeeAlso: INT 67/AX=DE04h

(Table 2152)
Values for calling QEMM QPI function 1005h:
        AX = 1005h free 4K page
        EDX = linear address of page to free
Return: CF clear
SeeAlso: INT 67/AX=DE05h

(Table 2153)
Values for calling QEMM QPI function 1006h:
        AX = 1006h NOP
Return: CF set

(Table 2154)
Values for calling QEMM QPI function 1007h:
        AX = 1007h get maximum physical memory address
Return: CF clear
        EDX = physical address of highest 4K memory page
SeeAlso: INT 67/AX=DE02h

(Table 2155)
Values for calling QEMM QPI function 1008h:
        AX = 1008h get physical address of page in first megabyte
        CX = page number (linear address shifted right 12 bits)
Return: CF clear
        EDX = linear address of page
SeeAlso: function 1F00h

(Table 2156)
Values for calling QEMM QPI function 1009h:
        AX = 1009h switch to protected mode
        ESI = linear address in first megabyte of system reg values
              (see INT 67/AX=DE0Ch)
        interrupts disabled
Return: interrupts disabled
        GDTR, IDTR, LDTR, TR loaded
        SS:ESP must have at least 16 bytes space, and the
              entry point is required to set up a new stack
              before enabling interrupts
        EAX, ESI, DS, ES, FS, GS destroyed

(Table 2157)
Values for calling QEMM QPI function 100Ah:
        AX = 100Ah switch back to virtual-86 mode
        DS = selector for data segment from function 1000h
        SS:ESP in first megabyte of linear memory
        interrupts disabled
        STACK:  QWORD  return address from FAR call to 32-bit segment
                DWORD  EIP
                DWORD  CS
                DWORD  reserved for EFLAGS
                DWORD  ESP
                DWORD  SS
                DWORD  ES
                DWORD  DS
                DWORD  FS
                DWORD  GS
        will switch to virtual86 mode with interrupts disabled, all
          segment registers loaded, and EAX destroyed.

(Table 2158)
Values for calling QEMM QPI function 11h:
        AH = 11h get memory type map
        AL = zero/nonzero ??? (set by QEMM.COM but apparently ignored
              by QEMM 6.00)
        ES:DI -> 256-byte buffer for memory types
Return: CF clear
        BL = ???
        ES:DI buffer filled
Note:   each byte of the buffer corresponds to a 4K page, and
          contains the type of that page: 00h = mappable,
          02h = mapped ROM, 03h = high RAM, 04h = excluded,
          05h = video, 06h = ROM, 07h = adapter ROM,
          08h = split ROM, 09h = page frame, 0Ah = RAMmable,
          0Bh = conventional, 83h = high RAM under MS Windows

(Table 2159)
Values for calling QEMM QPI function 12h:
        AH = 12h get HIRAM chain
Return: CF clear
        BX = segment of first MCB in high memory
            0000h if no high memory

(Table 2160)
Values for calling QEMM QPI function 1300h:
        AX = 1300h VIDRAMEGA???
        BL = 00h copy ???
             nonzero copy ??? (reverse)
Return: CF clear
        AL = status
            00h if all pages clean
            01h if any page dirty

(Table 2161)
Values for calling QEMM QPI function 1301h:
        AX = 1301h check if pages modified
        DX:DI = start address of range to check
        CX = length of range in paragraphs
Return: CF clear
        CX = status
            0000h none of the indicated pages is dirty
                DI destroyed
            1000h one or more pages is dirty
                DI = low word of first dirty page's linear addr

(Table 2162)
Values for calling QEMM QPI function 1302h:
        AX = 1302h ???
        BL = ???
        BH = ???
        CX = ???
        SI = offset of ???
        DI = offset of ???
        ???
Return: CF clear
        ???
Note:   disables certain interrupts at the two 8259 PICs during
          execution; also modifies CRT controller during
          execution under certain circumstances

(Table 2163)
Values for calling QEMM QPI function 1303h:
        AX = 1303h initialize EGA graphics virtualization
        BX = number of pages (less 1) of EMS to allocate
Return: CF clear if successful
            DX = EMS handle
        CF set on error

(Table 2164)
Values for calling QEMM QPI function 1304h:
        AX = 1304h shutdown EGA graphics virtualization
        DX = EMS handle being used for virtualization
Return: CF clear

(Table 2165)
Values for calling QEMM QPI function 1305h:
        AX = 1305h select portion of EGA graphics to virtualize???
        (related to graphics virtualization, changes memory mappings)
        CX = start offset within A000h segment of virtualized mem???
Return: CF clear
Note:   disables certain interrupts at the two 8259 PICs during
          execution (see func 130Ch) and runs inside a QEMM
          critical section

(Table 2166)
Values for calling QEMM QPI function 1306h:
        AX = 1306h set DESQview critical section counter address
        ES:BX -> WORD DESQview critical section counter or 0000h:0000h
Return: CF clear
Note:   also sets a pointer in the low-memory part of QEMM to
          the current value of INT 15 if ES:BX not 0000h:0000h

(Table 2167)
Values for calling QEMM QPI function 1307h:
        AX = 1307h ??? (changes memory mappings for entire A000h segment)
Return: CF clear
Note:   disables certain interrupts at the two 8259 PICs during
          execution (see func 130Ch) and runs inside a QEMM
          critical section

(Table 2168)
Values for calling QEMM QPI function 1308h:
        AX = 1308h start/reset CRT controller I/O trapping
        BL = subfunction
            00h restore CRTC I/O port trapping to previous state
            else start trapping all accesses to I/O ports 03B0-03DF
Return: CF clear
Note:   if called more than once in a row with BL nonzero, the
          original state of the I/O port trapping will be lost

(Table 2169)
Values for calling QEMM QPI function 1309h:
        AX = 1309h Hercules mode-change support
        ES:BX -> new address for Hercules mode-change callback
Return: CF clear
Note:   the callback function is called whenever the CRTC mode
          register is written, with AL set to the value written

(Table 2170)
Values for calling QEMM QPI function 130Ah:
        AX = 130Ah virtualize EGA/VGA DAC registers (I/O ports 03C8h/03C9h)
        CX:DX -> DAC register virtualization buffer (see #2252)
                or 0000h:0000h to disable
Return: CF clear

(Table 2171)
Values for calling QEMM QPI function 130Bh:
        AX = 130Bh ???
        BL = ??? (??? or 00h)
Return: CF clear
        ???
Note:   calls AX=130Eh in some cases

(Table 2172)
Values for calling QEMM QPI function 130Ch:
        AX = 130Ch set interrupts to mask
        BX = interrupts to mask out during AX=1302h,AX=1307h,AX=1308h,
              AX=130Dh,AX=1310h (BL = master PIC, BH = slave PIC)
Return: CF clear

(Table 2173)
Values for calling QEMM QPI function 130Dh:
        AX = 130Dh map EGA memory at A0000h
        ???
Return: CF clear
Note:   disables certain interrupts at the two 8259 PICs during execution
          (see #2172) and runs inside a QEMM critical section
        calls AX=1307h (see #2167)

(Table 2174)
Values for calling QEMM QPI function 130Eh:
        AX = 130Eh ??? (modifies CRT controller setup)
        ???
Return: CF clear

(Table 2175)
Values for calling QEMM QPI function 130Fh:
        AX = 130Fh reset ???
Return: CF clear

(Table 2176)
Values for calling QEMM QPI function 1310h:
        AX = 1310h copy modified pages to physical video RAM???
        ???
Return: CF clear
Note:   disables certain interrupts at the two 8259 PICs during execution
          (see #2172) and runs inside a QEMM critical section
        also calls AX=130Dh (see #2173)

(Table 2177)
Values for calling QEMM QPI function 1311h:
        AX = 1311h set ???
        BL = zero/nonzero???
Return: CF clear
Note:   certain operations will be performed with interrupts
          (as set by AX=130Ch) enabled rather than disabled if
          called with BL nonzero

(Table 2178)
Values for calling QEMM QPI function 1312h:
        AX = 1312h (v6.02) NOP???
Note:   called by DV 2.42, but appears to be a NOP in QEMM 6.02

(Table 2179)
Values for calling QEMM QPI function 1400h:
        AX = 1400h initialize DESQview "protection level" support
        ES:DI -> protection level configuration (at least 24 bytes)
                (see #2246)
        BL = highest ??? to return (one less than number of words)
Return: CF clear
        AX = ??? (4204h for v6.00)
Note:   QEMM also sets the protected mode INT 02 and INT 06
          vectors to alternate handlers in certain cases

(Table 2180)
Values for calling QEMM QPI function 1401h:
        AX = 1401h turn off DESQview protection level support
                Return: CF clear
                        ???
                Notes:  clears the DV critical-section flag address set with
                          function 1306h
                        QEMM also sets the protected mode INT 02 and INT 06
                          vectors to the default handlers if they had been
                          revectored by function 1400h

(Table 2181)
Values for calling QEMM QPI function 1402h:
        AX = 1402h set protection level???
                BL = protection level???
                    00h NOP
                    01h ???
                    02h ???
                    other (03h) ???
                ES:DI -> ???
                Return: CF clear
                        ???
                Format of Data structure:
                Offset  Size    Description
                 00h    WORD    segment of ??? (X, word at X:0136h set to X)
                 02h    WORD    segment of ??? (word at X:0124h set to this)
                 04h    WORD    number of paragraphs of ???
                 06h  3 WORDs   ??? (copied to X:0000h)
                 0Ch    WORD    ???

(Table 2182)
Values for calling QEMM QPI function 1403h:
        AX = 1403h add ??? to end of list and ??? (execute func 1406h)
                ES:DI -> ??? structure added to end of ??? list
                        (at least 31 bytes, DWORD at offset 06h used for
                         storing pointer to next struc, WORD at offset 00h
                         seems to be a key or index)
                Return: CF clear

(Table 2183)
Values for calling QEMM QPI function 1404h:
        AX = 1404h NOP
                Return: CF clear

(Table 2184)
Values for calling QEMM QPI function 1405h:
        AX = 1405h remove ??? from ??? list
                BX = key???
                Return: CF clear

(Table 2185)
Values for calling QEMM QPI function 1406h:
        AX = 1406h ???
                ???
                Return: CF clear
                        ???
                Notes:  this function is a NOP unless protection level 2 or 3
                          is active
                        when not a NOP, one of the actions is to write-protect
                          certain memory pages

(Table 2186)
Values for calling QEMM QPI function 1407h:
        AX = 1407h ???
                ???
                Return: CF clear
                        ???
                Note:   same as function 1406h, but only does anything if
                          protection level 2 is active

(Table 2187)
Values for calling QEMM QPI function 1408h:
        AX = 1408h unprotect???
                ???
                Return: CF clear
                        ???

(Table 2188)
Values for calling QEMM QPI function 1409h:
        AX = 1409h abort program causing protection violation???
                ???
                Return: CF clear
                        ???

(Table 2189)
Values for calling QEMM QPI function 140Ah:
        AX = 140Ah set ???
                BX = index of ???
                Return: CF clear
                        ???
                Notes:  no range checking is performed on BX
                        this function is a NOP unless protection level 3 active

(Table 2190)
Values for calling QEMM QPI function 140Bh:
        AX = 140Bh get ???
                BX = index of ???
                SI = 0000h
                Return: CF clear
                        SI = segment of 256-byte buffer??? or 0000h
                Notes:  no range checking is performed on BX
                        this function is a NOP unless protection level 3 active

(Table 2191)
Values for calling QEMM QPI function 15h:
        AH = 15h set timer channel 0 virtualization buffer
                ES:BX -> WORD buffer for timer channel 0 divisor
                        0000h:0000h to disable virtualization
                Return: CF clear

(Table 2192)
Values for calling QEMM v5.00+ QPI function 1600h:
        AX = 1600h get memory access status
                ES:DI -> 256-byte buffer
                Return: ES:DI buffer filled
                Note:   each byte of the buffer indicates the status of a 4K
                          page (bit 0 set if read, bit 1 set if written)

(Table 2193)
Values for calling QEMM v5.00+ QPI function 1601h:
        AX = 1601h set memory access status
                ES:DI -> 256-byte buffer containing access statuses (see #2192)

(Table 2194)
Values for calling QEMM v5.00+ QPI function 17h:
        AH = 17h get memory usage statistics
                ES:DI -> 81-byte buffer for memory statistics (see #2250)
                Return: CF clear

(Table 2195)
Values for calling QEMM v5.11+ QPI function 18h:
        AH = 18h check whether conventional memory mapped into address range
                ES:BX = starting address
                CX = number of 4K pages
                Return: CF clear
                        AL = 00h one or more pages is remapped
                             01h all pages in range are conventional memory
                                (physical address == virtual address)

(Table 2196)
Values for calling QEMM v5.11+ QPI function 19h:
        AH = 19h NOP
                Return: CF set

(Table 2197)
Values for calling QEMM v5.11+ "QPI_UntrappedIORead" function:
        AX = 1A00h get byte from I/O port
        DX = port number
Return: CF clear
        BL = port value
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2198)
Values for calling QEMM v5.11+ "QPI_UntrappedIOWrite" function:
        AX = 1A01h send byte to I/O port
        BL = value to send
        DX = port number
Return: CF clear
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2199)
Values for calling QEMM v5.11+ "QPI_UntrappedIOReadIndexed" function:
        AX = 1A02h
        BH = index value to send
        DX = base port number
Return: CF clear
        BL = value read from I/O port (DX+1)
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2200)
Values for calling QEMM v5.11+ "QPI_UntrappedIOWriteIndexed" function:
        AX = 1A03h send bytes to two consecutive I/O ports
        BH = value for first I/O port (DX)
        BL = value for second I/O port (DX+1)
        DX = base port number
Return: CF clear
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2201)
Values for calling QEMM v7.03+ "QPI_UntrappedIO" function:
        AX = 1A04h
        BX = value to write to port
        CX = direction and size
            bit 2: output instead of input
            bit 3: word instead of byte
        DX = I/O port to be accessed
Return: CF clear
        BX = value read (if CX indicates read)
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2202)
Values for calling QEMM v7.03+ function 1A05h
        AX = 1A05h
        ???
Return: ???

(Table 2203)
Values for calling QEMM v7.03+ "QPI_GetIOCallback" function:
        AX = 1A06h
Return: CF clear
        ES:DI -> current I/O callback function
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2204)
Values for calling QEMM v7.03+ "QPI_SetIOCallback" function:
        AX = 1A07h
        ES:DI -> new I/O callback function
Return: CF clear
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2205)
Values for calling QEMM v7.03+ "QPI_GetPortTrap" function:
        AX = 1A08h
        DX = I/O port number
Return: CF clear
        BL = trapping state (00h not being trapped, 01h trap installed)
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2206)
Values for calling QEMM v7.03+ "QPI_SetPortTrap" function:
        AX = 1A09h
        DX = I/O port number
Return: CF clear
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2207)
Values for calling QEMM v7.03+ "QPI_ClearPortTrap" function:
        AX = 1A0Ah
        DX = I/O port number
Return: CF clear
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2208)
Values for calling QEMM v5.11+ QPI function 1B00h:
        AX = 1B00h get EMM Import Structure address
        ES:DI -> buffer for EMM import data structure (see #2248)
Return: CF set on error
        CF clear if successful
SeeAlso: INT 21/AX=4402h/SF=01h

(Table 2209)
Values for calling QEMM v5.11+ QPI function 1B01h:
        AX = 1B01h disable V86 mode
Return: CF set on error
            (i.e. no Global EMM Import rec. allocated)
        CF clear if successful
Note:   shuts down EMS and initializes Global EMM Import record; this function
          is invoked from the callback supplied by INT 2F/AX=1605h

(Table 2210)
Values for calling QEMM v5.11+ QPI function 1B02h:
        AX = 1B02h enable V86 mode
Return: CF set on error
        CF clear if successful
Note:   restarts EMS and frees Global EMM Import record; this function is
          invoked from the callback supplied by INT 2F/AX=1605h

(Table 2211)
Values for calling QEMM v5.11+ QPI function 1B03h:
        AX = 1B03h MS Windows initializing
        CX = segment from which Windows init broadcast made???
        DX = Windows startup flags
        DI = Windows version number (major in upper byte)
Return: CF clear if successful
            DS:SI -> V86 mode enable/disable callback
                  (see #1413 at INT 2F/AX=1605h)
            ES:BX -> startup info structure (see #1410 at INT 2F/AX=1605h)
        CF set on error (unable to start Windows)
SeeAlso: INT 2F/AX=1605h

(Table 2212)
Values for calling QEMM v5.11+ QPI function 1B04h:
        AX = 1B04h MS Windows terminating
Return: CF clear

(Table 2213)
Values for calling QEMM v5.11+ QPI function 1B05h:
        AX = 1B05h determine whether program is driver
        DS:DX -> ASCIZ filename
Return: CF clear
        AL = status
            01h if string ends in ".DRV"
            FFh if string ends in "GDI.EXE"
            00h otherwise
Note:   when MS Windows 3.0 standard mode starts, QEMM patches all drivers
          until GDI.EXE is loaded

(Table 2214)
Values for calling QEMM v5.11+ QPI function 1B06h:
        AX = 1B06h patch protected-mode check in Windows driver
        CX = length of data pointed at by DS:DX
        DS:DX -> buffer containing Windows driver code
Return: CF clear
Note:   patches all SMSW x/TEST x,1 instruction sequences into MOV x,CS/VERW x
          sequences, which has the effect that the protected-mode check will
          only indicate protected mode in native protected mode and not in V86
          mode

(Table 2215)
Values for calling QEMM v5.11+ QPI function 1B07h:
        AX = 1B07h
BUG: QEMM 6.00-7.01 accept this and branch randomly

(Table 2216)
Values for calling QEMM v5.11+ QPI function 1Bxxh:
        AX = 1B08h to 1BFFh
Return: CF set

(Table 2217)
Values for calling QEMM v5.11+ QPI function 1C00h:
        AX = 1C00h disable IRQ0-7 calldowns
Return: CF clear

(Table 2218)
Values for calling QEMM v5.11+ QPI function 1C01h:
        AX = 1C01h set V86-mode IRQ0-7 handlers
        ES:DI -> 8 DWORDs containing V86-mode handler addresses
Return: CF clear

(Table 2219)
Values for calling QEMM v5.11+ QPI function 1C02h:
        AX = 1C02h disable IRQ8-15 handlers
Return: CF clear

(Table 2220)
Values for calling QEMM v5.11+ QPI function 1C03h:
        AX = 1C03h set V86-mode IRQ8-15 handlers
        ES:DI -> 8 DWORDs containing V86-mode handler addresses
BUG:    although the jump table only contains four entries, QEMM 6.00 will
          attempt to use it for any value of AL between 00h and 2Ah, thus
          branching unpredictably for AL=04h-2Ah; QEMM v7.01 behaves
          similarly for AL=04h-1Bh
Note:   when enabled, the appropriate IRQs are reflected back to the specified
          handlers in virtual-86 mode after the CPU automatically invokes the
          protected-mode handler inside QEMM

(Table 2221)
Values for calling QEMM v7.03+ "QPI_SimulateHWInt" function:
        AX = 1C04h
        BX = number of interrupt to simulate
Return: ???
Notes:  this function will allow proper simulation of a hardware interrupt
          under DESQview and DESQview/X, where the correct interrupt handler
          may be in a different process with a completely different address
          space
        this function was officially documented with the release of QEMM v7.50

(Table 2222)
Values for calling QEMM v6.0x only QPI function 1D00h:
        AX = 1D00h switch to pre-Stealth interrupt vector table
Return: CF clear if supported (QEMM v6.x)
        CF set if not supported (QEMM v7+)
Notes:  also switches VGA Save table pointer (0040h:00A8h) and overwrites the
          vectors currently assigned for use by the two interrupt controllers
          (see INT 67/AX=DE0Ah) with the vectors for INT 08-0F and 70-77 (to
          avoid crashing the system).
        functions 1Dxxh are not supported by QEMM v7.01, and always return CF
          set

(Table 2223)
Values for calling QEMM v6.0x only QPI function 1D01h:
        AX = 1D01h restore user interrupt vector table
Return: CF clear if supported (QEMM v6.x)
        CF set if not supported (QEMM v7+)
Notes:  interrupts should be disabled around the AX=1D00h and AX=1D01h calls
          because QEMM does not modify the memory maps to map in ROM, so
          an interrupt could be disastrous
        clears any pending IRQ7 at end of function
        functions 1Dxxh are not supported by QEMM v7.01, and always return CF
          set

(Table 2224)
Values for calling QEMM v6.00+ QPI function 1Dxxh:
        AX = 1D02h to 1DFFh
Return: CF set

(Table 2225)
Values for calling QEMM v6.00+ "QEMM_GET_INFO"/"QPI_GetInfo" function:
        AX = 1E00h get Stealth configuration
Return: CF clear
        BL = memory configuration flags (documented as "reserved") (see #2249)
        BH = (v7.00+) disk buffer flags
            bit 0: DISKBUFFRAME buffer instead of DISKBUF buffer
            bit 1: buffer has already been used
        CL = stealth type (00h none, 46h Frame, 4Dh Map, 50h Protect)
        CH = suspend/resume interrupt (00h none)
        DL = (v7.00+) size of QEMM disk buffer in KB (00h none)
        DH = reserved (always 00h for v6.00)
        SI = reserved (always 0000h for v6.00)
        DI = reserved (always 0000h for v6.00)
Note:   this function is officially documented

(Table 2226)
Values for calling QEMM v6.00+ "QPI_GetStealthCount" function:
        AX = 1E01h get number of Stealth'ed ROMs
Return: CF clear
        BX = number of Stealth'ed ROMs
Note:   this function is officially documented

(Table 2227)
Values for calling QEMM v6.00+ "QPI_GetStealthList" function:
        AX = 1E02h
        ES:DI -> buffer for Stealth ROM info (see #2251)
Return: CF clear
        BX = number of Stealth'ed ROMs
        ES:DI buffer filled
Note:   this function is officially documented

(Table 2228)
Values for unimplemented Stealth information functions:
        AX = 1E03h to 1EFFh
Return: CF set


(Table 2229)
Values for calling QEMM v6.00+ "QEMM_GET_PTE"/"QPI_GetPTE" function:
        AX = 1F00h get page table entry
        CX = page number (0000h-010Fh)
Return: CF clear
        EDX = page table entry
Note:   this function is officially documented

(Table 2230)
Values for calling QEMM v6.00+ "QEMM_SET_PTE"/"QPI_SetPTE" function:
        AX = 1F01h set page table entry
        CX = page number (0000h-010Fh)
        EDX = new page table entry
Return: CF clear
Note:   this function is officially documented
SeeAlso: function 1008h

(Table 2231)
Values for calling QEMM v6.00+ QPI function 1Fxxh:
        AX = 1F02h to 1FFFh
Return: CF set

(Table 2232)
Values for calling QEMM v6.00+ "QEMM_GET_VHI_INFO"/"QPI_GetVHIInfo" function:
        AX = 2000h "QEMM_GET_VHI_INFO" get VirtualHDIRQ information
Return: CF clear
        BL = flags
            bit 7: VirtualHDIRQ setting respected
                  (set if Stealth active)
            bits 6-1 reserved
            bit 0: VirtualHDIRQ currently enabled
                (INT 15/AH=90h suppressed when enabled)
Note:   this function is officially documented
SeeAlso: #2233

(Table 2233)
Values for calling QEMM v6.00+ "QEMM_SET_VHI_INFO"/"QPI_SetVHIInfo" function:
        AX = 2001h set VirtualHDIRQ state
        BL bit 0 = new VirtualHDIRQ state
Return: CF clear
        BL = old VHI setting (bits 0 and 7, see #2232)
Note:   this function is officially documented
SeeAlso: #2232

(Table 2234)
Values for calling QEMM v6.00+ QPI function 20xxh:
        AX = 2002h to 20FFh
Return: CF set

(Table 2235)
Values for calling QEMM v6.00+ "QEMM_COPY_STEALTH_ROMS"/"QPI_CopyStealthRoms":
        AX = 2100h copy data from Stealthed address space
        DS:SI -> start address of hidden memory to copy
        ES:DI -> buffer for copied data
        ECX = number of bytes to copy
Return: CF clear if successful
        CF set on error (no Stealth or DS:SI < C000h:0000h or DS:SI + ECX > 1M)
Note:   this function was officially documented with the release of QEMM 7.50

(Table 2236)
Values for calling QEMM v6.00+ QPI function 21xxh:
        AX = 2101h to 21FFh
Return: CF set

(Table 2237)
Values for calling QEMM v6.03+ QPI function 2200h:
        AX = 2200h DESQview/X support -- get ???
Return: CF clear
        ES:DI -> ???

(Table 2238)
Values for calling QEMM v6.03+ QPI function 2201h:
        AX = 2201h DESQview/X support -- set ???
        ES:DI -> ??? or 0000h:0000h
Return: CF clear if successful
        CF set on error

(Table 2239)
Values for calling QEMM v6.04+ QPI function 2300h:
        AX = 2300h get ???
        BX = which ??? to get (must be 0000h for v6.04)
Return: CF clear if successful
            ES:DI -> ???
        CF set on error

(Table 2240)
Values for calling QEMM v6.04+ QPI function 2301h:
        AX = 2301h set ???
        BX = which ??? to set (must be 0000h for v6.04)
        ES:DI -> ???
Return: CF clear if successful
        CF set on error

(Table 2241)
Values for calling QEMM v6.04+ QPI function 2302h:
        AX = 2302h clear specified ???
        BX = which ??? to clear (must be 0000h for v6.04)
Return: CF clear if successful
        CF set on error

(Table 2242)
Values for calling QEMM v6.04+ QPI function 23FFh:
        AX = 23FFh clear all ???
Return: CF clear if successful
        CF set on error

(Table 2243)
Values for calling QEMM v6.04+ QPI function 23xxh:
        AX = 2303h to 23FEh
Return: CF set

(Table 2244)
Values for calling QEMM v7.01+ QPI function 24h:
        AH = 24h ST-DBL support
        AL = subfunction
            00h set ???
                EDX -> information table (EDX = segment SHL 16 + offset)
            01h ???
Return: CF clear if successful
        CF set on error

(Table 2245)
Values for calling QEMM unimplemented QPI functions:
        AH = 25h to FFh
Return: CF set

Format of QEMM protection level configuration:
Offset  Size    Description     (Table 2246)
 00h    WORD    segment of 128 breakpoint (INT 3) instructions for use in
                  DESQview protection level 3 interrupt vector checking, or
                  0000h to disable; in pl3, INTs 00-7F are pointed at these
                  breakpoints
 02h    DWORD   -> array of actual interrupt handler addresses for INT 00-7F
                  when interrupt vectors are pointed at protection level 3
                  breakpoints
 06h    DWORD   far pointer to ??? region list (see #2247)
 0Ah    DWORD   far pointer to buffer for returned ???
 0Eh    DWORD   seg:ofs of function to call on protection violation???
 12h    WORD    segment of ???
 14h    DWORD   far pointer to DWORD containing number of paragraphs of
                  ??? for segment at offset 12h
        ???

Format of protection level Region List:
Offset  Size    Description     (Table 2247)
 00h    WORD    number of PAIRS of pointers to follow
 02h 2N DWORDs  start/end seg:ofs addresses of ??? regions
Note:   QEMM converts the segmented addresses into linear addresses in place

Format of EMM Import structure:
Offset  Size    Description     (Table 2248)
 00h    DWORD   physical address of EMM import struct
 04h    BYTE    major version (v6.00 sets to 01h)
 05h    BYTE    minor version (v6.00 sets to 00h/0Bh)
SeeAlso: INT 21/AX=4402h/SF=01h

Bitfields for memory configuration flags:
Bit(s)  Description     (Table 2249)
 0      conventional memory sorted
 1      conventional memory filled
 2      ???
 3      ???
 4      expanded memory is in use
 5      ???

Format of QEMM 6.0 memory statistics:
Offset  Size    Description     (Table 2250)
 00h    BYTE    01h if Shadow RAM found, 00h otherwise
 01h    DWORD   initial conventional memory in bytes
 05h    DWORD   initial extended memory in bytes
 09h    DWORD   initial expanded memory in bytes
 0Dh    DWORD   initial "top" or "shadow" memory in bytes
 11h    DWORD   Unavailable conventional memory in bytes
 15h    DWORD   Unavailable extended memory in bytes
 19h    DWORD   Unavailable expanded memory in bytes
 1Dh    DWORD   Unavailable "top" or "shadow" memory in bytes
                Add to offset 49h for Total unavailable top/shadow.
 21h    DWORD   QEMM code size in bytes
 25h    DWORD   QEMM data size in bytes
 29h    DWORD   bytes used for TASKS=
 2Dh    DWORD   DMA buffer size
 31h    DWORD   bytes used for MAPS=
 35h    DWORD   bytes of high RAM
 39h    DWORD   bytes used by mapped ROMs
 3Dh    DWORD   bytes of conventional memory provided by QEMM
 41h    DWORD   bytes of extended memory NOT converted by QEMM (EXT=xxx)
 45h    DWORD   bytes of EMS/XMS pool memory provided by QEMM
 49h    DWORD   Unavailable "top" or "shadow" memory in bytes
                Add to offset 1Dh for Total unavailable top/shadow.
 4Dh    DWORD   conventional memory overhead in bytes
                (set to 0 by QEMM.COM prior to call)

Format of Stealth ROM info [array]:
Offset  Size    Description     (Table 2251)
 00h    WORD    starting segment of ROM
 02h    WORD    length of ROM in paragraphs

Format of QEMM EGA/VGA DAC register virtualization buffer:
Offset  Size    Description     (Table 2252)
 00h    BYTE    (temp) current color register number
 01h    BYTE    (temp) number of bytes written so far for current color reg
 02h 768 BYTEs  three bytes per color register
--------m-6740-------------------------------
