;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SERIAL_DRV_ERR_PORT_COUNT = 1 ; reached maximum ports number in system
SERIAL_DRV_ERR_PORT_DESC = 2 ; invalid port descriptor
SERIAL_API_ERR_PORT_INVALID = 1
SERIAL_API_ERR_PORT_BUSY = 2
SERIAL_API_ERR_ACCESS = 3

SERIAL_STATUS_IS_OPENED = 0

struct serial_funcs
        size            dd ?
        startup         dd ?
        shutdown        dd ?
ends

struct serial_port
        mtx             MUTEX
        status          dd ? ; port status bit field, see SERIAL_STATUS_*
        pid             dd ? ; id of process-owner
        funcs           dd ? ; pointer to struct serial_funcs
        ev_mask         dd ? ; event mask for process
        ; simple ring buffer
        rx_ridx         db ?
        rx_widx         db ?
        rx_buf          rb 256
ends

struct serial_status
        size            db ? ; sizeof this struct
        baudrate        dd ? ; current baudrate
        rx_count        dw ? ; bytes count in rx fifo
        tx_count        dw ? ; bytes count in tx fifo
        dtr             db ?
        rts             db ?
        cts             db ?
        dcd             db ?
        dsr             db ?
        ri              db ?
ends
