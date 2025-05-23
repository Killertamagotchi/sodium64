/*
    Copyright 2021-2025 Hydr8gon

    This file is part of sodium64.

    sodium64 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published
    by the Free Software Foundation, either version 3 of the License,
    or (at your option) any later version.

    sodium64 is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with sodium64. If not, see <https://www.gnu.org/licenses/>.
*/

#include "macros.h"

.globl jit_tags
.globl jit_lookup
.globl jit_pointer

.globl jit_read8
.globl compile_block
.globl finish_opcode
.globl finish_block
.globl load_reg_x
.globl load_reg_y
.globl load_accum
.globl load_stack
.globl load_flags
.globl queue_nz
.globl update_nz
.globl emit_op
.globl emit_j
.globl emit_jal

.data

.align 4
jit_tags: .word 0:0x400
jit_lookup: .word 0:0x10000
jit_pointer: .word JIT_BUFFER

.align 4
jit_opcodes: // Lookup table for addressing and operation functions
    .word next_opcode, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0x00-0x03
    .word apu_dirr, apu_ora,  apu_absr, apu_ora,  apu_brxr, apu_ora,  apu_idxr, apu_ora // 0x04-0x07
    .word apu_imm, apu_ora,  apu_dr2, apu_orm,  apu_drb, apu_or1a,  apu_dirr, apu_aslm // 0x08-0x0B
    .word apu_absr, apu_aslm,  apu_php, 0,  apu_absr, apu_tset1,  apu_brk, 0 // 0x0C-0x0F
    .word apu_bpl, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0x10-0x13
    .word apu_drxr, apu_ora,  apu_abxr, apu_ora,  apu_abyr, apu_ora,  apu_idyr, apu_ora // 0x14-0x17
    .word apu_dri, apu_orm,  apu_bxy, apu_orm,  apu_dirr, apu_decw,  apu_drxr, apu_aslm // 0x18-0x1B
    .word apu_asla, 0,  apu_decx, 0,  apu_absr, apu_cmpx,  apu_abxr, apu_jmpm // 0x1C-0x1F
    .word apu_clrp, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0x20-0x23
    .word apu_dirr, apu_anda,  apu_absr, apu_anda,  apu_brxr, apu_anda,  apu_idxr, apu_anda // 0x24-0x27
    .word apu_imm, apu_anda,  apu_dr2, apu_andm,  apu_drb, apu_or1b,  apu_dirr, apu_rolm // 0x28-0x2B
    .word apu_absr, apu_rolm,  apu_pha, 0,  apu_dirr, apu_cbne,  apu_bra, 0 // 0x2C-0x2F
    .word apu_bmi, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0x30-0x33
    .word apu_drxr, apu_anda,  apu_abxr, apu_anda,  apu_abyr, apu_anda,  apu_idyr, apu_anda // 0x34-0x37
    .word apu_dri, apu_andm,  apu_bxy, apu_andm,  apu_dirr, apu_incw,  apu_drxr, apu_rolm // 0x38-0x3B
    .word apu_rola, 0,  apu_incx, 0,  apu_dirr, apu_cmpx,  apu_absa, apu_call // 0x3C-0x3F
    .word apu_setp, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0x40-0x43
    .word apu_dirr, apu_eora,  apu_absr, apu_eora,  apu_brxr, apu_eora,  apu_idxr, apu_eora // 0x44-0x47
    .word apu_imm, apu_eora,  apu_dr2, apu_eorm,  apu_drb, apu_and1a,  apu_dirr, apu_lsrm // 0x48-0x4B
    .word apu_absr, apu_lsrm,  apu_phx, 0,  apu_absr, apu_tclr1,  apu_pcall, 0 // 0x4C-0x4F
    .word apu_bvc, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0x50-0x53
    .word apu_drxr, apu_eora,  apu_abxr, apu_eora,  apu_abyr, apu_eora,  apu_idyr, apu_eora // 0x54-0x57
    .word apu_dri, apu_eorm,  apu_bxy, apu_eorm,  apu_dirr, apu_cmpw,  apu_drxr, apu_lsrm // 0x58-0x5B
    .word apu_lsra, 0,  apu_movxa, 0,  apu_absr, apu_cmpy,  apu_absa, apu_jmp // 0x5C-0x5F
    .word apu_clrc, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0x60-0x63
    .word apu_dirr, apu_cmpa,  apu_absr, apu_cmpa,  apu_brxr, apu_cmpa,  apu_idxr, apu_cmpa // 0x64-0x67
    .word apu_imm, apu_cmpa,  apu_dr2, apu_cmpm,  apu_drb, apu_and1b,  apu_dirr, apu_rorm // 0x68-0x6B
    .word apu_absr, apu_rorm,  apu_phy, 0,  apu_dirr, apu_dbnzm,  apu_ret, 0 // 0x6C-0x6F
    .word apu_bvs, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0x70-0x73
    .word apu_drxr, apu_cmpa,  apu_abxr, apu_cmpa,  apu_abyr, apu_cmpa,  apu_idyr, apu_cmpa // 0x74-0x77
    .word apu_dri, apu_cmpm,  apu_bxy, apu_cmpm,  apu_dirr, apu_addw,  apu_drxr, apu_rorm // 0x78-0x7B
    .word apu_rora, 0,  apu_movax, 0,  apu_dirr, apu_cmpy,  apu_ret1, 0 // 0x7C-0x7F
    .word apu_setc, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0x80-0x83
    .word apu_dirr, apu_adca,  apu_absr, apu_adca,  apu_brxr, apu_adca,  apu_idxr, apu_adca // 0x84-0x87
    .word apu_imm, apu_adca,  apu_dr2, apu_adcm,  apu_drb, apu_eor1,  apu_dirr, apu_decm // 0x88-0x8B
    .word apu_absr, apu_decm,  apu_imm, apu_movy,  apu_ppp, 0,  apu_dri, apu_movm // 0x8C-0x8F
    .word apu_bcc, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0x90-0x93
    .word apu_drxr, apu_adca,  apu_abxr, apu_adca,  apu_abyr, apu_adca,  apu_idyr, apu_adca // 0x94-0x97
    .word apu_dri, apu_adcm,  apu_bxy, apu_adcm,  apu_dirr, apu_subw,  apu_drxr, apu_decm // 0x98-0x9B
    .word apu_deca, 0,  apu_movxs, 0,  apu_div, 0,  apu_xcn, 0 // 0x9C-0x9F
    .word apu_ei, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0xA0-0xA3
    .word apu_dirr, apu_sbca,  apu_absr, apu_sbca,  apu_brxr, apu_sbca,  apu_idxr, apu_sbca // 0xA4-0xA7
    .word apu_imm, apu_sbca,  apu_dr2, apu_sbcm,  apu_drb, apu_mov1b,  apu_dirr, apu_incm // 0xA8-0xAB
    .word apu_absr, apu_incm,  apu_imm, apu_cmpy,  apu_ppa, 0,  apu_bxpa, apu_amov // 0xAC-0xAF
    .word apu_bcs, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0xB0-0xB3
    .word apu_drxr, apu_sbca,  apu_abxr, apu_sbca,  apu_abyr, apu_sbca,  apu_idyr, apu_sbca // 0xB4-0xB7
    .word apu_dri, apu_sbcm,  apu_bxy, apu_sbcm,  apu_dirr, apu_movwya,  apu_drxr, apu_incm // 0xB8-0xBB
    .word apu_inca, 0,  apu_movsx, 0,  apu_unk, 0,  apu_bxpr, apu_mova // 0xBC-0xBF
    .word apu_di, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0xC0-0xC3
    .word apu_dira, apu_amov,  apu_absa, apu_amov,  apu_brxa, apu_amov,  apu_idxa, apu_amov // 0xC4-0xC7
    .word apu_imm, apu_cmpx,  apu_absa, apu_xmov,  apu_drb, apu_mov1a,  apu_dira, apu_ymov // 0xC8-0xCB
    .word apu_absa, apu_ymov,  apu_imm, apu_movx,  apu_ppx, 0,  apu_mul, 0 // 0xCC-0xCF
    .word apu_bne, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0xD0-0xD3
    .word apu_drxa, apu_amov,  apu_abxa, apu_amov,  apu_abya, apu_amov,  apu_idya, apu_amov // 0xD4-0xD7
    .word apu_dira, apu_xmov,  apu_drya, apu_xmov,  apu_dira, apu_movway,  apu_drxa, apu_ymov // 0xD8-0xDB
    .word apu_decy, 0,  apu_movay, 0,  apu_drxr, apu_cbne,  apu_unk, 0 // 0xDC-0xDF
    .word apu_clrv, 0,  apu_tcall1, 0,  apu_dirr, apu_set1,  apu_dirr, apu_bbs1 // 0xE0-0xE3
    .word apu_dirr, apu_mova,  apu_absr, apu_mova,  apu_brxr, apu_mova,  apu_idxr, apu_mova // 0xE4-0xE7
    .word apu_imm, apu_mova,  apu_absr, apu_movx,  apu_drb, apu_not1,  apu_dirr, apu_movy // 0xE8-0xEB
    .word apu_absr, apu_movy,  apu_notc, 0,  apu_ppy, 0,  apu_unk, 0 // 0xEC-0xEF
    .word apu_beq, 0,  apu_tcall1, 0,  apu_dirr, apu_clr1,  apu_dirr, apu_bbc1 // 0xF0-0xF3
    .word apu_drxr, apu_mova,  apu_abxr, apu_mova,  apu_abyr, apu_mova,  apu_idyr, apu_mova // 0xF4-0xF7
    .word apu_dirr, apu_movx,  apu_dryr, apu_movx,  apu_dr2, apu_movm,  apu_drxr, apu_movy // 0xF8-0xFB
    .word apu_incy, 0,  apu_movya, 0,  apu_dbnzy, 0,  apu_unk, 0 // 0xFC-0xFF

