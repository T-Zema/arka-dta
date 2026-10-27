; patch-zergbuild.ps1 cave (nasm -f bin): Zerg creep building rules (user 2026-10-27) around
; CellClass::Is_Clear_To_Build(SpeedType, BuildingTypeClass const *, HouseClass const *) (0x452250, thiscall, ret 0Ch).
; Every building placement goes through it: sidebar placement and MCV / drone deploy (BuildingTypeClass::Legal_Placement via
; TechnoTypeClass::Legal_Placement 0x63D3D9), BuildingClass::Mark at Unlimbo (0x4294A0), the placement grid colours
; (CellClass::Draw_Placement_Cursor 0x454D77). Vinifera calls it through its own thunk, it does not replace it.
; "Zerg" is decided by the BUILDING TYPE (IniName "SCZ*", all 26 Zerg building types), not by the house: UnitClass::Try_To_Deploy
; checks Legal_Placement(cell, NULL), without a house.
; Only when the original says "clear", outside scenario init, with a building type:
;   - creep cell (overlay 126 VEINS / 178 VEINHOLEDUMMY; [VEINS] is Insignificant=yes so it is buildable at all): Zerg only;
;   - Zerg building on a cell without creep: refused, except Hatchery/Lair/Hive/Infested CC (ToBuild = RTTI_UNITTYPE), the
;     Extractor (IsRefinery) and 1x1 non-wall buildings (burrowed Lurker). The Creep Tumor (1x1, Wall=yes) needs creep (SC2).
; Offsets (Vinifera.pdb): AbstractTypeClass IniName +14h, BuildingTypeClass ToBuild +508h, Size +528h (BSIZE_11 = 0),
; IsWall +809h, IsRefinery +81Bh; CellClass Overlay +30h; ScenarioInit 0x7E4394; RTTI_UNITTYPE = 28h.
bits 32
org 0x86CD00
wrap:   push esi
        push edi
        mov esi, ecx                    ; cell
        push dword [esp+14h]            ; house
        push dword [esp+14h]            ; building type
        push dword [esp+14h]            ; speed type
        mov ecx, esi
        call orig
        test al, al
        jz .done                        ; not clear anyway
        cmp dword [7E4394h], 0          ; scenario init: map buildings are placed as written
        jne .done
        mov edi, [esp+10h]              ; building type   (stack: edi, esi, ret, speed, type, house)
        test edi, edi
        jz .done
        xor edx, edx                    ; edx = 1 for a Zerg building type
        cmp word [edi+14h], 'SC'
        jne .side
        cmp byte [edi+16h], 'Z'
        jne .side
        inc edx
.side:  mov ecx, [esi+30h]              ; overlay
        cmp ecx, 7Eh                    ; VEINS
        je .creep
        cmp ecx, 0B2h                   ; VEINHOLEDUMMY
        je .creep
        test edx, edx                   ; no creep: only Zerg buildings have a rule
        jz .done
        cmp dword [edi+508h], 28h       ; ToBuild == RTTI_UNITTYPE: Hatchery, Lair, Hive, Infested CC
        je .done
        cmp byte [edi+81Bh], 0          ; IsRefinery: Extractor
        jne .done
        cmp dword [edi+528h], 0         ; Size != BSIZE_11: needs creep
        jne .refuse
        cmp byte [edi+809h], 0          ; 1x1 wall = Creep Tumor: needs creep; other 1x1 (burrowed Lurker): free
        je .done
        jmp .refuse
.creep: test edx, edx                   ; creep: Zerg only
        jnz .done
.refuse: xor eax, eax
.done:  pop edi
        pop esi
        ret 0Ch
orig:   mov eax, [7E4394h]              ; the overwritten first instruction
        jmp 452255h
