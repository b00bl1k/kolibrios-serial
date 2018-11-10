;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

format PE DLL native 0.05
entry START

L_DBG = 1
L_ERR = 2

__DEBUG__ = 1
__DEBUG_LEVEL__ = L_DBG
API_VERSION = 1

THR_REG = 0 ; transtitter/reciever 3f8
IER_REG = 1 ; interrupt enable 3f9
IIR_REG = 2 ; interrupt info 3fa
FCR_REG = 2 ; FIFO control 3fb
LCR_REG = 3 ; line control 3fc
MCR_REG = 4 ; modem control 3fd
LSR_REG = 5 ; line status 3fe
MSR_REG = 6 ; modem status 3ff
SCR_REG = 7 ; scratch

DLL_REG = THR_REG ; divisor latch (LSB)
DLM_REG = IER_REG ; divisor latch (MSB)

LCR_5BIT   = 0x00
LCR_6BIT   = 0x01
LCR_7BIT   = 0x02
LCR_8BIT   = 0x03
LCR_STOP_1 = 0x00
LCR_STOP_2 = 0x04
LCR_PARITY = 0x08
LCR_EVEN   = 0x10
LCR_STICK  = 0x20
LCR_BREAK  = 0x40
LCR_DLAB   = 0x80

LSR_DR   = 0x01 ; data ready
LSR_OE   = 0x02 ; overrun error
LSR_PE   = 0x04 ; parity error
LSR_FE   = 0x08 ; framing error
LSR_BI   = 0x10 ; break interrupt
LSR_THRE = 0x20 ; transmitter holding empty
LSR_TEMT = 0x40 ; transmitter empty
LSR_FER  = 0x80 ; FIFO error

FCR_EFIFO   = 0x01 ; enable FIFO
FCR_CRB     = 0x02 ; clear reciever FIFO
FCR_CXMIT   = 0x04 ; clear transmitter FIFO
FCR_RDY     = 0x08 ; set RXRDY and TXRDY pins
FCR_FIFO_1  = 0x00 ; 1  byte trigger
FCR_FIFO_4  = 0x40 ; 4  bytes trigger
FCR_FIFO_8  = 0x80 ; 8  bytes trigger
FCR_FIFO_14 = 0xC0 ; 14 bytes trigger

IIR_INTR  = 0x01 ; 1= no interrupts
IIR_IID   = 0x0E ; interrupt source mask

IER_RDAI  = 0x01 ; reciever data interrupt
IER_THRI  = 0x02 ; transmitter empty interrupt
IER_LSI   = 0x04 ; line status interrupt
IER_MSI   = 0x08 ; modem status interrupt

MCR_DTR   = 0x01 ; 0-> DTR=1, 1-> DTR=0
MCR_RTS   = 0x02 ; 0-> RTS=1, 1-> RTS=0
MCR_OUT1  = 0x04 ; 0-> OUT1=1, 1-> OUT1=0
MCR_OUT2  = 0x08 ; 0-> OUT2=1, 1-> OUT2=0;  enable intr
MCR_LOOP  = 0x10 ; lopback mode

MSR_DCTS  = 0x01 ; delta clear to send
MSR_DDSR  = 0x02 ; delta data set redy
MSR_TERI  = 0x04 ; trailinh edge of ring
MSR_DDCD  = 0x08 ; delta carrier detect
MSR_CTS   = 0x10
MSR_DSR   = 0x20
MSR_RI    = 0x40
MSR_DCD   = 0x80

MCR_TEST_MASK = MCR_DTR or MCR_RTS or MCR_OUT1 or MCR_OUT2 or MCR_LOOP
MSR_CHECK_MASK = MSR_CTS or MSR_DSR or MSR_RI or MSR_DCD

section '.flat' readable writable executable

include '../struct.inc'
include '../proc32.inc'
include '../fdo.inc'
include '../macros.inc'
include '../peimport.inc'

struct  APPOBJ                  ; common object header
        magic           dd ?    ;
        destroy         dd ?    ; internal destructor
        fd              dd ?    ; next object in list
        bk              dd ?    ; prev object in list
        pid             dd ?    ; owner id
ends