.text
.set noreorder

.align 5
jit_read8: // a0: address - v0: value
    // Read a byte from memory, count cycles, and increment the address
    lbu v0, apu_clock
    srl t0, a0, 6
    lbu t1, apu_map(t0)
    sub s2, s2, v0
    add t0, a0, t1
    lbu v0, apu_ram(t0)
    jr ra
    addi a0, a0, 1

.align 5
compile_block:
    // Round the JIT pointer to nearest cache line, offset by header size
    lw t0, jit_pointer
    addi t0, t0, 0x1F + 12
    andi t1, t0, 0x1F
    sub a1, t0, t1 // Pointer
    addi t0, a1, -12
    sw t0, jit_pointer

    // Initialize values for tracking JIT block state
    move s1, zero // Status
    move s2, zero // Cycles
    move a0, s0 // PC
    addi t9, a0, BLOCK_SIZE // Limit

    // Check JIT bounds and invalidate data cache for the header
    li a2, ROM_BUFFER // Bounds
    bgeu a1, a2, reset_buffer
    srl t1, a0, 6
    cache 0x11, CACHED(0)(t0)

    // Set the start memory block and tag in the JIT header
    sll t1, t1, 2
    sh t1, 0(t0)
    lw t1, jit_tags(t1)
    sw t1, 4(t0)

