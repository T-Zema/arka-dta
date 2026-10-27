; Infantry deploy = change into a partner infantry type (TS 2.03 + DTA game.exe). Source of the cave written by
; Modding/tools/patch-infdeploy.ps1 (the script carries the assembled bytes; rebuild them with
;   pixi exec --spec nasm nasm -f bin -o patch-infdeploy.bin patch-infdeploy.asm
; and paste the hex into the script after a change). Wiki: mods/sc-infantry-stim, engine/transform-deploy.
;
; Rule (data-driven, no list in the patch): infantry type X deploys into the infantry type named X_D, and X_D deploys
; back into X. Types without such a partner are untouched. Deploy = the D key (DeployCommandClass -> EVENT_DEPLOY).
;   X -> X_D : costs 1/4 of X's max HP (refused at or below that), the rest keeps its ratio of the max HP; plays the
;              sound named like the new type (Sound.ini entry "X_D", e.g. SCMARI_D) if there is one; the stim ends by
;              itself after STIM_FRAMES game frames (InfantryClass::AI hook, timer in the padding at +0x36E)
;   X_D -> X : HP keeps its ratio of the max HP
; The infantry object stays the same (only its type pointer changes), so selection, control group, veterancy, the
; trigger tag, the position, the target and the AI team all survive; the house's type counters are moved with
; HouseClass::Tracking_Remove / Tracking_Add around the swap.
;
; v6 (2026-10-27): the diagnostics of v3-v5 ("INFDEP" log lines, D-key entry hook 0x4E9400) are gone, so the cave
; ends before 0x86C700, which patch-veins.ps1 (Zerg creep) uses.
; Hooks (see the .ps1 for the replaced bytes):
;   0x494C04  EventClass::Execute, EVENT_DEPLOY, before Assign_Mission(MISSION_UNLOAD): the swap
;   0x4E9482  DeployCommandClass::Execute: infantry with a partner skips Can_Deploy_Now (Vinifera replaces that
;             function at run time and refuses infantry without passengers)
;   0x632265  TechnoClass::Can_Deploy_Now, non-unit path (dead in game because of Vinifera; harmless)
;   0x4D4EB0  InfantryClass::AI entry: stim timer -> back to X
; Offsets (Game.pdb / Vinifera.pdb, 2026-10-27): obj+0x28 Strength, +0xEC House, InfantryClass+0x350 Class,
; +0x36E 2 bytes of padding (between WasSelected +0x36D and ProneStruggleTimer +0x370) = low 16 bits of the frame the
; stim ends; type+0x14 IniName[24], type+0x68 MaxStrength; vtable+0x2C Fetch_RTTI (RTTI_INFANTRY = 0x0F),
; +0x4C Center_Coord(&ret). Frame counter 0x7E4924 (15 frames = 1 game second, as trigger Elapsed Time).

bits 32
org 0x86C400

FROM_NAME       equ 0x4DA5E0    ; InfantryTypeClass::From_Name (fastcall ecx = name) -> index or -1
INF_TYPES_VEC   equ 0x7E4014    ; InfantryTypes.Vector (DynamicVectorClass<InfantryTypeClass*>)
TRACK_REMOVE    equ 0x4C2060    ; HouseClass::Tracking_Remove(TechnoClass*)  thiscall
TRACK_ADD       equ 0x4C2190    ; HouseClass::Tracking_Add(TechnoClass*)     thiscall
VOC_FROM_NAME   equ 0x665100    ; VocClass::From_Name (fastcall ecx = name) -> VocType or -1
STATIC_SOUND    equ 0x664D10    ; Static_Sound(VocType ecx, const Coord& edx)  fastcall
FRAME           equ 0x7E4924    ; game frame counter
STIM_FRAMES     equ 450         ; 30 game seconds (user 2026-10-27: "po 30 sekundach czasu gry")
STIM_TIMER      equ 0x36E       ; InfantryClass padding: low 16 bits of the end frame, 0 = not set
DEPLOY_EPILOG   equ 0x494C3D    ; EventClass::Execute: pop edi/esi/ebp/ebx, add esp,1A8h, ret
DEPLOY_CONT     equ 0x494C0D    ; after the 9 replaced bytes (mov edx,[esi] / push 0 / push 7E47D8h)
CANDEP_CONT     equ 0x63226A    ; after the 5 replaced bytes (mov edx,[ebp] / mov ecx,ebp)
DEPCMD_SEND     equ 0x4E9490    ; DeployCommandClass::Execute: build and queue EVENT_DEPLOY for this object
DEPCMD_TEST     equ 0x4E948C    ; after the 10 replaced bytes: test al,al / je skip
AI_CONT         equ 0x4D4EB6    ; InfantryClass::AI after sub esp,0Ch / push esi / mov esi,ecx

