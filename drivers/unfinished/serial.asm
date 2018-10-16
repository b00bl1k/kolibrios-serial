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

section '.flat' readable writable executable

include '../struct.inc'
include '../proc32.inc'
include '../fdo.inc'
include '../struct.inc'
include '../macros.inc'
include '../peimport.inc'

struct serial_port
        status          dd ? ; port status bit field
        pid             dd ? ; who currently accesseing to port
ends

struct port serial_port
        io_addr         dd ? ; base address of io port
ends

proc START c, state:dword, cmdline:dword
        cmp     [state], 1
        jne     .exit
        call    detect
        invoke  RegService, drv_name, service_proc
        ret
.exit:
        xor     eax, eax
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

; return not null, if success
proc add_port uses ebx edi, io_addr:dword
        DEBUGF  L_DBG, "Serial: found serial port 0x%x\n", [io_addr]
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
        invoke  KernelAlloc, sizeof.port
        test    eax, eax
        jz      .nomem
        mov     edi, eax
        push    edi
        ; clear allocated memory
        xor     eax, eax
        mov     ecx, sizeof.port
        cld
        rep stosb
        pop     edi
        ; fill
        mov     eax, [io_addr]
        mov     [edi + port.io_addr], eax
        ; add device
        invoke  SerialAddPort, edi
        test    eax, eax
        jnz     .fail
        mov     eax, edi
        ret

.fail:
        DEBUGF  L_ERR, "Serial: add device failed with code=%d\n", eax
        invoke  KernelFree, edi

.nomem:
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

; edx = addr
uart_test:
        ; read MCR and save old value in ah
        add     edx, 4
        in      al, dx
        shl     ax, 8
        ; enable loopback
        mov     al, 0x10
        out     dx, al
        ; read MSR
        add     dx, 2
        in      al, dx
        and     al, 0xf0
        test    al, al
        jnz     .unavailable
        ; set RTS, DTR
        sub     dx, 2
        mov     al, 0x1f
        out     dx, al
        ; check for RTS, DTR
        add     dx, 2
        in      al, dx
        and     al, 0xf0
        cmp     al, 0xf0
        jz      .found

.unavailable:
        xor     eax, eax
        ret
.found:
        ; restore MCR
        shr     ax, 8
        out     dx, al
        xor     eax, eax
        inc     eax
.return:
        ret

detect:
        mov     edx, 0x3F8
        call    uart_test
        test    eax, eax
        jz      @f
        stdcall add_port, 0x3F8
@@:
        mov     edx, 0x2F8
        call    uart_test
        test    eax, eax
        jz      @f
        stdcall add_port, 0x2F8
@@:
        mov     edx, 0x3E8
        call    uart_test
        test    eax, eax
        jz      @f
        stdcall add_port, 0x3E8
@@:
        mov     edx, 0x2E8
        call    uart_test
        test    eax, eax
        jz      @f
        stdcall add_port, 0x2E8
@@:
        DEBUGF  L_DBG, "Serial: ports scan completed\n"
        ret


version     dd  0x0000001
drv_name    db 'SERIAL', 0

include_debug_strings

align 4
data fixups
end data
