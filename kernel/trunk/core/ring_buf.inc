;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2018. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;bool __fastcall ring_buf_create(struct RING_BUF *buf, u32 pages)
align 4
proc ring_buf_create
        shl     edx, 12
        push    ecx
        push    edx
        stdcall create_ring_buffer, edx, PG_SWR
        pop     edx
        pop     ecx
        test    eax, eax
        jz      .exit

        mov     [ecx + RING_BUF.start_ptr], eax
        mov     [ecx + RING_BUF.write_ptr], eax
        mov     [ecx + RING_BUF.read_ptr], eax
        add     eax, edx
        mov     [ecx + RING_BUF.end_ptr], eax
        mov     [ecx + RING_BUF.size], edx
        or      eax, 1

.exit:
        ret
endp

;void __fastcall ring_buf_destroy(struct RING_BUF *buf)
align 4
proc ring_buf_destroy
        xor     eax, eax
        mov     [ecx + RING_BUF.write_ptr], eax
        mov     [ecx + RING_BUF.read_ptr], eax
        mov     [ecx + RING_BUF.end_ptr], eax
        mov     [ecx + RING_BUF.size], eax
        xchg    eax, [ecx + RING_BUF.start_ptr]
        stdcall kernel_free, eax
        ret
endp

;u32 __fastcall ring_buf_count(struct RING_BUF *buf)
align 4
proc ring_buf_count
        mov     eax, [ecx + RING_BUF.write_ptr]
        mov     edx, [ecx + RING_BUF.read_ptr]
        cmp     eax, edx
        jb      @f
        sub     eax, edx
        ret

@@:
        sub     eax, edx
        add     eax, [ecx + RING_BUF.size]
        ret
endp

;u32 __fastcall ring_buf_free(struct RING_BUF *buf)
align 4
proc ring_buf_free
        mov     eax, [ecx + RING_BUF.read_ptr]
        mov     edx, [ecx + RING_BUF.write_ptr]
        cmp     eax, edx
        jae     @f
        sub     eax, edx
        dec     eax
        ret

@@:
        sub     eax, edx
        dec     eax
        add     eax, [ecx + RING_BUF.size]
        ret
endp

;u32 __stdcall ring_buf_peek(struct RING_BUF *buf, u32 *dst, u32 offset, u32 size)
align 4
proc ring_buf_peek stdcall uses esi edi, buf, dst, offset, size
        mov     ecx, [buf]
        push    ecx
        call    ring_buf_count
        pop     ecx

        mov     esi, [ecx + RING_BUF.read_ptr]
        mov     edx, [offset]
        add     esi, edx

        neg     edx
        add     edx, eax
        jle     .no_data_at_all

        mov     edi, [dst]
        mov     ecx, [size]
        cmp     ecx, edx
        jbe     .copy
        mov     ecx, edx
.copy:
        DEBUGF  1, "ring_buf_peek: copy %d bytes from 0x%x to 0x%x\n", ecx, esi, edi
        mov     eax, ecx
        shr     ecx, 1
        jnc     .nb
        cld
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
        ret

.no_data_at_all:
        DEBUGF  1, "ring_buf_peek: no data at all\n"
        xor     eax, eax
        ret
endp

;u32 __stdcall ring_buf_write(struct RING_BUF *buf, const u32 *src, u32 size)
align 4
proc ring_buf_write stdcall uses esi edi, buf, src, size
        mov     ecx, [buf]
        push    ecx
        call    ring_buf_free
        pop     ecx
        test    eax, eax
        jz      .nothing

        mov     esi, [src]
        mov     edi, [ecx + RING_BUF.write_ptr]
        mov     ecx, [size]
        cmp     ecx, eax
        jbe     .copy
        mov     ecx, eax
.copy:
        DEBUGF  1, "ring_buf_write: copy %d bytes from 0x%x to 0x%x\n", ecx, esi, edi
        mov     eax, ecx
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
        mov     ecx, [buf]
        cmp     edi, [ecx + RING_BUF.end_ptr]
        jb      @f
        sub     edi, [ecx + RING_BUF.size]
@@:
        mov     [ecx + RING_BUF.write_ptr], edi

.nothing:
        ret
endp

;u32 __stdcall ring_buf_read(struct RING_BUF *buf, u32 *dst, u32 size)
align 4
proc ring_buf_read stdcall uses esi edi, buf, dst, size
        mov     ecx, [buf]
        push    ecx
        call    ring_buf_count
        pop     ecx

        mov     esi, [ecx + RING_BUF.read_ptr]
        mov     edi, [dst]
        mov     ecx, [size]
        cmp     ecx, eax
        jbe     .copy
        mov     ecx, eax
.copy:
        DEBUGF  1, "ring_buf_read: copy %d bytes from 0x%x to 0x%x\n", ecx, esi, edi
        mov     eax, ecx
        shr     ecx, 1
        jnc     .nb
        cld
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
        mov     ecx, [buf]
        cmp     esi, [ecx + RING_BUF.end_ptr]
        jb      .save_ptr
        sub     esi, [ecx + RING_BUF.size]
.save_ptr:
        mov     [ecx + RING_BUF.read_ptr], esi
        ret
.nothing:
        xor     eax, eax
        ret
endp

;u32 __fastcall ring_buf_discard(struct RING_BUF *buf, u32 size)
align 4
proc ring_buf_discard
        push    ecx
        push    edx
        call    ring_buf_count
        pop     edx
        pop     ecx

        cmp     eax, edx
        jae     .discard
        mov     edx, eax
.discard:
        push    edx
        add     edx, [ecx + RING_BUF.read_ptr]
        cmp     edx, [ecx + RING_BUF.end_ptr]
        jb      .save_ptr
        sub     edx, [ecx + RING_BUF.size]
.save_ptr:
        mov     [ecx + RING_BUF.read_ptr], edx
        pop     eax
        DEBUGF  1, "ring_buf_discard: %d bytes\n", eax
        ret
endp
