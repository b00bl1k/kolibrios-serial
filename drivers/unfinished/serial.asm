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

; Registers offset
UART_REG_RBR_RO = 0x00 ; Receive Buffer Register
UART_REG_THR_WO = 0x00 ; Transmitter Holding Register
UART_REG_DL_LSB = 0x00 ; Divisor Latch (LSB)
UART_REG_IER = 0x01 ; Interrupt Enable Register
UART_REG_DL_MSB = 0x01 ; Divisor Latch (MSB)
UART_REG_IIR_RO = 0x02 ; Interrupt Indentification Register
UART_REG_FCR_WO = 0x02 ; FIFO Control Register
UART_REG_LCR = 0x03 ; Line Control Register
UART_REG_MCR = 0x04 ; Modem Control Register
UART_REG_LSR = 0x05 ; Line Status Register
UART_REG_MSR = 0x06 ; Modem Status Register
UART_REG_SCR = 0x07 ; Scratch Register

UART_FLAG_IER_DR = 0x00 ; Data Ready Interrupt
UART_FLAG_IER_THRE = 0x01 ; THR Empty Interrupt
UART_FLAG_IER_LS = 0x02 ; Line Status Interrupt
UART_FLAG_IER_DSS = 0x03 ; Delta Status Signals Interrupt

UART_FLAG_IIR_NO_INT = 0x00
UART_FLAG_IIR_IID0 = 0x01
UART_FLAG_IIR_IID1 = 0x02
UART_FLAG_IIR_IID2 = 0x03
UART_FLAG_IIR_IID_MASK = 0x0E

UART_FLAG_FCR_EN = 0x00 ; FIFO enable
UART_FLAG_FCR_CLR_RX = 0x01 ; Clear recevier FIFO
UART_FLAG_FCR_CLR_TX = 0x02 ; Clear transmitter FIFO
UART_FLAG_FCR_DMA = 0x03 ; DMA mode
UART_FLAG_FCR_TRIG_LVL0 = 0x04 ; Trigger level of the DR-interrupt
UART_FLAG_FCR_TRIG_LVL1 = 0x05

UART_FLAG_LCR_WL0 = 0x00 ; Word length
UART_FLAG_LCR_WL1 = 0x01
UART_FLAG_LCR_SB = 0x02 ; Stop bits
UART_FLAG_LCR_PE = 0x03 ; Parity enable
UART_FLAG_LCR_ES = 0x04 ; Even Parity select
UART_FLAG_LCR_SP = 0x05 ; Stick Parity select
UART_FLAG_LCR_SBR = 0x06
UART_FLAG_LCR_DLAB = 0x07

UART_FLAG_MCR_DTR = 0x00
UART_FLAG_MCR_RTS = 0x01
UART_FLAG_MCR_OUT1 = 0x02
UART_FLAG_MCR_OUT2 = 0x03
UART_FLAG_MCR_LOOP = 0x04

UART_FLAG_LSR_RBF = 0x00 ; Receiver Buffer Full
UART_FLAG_LSR_OE = 0x01 ; Overrun Error
UART_FLAG_LSR_PE = 0x02 ; Parity error
UART_FLAG_LSR_FE = 0x03 ; Framing Error
UART_FLAG_LSR_BREAK = 0x04 ; Broken line detected
UART_FLAG_LSR_THRE = 0x05 ; Transmitter Holding Register Empty
UART_FLAG_LSR_TEMT = 0x06 ; Transmitter Empty
UART_FLAG_LSR_FIFO_ERR = 0x07 ; At least one error is pending in the RX FIFO chain

UART_FLAG_MSR_DCTS = 0x00
UART_FLAG_MSR_DDSR = 0x01
UART_FLAG_MSR_TERI = 0x02
UART_FLAG_MSR_DDCD = 0x03
UART_FLAG_MSR_CTS = 0x04
UART_FLAG_MSR_DSR = 0x05
UART_FLAG_MSR_RI = 0x06
UART_FLAG_MSR_DCD = 0x07

UART_TEST_SIGNALS = (1 shl UART_FLAG_MCR_DTR) + \
                    (1 shl UART_FLAG_MCR_RTS) + \
                    (1 shl UART_FLAG_MCR_OUT1) + \
                    (1 shl UART_FLAG_MCR_OUT2) + \
                    (1 shl UART_FLAG_MCR_LOOP)

UART_CHECK_MASK = (1 shl UART_FLAG_MSR_CTS) + \
                  (1 shl UART_FLAG_MSR_DSR) + \
                  (1 shl UART_FLAG_MSR_RI) + \
                  (1 shl UART_FLAG_MSR_DCD)

section '.flat' readable writable executable

include '../struct.inc'
include '../proc32.inc'
include '../fdo.inc'
include '../struct.inc'
include '../macros.inc'
include '../peimport.inc'
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

