.cpu _65c02
#import "Libraries/constants.asm"
#import "Libraries/petscii.asm"
#import "Macros/macro.asm"

BasicUpstart2(Main)

Main:
    clc             // Set to 'place at position'
    ldx #15         // Start at row 15
    ldy #11         // Start at column 11
    jsr PLOT

    ldy #0          // initialize pointer

Looper:
    lda Message,y   // load character from message
    beq Exit        // if the character is zero, message has finished
    jsr CHROUT      // print the character to the screen
    iny             // increment pointer
    bra Looper      // loop

Exit:
    jmp *           // stop execution

.encoding "petscii_mixed"
Message:
    .text "commander x16 says hello world"
    .byte $00
