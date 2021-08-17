        /* Simple ADFS patcher (for putting in my IDE podule ROM), according to
         * fixes by sirbod at https://stardot.org.uk/forums/viewtopic.php?f=16&t=14016
         *
         * These seem to be:
         *  1. Reduce max request size from 255 to 1
         *  2. Increase timeout from 700 to 64K magic-time-units
         *
         * ADFS reverse engineering by sirbod, this module by Matt Evans
         * (c) Matt Evans 2021
         *
         * v0.1 17 Aug 2021
         */

        /* Tunables: */
#define VERBOSE         // Reassuring (but noisy) messages

        /* Defs: */
#define SWI_X           0x20000
#define SWI_OS_WRITEC   0x0
#define SWI_OS_WRITE0   0x2
#define SWI_OS_NEWLINE  0x3
#define SWI_OS_CLI      0x5
#define SWI_OS_MODULE   0x1e

        .text
        .org    0
        .globl _start
_start:
module_header:
        .long   0               // No run/start code
        .long   init
        .long   fini
        .long   0               // No service call
        .long   title_str
        .long   help_str
        .long   0               // No help/command keyword table
        .long   0               // No SWI Chunk number
        .long   0               // No SWI handler
        .long   0               // No SWI names
        .long   0               // No SWI decoder
        .long   0               // No messages
        .long   0               // No module flags


fini:
        movs    pc,r14

        /* Entry:
         *      r0 = environment/init parameters
         *      r11 = IO base/instantiation number
         *      r12 = private word
         *      r13 = SVC stack
         *      r14 = return
         *
         * Return:
         *      V clear on success
         *      V set, r0 = error block
         */
