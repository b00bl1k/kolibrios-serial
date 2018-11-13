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

SERIAL_SR_RXNE = 0x01 ; RX buffer is not empty
SERIAL_SR_TXE = 0x02 ; TX buffer is empty

struct serial_funcs
        size            dd ? ; sizeof this struct
        startup         dd ? ; void __stdcall ( *startup)(void * user_data);
        shutdown        dd ? ; void __stdcall ( *shutdown)(void * user_data);
        read            dd ? ; u32 __stdcall ( *read)(void * user_data, void * dst, u32 size);
        write           dd ? ; u32 __stdcall ( *write)(void * user_data, const void * src, u32 size);
ends

struct serial_status
        size            db ? ; sizeof this struct
        baudrate        dd ? ; current baudrate
        rx_count        dd ? ; bytes count in rx fifo
        tx_free         dd ? ; free space in tx fifo
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
