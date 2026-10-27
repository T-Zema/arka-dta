; patch-zergbuild.ps1 cave 2 (nasm -f bin): placement grid while the mouse shows the deploy cursor (user 2026-10-27).
; Tactical::Render calls Tactical::Draw_Placement(bool) twice (0x611ADC false, 0x611B65 true); both calls come here instead.
; With a real pending placement nothing changes. Otherwise, if Map.CurrentMouseShape is MOUSE_DEPLOY (27) or MOUSE_NO_DEPLOY
; (28), then for EVERY selected unit with UnitTypeClass::DeploysInto (D deploys them all) the building foundation is drawn
; where UnitClass::Try_To_Deploy would put it (unit cell, + AdjacentCoord[7] unless BuildingTypeClass::Is_Mobile_Deployer):
; the Map placement state is faked for one Draw_Placement call per unit and restored at the end.
; v1 drew only the unit whose cell was under the mouse: the cursor is over the unit's picture, drawn above its cell, so the
; cells hardly ever matched and no grid appeared (in-game test 2026-10-27).
; Cell colours come from CellClass::Draw_Placement_Cursor -> Is_Clear_To_Build, so the creep rules (cave 1) show red/green.
; Map (0x748348) members (Vinifera.pdb): ZoneCell 0x7494E4, ZoneOffset 0x7494E8, CursorSize 0x7494EC, IsProximityCheck 0x7494F0,
; PendingObjectPtr 0x7494F8, PendingObject 0x7494FC, PendingHouse 0x749500 (the 32 bytes 0x7494E4-0x749503 are saved and
; restored), CurrentMouseShape 0x74A068 (MouseClass +1D20h, also written by Vinifera's _Override_Mouse_Shape).
; CurrentObjects: vector 0x7E485C, count 0x7E4868 (as DeployCommandClass::Execute). UnitClass Class +360h, UnitTypeClass
; DeploysInto +274h, ObjectClass Coord +40h; BuildingTypeClass::Occupy_List 0x43FED0 (ret 4), Is_Mobile_Deployer 0x443EC0;
; RTTI_UNIT = 1. Vinifera's hook in Draw_Placement (0x611E4D, radial indicators) skips a null PendingObjectPtr.
bits 32
org 0x86CA00
dpx:    cmp dword [7494FCh], 0          ; a real placement is pending: unchanged
        jne 611DD0h
        mov eax, [74A068h]              ; Map.CurrentMouseShape
        cmp eax, 27                     ; MOUSE_DEPLOY
        je .go
        cmp eax, 28                     ; MOUSE_NO_DEPLOY
        je .go
        ret 4
.go:    push ebp
        push ebx
        push esi
        push edi
        mov ebp, ecx                    ; Tactical
        sub esp, 28h                    ; +0 building type, +4 origin cell, +8 saved Map state (32 bytes)
        mov esi, 7494E4h                ; save the Map placement state
        lea edi, [esp+8]
        mov ecx, 8
        rep movsd
        xor ebx, ebx
.next:  cmp ebx, [7E4868h]              ; CurrentObjects
        jge .done
        mov eax, [7E485Ch]
        mov esi, [eax+ebx*4]
        inc ebx
        test esi, esi
        jz .next
        mov ecx, esi
        mov eax, [esi]
        call [eax+2Ch]                  ; What_Am_I
        cmp eax, 1                      ; RTTI_UNIT
        jne .next
        mov eax, [esi+360h]             ; UnitTypeClass
        mov eax, [eax+274h]             ; DeploysInto
        test eax, eax
        jz .next
        mov [esp], eax                  ; building type
        mov ecx, [esi+40h]              ; coord X
        sar ecx, 8
        mov edi, [esi+44h]              ; coord Y
        sar edi, 8
        shl edi, 16
        mov di, cx                      ; unit cell
        mov ecx, eax
        call 443EC0h                    ; BuildingTypeClass::Is_Mobile_Deployer
        test al, al
        jnz .origin
        add di, [761164h]               ; + AdjacentCoord[7], as Try_To_Deploy
        ror edi, 16
        add di, [761166h]
        ror edi, 16
.origin: mov [7494E4h], edi             ; ZoneCell = building origin
        mov dword [7494E8h], 0          ; ZoneOffset
        mov ecx, [esp]
        push 1
        call 43FED0h                    ; BuildingTypeClass::Occupy_List(true)
        mov [7494ECh], eax              ; CursorSize
        mov byte [7494F0h], 1           ; IsProximityCheck: colour by Is_Clear_To_Build only
        mov dword [7494F8h], 0          ; PendingObjectPtr: no ghost picture
        mov eax, [esp]
        mov [7494FCh], eax              ; PendingObject
        push dword [esp+3Ch]            ; the bool argument (locals 28h + 4 registers + return address)
        mov ecx, ebp
        call 611DD0h                    ; Tactical::Draw_Placement
        jmp .next
.done:  lea esi, [esp+8]                ; restore the Map placement state
        mov edi, 7494E4h
        mov ecx, 8
        rep movsd
        add esp, 28h
        pop edi
        pop esi
        pop ebx
        pop ebp
        ret 4