struct  RING_BUF
        start_ptr       dd ?   ; Pointer to start of buffer
        end_ptr         dd ?   ; Pointer to end of buffer
        read_ptr        dd ?   ; Read pointer
        write_ptr       dd ?   ; Write pointer
        size            dd ?   ; Size of buffer
ends

include '../../kernel/trunk/serial-common.inc'

struct port serial_port
        io_addr         dd ? ; base address of io port
ends

; dx = base io
; al = result
macro rd_reg reg
{
        push    edx
        add     dx, reg
        in      al, dx
        pop     edx
}

; dx = base io
; al = new value
macro wr_reg reg
{
        push    edx
        add     dx, reg
        out     dx, al
        pop     edx
}

; dx = port
; ax = divisor value
proc uart_set_baud
        push    eax
        rd_reg  LCR_REG
        or      al, LCR_DLAB
        wr_reg  LCR_REG
        pop     eax
        wr_reg  DLL_REG
        shr     ax, 8
        wr_reg  DLM_REG
        rd_reg  LCR_REG
        and     al, 0x7f
        wr_reg  LCR_REG
        ret
endp

proc START c, state:dword, cmdline:dword
        cmp     [state], 1
        je      @f
        xor     eax, eax
        ret

  @@:
        stdcall add_port, 0x3f8, 4
        stdcall add_port, 0x2f8, 3
        stdcall add_port, 0x3e8, 4
        stdcall add_port, 0x2e8, 3
        invoke  RegService, drv_name, service_proc
        ret
endp

proc service_proc stdcall, ioctl:dword
        mov     edi, [ioctl]
        mov     eax, [edi + IOCTL.io_code]
        test    eax, eax
        jz      .getversion
        jmp     .err

  .getversion:
        cmp     [edi + IOCTL.out_size], 4
        jb      .err
        mov     edi, [edi + IOCTL.output]
        mov     dword [edi], API_VERSION

  .ok:
        xor     eax, eax
        ret

  .err:
        or      eax, -1
        ret
endp

proc add_port stdcall uses ebx esi edi, io_addr:dword, irqn:dword
        xor     ebx, ebx ; 0 = reserve
        mov     ecx, [io_addr]
        lea     edx, [ecx + 7]
        push    ebp
        invoke  ReservePortArea
        pop     ebp
        test    eax, eax
        jz      @f

        DEBUGF  L_ERR, "serial.sys: failed to reserve ports\n"
        jmp     .err

  @@:
        mov     edx, [io_addr]

        ; enable loopback
        mov     al, MCR_LOOP
        wr_reg  MCR_REG

        ; read status
        rd_reg  MSR_REG
        and     al, MSR_CHECK_MASK
        test    al, al
        jnz     .free_port

        ; set test signals
        mov     al, MCR_TEST_MASK
        wr_reg  MCR_REG

        ; check signals
        rd_reg  MSR_REG
        and     al, MSR_CHECK_MASK
        cmp     al, MSR_CHECK_MASK
        jnz     .free_port

        DEBUGF  L_DBG, "serial.sys: found serial port 0x%x\n", [io_addr]

        ; initialize port
        xor     ax, ax
        wr_reg  MCR_REG
        wr_reg  IER_REG
        wr_reg  LCR_REG
        wr_reg  FCR_REG

        ; create descriptor
        invoke  KernelAlloc, sizeof.port
        test    eax, eax
        jz      .free_port

        mov     edi, eax
        push    edi

        ; clear allocated memory
        xor     eax, eax
        mov     ecx, sizeof.port
        cld
        rep stosb
        pop     edi

        ; fill
        mov     eax, drv_funcs
        mov     [edi + port.funcs], eax
        mov     eax, [io_addr]
        mov     [edi + port.io_addr], eax

        invoke  AttachIntHandler, [irqn], int_handler, edi
        test    eax, eax
        jz      .free_mem

        ; add device
        invoke  SerialAddPort, edi
        test    eax, eax
        jnz     .free_mem

        mov     eax, edi
        ret

  .free_mem:
        DEBUGF  L_DBG, "serial.sys: add port 0x%x failed\n", [io_addr]
        invoke  KernelFree, edi

  .free_port:
        xor     ebx, ebx
        inc     ebx ; 1 = release
        mov     ecx, [io_addr]
        lea     edx, [ecx + 7]
        push    ebp
        invoke  ReservePortArea
        pop     ebp

  .err:
        xor     eax, eax
        ret
