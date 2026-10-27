; patch-veins.ps1 site 6, cave4 (nasm -f bin). Jumped to from OverlayClass::Mark (0x58B71A) right after
; "new VeinholeMonsterClass(cell)"; ebp = centre CellClass*. Outside map loading, seed veins on the 5x5 ring around the
; monster (as the RMG does in MapSeedClass::Generate_Veinholes, 0x54FAA7-0x54FB16: Place_Veins + Recalc_Attributes(-1)),
; then Place_Monsters(false) builds the growth queues, which start only from VEINS cells within 2 cells of the monster.
bits 32
org 0x86CE60
        cmp dword [0x7E4394], 0         ; ScenarioInit (map load builds queues itself)
        jne done
        push ebx
        push esi
        push edi
        mov ebx, -2                     ; dy
yl:     mov esi, -2                     ; dx
xl:     cmp esi, -2
        je ring
        cmp esi, 2
        je ring
        cmp ebx, -2
        je ring
        cmp ebx, 2
        jne next
ring:   mov ax, [ebp+0x16]              ; Cell.Y
        add ax, bx
        shl eax, 16
        mov ax, [ebp+0x14]              ; Cell.X
        add ax, si
        push eax                        ; Cell on the stack
        push esp
        mov ecx, 0x748348               ; Map
        call 0x50F280                   ; MapClass::operator[]
        pop ecx
        cmp eax, 0x805B48               ; off-map dummy cell
        je next
        mov edi, eax
        mov ecx, eax
        call 0x45B760                   ; CellClass::Place_Veins
        push -1
        mov ecx, edi
        call 0x453240                   ; CellClass::Recalc_Attributes(-1)
next:   inc esi
        cmp esi, 2
        jle xl
        inc ebx
        cmp ebx, 2
        jle yl
        pop edi
        pop esi
        pop ebx
        xor ecx, ecx                    ; reset = false
        call 0x6623F0                   ; VeinholeMonsterClass::Place_Monsters
done:   jmp 0x58BDE0