init:
        stmfd   r13!,{r0-r12,r14}

        /* Rough plan:
         *
         * - RMFaster ADFS (OS_Module 11)
         * - OS_Module 18 to look up name, get base
         * - Iterate through patch list, applying modifications
        */

        /* This is equivalent to RMFaster:
         * Do an OS_Module 18 to find the base, then OS_Module 11 to copy to RMA.
         * FIXME: If it's already in the RMA we could be fancy and skip it, but meh.
         */
        mov     r0, #18
        adr     r1, str_adfs
        swi     SWI_OS_MODULE | SWI_X
        bvs     fail_no_mod
        // r3 = module base (r3-4 len!)

        adr     r0, msg_found
        swi     SWI_OS_WRITE0 | SWI_X
        bvs     fail_err_return
        mov     r0, r3
        bl      print_hex32

        ldr     r4, [r3, #-4]           // r4 = module len

        // Now, re-insert into RMA:
        mov     r0, #11
        mov     r1, r3
        mov     r2, r4
        swi     SWI_OS_MODULE | SWI_X
        bvs     fail_cant_move

        // Finally, look up module again to get new (patchable) location in RAM:
        mov     r0, #18
        adr     r1, str_adfs
        swi     SWI_OS_MODULE | SWI_X
        bvs     fail_no_mod2

        adr     r0, msg_found_ram
        swi     SWI_OS_WRITE0 | SWI_X
        bvs     fail_err_return
        mov     r0, r3
        bl      print_hex32

        // Module address in r3

        // Iterate through patch list, applying:
        adr     r0, patches
        mov     r8, #0
        mov     r9, #0
1:
        ldmia   r0!, {r5,r6,r7}         // offset, expect, new
        cmp     r5, #-1
        beq     2f

        ldr     r1, [r3, r5]            // Load existing instr at offset
        cmp     r1, r6
        streq   r7, [r3, r5]            // If match, patch it!
        addeq   r8, r8, #1              // Count success
        addne   r9, r9, #1              // Count fail

        b       1b
2:
        // Done.  Pretty-print message...?
        adr     r0, msg_done
        swi     SWI_OS_WRITE0 | SWI_X
        bvs     fail_err_return

        mov     r0, r8
        bl      print_hex8slz
        bvs     fail_err_return

        adr     r0, msg_doneA
        swi     SWI_OS_WRITE0 | SWI_X
        bvs     fail_err_return

        mov     r0, r9
        bl      print_hex8slz
        bvs     fail_err_return

        adr     r0, msg_doneB
        swi     SWI_OS_WRITE0 | SWI_X
        bvs     fail_err_return

1:
        swi     SWI_OS_NEWLINE | SWI_X
        bvs     fail_err_return
        // Finished!

        ldmfd   r13!,{r0-r12,pc}^

fail_cant_move:
        adr     r0, error_cant_move
        b       fail_err_return
fail_no_mod:
        adr     r0, error_no_mod
        b       fail_err_return
fail_no_mod2:
        adr     r0, error_no_mod2
        // Fall through
fail_err_return:
        add     r13, r13, #4
        ldmfd   r13!,{r1-r12,lr}
        orr     pc, lr, #0x10000000

print_hex8:     // r0 = byte to print
        stmfd   r13!, {r1, lr}
        mov     r1, r0
        and     r0, r0, #0xf0
        mov     r0, r0, lsr#4
        cmp     r0, #9
        addgt   r0, r0, #'a'-10
        addle   r0, r0, #'0'
        swi     SWI_OS_WRITEC | SWI_X
        and     r0, r1, #0x0f
        cmp     r0, #9
        addgt   r0, r0, #'a'-10
        addle   r0, r0, #'0'
        swi     SWI_OS_WRITEC | SWI_X
        ldmfd   r13!, {r1, pc}^

        // Suppressing leading zero form:
print_hex8slz:     // r0 = byte to print
        stmfd   r13!, {r1, lr}
        mov     r1, r0
        and     r0, r0, #0xf0
        movs    r0, r0, lsr#4
        beq     1f
        cmp     r0, #9
        addgt   r0, r0, #'a'-10
        addle   r0, r0, #'0'
        swi     SWI_OS_WRITEC | SWI_X
1:      and     r0, r1, #0x0f
        cmp     r0, #9
        addgt   r0, r0, #'a'-10
        addle   r0, r0, #'0'
        swi     SWI_OS_WRITEC | SWI_X
        ldmfd   r13!, {r1, pc}^

print_hex32:    // r0 = word to print
        stmfd   r13!, {r10, lr}
        mov     r10, r0
        mov     r0, r10, lsr#24
        bl      print_hex8
        mov     r0, r10, lsr#16
        bl      print_hex8
        mov     r0, r10, lsr#8
        bl      print_hex8
        mov     r0, r10
        bl      print_hex8
        ldmfd   r13!, {r10, pc}^

        ////////////////////////////////////////////////////////////////

        // Format of patches is:
        // 3-word chunk, with offset, existing instruction, patched instruction
patches:
        // - Reduce max request length:
        .long   0x24ac          // At this address...
        mov     r9, #255        // ...turn this...
        mov     r9, #1          // ...into this.
        // - Bump up the jam^Wtimeout:
        .long   0x2560
        mov     r1, #700
        mov     r1, #65536
        // Fin:
        .long   0xffffffff, 0, 0

        ////////////////////////////////////////////////////////////////
        // Data

error_no_mod:
        .long   0xdeadbeef
        .asciz  "Can't find ADFS module"
        .align
error_no_mod2:
        .long   0xfacef00d
        .asciz  "Can't find ADFS module in RMA"
        .align
error_cant_move:
        .long   0xbeefcace
        .asciz  "Can't move ADFS module to RMA"
        .align

str_adfs:       .asciz "ADFS"
        .align
msg_found:      .asciz "ADFS patcher: RM at "
        .align
msg_found_ram:  .asciz ", moved to "
        .align
msg_done:       .asciz ". "
        .align
msg_doneA:      .asciz " patches OK, "
        .align
msg_doneB:      .asciz " failed."
        .align

title_str:      .asciz "ADFSPatcher"
help_str:       .asciz "ADFSPatcher	0.10 (17 Aug 2021)"
copyright:      .asciz "(c) 2021 Matt Evans"
        .align

        ////////////////////////////////////////////////////////////////

.end