endp

proc int_handler c uses ebx esi edi, desc:dword
        mov     esi, [desc]
        mov     edx, [esi + port.io_addr]
        xor     ebx, ebx
        ; invoke  SerialWakeUp, [desc]

  .read_iir:
        rd_reg  IIR_REG
        DEBUGF  L_DBG, "SER INT 0x%x\n", al
        test    al, IIR_INTR
        jnz     .exit

        inc     ebx
        and     ax, IIR_IID
        shr     ax, 1

        ; check source
        test    ax, ax
        jz      .modem
        cmp     ax, 1
        jz      .xmit
        cmp     ax, 2
        jz      .recv
        cmp     ax, 3
        jz      .status
        jmp     .exit

  .modem:
        ; read MSR for clear interrupt
        rd_reg  MSR_REG
        jmp     .read_iir

  .xmit:
        ; write byte or disable THRE int
        jmp     .read_iir

  .recv:
        ; read byte
        rd_reg  THR_REG

        mov     edi, [esi + port.rx_buf + RING_BUF.write_ptr]
        inc     edi
        cmp     edi, [esi + port.rx_buf + RING_BUF.end_ptr]
        jnz     @f
        mov     edi, [esi + port.rx_buf + RING_BUF.start_ptr]
  @@:
        cmp     edi, [esi + port.rx_buf + RING_BUF.read_ptr]
        jnz     .put_byte

        ; TODO: Overflow. Read all bytes from uart and exit
        DEBUGF  L_DBG, "OVF\n"
        jmp     .skip

  .put_byte:
        push    edi
        mov     edi, [esi + port.rx_buf + RING_BUF.write_ptr]
        mov     byte [edi], al
        pop     edi
        mov     [esi + port.rx_buf + RING_BUF.write_ptr], edi

  .skip:
        ; check for more recevied bytes
        rd_reg  LSR_REG
        test    al, LSR_DR
        jnz     .recv
        jmp     .read_iir

  .status:
        rd_reg  LSR_REG
        jmp     .read_iir

  .fifo:
        jmp     .read_iir

  .exit:
        xchg    eax, ebx
        ret
endp

proc drv_startup stdcall, desc:dword
        DEBUGF  L_DBG, "serial.sys: open 0x%x\n", [desc]
        mov     ecx, [desc]
        mov     edx, [ecx + port.io_addr]

        mov     ax, 12 ; 9600
        call    uart_set_baud

        mov     al, LCR_8BIT
        wr_reg  LCR_REG

        mov     al, MCR_DTR or MCR_OUT1 or MCR_OUT2
        wr_reg  MCR_REG

        ; enable rx interrupt
        mov     al, IER_RDAI or IER_LSI
        wr_reg  IER_REG

        ret
endp

proc drv_shutdown stdcall, desc:dword
        DEBUGF  L_DBG, "serial.sys: close 0x%x\n", [desc]
        ; disable interrupts
        mov     ecx, [desc]
        mov     edx, [ecx + port.io_addr]
        xor     ax, ax
        wr_reg  IER_REG
        ret
endp

proc drv_read_sr stdcall, desc:dword
        mov     ecx, [desc]
        mov     edx, [ecx + port.io_addr]
        rd_reg  LSR_REG
        shl     ax, 8
        rd_reg  MSR_REG
        mov     dx, ax
        xor     eax, eax
        test    dh, LSR_DR shl 8
        jz      @f
        or      eax, SERIAL_SR_RXNE
  @@:
        test    dh, LSR_THRE
        jz      @f
        or      eax, SERIAL_SR_TXE
  @@:
        ret
endp

proc drv_read_dr stdcall, desc:dword
        mov     ecx, [desc]
        mov     edx, [ecx + port.io_addr]
        xor     eax, eax
        rd_reg  THR_REG
        ret
endp

version     dd  0x0000001
drv_name    db 'SERIAL', 0

align 4
drv_funcs:
        dd drv_funcs_end - drv_funcs
        dd drv_startup
        dd drv_shutdown
drv_funcs_end:

include_debug_strings

align 4
data fixups
end data
