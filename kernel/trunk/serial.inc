;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SERIAL_PORTS_MAX = 64

include 'serial-common.inc'

uglobal
align 4
; list of serial ports
serial_ports        rd SERIAL_PORTS_MAX
; lock for serial ports list
serial_ports_mutex  MUTEX
endg

iglobal
align 4
; base filename of driver
serial_drv_name     db 'SERIAL', 0
; table for api
serial_api:
        dd serial_open
        dd serial_close
        dd serial_get_status
        dd serial_set_ev_mask
        dd serial_get_ev_mask
        dd serial_read
serial_api_end:
endg

align 4
serial_init:
        ; initialize lock for serial ports list
        mov     ecx, serial_ports_mutex
        call    mutex_init
        ; try to load std serial port driver
        stdcall get_service, serial_drv_name
        test    eax, eax
        jnz     .fail
        DEBUGF  1, "K : Serial driver is not loaded\n"
.fail:
        ret

; __stdcall u32 SerialAddPort(struct serial_port * port);
; return 0 if ok, otherwise err code
proc serial_add_port stdcall uses edi, port:dword
        ; check descriptor
        mov     edi, [port]
        ; 1. sizeof funcs table
        mov     ecx, [edi + serial_port.funcs]
        mov     eax, [ecx + serial_funcs.size]
        cmp     eax, sizeof.serial_funcs
        jz      @f
        mov     eax, SERIAL_DRV_ERR_PORT_DESC
        ret
@@:
        ; get access to list
        mov     ecx, serial_ports_mutex
        call    mutex_lock
        ; find free slot
        xor     eax, eax
        mov     ecx, SERIAL_PORTS_MAX
        mov     edi, serial_ports
        repne scasd
        jz      .found_slot
        ; save error code
        mov     eax, SERIAL_DRV_ERR_PORT_COUNT
        push    eax
        jmp     .unlock

.found_slot:
        ; store pointer to the port descriptor
        sub     edi, 4
        mov     eax, [port]
        ; initialize fields of descriptor
        lea     ecx, [eax + serial_port.mtx]
        call    mutex_init
        ; write to slot
        mov     [edi], eax
        DEBUGF  1, "K : Added serial port 0x%x\n", [port]
        ; save result 0 - no error
        xor     eax, eax
        push    eax

.unlock:
        mov     ecx, serial_ports_mutex
        call    mutex_unlock
        ; restore error code
        pop     eax
        ret
endp

; __stdcall u32 SerialRemovePort(struct serial_port * port);
proc serial_remove_port stdcall, device:dword
        ret
endp

; Check that the port is open and we own it
; in:
;   eax -> pointer to the port descriptor
; out:
;   cf=1 if no access
proc serial_check_access
        bt      [eax + serial_port.status], SERIAL_STATUS_IS_OPENED
        jnc     @f ; not opened
        push    ebx
        mov     ebx, [TASK_BASE]
        mov     ebx, [ebx + TASKDATA.pid]
        cmp     [eax + serial_port.pid], ebx
        pop     ebx
        stc
        jz      @f ; we owner
        clc
@@:
        cmc
        ret
endp

align 4
syscall_serial:
        ; eax = function
        ; bl = sub function
        ; bh = port number
        ; check if sub function exists
        cmp     bl, (serial_api_end - serial_api) / 4
        jl      .func_is_ok
        or      eax, -1
        jmp     .return

.func_is_ok:
        ; check if port number is valid
        movzx   eax, bh
        shl     eax, 2
        mov     eax, [eax + serial_ports]
        test    eax, eax
        jnz     .port_is_ok
        mov     eax, SERIAL_API_ERR_PORT_INVALID
        jmp     .return

.port_is_ok:
        ; eax is pointer to serial_port descriptor
        push    eax ecx edx
        ; get access to the port
        lea     ecx, [eax + serial_port.mtx]
        call    mutex_lock
        pop     edx ecx eax
        ; call function by number
        and     ebx, 0xff
        push    eax
        ; pass args by regs:
        ;   eax -> pointer to port descriptor (struct serial_port)
        ;   ecx, edx, esi, edi = args of int40h
        call    dword [serial_api + ebx * 4]
        pop     esi
        ; release access
        lea     ecx, [esi + serial_port.mtx]
        push    eax
        call    mutex_unlock
        pop     eax

