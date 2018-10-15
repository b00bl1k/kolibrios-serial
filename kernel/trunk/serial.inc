;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SERIAL_PORTS_MAX = 256

struct serial_port
next                dd ?
prev                dd ?
driver              dd ?
status              dd ?
pid                 dd ?
ends

uglobal
align 4
serial_ports        dd ?
endg

iglobal
align 4
serial_drv_name     db 'SERIAL', 0
endg

align 4
serial_init:
        ; alloc memory for ports list
        stdcall kernel_alloc, SERIAL_PORTS_MAX * 4
        mov     [serial_ports], eax
        test    eax, eax
        jz      .fail
        ; clear memory
        mov     ecx, SERIAL_PORTS_MAX
        mov     edi, eax
        cld
        rep stosd
        ; try to load std serial port driver
        stdcall get_service, serial_drv_name
        test    eax, eax
        jnz     .fail
        DEBUGF  1, "K : Serial driver is not loaded\n"
.fail:
        ret

; __stdcall u32 SerialAddPort(SERIAL_DEVICE * device);
proc serial_add_port stdcall, device:dword
        ret
endp

; __stdcall u32 SerialRemovePort(SERIAL_DEVICE * device);
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