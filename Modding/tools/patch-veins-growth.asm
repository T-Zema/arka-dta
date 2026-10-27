; patch-veins.ps1 sites 9 and 10 (nasm -f bin), Zerg creep (user 2026-10-27).
bits 32
org 0x86C900

; Site 9, hook 0x661F1B in VeinholeMonsterClass::Grow (mov ecx,edi / call CellClass::Can_Place_Veins): a neighbour cell only
; joins the growth queue within 8 cells of the monster (dx*dx + dy*dy <= 72, a round patch of radius ~8.5). The candidate cell
; is at [esp+14h] (X, Y words), MonsterCell at [esi+94h]; ebx (cell index) is kept. Back to 0x661F22 (test al,al).
radius: movsx eax, word [esp+14h]
        movsx edx, word [esi+94h]
        sub eax, edx
        imul eax, eax
        movsx edx, word [esp+16h]
        movsx ecx, word [esi+96h]
        sub edx, ecx
        imul edx, edx
        add eax, edx
        cmp eax, 72
        jg .far
        mov ecx, edi
        call 45B0D0h                    ; CellClass::Can_Place_Veins
        jmp 661F22h
.far:   xor eax, eax
        jmp 661F22h

        times 0x40 - ($ - $$) db 0CCh
; Site 10, hook 0x661420 (start of VeinholeMonsterClass::AI, ecx = monster): a monster under a Zerg building dies with it.
; Each frame: if a building of type SCZ* occupies MonsterCell, the monster is marked 'ZG' in its padding bytes +9Eh/+9Fh
; (after IsToPuffGas +9Dh, before field_A0; a fresh object has garbage there, so the mark is a 2-byte magic). A marked
; monster without that building any more dies like in Take_Damage on RESULT_DESTROYED (0x661BF5): next state 3 (dying
; animation, then Destroy_Monster shrinks the veins) and Detach_This_From_All (0x6489B0, fastcall ecx = object, dl = 0).
; Creep Tumor holes never get the mark: no building can stand on a hole centre (VEINHOLE is not Insignificant).
link:   push ecx
        push esi
        push edi
        push ebx
        mov esi, ecx
        cmp dword [esi+6Ch], 3          ; already dying
        je .ret
        cmp dword [esi+68h], 3
        je .ret
        lea eax, [esi+94h]              ; MonsterCell
        push eax
        mov ecx, 748348h                ; Map
        call 50F280h                    ; MapClass::operator[]
        mov edi, [eax+70h]              ; first occupier
        xor ebx, ebx
.occ:   test edi, edi
        jz .seen
        mov ecx, edi
        mov eax, [edi]
        call [eax+2Ch]                  ; What_Am_I
        cmp eax, 6                      ; RTTI_BUILDING
        jne .nx
        mov eax, [edi+220h]             ; BuildingTypeClass
        cmp word [eax+14h], 'SC'
        jne .nx
        cmp byte [eax+16h], 'Z'
        jne .nx
        inc ebx
        jmp .seen
.nx:    mov edi, [edi+20h]              ; ObjectClass::Next
        jmp .occ
.seen:  test ebx, ebx
        jz .gone
        mov word [esi+9Eh], 'ZG'        ; tied to a Zerg building
        jmp .ret
.gone:  cmp word [esi+9Eh], 'ZG'
        jne .ret
        mov word [esi+9Eh], 0
        mov dword [esi+6Ch], 3          ; dying
        xor edx, edx
        mov ecx, esi
        call 6489B0h                    ; Detach_This_From_All(object, false)
.ret:   pop ebx
        pop edi
        pop esi
        pop ecx
        sub esp, 24h                    ; the overwritten first instructions of AI
        push ebp
        push esi
        jmp 661425h
