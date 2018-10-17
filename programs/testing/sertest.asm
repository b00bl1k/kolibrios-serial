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

include '../macros.inc'
include '../debug-fdo.inc'
include '../KOSfuncs.inc'

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
        jmp     event_wait

.open:
        mcall   78, 0x0000
        DEBUGF  1, "Serial open result: 0x%x\n", eax
        jmp     event_wait

.close:
        mcall   78, 0x0001
        DEBUGF  1, "Serial close result: 0x%x\n", eax
        jmp     event_wait

.exit:
        mcall   SF_TERMINATE_PROCESS

draw_window:
        mcall   SF_REDRAW, SSF_BEGIN_DRAW

        mov     ebx, 100 * 65536 + 300
        mov     ecx, 100 * 65536 + 120
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
        mov     ecx, 34 * 65536 + 25
        mov     edx, BTN_CLOSE_ID
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

        mcall   SF_REDRAW, SSF_END_DRAW

        ret

title           db "Serial Test", 0
btn_open_cap    db "Open", 0
btn_close_cap   db "Close", 0

include_debug_strings

I_END:


align 4
sc system_colors

rb 4096
align 16
STACKTOP:

MEM:
