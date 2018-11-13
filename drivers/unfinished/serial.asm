;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

format PE DLL native 0.05
entry START

L_ERR = 1
L_DBG = 2

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

SERIAL_RING_BUF_SIZE = 4096

section '.flat' readable writable executable

include '../struct.inc'
include '../proc32.inc'
include '../fdo.inc'
include '../macros.inc'
include '../peimport.inc'
include '../ring_buf.inc'

include '../../kernel/trunk/serial-common.inc'

struct drv_data
        io_addr         dd ? ; base address of io port
        handle          dd ? ; serial port handle
        rx_buf          RING_BUF
        tx_buf          RING_BUF
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
        mov     edx, [ioctl]
        mov     eax, [edx + IOCTL.io_code]
        test    eax, eax
        jz      .getversion
        jmp     .err

  .getversion:
        cmp     [edx + IOCTL.out_size], 4
        jb      .err
        mov     edx, [edx + IOCTL.output]
        mov     dword [edx], API_VERSION

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
        jnz     .err

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
        mov     eax, sizeof.drv_data
        invoke  Kmalloc
        test    eax, eax
        jz      .free_port
        mov     edi, eax
        ; create rx and tx ring buffers
        lea     ecx, [edi + drv_data.rx_buf]
        mov     edx, SERIAL_RING_BUF_SIZE shr 12
        call    ring_buf_create
        test    eax, eax
        jz      .free_desc
        lea     ecx, [edi + drv_data.tx_buf]
        mov     edx, SERIAL_RING_BUF_SIZE shr 12
        call    ring_buf_create
        test    eax, eax
        jz      .free_rx_buf

        mov     eax, [io_addr]
        mov     [edi + drv_data.io_addr], eax

        invoke  AttachIntHandler, [irqn], int_handler, edi
        test    eax, eax
        jz      .free_tx_buf

        ; add device
        invoke  SerialAddPort, edi, drv_funcs
        test    eax, eax
        jz      .free_tx_buf

        ; save port handle
        mov     [edi + drv_data.handle], eax
        ret

  .free_tx_buf:
        lea     ecx, [edi + drv_data.tx_buf]
        call    ring_buf_destroy

  .free_rx_buf:
        lea     ecx, [edi + drv_data.rx_buf]
        call    ring_buf_destroy

  .free_desc:
        mov     eax, edi
        invoke  Kfree

  .free_port:
        xor     ebx, ebx
        inc     ebx ; 1 = release
        mov     ecx, [io_addr]
        lea     edx, [ecx + 7]
        push    ebp
        invoke  ReservePortArea
        pop     ebp

  .err:
        DEBUGF  L_DBG, "serial.sys: add port 0x%x failed\n", [io_addr]
        ret
endp

proc int_handler c uses ebx esi edi, data:dword
        mov     esi, [data]
        mov     edx, [esi + drv_data.io_addr]
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
        mov     edi, [esi + drv_data.tx_buf + RING_BUF.read_ptr]
        cmp     edi, [esi + drv_data.tx_buf + RING_BUF.write_ptr]
        jne     .tx_byte

        ; disable THR empty interrupt
        rd_reg  IER_REG
        and     ax, not IER_THRI
        wr_reg  IER_REG
        jmp     .read_iir

  .tx_byte:
        mov     al, byte [edi]
        inc     edi
        cmp     edi, [esi + drv_data.tx_buf + RING_BUF.end_ptr]
        jnz     @f
        mov     edi, [esi + drv_data.tx_buf + RING_BUF.start_ptr]
  @@:
        mov     [esi + drv_data.tx_buf + RING_BUF.read_ptr], edi
        wr_reg  THR_REG
        jmp     .read_iir

  .recv:
        ; read byte
        rd_reg  THR_REG

        mov     edi, [esi + drv_data.rx_buf + RING_BUF.write_ptr]
        inc     edi
        cmp     edi, [esi + drv_data.rx_buf + RING_BUF.end_ptr]
        jnz     @f
        mov     edi, [esi + drv_data.rx_buf + RING_BUF.start_ptr]
  @@:
        cmp     edi, [esi + drv_data.rx_buf + RING_BUF.read_ptr]
        jnz     .put_byte

        ; TODO: Overflow. Read all bytes from uart and exit
        DEBUGF  L_DBG, "OVF\n"
        jmp     .skip

  .put_byte:
        push    edi
        mov     edi, [esi + drv_data.rx_buf + RING_BUF.write_ptr]
        mov     byte [edi], al
        pop     edi
        mov     [esi + drv_data.rx_buf + RING_BUF.write_ptr], edi

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

proc drv_startup stdcall, data:dword
        DEBUGF  L_DBG, "serial.sys: open 0x%x\n", [data]
        mov     ecx, [data]
        mov     edx, [ecx + drv_data.io_addr]

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

proc drv_shutdown stdcall, data:dword
        DEBUGF  L_DBG, "serial.sys: close 0x%x\n", [data]
        ; disable interrupts
        mov     ecx, [data]
        mov     edx, [ecx + drv_data.io_addr]
        xor     ax, ax
        wr_reg  IER_REG
        ret
endp

proc drv_read stdcall, data, dst, size
        DEBUGF  L_DBG, "serial.sys: read %d bytes from port 0x%x\n", [size], [data]
        ret
endp

proc drv_write stdcall, data, src, size
        DEBUGF  L_DBG, "serial.sys: write %d bytes to port 0x%x\n", [size], [data]
        ret
endp

proc drv_start_tx stdcall, data:dword
        DEBUGF  L_DBG, "serial.sys: start_tx 0x%x\n", [data]
        mov     ecx, [data]
        mov     edx, [ecx + drv_data.io_addr]
        spin_lock_irqsave
        rd_reg  IER_REG
        or      ax, IER_THRI
        wr_reg  IER_REG
        spin_unlock_irqrestore
        ret
endp

version     dd  API_VERSION
drv_name    db 'SERIAL', 0

align 4
drv_funcs:
        dd drv_funcs_end - drv_funcs
        dd drv_startup
        dd drv_shutdown
        dd drv_read
        dd drv_write
drv_funcs_end:

include_debug_strings

align 4
data fixups
end data