next_opcode:
    // Read an opcode from memory and jump to its functions
    jal jit_read8
    nop
    sll v1, v0, 3
    lw t1, jit_opcodes + 0(v1)
    lw gp, jit_opcodes + 4(v1)
    jr t1
    nop

.align 5
finish_opcode:
    // Compile another opcode if the limit hasn't been reached
    blt a0, t9, next_opcode
    nop

finish_block:
    // Update NZ flags at the end of a block
    jal update_nz
    nop

    // Emit code to store register X if enabled
    andi t0, s1, FLAG_SX
    beqz t0, skip_sx
    li t3, SB(T9, 0, 0)
    la t4, apu_reg_x
    jal full_address
    nop

skip_sx:
    // Emit code to store register Y if enabled
    andi t0, s1, FLAG_SY
    beqz t0, skip_sy
    li t3, SB(T8, 0, 0)
    la t4, apu_reg_y
    jal full_address
    nop

skip_sy:
    // Emit code to store the accumulator if enabled
    andi t0, s1, FLAG_SA
    beqz t0, skip_sa
    li t3, SB(T7, 0, 0)
    la t4, apu_accum
    jal full_address
    nop

skip_sa:
    // Emit code to store the stack pointer if enabled
    andi t0, s1, FLAG_SS
    beqz t0, skip_ss
    li t3, SB(S2, 0, 0)
    la t4, apu_stack
    jal full_address
    nop

skip_ss:
    // Emit code to store the flags if enabled
    andi t0, s1, FLAG_SF
    beqz t0, skip_sf
    li t3, SB(S1, 0, 0)
    la t4, apu_flags
    jal full_address
    nop

skip_sf:
    // Emit code to load the program counter value unless disabled
    andi t0, s1, FLAG_PC
    bnez t0, skip_pc
    li t0, ORI(S0, ZERO, 0)
    jal emit_op
    or t0, t0, a0

skip_pc:
    // Emit code to store the program counter
    la t4, apu_count
    jal full_address
    li t3, SH(S0, 0, 0)

    // Emit code to adjust APU cycle count and return to the main loop
    la t0, cpu_execute
    jal emit_j
    andi s2, s2, 0xFFFF
    li t0, ADDI(S3, S3, 0)
    jal emit_op
    or t0, t0, s2

    // Update the JIT pointer and use its old value for block lookup
    lw t0, jit_pointer
    sw a1, jit_pointer
    sll t1, s0, 2
    lui t2, 0x2000
    sub t2, t0, t2 // Cached
    sw t2, jit_lookup(t1)

    // Set the end memory block and tag in the JIT header
    srl t1, a0, 6
    sll t1, t1, 2
    sh t1, 2(t0)
    lw t1, jit_tags(t1)

    // Jump to the finished JIT block's code
    addi t2, t2, 12
    jr t2
    sw t1, 8(t0)

.align 5
reset_buffer:
    // Clear all block lookup pointers
    la t0, jit_lookup
    la t1, jit_pointer
