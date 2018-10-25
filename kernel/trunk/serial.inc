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
; event for serial
serial_event        dd ?
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

;         ; create serial thread
;         movi    ebx, 1 ; kernel thread
;         mov     ecx, serial_thread_proc
;         xor     edx, edx
;         call    new_sys_threads
;         test    eax, eax
;         jns     @f
;         DEBUGF  1, "K : Cannot create kernel thread for serial, error %d\n", eax
;         jmp     .exit
; @@:

;         ; wait while the serial thread initializes itself
;         call    change_task
;         cmp     [serial_event], 0
;         jz      @b
;         cmp     [serial_event], -1
;         jz      .exit

        ; try to load std serial port driver
        stdcall get_service, serial_drv_name
        test    eax, eax
        jnz     .exit
        DEBUGF  1, "K : Standard serial driver is not loaded\n"

.exit:
        ret

proc serial_thread_proc
        ; create event
        xor     esi, esi
        mov     ecx, MANUAL_DESTROY
        call    create_event
        test    eax, eax
        jnz     @f
        DEBUGF  1, "Cannot create event for serial thread\n"
        or      [serial_event], -1
        jmp     sys_end
  @@:
        ; save event handle
        mov     [serial_event], eax
  .wait_ev:
        ; main loop of thread
        mov     eax, [serial_event]
        mov     ebx, [eax + EVENT.id]
        or      ecx, -1
        call    wait_event_timeout

        mov     eax, [serial_event]
        mov     ebx, [eax + EVENT.code + serial_evdata.port]
        call    serial_check_port

        jmp     .wait_ev
endp

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
        ; create rx and tx ring buffers
        lea     eax, [edi + serial_port.rx_buf]
        stdcall serial_create_ring_buf, eax
        test    eax, eax
        jnz     @f
        mov     eax, SERIAL_DRV_ERR_NO_MEM
        ret

  @@:
        lea     eax, [edi + serial_port.tx_buf]
        stdcall serial_create_ring_buf, eax
        test    eax, eax
        jnz     @f
        mov     eax, [edi + serial_port.rx_buf + ring_buf.start_ptr]
        call    free
        mov     eax, SERIAL_DRV_ERR_NO_MEM
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
proc serial_remove_port stdcall, port:dword
        ret
endp

; __stdcall u32 SerialWakeUp(struct serial_port * port);
proc serial_wake_up stdcall uses ebx esi edi, port:dword
locals
evdata serial_evdata
endl
        ; store pointer to serial_port
        lea     esi, [evdata]
        mov     eax, [port]
        mov     [esi + serial_evdata.port], eax

        mov     eax, [serial_event]
        mov     ebx, [eax + EVENT.id]
        xor     edx, edx
        call    raise_event
        ret
endp

proc serial_create_ring_buf stdcall uses esi, rb_ptr
        mov     esi, [rb_ptr]
        movi    eax, SERIAL_RING_BUF_SIZE
        call    malloc
        test    eax, eax
        jz      .exit

        lea     ecx, [esi + ring_buf.mutex]
        call    mutex_init

        mov     [esi + ring_buf.start_ptr], eax
        mov     [esi + ring_buf.write_ptr], eax
        mov     [esi + ring_buf.read_ptr], eax
        mov     [esi + ring_buf.size], 0
        add     eax, SERIAL_RING_BUF_SIZE
        mov     [esi + ring_buf.end_ptr], eax
        mov     eax, esi

  .exit:
        ret
endp

;-----------------------------------------------------------------;
;                                                                 ;
; serial_ring_buf_read: Read from ring buffer                     ;
;                                                                 ;
;   IN: eax = ring struct ptr                                     ;
;       ecx = bytes to read                                       ;
;       edi = ptr to buffer start                                 ;
;                                                                 ;
;  OUT: eax = unchanged                                           ;
;       ecx = number of bytes read (0 on error)                   ;
;       edx = destroyed                                           ;
;       esi = destroyed                                           ;
;       edi = ptr to buffer end                                   ;
;                                                                 ;
;-----------------------------------------------------------------;
proc serial_ring_buf_read
        DEBUGF  1, "serial_ring_buf_read: ringbuff=%x ptr=%x size=%u\n", eax, edi, ecx

        mov     esi, [eax + ring_buf.read_ptr]
        mov     edx, [eax + ring_buf.size]

        cmp     ecx, edx
        jle     @f
        ; less than request
        mov     ecx, edx
  @@:
        DEBUGF  1, "serial_ring_buf_read: %u bytes from %x to %x\n", ecx, esi, edi
        push    ecx
        shr     ecx, 1
        jnc     .nb
        movsb
  .nb:
        shr     ecx, 1
        jnc     .nw
        movsw
  .nw:
        test    ecx, ecx
        jz      .nd
        rep movsd
  .nd:
        pop     ecx

        sub     [eax + ring_buf.size], ecx
        add     [eax + ring_buf.read_ptr], ecx
        mov     edx, [eax + ring_buf.end_ptr]
        cmp     [eax + ring_buf.read_ptr], edx
        jb      @f
        sub     [eax + ring_buf.read_ptr], SERIAL_RING_BUF_SIZE
  @@:
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

        mov     eax, [eax + serial_port.rx_buf + ring_buf.size]
        mov     [edi + serial_status.rx_count], ax
        xor     eax, eax
        ret

align 4
serial_set_ev_mask:
        call    serial_check_access
        jnc     @f
        mov     eax, SERIAL_API_ERR_ACCESS
        ret
  @@:
        or      eax, -1
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
        spin_lock_irqsave
        lea     eax, [eax + serial_port.rx_buf]
        call    serial_ring_buf_read
        spin_unlock_irqrestore
        mov     dword [esp + 36], ecx
        and     eax, 0
        ret
