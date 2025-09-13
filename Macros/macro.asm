// macro files
.cpu _65c02
#importonce
#import "../Libraries/constants.asm"

//veraAddr: .byte 0,0,0,0

.macro setAddrSel(dataPort)
{
    // Inputs : DataPort, this is the VERA Dataport to use, either 0 or 1

    pha             // Preserve the Accumulator
    lda VERACTRL    // load the CTRL Register
    and #%11111110  // Preserver the Bits we dont want to Change
    ora #dataPort   // Apply the Data Port Bit
    sta VERACTRL    // Store back
    pla
}

.macro addressRegisterByValue(dataPort,address,increment,direction) 
{
    // Inputs:
    //          dataPort : Which Vera DataPort do you want to use
    //          address  : The VERA Memory Address to read from or write to
    //          increment: This tells VERA what the increment is
    //          direction: This tells VERA which Direction the incrementor
    //                      should go in, increasing or decreasing

    setAddrSel(dataPort)

	lda #address        // lets the low byte of the address
	sta VERAAddrLow

	lda #address >> 8   // shifts 8 bits to the right, to get the next 8 bits
	sta VERAAddrHigh
	
	lda #(increment << 4 ) | direction << 3 | address >> 16 
	sta VERAAddrBank
}

.macro addressRegisterByAddr(dataPort,bit16,addrAddress,increment,direction)
{
    // Inputs:
    //          dataPort : Which Vera DataPort do you want to use
    //          bit16    : Tells which 64K bank to use
    //          addrAddress : The memory address on the CX16 that holds
    //                      The vera memory address
    //          increment: This tells VERA what the increment is
    //          direction: This tells VERA which Direction the incrementor
    //                      should go in, increasing or decreasing
    
    setAddrSel(dataPort)

	lda addrAddress     // gets the low byte of the address
	sta VERAAddrLow

	lda addrAddress + 1 // gets the hi byte of the address
	sta VERAAddrHigh
	
	lda #(increment << 4 ) | bit16 | direction << 3
	sta VERAAddrBank
}

.macro break()
{
    // This will create a break in the Commander X16 Emulator
    .byte $db
}

.macro skip1Byte()
{  // 2 byte nop 65c02
    .byte $24  // $42 etc dont work in emulator
}

.macro skip2Bytes()
{  // 3 byte nop 65c02
    .byte  $2c  // $dc and $fc dont work in emulator
}

.macro resetVera()
{
    // Resets the VERA CHIP back to Defaults
    lda #$80
    sta VERACTRL
}

.macro backupVeraAddrInfo()
{
    // Back Up the Important VERA Registers to the Stack
    
    lda VERAAddrLow
    pha
    lda VERAAddrHigh
    pha
    lda VERAAddrBank
    pha
    lda VERACTRL
    pha
}

.macro restoreVeraAddrInfo()
{
    // Restore the Important VERA Registers from the Stack

    pla
    sta VERACTRL
    pla
    sta VERAAddrBank
    pla
    sta VERAAddrHigh
    pla
    sta VERAAddrLow
}

.macro backupVERAForIRQ()
{
    // Back Up the Important VERA Registers to the Stack For IRQ
    backupVeraAddrInfo()
    eor #%00000001
    sta VERACTRL
    backupVeraAddrInfo()
}

.macro restoreVERAForIRQ()
{
    // Restore the Important VERA Registers from the Stack For IRQ
    restoreVeraAddrInfo()
    restoreVeraAddrInfo()
}

.macro setDCSel(dcSel)
{
    // Set the DC_VIDEO Bank Selector
    pha             // Store away the Accumulator
    lda VERACTRL    // Load CTRL From VERA
    and #%10000001  // Retain other information, clear out DCSEL portion
    ora #dcSel<<1   // Apply the DCSelector
    sta VERACTRL    // Store back to VERA CTRL
    pla             // Restore Accumulator
}

.macro copyVERASinglePageData(source, destination, bytecount)
{
    // source greater than dest - regular copy
    .if (source > destination) {
        addressRegisterByValue(0,source,1,0)
        addressRegisterByValue(1,destination,1,0)
    }
    else
    {
        // source below dest - do backwards starting at end
        addressRegisterByValue(0,source + bytecount,1,1)
        addressRegisterByValue(1,destination + bytecount,1,1)
    }
    ldy #bytecount          // Initialise the number of bytes to copy
copyloop:
    lda VERADATA0           // Load Source Values
 	sta VERADATA1           // Store Destination Values
 	dey                     // decrease byte count by 1
 	bpl copyloop            // do we still have bytes to copy
}