proc add_port stdcall uses ebx edi, io_addr:dword, irqn:dword
        xor     ebx, ebx ; 0 = reserve
        mov     ecx, [io_addr]
        lea     edx, [ecx + 7]
        push    ebp
        invoke  ReservePortArea
        pop     ebp
        test    eax, eax
        jz      @f
        DEBUGF  L_ERR, "Serial: failed to reserve ports\n"
        jmp     .err
@@:
        mov     edx, [io_addr]

        ; enable loopback
        mov     al, (1 shl UART_FLAG_MCR_LOOP)
        wr_reg  UART_REG_MCR

        ; read status
        rd_reg  UART_REG_MSR
        and     al, UART_CHECK_MASK
        test    al, al
        jnz     .free_port

        ; set test signals
        mov     al, UART_TEST_SIGNALS
        wr_reg  UART_REG_MCR

        ; check signals
        rd_reg  UART_REG_MSR
        and     al, UART_CHECK_MASK
        cmp     al, UART_CHECK_MASK
        jnz     .free_port

        DEBUGF  L_DBG, "Serial: found serial port 0x%x\n", [io_addr]

        ; initialize port
        xor     eax, eax
        wr_reg  UART_REG_MCR
        wr_reg  UART_REG_IER
        wr_reg  UART_REG_LCR
        wr_reg  UART_REG_FCR_WO

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

        invoke  AttachIntHandler, [irqn], irq_handler, edi
        test    eax, eax
        jz      .free_mem

        ; add device
        invoke  SerialAddPort, edi
        test    eax, eax
        jnz     .free_mem
        mov     eax, edi
        ret

.free_mem:
        DEBUGF  L_DBG, "Serial: add port 0x%x failed\n", [io_addr]
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

proc irq_handler c uses ebx edi, desc:dword
locals
        res     dd ? ; return 0 if no uart int pending
endl
        and     [res], 0
        mov     ecx, [desc]
        mov     edx, [ecx + port.io_addr]
.read_iir:
        rd_reg  UART_REG_IIR_RO
        DEBUGF  L_DBG, "SER INT 0x%x\n", al
        test    al, (1 shl UART_FLAG_IIR_NO_INT)
        jnz     .exit
        inc     [res]
        and     ax, UART_FLAG_IIR_IID_MASK
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
        jmp     .read_iir

.modem:
        ; read MSR for clear interrupt
        rd_reg  UART_REG_MSR
        jmp     .read_iir

.xmit:
        ; write byte or disable THRE int
        jmp     .read_iir

.recv:
        ; read byte
        rd_reg  UART_REG_RBR_RO
        mov     bl, [ecx + serial_port.rx_widx]
        inc     bl
        ; check free space
        cmp     bl, [ecx + serial_port.rx_ridx]
        je      .rx_overflow
        ; put byte into rx buffer
        dec     bl
        lea     edi, [ecx + serial_port.rx_buf]
        and     ebx, 0xff
        add     edi, ebx
        mov     [edi], al
        inc     bl
        mov     [ecx + serial_port.rx_widx], bl
        rd_reg  UART_REG_LSR
        test    al, 1 shl UART_FLAG_LSR_RBF
        jnz     .recv

.rx_overflow:
        jmp     .read_iir

.status:
        rd_reg  UART_REG_LSR
        DEBUGF  L_DBG, "LSR 0x%x\n", al
        jmp     .read_iir

.fifo:
        jmp     .read_iir

.exit:
        mov     eax, [res]
        ret
endp

proc drv_startup stdcall, desc:DWORD
        DEBUGF  L_DBG, "Serial: open 0x%x\n", [desc]
        mov     ecx, [desc]
        mov     edx, [ecx + port.io_addr]
        ; 115200
        mov     al, 1 shl UART_FLAG_LCR_DLAB
        wr_reg  UART_REG_LCR
        mov     al, 1
        wr_reg  UART_REG_DL_LSB
        mov     al, 0
        wr_reg  UART_REG_DL_MSB
        ; 8n1
        mov     al, (1 shl UART_FLAG_LCR_WL0) or \
                    (1 shl UART_FLAG_LCR_WL1)
        wr_reg  UART_REG_LCR
        ; dtr, out1, out2
        mov     al, (1 shl UART_FLAG_MCR_DTR) or \
                    (1 shl UART_FLAG_MCR_OUT1) or \
                    (1 shl UART_FLAG_MCR_OUT2)
        wr_reg  UART_REG_MCR
        ; enable rx interrupt
        mov     al, (1 shl UART_FLAG_IER_DR) or (1 shl UART_FLAG_IER_LS)
        wr_reg  UART_REG_IER
        ret
endp

proc drv_shutdown stdcall, desc:DWORD
        DEBUGF  L_DBG, "Serial: close 0x%x\n", [desc]
        ; disable interrupts
        mov     ecx, [desc]
        mov     edx, [ecx + port.io_addr]
        xor     ax, ax
        wr_reg  UART_REG_IER
        wr_reg  UART_REG_MCR
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