.return:
        mov     dword [esp + 32], eax
        ret

align 4
serial_open:
        ; check for busy
        bts     [eax + serial_port.status], SERIAL_STATUS_IS_OPENED
        jnc     .open
        mov     eax, SERIAL_API_ERR_PORT_BUSY
        ret
.open:
        ; save id of calling process
        mov     ebx, [TASK_BASE]
        mov     ebx, [ebx + TASKDATA.pid]
        mov     [eax + serial_port.pid], ebx
        ; reset fields
        and     [eax + serial_port.ev_mask], 0
        and     [eax + serial_port.rx_ridx], 0
        and     [eax + serial_port.rx_widx], 0
        ; tell driver about port open
        mov     ebx, [eax + serial_port.funcs]
        stdcall dword [ebx + serial_funcs.startup], eax
        xor     eax, eax
        ret

align 4
serial_close:
        call    serial_check_access
        jnc     @f
        mov     eax, SERIAL_API_ERR_ACCESS
        ret
@@:
        ; tell driver about port close
        mov     ebx, [eax + serial_port.funcs]
        push    eax
        stdcall dword [ebx + serial_funcs.shutdown], eax
        pop     eax
        ; reset flag
        and     [eax + serial_port.status], not (1 shl SERIAL_STATUS_IS_OPENED)
        xor     eax, eax
        ret

align 4
serial_get_status:
        call    serial_check_access
        jnc     @f
        mov     eax, SERIAL_API_ERR_ACCESS
        ret
@@:
        movzx   ebx, byte [edi + serial_status.size]
        cmp     ebx, sizeof.serial_status
        jae     @f
        mov     eax, -2 ; invalid size of structure
        ret
@@:
        mov     ebx, 115200
        mov     [edi + serial_status.baudrate], ebx

        xor     ebx, ebx
        spin_lock_irqsave
        mov     bl, [eax + serial_port.rx_ridx]
        mov     bh, [eax + serial_port.rx_widx]
        spin_unlock_irqrestore
        sub     bh, bl
        jnc     @f
        add     bh, 0xff
@@:
        shr     ebx, 8
        mov     [edi + serial_status.rx_count], bx
        xor     eax, eax
        ret

align 4
serial_set_ev_mask:
        call    serial_check_access
        jnc     @f
        mov     eax, SERIAL_API_ERR_ACCESS
        ret
@@:
        spin_lock_irqsave
        mov     [eax + serial_port.ev_mask], ecx
        spin_unlock_irqrestore
        xor     eax, eax
        ret

align 4
serial_get_ev_mask:
        or      eax, -1
        ret

align 4
serial_read:
        call    serial_check_access
        jnc     @f
        mov     eax, SERIAL_API_ERR_ACCESS
        ret
@@:
        xor     ebx, ebx
        xor     edx, edx
        spin_lock_irqsave
        mov     dl, [eax + serial_port.rx_ridx]
        mov     bl, [eax + serial_port.rx_widx]
        spin_unlock_irqrestore
        DEBUGF  1, "K : serial ridx=%d, widx=%d\n", dl, bl
        sub     bl, dl
        jnc     @f
        add     bl, 0xff
@@:
        ; ecx = num of requested bytes
        ; ebx = num of available bytes
        cmp     ebx, ecx
        jle     @f
        mov     ebx, ecx
@@:
        xchg    ecx, ebx
        test    ecx, ecx
        jz      .fail
        lea     esi, [eax + serial_port.rx_buf]
        add     esi, edx
        push    ecx
.copy:
        inc     dl
        movsb
        loop    .copy
        spin_lock_irqsave
        mov     [eax + serial_port.rx_ridx], dl
        spin_unlock_irqrestore
        pop     ecx
        DEBUGF  1, "K : serial readed=%d\n", dl, bl
        mov     dword [esp + 36], ecx
        xor     eax, eax
        ret

.fail:
        or      eax, -1
        ret