.macro copyDataToVera(source,destination,bytecount) 
{
    // Inputs:
    //          source      : x16 memory address
    //          destination : is vera memory location
    //          bytecount   : max 65535 
    //
    // Accumulator is destroyed
    addressRegisterByValue(0,destination,1,0)   // Set VERA Memory
                                                // Destination Address
    lda counter: $deaf              // Byte Counter
    lda #bytecount & $ff            // Get Lo ByteCounter
    sta counter
    lda #(bytecount >> 8) & $ff     // Get Hi Byte Counter
    sta counter+1
    lda #source & $ff               // Get Low Byte Source Address
    sta copyFrom
    lda #(source >>8) & $ff         // Get Hi Byte Source Address
    sta copyFrom + 1

loop:
    lda copyFrom: $deaf             // Load CX 16 Memory Location
    sta VERADATA0                   // Store in VERA
    inc copyFrom                    // increase address location by 1
    bne skip1                       // Crossed page boundary
    inc copyFrom+1                  // Yes, increase hi byte by 1
skip1:
    dec counter                     // Decrease Counter by one
    bne loop                        // Crossed page boundary
    dec counter+1                   // Yes, decrease Counter hi Byte by 1
    bpl loop
}

.macro fillVeraMemory(destination,value,step,bytecount) 
{
    // Inputs:
    //          destination : is vera memory location
    //          value       : the value to fill memory
    //          step        : the increment value for VERA
    //          bytecount   : max 65535 
    //
    // Accumulator is destroyed
    addressRegisterByValue(0,destination,step,0)   // Set VERA Memory
                                                // Destination Address
    lda counter: $deaf              // Byte Counter
    lda #bytecount & $ff            // Get Lo ByteCounter
    sta counter
    lda #(bytecount >> 8) & $ff     // Get Hi Byte Counter
    sta counter+1

loop:
    lda #value                      // Load value
    sta VERADATA0                   // Store in VERA

    dec counter                     // Decrease Counter by one
    bne loop                        // Crossed page boundary
    dec counter+1                   // Yes, decrease Counter hi Byte by 1
    bpl loop
}

.macro setToSpriteBase(SpriteNumber, Offset, Advance)
{
    // Inputs:
    //          SpriteNumber: is the Sprite To be affected
    //          Offset      : the offset from the base sprite address
    //          Advance     : the increment value for VERA
    //
    // Accumulator is destroyed

    // Set the Vera Memory Address to the Sprite Number required
    lda #<(SpriteNumber<<3)
	sta VERAAddrLow

    lda #>(SpriteNumber<<3)
    clc
    adc #>(SPRITEREGBASE-$10000)
	sta VERAAddrHigh

    // if offset it not zero, alter vera address
    .if (Offset != 0)
    {
        clc
        lda VERAAddrLow
        adc #Offset
        sta VERAAddrLow
        lda VERAAddrHigh
        adc #0
        sta VERAAddrHigh
    }

    // Set the Incremental Stepper Value
	lda #(Advance << 4) | %0001
	sta VERAAddrBank    
}

.macro setToSpriteBaseByAddr(addrSpriteNumber, Offset, Advance)
{
    // Inputs:
    //          addrSpriteNumber: is the address that contains the Sprite To be affected
    //          Offset      : the offset from the base sprite address
    //          Advance     : the increment value for VERA
    //
    // Accumulator is destroyed

    // clear out High Byte
    stz VERAAddrHigh

    lda addrSpriteNumber            // load Sprite Number
    asl                             // x 2
    rol VERAAddrHigh
    asl                             // x 4
    rol VERAAddrHigh
    asl                             // x 8
    rol VERAAddrHigh
	sta VERAAddrLow                 // Store Lo Byte

    lda VERAAddrHigh
    clc
    adc #>(SPRITEREGBASE-$10000)
	sta VERAAddrHigh                // add Sprite Base Address
    
    // if offset it not zero, alter vera address
    .if (Offset != 0)
    {
        clc
        lda VERAAddrLow
        adc #Offset
        sta VERAAddrLow
        lda VERAAddrHigh
        adc #0
        sta VERAAddrHigh
    }

    // Set the Incremental Stepper Value
	lda #(Advance << 4) | %0001
	sta VERAAddrBank    
}

