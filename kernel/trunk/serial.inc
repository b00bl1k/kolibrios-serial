;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SERIAL_PORTS_MAX = 64

struct serial_port
        status          dd ? ; port status bit field
        pid             dd ? ; who currently accesseing to port
ends

uglobal
align 4
serial_ports        rd SERIAL_PORTS_MAX
endg

iglobal
align 4
serial_drv_name     db 'SERIAL', 0
endg

align 4
serial_init:
        ; try to load std serial port driver
        stdcall get_service, serial_drv_name
        test    eax, eax
        jnz     .fail
        DEBUGF  1, "K : Serial driver is not loaded\n"
.fail:
        ret

; __stdcall u32 SerialAddPort(struct serial_port * port);
; return 0 if ok, otherwise err code
proc serial_add_port stdcall, port:dword
        ; find free slot
        xor     eax, eax
        mov     ecx, SERIAL_PORTS_MAX
        mov     edi, serial_ports
        repne scasd
        jnz     .err
        ; store pointer to the port descriptor
        sub     edi, 4
        mov     eax, [port]
        mov     [edi], eax
        ; num of port
        DEBUGF  1, "K : Added serial port 0x%x\n", edi, [port]
        xor     eax, eax
        ret

.err:
        xor     eax, eax
        inc     eax
        ret
endp

; __stdcall u32 SerialRemovePort(struct serial_port * port);
proc serial_remove_port stdcall, device:dword
        ret
endp

align 4
syscall_serial:
        ret

align 4
serial_open:
        ret

align 4
serial_close:
        ret

align 4
serial_tx_start:
        ret

align 4
serial_tx_stop:
        ret

align 4
serial_rx_stop:
        ret

align 4
serial_rx_start:
        ret

align 4
serial_enum:
        ret

align 4
serial_opts:
        ret