; patch-vinifera-veins.ps1 caves (nasm -f bin), in Vinifera.dll section .scdock + 0x100 (VA 0x106DB100 as linked; every
; jump/call is relative, game addresses are only reached through Vinifera's own thunks, so a relocated DLL still works).
; Vinifera replaces AnimClass::AI with AnimClassExt::_AI (0x1003D788), whose tiberium-spawn loop copies the game's code, so the
; game.exe sites of patch-veins.ps1 in AnimClass::AI never run. Same three fixes here, for TiberiumSpawnType = VEINHOLE (0xA7):
bits 32
org 0x106DB100

; V1, hook 0x1003DDBA (after Map[adjacent cell]): the anim's OWN cell (not the north neighbour, Vinifera's loop has the same
; AdjacentCell(cell, dx & 7) bug), and only "no overlay there" instead of Can_Tiberium_Germinate (which refuses any cell with
; a visible building, so nothing could seed under a Zerg building).
v1:     xor edi, edi
        mov [ebp-20h], eax              ; cell = Map[adjacent]  (original)
        mov ecx, [esi+64h]              ; AnimType
        mov ecx, [ecx+1C0h]             ; TiberiumSpawnType
        test ecx, ecx
        jz .normal
        cmp dword [ecx+124h], 0A7h      ; VEINHOLE
        jne .normal
        lea eax, [ebp-28h]              ; the anim's own cell
        push eax
        mov ecx, 748348h                ; Map (game.exe, fixed base)
        call 10190CA7h                  ; thunk -> MapClass::operator[]
        mov [ebp-20h], eax
        cmp dword [eax+30h], -1         ; no overlay
        sete al
        jmp 1003DDC7h                   ; test al,al
.normal: push edi                       ; nullptr
        mov ecx, [ebp-20h]
        call 1019262Ch                  ; thunk -> CellClass::Can_Tiberium_Germinate
        jmp 1003DDC7h

        align 16, db 0CCh
; V2, hook 0x1003DE13: overlay = TiberiumSpawnType + Random(0,3); no random part for VEINHOLE (167+1 = CORPSE...).
v2:     mov ecx, [esi+64h]
        mov ecx, [ecx+1C0h]
        cmp dword [ecx+124h], 0A7h
        jne .add
        xor eax, eax
.add:   add eax, [ecx+124h]
        jmp 1003DE22h

        align 16, db 0CCh
; V3, hook 0x1003DE5A: OverlayData = Random(0,2); 0 for the Veinhole Monster centre, as OverlayClass::Mark sets it.
v3:     mov ecx, [ebp-20h]
        cmp dword [ecx+30h], 0A7h
        jne .w
        xor eax, eax
.w:     mov [ecx+96h], al
        jmp 1003DE63h
