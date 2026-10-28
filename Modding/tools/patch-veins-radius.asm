; patch-veins.ps1 site 14 (nasm -f bin): the creep radius of a mission (user 2026-10-28, ARKA 5: "creep rosnie na 30 pola
; od overlordow"). Called from site 9 (Grow, patch-veins-growth.asm) and site 12 (Build_Growth_Queue flood,
; patch-veins-shrink.asm) in place of "add eax,edx / cmp eax,72": eax = dx*dx, edx = dy*dy, esi = the monster; returns the
; flags of "cmp dx*dx + dy*dy, limit" for the caller's jg. edx is clobbered (free at both callers).
; The limit is 72 (~8.5 cells), except for a monster made during the game ('ZC': a Creep Tumor, an Overlord's spit) when
; [General] VeinholeMonsterStrength (Rules +0B8h) is 1-100: then that many cells (limit = value squared). The key is read
; by RulesClass::General but used nowhere since TS 2.0 (Rules.ini: "no longer used"), default 10000, so a mission sets
; it in its [General] and every other map keeps 72. Holes under Zerg buildings ('ZG') and from map files keep 72.
bits 32
org 0x86C7E0

limit:  add eax, edx
        cmp word [esi+9Eh], 'ZC'
        jne .small
        mov edx, [74C488h]              ; Rule
        mov edx, [edx+0B8h]             ; VeinholeMonsterStrength
        dec edx
        cmp edx, 99
        ja .small                       ; not 1-100
        inc edx
        imul edx, edx
        cmp eax, edx
        ret
.small: cmp eax, 72
        ret