.macro setUpSpriteInVera(SpriteNumber, SpriteAddress, Mode, XPos, YPos, ZDepth, Height, Width, PalletOffset)
{
    // Inputs:
    //          SpriteNumber    : Sprite to be configured
    //          SpriteAddress   : Sprite Frame Address
    //          Mode            : Colour type of sprite
    //          XPos            : Initial X Position
    //          YPos            : Initial Y Position
    //          ZDepth          : Layer the Sprite will appear
    //          Height          : Hight of the Sprite
    //          Width           : Width of the Sprite
    //          PalletOffset    : Pallette to be used

    // using DATA0
    setAddrSel(0)

    setToSpriteBase(SpriteNumber, 0, 1)

    lda #<(SpriteAddress>>5)
    sta VERADATA0
    lda #>(SpriteAddress>>5) | Mode
    sta VERADATA0

    lda #<XPos
    sta VERADATA0
    lda #>XPos
    sta VERADATA0

    lda #<YPos
    sta VERADATA0
    lda #>YPos
    sta VERADATA0

    lda #ZDepth
    sta VERADATA0

    lda #Height | Width | PalletOffset
    sta VERADATA0

}

.macro setUpSpriteInVeraWithCol(SpriteNumber, SpriteAddress, Mode, XPos, YPos, ZDepth, Height, Width, PalletOffset, ColMask)
{
    // Inputs:
    //          SpriteNumber    : Sprite to be configured
    //          SpriteAddress   : Sprite Frame Address
    //          Mode            : Colour type of sprite
    //          XPos            : Initial X Position
    //          YPos            : Initial Y Position
    //          ZDepth          : Layer the Sprite will appear
    //          Height          : Hight of the Sprite
    //          Width           : Width of the Sprite
    //          PalletOffset    : Pallette to be used
    //          ColMask         : Collision mask used for this sprite

    // using DATA0
    setAddrSel(0)

    setToSpriteBase(SpriteNumber, 0, 1)

    lda #<(SpriteAddress>>5)
    sta VERADATA0
    lda #>(SpriteAddress>>5) | Mode
    sta VERADATA0

    lda #<XPos
    sta VERADATA0
    lda #>XPos
    sta VERADATA0

    lda #<YPos
    sta VERADATA0
    lda #>YPos
    sta VERADATA0

    lda #ZDepth | (ColMask << 4)
    sta VERADATA0

    lda #Height | Width | PalletOffset
    sta VERADATA0

}

.macro disableSpriteInVera(addrSpriteNumber)
{
    // Inputs:
    //          SpriteNumber    : Sprite to be disabled

    // using DATA0
    setAddrSel(0)

    setToSpriteBaseByAddr(addrSpriteNumber, 0, 1)

    stz VERADATA0
    stz VERADATA0
    stz VERADATA0
    stz VERADATA0
    stz VERADATA0
    stz VERADATA0
    stz VERADATA0
    stz VERADATA0
}

.macro setUpSpriteInVeraByAddr(addrSpriteNumber, addSpriteFrame, Mode, addrXPos, addrYPos, ZDepth, Height, Width, PalletOffset)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBaseByAddr(addrSpriteNumber, 0, 1)

    lda addSpriteFrame
    sta VERADATA0
    lda addSpriteFrame + 1
    ora #Mode
    sta VERADATA0

    lda addrXPos
    sta VERADATA0
    lda addrXPos + 1
    sta VERADATA0

    lda addrYPos
    sta VERADATA0
    lda addrYPos + 1
    sta VERADATA0

    lda #ZDepth
    sta VERADATA0

    lda #Height | Width | PalletOffset
    sta VERADATA0
}

.macro setUpSpriteInVeraWithColByAddr(addrSpriteNumber, addSpriteFrame, Mode, addrXPos, addrYPos, ZDepth, Height, Width, PalletOffset, addrColMask)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBaseByAddr(addrSpriteNumber, 0, 1)

    lda addSpriteFrame
    sta VERADATA0
    lda addSpriteFrame + 1
    ora #Mode
    sta VERADATA0

    lda addrXPos
    sta VERADATA0
    lda addrXPos + 1
    sta VERADATA0

    lda addrYPos
    sta VERADATA0
    lda addrYPos + 1
    sta VERADATA0

    lda addrColMask
    asl
    asl
    asl
    asl
    ora #ZDepth
    sta VERADATA0

    lda #Height | Width | PalletOffset
    sta VERADATA0
}

