; k_tid_addr_of(): Find the address of a tid in the thread table
;
; Purpose:
;   The tid specifies an index into the thread table. The purpose of this
;   function is to take a tid and turn it into an address.
;
; Usage:
;   1) put the desired tid into a
;   2) call "k_tid_addr_of"
;   3) the address is in de
;
; Explanation:
;   The value a is the thread index id. This is loaded into hl and then
;   multiplied by 16 to calculate the table offset. This is then added to the
;   table base address.
;
; Registers used:
;
;   a:  the current tid
;   hl: temporary for multiplication
;   de: address of tid entry in memory
;
k_tid_addr_of:
    ld de, k_tid_tab_base   ; put base address in de
    ld h, 0x00              ; zero h
    ld l, a                 ; copy current tid to l
    add hl, hl              ; x2
    add hl, hl              ; x4
    add hl, hl              ; x8
    add hl, hl              ; x16
    add hl, de              ; base address to calculated offset
    ex de, hl               ; exchange so de has the address
    ret

; k_tids_addr_of(): Find the address of a tid in the thread status table
;
; Purpose:
;   The tid specifies an index into the thread status table. The purpose of
;   this function is to take a tid and turn it into an address.
;
; Usage:
;   1) put the desired tid into a
;   2) call "k_tids_addr_of"
;   3) the address is in de
;
; Explanation:
;   The value at (k_tid_curr) holds the current thread id. This is added to
;   k_tids_tab_base to find the address of the status byte in the thread status
;   table.
;
; Registers used:
;
;   a:  the current tid
;   hl: temporary for addition
;   de: address of tid entry in memory
;
k_tids_addr_of:
    ld hl, k_tids_tab_base  ; put base address in hl
    ld d, 0x00              ; zero d
    ld e, a                 ; copy it to e
    add hl, de              ; add de to hl
    ex de, hl               ; put value into de and free up hl
    ret

; k_tid_find_status(): Find the next tid entry after tid with a given status
;
; Purpose:
;   The thread table can be fragmented, with empty spaces between valid threads
;   (paused or running). This function is to find the next entry after the
;   current tid that has a certain status. If the current tid is greater than
;   zero and no free threads are found after that tid, the code wraps back
;   around and searches from the start of the thread table back up to tid. If
;   we always search from the beginning early threads would hog the CPU.
;
; Usage:
;   1) put the desired status into c
;   2) call "k_tid_find_status"
;   3) if l != 0 then de == address of tid and l == the new tid
;   4) if l == 0 then no thread of that status was found (tid 0 is reserved)
;
; Explanation:
;   First k_tids_addr_of() is called to set hl to the address of the thread table
;   entry. Then de is reset to the entry size. Then a loop of k_tid_max is
;   started to scan all possible table entries. Each loop adds de to ix to move
;   to the next entry. Unless tid is zero this loop would extend beyond the
;   table. So the tid is subtracted from k_tid_max to give the point where
;   we reset ix to the beginning of the table and reset l to 0. This means we
;   will scan up from the current tid looking for the next free entry, and when
;   we get to the top it will cycle back to the beginning of the table. Because
;   b is controlling the loop we will stop before getting back to the current
;   tid.
;
; Registers used:
;
;   a:  misc
;   b:  loop variable for the thread table
;   l:  The return tid
;   h:  number of entries from current tid until end of table
;   de: address of tid entry in memory
;
k_tid_find_status:
    ld a, (k_tid_curr)      ; load current tid into a
    call k_tids_addr_of     ; calculate the address of the current tid in the table
    ld l, a                 ; copy current tid to l
    ld a, k_tid_max         ; calculate the diff betwen tid and the max table entry
    sub l                   ; a now contains k_tid_max - tid (nr of loops before resetting k_tids_tab_base)
    ld h, a                 ; free up a, h becomes loops until a reset of ix needed
    ld b, k_tid_max         ; prepare to loop around k_tid_max times
k_tid_next_id:
    inc de                  ; shift de to next item
    inc l                   ; increment the new tid stored in l
    dec h                   ; decrement h
    jp nz, k_tid_no_reset   ; if h is not zero skip resetting ix
    ld de, k_tids_tab_base  ; cycle ix back to beginning of table
    ld l, 0x00              ; cycle new tid back around
k_tid_no_reset:
    ld a, (de)              ; load status byte into a
    sub c                   ; subtract the wanted status
    jp z, k_tid_found       ; if zero we found an entry
    djnz k_tid_next_id      ; keep looking b number of times
    ld l, 0x00              ; not found
k_tid_found:
    ret

; k_tid_next_free(): Find the next empty thread table entry
;
; Purpose:
;   Finds the tid and address of the next empty thread.
;
; Usage:
;   1) call "k_tid_next_free"
;   2) if c != 0 then ix == address of tid and c == next runnable tid
;   3) if c == 0 then no runnable threads were found (tid 0 is reserved)
;
k_tid_next_free:
    ld c, k_t_unused        ; looking for status zero meaning free
    jp k_tid_find_status    ; use status search routine

; k_tid_next_run(): Find the next runnable thread
;
; Purpose:
;   Finds the tid and address of the next runnable thread.
;
; Usage:
;   1) call "k_tid_next_run"
;   2) if c != 0 then ix == address of tid and c == next runnable tid
;   3) if c == 0 then no runnable threads were found (tid 0 is reserved)
;
k_tid_next_run:
    ld c, k_t_running       ; look for running status
    jp k_tid_find_status    ; use status search routine

; k_tid_set_status(): Set the status of a given tid
;
; Purpose:
;   Set the status of a given tid in the thread status table.
;
; Usage:
;   1) put the desired tid into a
;   2) put the desired status into c
;   3) call "k_tid_set_status"
;
k_tid_set_status:
    call k_tids_addr_of     ; calculate the address of the current tid in the table
    ld a, (de)              ; load the current status into a
    and 11111000b           ; zero out the lower 3 bits of current status
    or c                    ; apply the lower 3 bits to a
    ld (de), a              ; save the status back
    ret

