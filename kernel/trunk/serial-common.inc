;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SERIAL_DRV_ERR_PORT_COUNT = 1 ; reached maximum ports number in system
SERIAL_DRV_ERR_PORT_DESC = 2 ; invalid port descriptor
SERIAL_DRV_ERR_NO_MEM = 3

SERIAL_API_ERR_PORT_INVALID = 1
SERIAL_API_ERR_PORT_BUSY = 2
SERIAL_API_ERR_ACCESS = 3

SERIAL_RING_BUF_SIZE = 4096

SERIAL_SR_RXNE = 0x01 ; RX buffer is not empty
SERIAL_SR_TXE = 0x02 ; TX buffer is empty

struct serial_funcs
        size            dd ?
        startup         dd ?
        shutdown        dd ?
ends

struct serial_con APPOBJ
        hport           dd ? ; pointer to serial_port
ends

struct serial_port
        mtx             MUTEX
        con             dd ? ; pointer to serial_con, if port is opened, otherwise null
        funcs           dd ? ; pointer to struct serial_funcs
        ev_mask         dd ? ; event mask for process
        rx_buf          RING_BUF
        tx_buf          RING_BUF
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

struct serial_evdata
        port            dd ?
        r1              dd ?
        r2              dd ?
        r3              dd ?
        r4              dd ?
ends