; ---------------------------------------------------------------- hook 1: EVENT_DEPLOY (esi = the TechnoClass)
deploy_hook:
        mov     ecx, esi
        call    find_partner            ; eax = partner type or 0, edx = 1 for X -> X_D
        test    eax, eax
        jz      .orig
        test    edx, edx
        jz      .down
        push    eax                     ; X -> X_D: the stim
        mov     ecx, [esi+0x350]
        mov     ecx, [ecx+0x68]         ; old max HP
        mov     edx, ecx
        shr     edx, 2                  ; cost = max/4
        mov     eax, [esi+0x28]
        cmp     eax, edx
        jle     .refuse
        sub     eax, edx
        mov     [esi+0x28], eax
        pop     eax
        call    swap_type
        mov     eax, [FRAME]
        add     eax, STIM_FRAMES
        test    ax, ax
        jnz     .timer
        inc     eax
.timer:
        mov     [esi+STIM_TIMER], ax
        call    play_type_sound
        jmp     DEPLOY_EPILOG
.down:                                  ; X_D -> X by hand
        mov     word [esi+STIM_TIMER], 0
        call    swap_type
        jmp     DEPLOY_EPILOG
.refuse:
        pop     eax
        jmp     DEPLOY_EPILOG
.orig:
        mov     edx, [esi]
        push    0
        push    0x7E47D8
        jmp     DEPLOY_CONT

; ---------------------------------------------------------------- hook 2: Can_Deploy_Now, non-unit path (ebp = this)
candeploy_hook:
        mov     ecx, ebp
        call    find_partner
        test    eax, eax
        jz      .orig
        pop     edi
        pop     esi
        pop     ebp
        pop     ebx
        mov     al, 1
        add     esp, 0x20
        ret
.orig:
        mov     edx, [ebp]
        mov     ecx, ebp
        jmp     CANDEP_CONT