reset_loop:
    addi t0, t0, 4
    bne t0, t1, reset_loop
    sw zero, -4(t0)

    // Reset the JIT pointer and restart compilation
    li t0, JIT_BUFFER
    sw t0, jit_pointer
    j compile_block
    nop

.align 5
apu_unk:
    // Emit code to loop infinitely for unimplemented opcodes
    ori s1, s1, FLAG_PC
    li t0, ORI(S0, ZERO, 0)
    addi t2, a0, -1
    andi t2, t2, 0xFFFF
    la ra, finish_block
    j emit_op
    or t0, t0, t2

.align 5
full_address: // t3: opcode, t4: address
    // Adjust the address for signed offsets
    andi t0, t4, 0x8000
    sll t0, t0, 1
    add t4, t4, t0

    // Emit code for accessing a 32-bit memory address
    move t6, ra
    li t0, LUI(AT_, 0)
    srl t1, t4, 16
    jal emit_op
    or t0, t0, t1
    move t0, t3
    li t1, AT_ << 21
    andi t2, t4, 0xFFFF
    or t0, t1, t2
    move ra, t6
    j emit_op
    or t0, t0, t3

.align 5
load_reg_x:
    // Check if register X has already been loaded
    andi t0, s1, FLAG_LX
    beqz t0, do_lx
    ori s1, s1, FLAG_LX
    jr ra

do_lx:
    // Emit code to load register X if needed
    li t3, LBU(T9, 0, 0)
    la t4, apu_reg_x
    j full_address
    nop

.align 5
load_reg_y:
    // Check if register Y has already been loaded
    andi t0, s1, FLAG_LY
    beqz t0, do_ly
    ori s1, s1, FLAG_LY
    jr ra

do_ly:
    // Emit code to load register Y if needed
    li t3, LBU(T8, 0, 0)
    la t4, apu_reg_y
    j full_address
    nop

.align 5
load_accum:
    // Check if the accumulator has already been loaded
    andi t0, s1, FLAG_LA
    beqz t0, do_la
    ori s1, s1, FLAG_LA
    jr ra

do_la:
    // Emit code to load the accumulator if needed
    li t3, LBU(T7, 0, 0)
    la t4, apu_accum
    j full_address
    nop

.align 5
load_stack:
    // Check if the stack pointer has already been loaded
    andi t0, s1, FLAG_LS
    beqz t0, do_ls
    ori s1, s1, FLAG_LS
    jr ra

do_ls:
    // Emit code to load the stack pointer if needed
    li t3, LBU(S2, 0, 0)
    la t4, apu_stack
    j full_address
    nop

.align 5
load_flags:
    // Check if the flags have already been loaded
    andi t0, s1, FLAG_LF
    beqz t0, do_lf
    ori s1, s1, FLAG_LF
    jr ra

do_lf:
    // Emit code to load the flags if needed
    li t3, LBU(S1, 0, 0)
    la t4, apu_flags
    j full_address
    nop

.align 5
queue_nz: // t1: value
    // Emit code to save a value for setting NZ flags later
    ori s1, s1, FLAG_NZ
    li t0, ANDI(A2, 0, 0xFF)
    sll t1, t1, 21
    j emit_op
    or t0, t0, t1

.align 5
update_nz:
    // Check if a value is queued for setting NZ flags
    andi t0, s1, FLAG_NZ
    bnez t0, do_nz
    move t7, ra
    jr ra
    nop

do_nz:
    // Emit code to update NZ flags if needed
    xori s1, s1, FLAG_NZ
    jal load_flags
    ori s1, s1, FLAG_SF
    EMIT_OP ANDI(S1, S1, 0x7D)
    EMIT_OP SLT(T6, ZERO, A2)
    EMIT_OP XORI(T6, T6, 0x1)
    EMIT_OP SLL(T6, T6, 1)
    EMIT_OP OR(S1, S1, T6)
    EMIT_OP ANDI(T6, A2, 0x80)
    li t0, OR(S1, S1, T6)
    j emit_op
    move ra, t7

.align 5
emit_op: // t0: opcode
    // Write to the JIT buffer, invalidate caches, and reset on overflow
    sw t0, (a1)
    cache 0x10, CACHED(0)(a1)
    cache 0x11, CACHED(0)(a1)
    addi a1, a1, 4
    beq a1, a2, reset_buffer
    nop
    jr ra
    nop

.align 5
emit_j: // t0: target
    // Emit a "j" opcode for the JIT
    srl t0, t0, 2
    li t1, 0x3FFFFFF
    and t0, t0, t1
    lui t1, 0x0800
    j emit_op
    or t0, t0, t1

.align 5
emit_jal: // t0: target
    // Emit a "jal" opcode for the JIT
    srl t0, t0, 2
    li t1, 0x3FFFFFF
    and t0, t0, t1
    lui t1, 0x0C00
    j emit_op
    or t0, t0, t1
