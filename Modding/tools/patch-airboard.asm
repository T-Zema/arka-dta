; patch-airboard: infantry boards a transport that hovers above its cell (Fly-locomotor Dropship/Shuttle).
; Hook: InfantryClass::Per_Cell_Process 0x4D38B3 (mov ecx,[esi+278h] -> jmp cave + nop), reached for PCP_END after the
; occupant search: edi = Cell_Unit/Cell_Aircraft/Cell_Building of the infantry's cell (ground layer only, so a flying unit is
; never found). If nothing was found, the infantry is on MISSION_ENTER (7) and its NavCom is a UnitClass standing in the same
; cell (Get_Cell, vtable +18Ch, the compare the original makes at 0x4D3A14), edi = NavCom. The original code then does the
; normal boarding: RADIO_CAN_LOAD to the transport -> CargoClass::Attach.
; esi = infantry, edi = occupant; eax/ecx/edx and ebp are free here (ebp is zeroed at 0x4D38B9).
; Build: pixi exec --spec nasm nasm -f bin -o patch-airboard.bin patch-airboard.asm   (bytes are copied into patch-airboard.ps1)
bits 32
org 0x86CB40

    test edi, edi
    jnz .done
    mov ebp, [esi+0x278]            ; NavCom
    test ebp, ebp
    jz .done
    mov eax, [esi]
    mov ecx, esi
    call [eax+0x154]                ; Get_Mission
    cmp eax, 7                      ; MISSION_ENTER
    jne .done
    mov ecx, [ebp+4]                ; IRTTITypeInfo: safe on any AbstractClass (NavCom may be a CellClass)
    lea eax, [ebp+4]
    push eax
    call [ecx+0x0C]                 ; What_Am_I (stdcall)
    cmp eax, 1                      ; RTTI_UNIT
    jne .done
    sub esp, 8                      ; [esp] = transport cell, [esp+4] = infantry cell
    mov eax, [ebp]
    mov ecx, esp
    push ecx
    mov ecx, ebp
    call [eax+0x18C]                ; Get_Cell (thiscall, callee pops the out pointer)
    mov eax, [esi]
    lea ecx, [esp+4]
    push ecx
    mov ecx, esi
    call [eax+0x18C]
    mov eax, [esp]
    cmp eax, [esp+4]                ; CellStruct = 2 x int16
    lea esp, [esp+8]                ; keeps the flags
    jne .done
    mov edi, ebp                    ; the hovering transport counts as the occupant
.done:
    mov ecx, [esi+0x278]            ; replaced instruction
    jmp 0x4D38B9