; ---------------------------------------------------------------- hook 3: DeployCommandClass::Execute (edi = the TechnoClass)
deploycmd_hook:
        mov     ecx, edi
        call    find_partner
        test    eax, eax
        jnz     DEPCMD_SEND
        mov     eax, [edi]
        mov     ecx, edi
        call    [eax+0x2A0]             ; Can_Deploy_Now (Vinifera's)
        jmp     DEPCMD_TEST

; ---------------------------------------------------------------- hook 5: InfantryClass::AI entry (ecx = this)
; Every frame for every infantry: only types whose name ends in "_D" go further. Timer 0 (e.g. a map-placed or loaded
; X_D) starts a fresh 30 s; an expired timer swaps back to X.
ai_hook:
        pushad
        mov     esi, ecx
        mov     eax, [esi+0x350]
        test    eax, eax
        jz      .done
        lea     edi, [eax+0x14]
        xor     ecx, ecx
.len:
        cmp     byte [edi+ecx], 0
        je      .gotlen
        inc     ecx
        cmp     ecx, 24
        jb      .len
        jmp     .done
.gotlen:
        cmp     ecx, 2
        jb      .done
        cmp     word [edi+ecx-2], 0x445F    ; "_D"
        jne     .done
        mov     ax, [esi+STIM_TIMER]
        test    ax, ax
        jnz     .running
        mov     eax, [FRAME]
        add     eax, STIM_FRAMES
        test    ax, ax
        jnz     .set
        inc     eax
.set:
        mov     [esi+STIM_TIMER], ax
        jmp     .done
.running:
        mov     edx, [FRAME]
        sub     dx, ax                  ; frames past the end (16-bit, wraps)
        js      .done                   ; not yet
        mov     ecx, esi
        call    find_partner            ; X_D -> X
        test    eax, eax
        jz      .done
        mov     word [esi+STIM_TIMER], 0
        call    swap_type
.done:
        popad
        sub     esp, 0x0C
        push    esi
        mov     esi, ecx
        jmp     AI_CONT

; ---------------------------------------------------------------- swap_type(esi = infantry, eax = new type)
; HP keeps its ratio of the max HP (at least 1), then the type pointer changes between Tracking_Remove/Add.
; Keeps ebx/esi/edi/ebp.
swap_type:
        push    eax                     ; [esp] new type
        mov     ecx, [esi+0x350]
        mov     ecx, [ecx+0x68]         ; old max HP
        mov     eax, [esi+0x28]
        test    ecx, ecx
        jle     .hp_set
        mov     edx, [esp]
        imul    eax, dword [edx+0x68]
        cdq
        idiv    ecx
        cmp     eax, 1
        jge     .hp_set
        mov     eax, 1
.hp_set:
        mov     [esi+0x28], eax
        mov     ecx, [esi+0xEC]
        push    esi
        call    TRACK_REMOVE
        mov     eax, [esp]
        mov     [esi+0x350], eax
        mov     ecx, [esi+0xEC]
        push    esi
        call    TRACK_ADD
        add     esp, 4
        ret

; ---------------------------------------------------------------- play_type_sound(esi = infantry)
; Sound.ini entry with the name of the infantry's (new) type, at its position; nothing when there is none.
play_type_sound:
        mov     eax, [esi+0x350]
        lea     ecx, [eax+0x14]
        call    VOC_FROM_NAME
        cmp     eax, -1
        je      .none
        push    eax                     ; [esp+12] after the buffer: the sound
        sub     esp, 12                 ; Coord buffer
        push    esp                     ; hidden return pointer (= buffer)
        mov     ecx, esi
        mov     edx, [esi]
        call    [edx+0x4C]              ; Center_Coord(&buffer) -> eax = &buffer (callee pops the pointer)
        mov     edx, eax
        mov     ecx, [esp+12]
        call    STATIC_SOUND
        add     esp, 16
.none:
        ret

; ---------------------------------------------------------------- find_partner(ecx = TechnoClass*)
; returns eax = partner InfantryTypeClass* (0 = none), edx = 1 for X -> X_D, 0 for X_D -> X; keeps ebx/esi/edi/ebp
find_partner:
        push    esi
        push    edi
        push    ebx
        sub     esp, 0x20               ; name buffer
        mov     esi, ecx
        mov     eax, [esi]
        call    [eax+0x2C]              ; Fetch_RTTI (ecx = this)
        cmp     eax, 0x0F               ; RTTI_INFANTRY
        jne     .none
        mov     eax, [esi+0x350]
        test    eax, eax
        jz      .none
        lea     esi, [eax+0x14]         ; IniName
        mov     edi, esp
        xor     ecx, ecx
.copy:
        mov     al, [esi+ecx]
        mov     [edi+ecx], al
        test    al, al
        jz      .copied
        inc     ecx
        cmp     ecx, 24
        jb      .copy
        jmp     .none
.copied:                                ; ecx = length
        xor     ebx, ebx
        cmp     ecx, 2
        jb      .append
        cmp     word [edi+ecx-2], 0x445F    ; "_D"
        jne     .append
        mov     byte [edi+ecx-2], 0         ; X_D -> X
        jmp     .lookup
.append:
        cmp     ecx, 21
        ja      .none
        mov     word [edi+ecx], 0x445F      ; X -> X_D
        mov     byte [edi+ecx+2], 0
        mov     ebx, 1
.lookup:
        mov     ecx, edi
        call    FROM_NAME
        cmp     eax, -1
        je      .none
        mov     ecx, [INF_TYPES_VEC]
        mov     eax, [ecx+eax*4]
        mov     edx, ebx
        jmp     .out
.none:
        xor     eax, eax
        xor     edx, edx
.out:
        add     esp, 0x20
        pop     ebx
        pop     edi
        pop     esi
        ret