.macro moveSpriteInVera(SpriteNumber, XPosAddr, YPosAddr)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBase(SpriteNumber, SPRITE_POSITION_X_LO_OFFSET, 1)

    lda XPosAddr
    sta VERADATA0
    lda XPosAddr+1
    sta VERADATA0

    lda YPosAddr
    sta VERADATA0
    lda YPosAddr + 1
    sta VERADATA0
}

.macro moveSpriteInVeraByAddr(SpriteNumberAddr, XPosAddr, YPosAddr)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBaseByAddr(SpriteNumberAddr, SPRITE_POSITION_X_LO_OFFSET, 1)

    lda XPosAddr
    sta VERADATA0
    lda XPosAddr+1
    sta VERADATA0

    lda YPosAddr
    sta VERADATA0
    lda YPosAddr + 1
    sta VERADATA0

}

.macro setSpriteAddressInVeraByAddr(SpriteNumber, addrSpriteAddress, Mode)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBase(SpriteNumber, 0, 1)

    lda addrSpriteAddress
    sta VERADATA0
    lda addrSpriteAddress + 1
    ora #Mode
    sta VERADATA0

}

.macro setSpriteFlip(SpriteNumber, Horizonal, Vertical)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBase(SpriteNumber, SPRITE_Z_DEPTH_OFFSET, 0)

    lda VERADATA0
    and #%11111100
    ora #Vertical<<1
    ora #Horizonal
    sta VERADATA0
}

.macro setSpriteFlipByAddr(addrSpriteNumber, Horizonal, Vertical)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBaseByAddr(addrSpriteNumber, SPRITE_Z_DEPTH_OFFSET, 0)

    lda VERADATA0
    and #%11111100
    ora #Vertical<<1
    ora #Horizonal
    sta VERADATA0
}

.macro setSpriteZDepth(SpriteNumber, ZDepth)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBase(SpriteNumber, SPRITE_Z_DEPTH_OFFSET, 0)

    lda VERADATA0
    and #%11110011
    ora #ZDepth
    sta VERADATA0
}

.macro setSpriteZDepthByAddr(addrSpriteNumber, ZDepth)
{
    // using DATA0
    setAddrSel(0)

    setToSpriteBaseByAddr(addrSpriteNumber, SPRITE_Z_DEPTH_OFFSET, 0)

    lda VERADATA0
    and #%11110011
    ora #ZDepth
    sta VERADATA0
}

.macro SetCharacterAddress(CharBaseAddress)
{
    lda VERA_L1_tilebase
    and #%00000011
    ora #>CharBaseAddress
    sta VERA_L1_tilebase
}

.macro SetUpPSGVoice(VoiceNo, Volume, WaveForm)
{
    addressRegisterByValue(0, VERA_PSG_VOICE00 + (VoiceNo * 4) + VERA_PSG_VOLUME_OFFSET,1,0)
    lda #VERA_PSG_STEREO_BOTH | Volume
    sta VERADATA0

    lda #WaveForm | $3F // All Other Sound Effects
    sta VERADATA0
}

.macro PlayNote(VoiceNo, addrNote)
{
    addressRegisterByValue(0, VERA_PSG_VOICE00 + (VoiceNo * 4) + VERA_PSG_FREQLO_OFFSET,1,0)
    lda addrNote
    sta VERADATA0
    lda addrNote + 1
    sta VERADATA0
}

.macro StopPSGVoice(VoiceNo)
{
    addressRegisterByValue(0, VERA_PSG_VOICE00 + (VoiceNo * 4) + VERA_PSG_VOLUME_OFFSET,1,0)

    lda #VERA_PSG_STEREO_BOTH | %00000000
    sta VERADATA0
}

// .macro copyDataToVeraViaAddr(sourceAddr,destination,bytecountAddr) 
// // source is x16 memory . dest is vera location, bytecount max 65535
// // destroys a
// {
//     addressRegister(0,destination,1,0)
//     lda bytecountAddr
//     sta counter
//     lda bytecountAddr + 1
//     sta counter + 1

//     lda counter: $deaf

//     lda sourceAddr
//     sta copyFrom
//     lda sourceAddr + 1
//     sta copyFrom + 1

//     loop:
//     lda copyFrom: $deaf
//     sta VERADATA0
//     inc copyFrom
//     bne skip1
//     inc copyFrom+1
// skip1:
//     dec counter
//     bne loop
//     dec counter+1
//     bpl loop
// }