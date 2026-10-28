; patch-veins.ps1 sites 11-13 (nasm -f bin), Zerg creep recedes (user 2026-10-28: "creep nie schodzi").
; Why it did not recede: Build_Growth_Queue (0x6626F0) floods ALL connected veins from the 5x5 around a monster, with no range,
; and Place_Monsters runs it for every monster, newest first. In a Zerg base the creeps touch, so one monster owned the whole
; carpet and the others owned nothing: killing their buildings shrank (almost) nothing. A dying monster then shrank its own
; cells at VeinholeShrinkRate (Rules 100: 1-4 cells per 100-150 frames, ~1 cell a second), and Build_Shrinking_Queue takes only
; mature veins (OverlayData >= 30h), so younger veins stayed for good.
bits 32
org 0x86C700

; Site 11, hook 0x58B71A in OverlayClass::Mark, right after "new VeinholeMonsterClass(cell)" (eax = the new monster, from the
; constructor). Marks a monster made during the game 'ZC' in the padding word +9Eh (the same word patch-veins-growth.asm sets to
; 'ZG' when a Zerg building stands on it); a monster from the map file gets 0 (a fresh object has garbage there). Sites 12 and
; the radius only touch 'ZC'/'ZG' monsters, so DTA maps with veinholes keep their veins. Then on to cave4 (0x86CE60).
mark:   mov word [eax+9Eh], 0
        cmp dword [7E4394h], 0          ; ScenarioInit: map load
        jne .go
        mov word [eax+9Eh], 'ZC'        ; made during the game: Zerg creep
.go:    jmp 86CE60h

        times 0x40 - ($ - $$) db 0CCh
; Site 12 (+40h), hook 0x6629AC in Build_Growth_Queue, the flood over the 8 neighbours (ebp = neighbour CellClass, esi = monster, edi =
; &neighbour.Cell, ebx = cell index; eax/ecx/edx free; the cell already holds VEINS). Replaces "test [ebp+0A4h],80000h / jne
; 0x662B53" (already owned this pass). For a Zerg monster: a cell more than ~8.5 cells away (dx*dx + dy*dy > 72, the radius of
; site 9) is not taken, so each monster owns its own circle and the cells nobody covers are dropped by Place_Monsters (veins no
; monster owns are removed); and a mature cell (OverlayData 30h-34h) also becomes a growth node, so a monster rebuilt after a
; neighbour died grows back into the gaps (Grow spreads from a mature node to free neighbours). Back to 0x6629BC (the
; maturity test), 0x662A28 (growth node) or 0x662B53 (next neighbour).
flood:  test dword [ebp+0A4h], 80000h
        jnz .skip
        cmp word [esi+9Eh], 'ZC'
        je .zerg
        cmp word [esi+9Eh], 'ZG'
        jne .orig
.zerg:  movsx eax, word [ebp+14h]       ; Cell.X
        movsx edx, word [esi+94h]       ; MonsterCell.X
        sub eax, edx
        imul eax, eax
        movsx edx, word [ebp+16h]       ; Cell.Y
        movsx ecx, word [esi+96h]       ; MonsterCell.Y
        sub edx, ecx
        imul edx, edx
        call 86C7E0h                    ; eax += edx, compared with the radius (patch-veins-radius.asm)
        jg .skip
        mov al, [ebp+96h]               ; OverlayData
        cmp al, 30h
        jb .orig
        cmp al, 35h
        jb 662A28h                      ; mature: growth node too
.orig:  jmp 6629BCh
.skip:  jmp 662B53h

        times 0xC0 - ($ - $$) db 0CCh
; Site 13 (+0C0h), hook 0x661408 in VeinholeMonsterClass::Update_All (the Remove_Dead loop: a shrinking monster whose queue is empty is
; deleted; esi = index, kept by Place_Monsters). After the delete, Place_Monsters(false) rebuilds every queue: the living
; monsters take back their circles (and regrow the gaps, site 12), veins nobody owns any more (younger veins of the dead one,
; cells outside every circle) are removed. Back to 0x66140F (reload of the vector).
dead:   mov eax, [ecx]
        push 1
        call [eax+20h]                  ; scalar deleting destructor
        xor ecx, ecx                    ; reset = false
        call 6623F0h                    ; VeinholeMonsterClass::Place_Monsters
        jmp 66140Fh
