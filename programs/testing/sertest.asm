format binary as ""
use32
org 0

db 'MENUET01'
dd 1
dd START
dd I_END
dd MEM
dd STACKTOP
dd 0, 0

__DEBUG__ equ 1
__DEBUG_LEVEL__ equ 1

BTN_OPEN_ID = 2
BTN_CLOSE_ID = 3
BTN_STATUS_ID = 4

include '../macros.inc'
include '../debug-fdo.inc'
include '../KOSfuncs.inc'
include '../struct.inc'

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

START:
        mcall   SF_STYLE_SETTINGS, SSF_GET_COLORS, sc, sizeof.system_colors
        call    draw_window

event_wait:
        mcall   SF_WAIT_EVENT

        cmp     eax, 1
        je      red

        cmp     eax, 2
        je      key

        cmp     eax, 3
        je      button

        jmp     event_wait

red:
        call    draw_window
        jmp     event_wait

key:
        mcall   SF_GET_KEY
        jmp     event_wait

button:
        mcall   SF_GET_BUTTON

        cmp     ah, 1
        jz      .exit
        cmp     ah, BTN_OPEN_ID
        jz      .open
        cmp     ah, BTN_CLOSE_ID
        jz      .close
        cmp     ah, BTN_STATUS_ID
        jz      .status
        jmp     event_wait

.open:
        mcall   78, 0x0000
        DEBUGF  1, "Serial open result: 0x%x\n", eax
        jmp     event_wait

.close:
        mcall   78, 0x0001
        DEBUGF  1, "Serial close result: 0x%x\n", eax
        jmp     event_wait

.status:
        mov     eax, sizeof.serial_status
        mov     [stat + serial_status.size], al
        mov     edi, stat
        mcall   78, 0x0002
        test    eax, eax
        jnz     event_wait

        DEBUGF  1, "Serial status result: 0x%x\n", eax
        mov     eax, [stat + serial_status.baudrate]
        DEBUGF  1, "Serial baudrate: %d\n", eax
        mov     ax, [stat + serial_status.rx_count]
        DEBUGF  1, "Serial rx_count: %d\n", ax
        test    ax, ax
        jz      event_wait

        mov     edi, test_buf
        mcall   78, 0x0005, 10
        lea     edi, [ecx + test_buf]
        mov     byte [edi], 0
        DEBUGF  1, "Serial read result: eax=0x%x ecx=0x%x\n", eax, ecx

        call    draw_window
        jmp     event_wait

.exit:
        mcall   SF_TERMINATE_PROCESS

draw_window:
        mcall   SF_REDRAW, SSF_BEGIN_DRAW

        mov     ebx, 100 * 65536 + 300
        mov     ecx, 100 * 65536 + 500
        mov     edx, 0x34ffffff
        mov     esi, 0x808899ff
        mov     edi, title
        mcall   SF_CREATE_WINDOW

        mov     ebx, 5 * 65536 + 100
        mov     ecx, 5 * 65536 + 25
        mov     edx, BTN_OPEN_ID
        mov     esi, [sc.work_button]
        mcall   SF_DEFINE_BUTTON

        mov     ebx, 5 * 65536 + 100
        mov     ecx, 35 * 65536 + 25
        mov     edx, BTN_CLOSE_ID
        mov     esi, [sc.work_button]
        mcall   SF_DEFINE_BUTTON

        mov     ebx, 5 * 65536 + 100
        mov     ecx, 65 * 65536 + 25
        mov     edx, BTN_STATUS_ID
        mov     esi, [sc.work_button]
        mcall   SF_DEFINE_BUTTON

        mov     ecx, [sc.work_button_text]
        or      ecx, 0x90000000
        mov     edx, btn_open_cap
        mcall   SF_DRAW_TEXT, (5 + (100 - 4 * 8) / 2) shl 16 + 10

        mov     ecx, [sc.work_button_text]
        or      ecx, 0x90000000
        mov     edx, btn_close_cap
        mcall   SF_DRAW_TEXT, (5 + (100 - 5 * 8) / 2) shl 16 + 40

        mov     ecx, [sc.work_button_text]
        or      ecx, 0x90000000
        mov     edx, btn_status_cap
        mcall   SF_DRAW_TEXT, (5 + (100 - 6 * 8) / 2) shl 16 + 70

        mov     ecx, [sc.work_text]
        or      ecx, 0x90000000
        mov     edx, test_buf
        mcall   SF_DRAW_TEXT, 5 shl 16 + 110

        mcall   SF_REDRAW, SSF_END_DRAW

        ret

title           db "Serial Test", 0
btn_open_cap    db "Open", 0
btn_close_cap   db "Close", 0
btn_status_cap  db "Status", 0

include_debug_strings

I_END:


align 4
sc system_colors
stat serial_status
test_buf rb 20

rb 4096
align 16
STACKTOP:

MEM:
