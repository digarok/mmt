****************************************
* MiniMemoryTester                     *
*                                      *
*  Dagen Brock <dagenbrock@gmail.com>  *
*  2015-09-16                          *
****************************************

                       org          $2000                         ; start at $2000 (all ProDOS8 system files)
                       typ          $ff                           ; set P8 type ($ff = "SYS") for output file
                       dsk          mtsystem                      ; tell compiler what name for output file
                       put          applerom

Init
                       clc
                       xce                                        ;enable full 65816
                       LDA          #$A0                          ;USE A BLANK SPACE TO
                       JSR          $C300                         ;TURN ON THE VIDEO FIRMWARE

                       lda          $C034                         ; save border color
                       sta          BorderColor

                       jsr          DetectRam
                       lda          BankExpansionLowest
                       sta          StartBank
                       lda          BankExpansionHighest
                       sta          EndBank

                       lda          #MainMenuDefs
                       ldx          #>MainMenuDefs
                       jsr          Menu_InitMenu

*
* Main Menu loop begin
*
Main
:menuLoop              jsr          DrawMenuBackground
                       jsr          DrawRomMessage
                       jsr          DrawRamMessages

                       jsr          LogWelcomeMessage
                       jsr          LogRamMessages

:menuDrawOptionsLoop   jsr          MenuUpdateConfig              ;always update this before draw in case of change
                       lda          #MainMenuDefs
                       ldy          #>MainMenuDefs
                       jsr          Menu_DrawOptions
:menuNoDrawLoop        jsr          MenuCheckKeyColor
                       bcc          :menuNoDrawLoop               ;hmm?
:keyHit                cmp          #KEY_ENTER                    ;8D
                       bne          :check1
:enter                 jsr          Menu_HandleSelection
                       bra          :menuDrawOptionsLoop          ;because an option might have changed

:check1                cmp          #KEY_UPARROW                  ;8B
                       beq          :prevItem
                       cmp          #KEY_LTARROW                  ;88
                       beq          :prevItem
                       cmp          #KEY_DNARROW                  ;8A
                       beq          :nextItem
                       cmp          #KEY_RTARROW                  ;95
                       beq          :nextItem
:unknownKey            bra          :menuNoDrawLoop
:prevItem              jsr          Menu_PrevItem
                       jsr          Menu_UndrawSelectedAll        ;hack for blinky cursor
                       stz          _ticker
                       bra          :menuNoDrawLoop
:nextItem              jsr          Menu_NextItem
                       jsr          Menu_UndrawSelectedAll        ;hack for blinky cursor
                       stz          _ticker
                       bra          :menuNoDrawLoop
*
* Main Menu loop end ^^^
*




DrawMenuBackground     jsr          HOME
                       lda          #MainMenuStrs
                       ldy          #>MainMenuStrs
                       ldx          #00                           ; horiz pos
                       jsr          PrintStringsX
                       rts

* Prints "Apple IIgs ROM 0x"
DrawRomMessage
                       PRINTXY      #54;#05;Mesg_Rom
                       lda          GSROM
                       jsr          PRBYTE
                       rts

* Prints "Built-In RAM  xxxK"
*        "Expansion RAM yyyyK"
DrawRamMessages
                       lda          GSROM
                       cmp          #3
                       bne          :rom0or1
:rom3                  PRINTXY      #54;#06;Mesg_InternalRam1024
                       bra          :drawExpansionMessage
:rom0or1               PRINTXY      #54;#06;Mesg_InternalRam256
:drawExpansionMessage  PRINTXY      #54;#07;Mesg_ExpansionRam
                       ldx          #BankExpansionRamKB
                       ldy          #>BankExpansionRamKB
                       jsr          PrintInt
                       lda          #"K"
                       jsr          COUT
                       rts

LogWelcomeMessage      jsr          WinConsole
                       LOG          Mesg_Welcome
                       jsr          WinFull
                       rts

LogRamMessages         jsr          WinConsole
                       LOG          Mesg_DetectedBanks

                       lda          BankExpansionLowest
                       jsr          PRBYTE
                       lda          #Mesg_ToBank
                       ldy          #>Mesg_ToBank
                       jsr          PrintString
                       lda          BankExpansionHighest
                       jsr          PRBYTE
                       jsr          WinFull
                       rts
LogTestDone            jsr          WinConsole
                       LOG          Mesg_Done
                       jsr          WinFull
                       rts





*
*    #######                                      ###    ###    ###
*       #    ######  ####  ##### ###### #####     ###    ###    ###
*       #    #      #        #   #      #    #    ###    ###    ###
*       #    #####   ####    #   #####  #    #     #      #      #
*       #    #           #   #   #      #####
*       #    #      #    #   #   #      #   #     ###    ###    ###
*       #    ######  ####    #   ###### #    #    ###    ###    ###
*
*
TestInit
                       PRINTXY      #$34;#$E;_clearstring
                       jsr          WinConsole
                       LOG          Mesg_Starting
                       jsr          WinFull
                       sei                                        ; disable interrupts
                       stz          _testErrors
                       stz          _testIteration
                       stz          _testIteration+1
                       stz          _testState


TestMasterLoop         clc
                       xce
                       rep          #$10                          ;long x/y
                       stz          CurBank
                       jsr          TestPrintIteration
                       jsr          TestPrintErrors               ;just to get it drawn
:NextBank              jsr          TestSetState                  ;sets read/write/both
                       jsr          TestGetNextBank               ;sets initial bank when CurBank = 0
                       jsr          TestPastFinalBank
                       bcs          :NextIteration

                       jsr          TestPrintState
                       jsr          TestGetStartAddress
:TestLoop
                       jsr          TestMemoryLocation
                       jsr          TestUpdateStatus


                       jsr          TestAdvanceLocation
                       bcc          :TestLoop
                       bcs          :NextBank

:NextIteration         inc          _testIteration                ;see if we've done enough tests
                       lda          TestIterations
                       beq          :infiniteIterations           ;0=infinite
                       cmp          _testIteration
                       bcc          :testComplete
:infiniteIterations    jmp          TestMasterLoop

:testComplete          sep          #$10
                       jsr          LogTestDone
                       rts
Mesg_Done              asc          "DONE WITH TEST",$8D,00







                       mx           %10
TestSetState           lda          TestTwoPass                   ;read pass then write pass?
                       bne          :twopass
                       lda          #TESTSTATE_BOTH               ;r&w
                       sta          _testState
                       rts
:twopass               lda          _testState
                       beq          :setWrite                     ;0 check for initial value
                       cmp          #TESTSTATE_READ
                       beq          :setWrite
                       lda          #TESTSTATE_READ
                       sta          _testState
                       rts
:setWrite              lda          #TESTSTATE_WRITE              ;otherwise, start with write pass
                       sta          _testState
                       rts


TestPrintState         PushAll
                       sep          #$10
                       lda          _testState
:check1                cmp          #1
                       bne          :check2
                       PRINTXY      #53;#12;Mesg_Writing
                       bra          :done
:check2                cmp          #2
                       bne          :check3
                       PRINTXY      #53;#12;Mesg_Reading
                       bra          :done
:check3                cmp          #3
                       bne          :done
                       PRINTXY      #53;#12;Mesg_RW
:done                  clc
                       xce
                       rep          #$10
                       PopAll
                       rts

TestPrintIteration     PushAll
                       sep          #$10
                       PRINTXY      #53;#10;Mesg_TestPass
                       ldx          #_testIteration
                       ldy          #>_testIteration
                       jsr          PrintInt
                       clc
                       xce
                       rep          #$10
                       PopAll
                       rts

TestPrintErrors        PushAll
                       sep          #$10
                       PRINTXY      #53;#11;Mesg_Errors
                       ldx          #_testErrors
                       ldy          #>_testErrors
                       jsr          PrintInt
                       clc
                       xce
                       rep          #$10
                       PopAll
                       rts

TestForceUpdateStatus  PushAll
                       stx _stash
                       bra :print
TestUpdateStatus       PushAll
                       stx          _stash                        ; save real X
                       lda          _stash                        ;get low byte
                       bne          :noprint
:print                 sep          #$10                          ;in case?  there was a sec xce combo here
                       GOXY         #66;#12
                       lda          CurBank
                       jsr          PRBYTE
                       lda          #"/"
                       jsr          COUT
                       lda          _stash+1
                       ldx          _stash
                       jsr          PRNTAX
                       clc
                       xce
                       rep          #$10
:noprint               PopAll
                       rts



TestMemoryLocation     rts
TestAdvanceLocation    lda          TestDirection
                       bne          :dn
:up                    lda          TestSize16Bit
                       beq          :up8
:up16                  inx
                       beq          :hitBankBoundry
:up8                   inx
                       beq          :hitBankBoundry               ;rollover
                       cpx          EndAddr                       ;sets carry if we are past/done
                       bcs          :done
                       rts
:dn                    lda          TestSize16Bit
                       beq          :dn8
:dn16                  cpx          #0
                       beq          :hitBankBoundry
                       dex
:dn8                   cpx          #0
                       beq          :hitBankBoundry
                       dex
                       cpx          StartAddr
                       bcc          :done
                       clc
                       rts
:done
:hitBankBoundry        sec
                       rts


TestGetStartAddress    lda          TestDirection
                       bne          :dn
:up                    ldx          StartAddr
                       rts
:dn                    ldx          EndAddr
:addressSet            rts

TestPastFinalBank      lda          TestDirection
                       bne          :descending
:ascending             lda          EndBank
                       cmp          CurBank                       ;is EndBank < CurBank ?
                       bcc          :yes                          ;past final bank
                       bcs          :no
:descending            lda          CurBank
                       cmp          StartBank                     ;is CurBank < StartBank ?
                       bcc          :yes
                       bcs          :no

:yes                   sec
                       rts
:no                    clc
                       rts


TestGetNextBank        lda          TestTwoPass                   ;see if we are doing two-passes of the bank
                       beq          :notTwoPass                   ;nope, no additional logic needed
                       lda          _testState
                       cmp          #TESTSTATE_READ               ;don't change bank on read pass of two-pass
                       bne          :twoPassNextBank
                       rts
:twoPassNextBank
:notTwoPass            lda          TestDirection
                       bne          :descending
:ascending             lda          CurBank
                       bne          :notInitialBank
                       lda          StartBank
                       sta          CurBank
                       rts
:notInitialBank        inc          CurBank
                       rts
:descending            lda          CurBank
                       bne          :notInitialBank2
                       lda          EndBank
                       sta          CurBank
                       rts
:notInitialBank2       dec          CurBank
                       rts


                       mx           %11












*
*
*     #####
*    #     # #      #####
*    #     # #      #    #
*    #     # #      #    #
*    #     # #      #    #
*    #     # #      #    #
*     #####  ###### #####
*
*

BeginTest              LOG          Mesg_Starting
                       stz          _testErrors
                       stz          _testIteration
                       stz          _testIteration+1



BeginTestPass
                       PRINTXY      #55;#10;Mesg_TestPass

                       inc          _testIteration
                       bne          :noroll
                       inc          _testIteration+1
:noroll                lda          _testIteration+1
                       ldx          _testIteration
                       jsr          PRNTAX
                       PRINTXY      #55;#12;Mesg_Writing

                                                                  ; WRITE START
                       clc
                       xce
                       rep          $10                           ; long x, short a
                       lda          StartBank
                       sta          CurBank
                       ldy          #0                            ; update interval counter
:bankloop              lda          CurBank
                       sta          :bankstore+3
                       ldx          StartAddr
                       lda          HexPattern
:bankstore             stal         $000000,x
                       cpx          EndAddr
                       beq          :donebank
                       inx
                       iny
                       cpy          #UpdateScanInterval
                       bcc          :bankstore
                       jsr          PrintTestCurrent
                       bcc          :noquit1
                       jmp          :escpressed
:noquit1               ldy          #0
                       bra          :bankstore
:donebank
                       ldy          #0                            ; because i'm anal.. this makes counter align
                       inc          CurBank
                       lda          EndBank
                       cmp          CurBank
                       bcs          :bankloop
                       dec          CurBank                       ; so many bad hacks
                       jsr          PrintTestCurrent              ; print final score ;)
                       bcc          :noquit2
                       jmp          :escpressed
:noquit2               sep          $10
                                                                  ; WRITE END

                       jsr          Pauser                        ; PAUSE

                       PRINTXY      #55;#12;Mesg_Reading          ; READ PREP

                                                                  ; READ START
                       clc
                       xce
                       rep          $10                           ; long x, short a
                       lda          StartBank
                       sta          CurBank
                       ldy          #0                            ; update interval counter
:bankrloop             lda          CurBank
                       sta          :bankread+3
                       ldx          StartAddr
:bankread              ldal         $000000,x
                       cmp          HexPattern
                       beq          :testpass
                       phx
                       sta          _stash                        ; = read value
                       lda          HexPattern
                       sta          _stash+1                      ; = expected value
                       stx          _stash+2
                       jsr          PrintTestError                ; addr in X
                       plx
:testpass              cpx          EndAddr
                       beq          :donerbank
                       inx
                       iny
                       cpy          #UpdateScanInterval
                       bcc          :bankread
                       jsr          PrintTestCurrent
                       ldy          #0
                       bra          :bankread
:donerbank
                       ldy          #0                            ; because i'm anal.. this makes counter align
                       inc          CurBank
                       lda          EndBank
                       cmp          CurBank
                       bcs          :bankrloop
                       dec          CurBank                       ; so many bad hacks
                       jsr          PrintTestCurrent              ; print final score ;)
                       sep          $10
                                                                  ; WRITE END


                       jsr          Pauser                        ; PAUSE
                       lda          BorderColor
                       sta          $C034
                       jmp          BeginTestPass
:escpressed            sep          $10

                       rts

_testIteration         ds           8
_testErrors            ds           8
_testState             ds           2                             ;1=read 2=write 3=both (read & write)
TESTSTATE_READ         =            1
TESTSTATE_WRITE        =            2
TESTSTATE_BOTH         =            3
UpdateScanInterval     equ          #$1000

Mesg_Welcome           asc          "Welcome to Mini Memory Tester v0.3 by Dagen Brock",$8D,00
Mesg_InternalRam256    asc          "Built-In RAM  256K",00
Mesg_InternalRam1024   asc          "Built-In RAM  1024K",00
Mesg_ExpansionRam      asc          "Expansion RAM ",00
Mesg_Rom               asc          "Apple IIgs ROM ",00
Mesg_UserManual        asc          "USE ARROW KEYS TO MOVE  -  USE ENTER TO SELECT/EDIT",00
Mesg_Starting          asc          $8D,"Starting Test",$8D,"Press P to pause, ESC to stop.",$8D,$8D,00
Mesg_Waiting           asc          "   Waiting: ",00
Mesg_Writing           asc          "   Writing: ",00
Mesg_Reading           asc          "   Reading: ",00
Mesg_RW                asc          "Read&Write: ",00
Mesg_Errors            asc          "    Errors:  ",$00
Mesg_TestPass          asc          " Test Pass:  ",00
Mesg_Blank             asc          "                 ",00
Mesg_DetectedBanks     asc          "Setting default start/end banks to detected memory expansion: $",00
Mesg_ToBank            asc          " to $",00

* Error message strings
Mesg_E1                asc          "Bad Read - Pass ",00
Mesg_E2                asc          "   Location: ",00
Mesg_E3                asc          "Wrote: $",00
Mesg_E4                asc          " ",$1B,'SU',$18," Read: $",00
Mesg_Arrow             asc          $1B,'SU',$18,00

                       mx           %10                           ;i think?
* called with short M,  long X
PrintTestError

                       sep          $30
                       inc          _testErrors
                       bne          :noRoll
                       inc          _testErrors+1
:noRoll                PRINTXY      #55;#11;Mesg_Errors
                       ldx          _testErrors
                       lda          _testErrors+1
                       jsr          PRNTAX
                       jsr          WinConsole
                       LOG          Mesg_E1
                       ldx          _testIteration
                       lda          _testIteration+1
                       jsr          PRNTAX
                       PRINTSTRING  Mesg_E2

                       lda          CurBank
                       jsr          PRBYTE
                       lda          #"/"
                       jsr          COUT
                       lda          _stash+3
                       ldx          _stash+2
                       jsr          PRNTAX
                       lda          #$8D
                       jsr          COUT
                       LOG          Mesg_E3
                       lda          _stash+1
                       jsr          PRBYTE
                       lda          #" "
                       jsr          COUT
                       lda          #"%"
                       jsr          COUT
                       lda          _stash+1
                       jsr          PRBIN
                       PRINTSTRING  Mesg_E4
                       lda          _stash
                       jsr          PRBYTE
                       lda          #" "
                       jsr          COUT
                       lda          #"%"
                       jsr          COUT
                       lda          _stash
                       jsr          PRBIN
                       jsr          WinFull
                       clc
                       xce
                       rep          $10
                       rts

*Mesg_Error0	asc "Error: Bad Read Pass 0000  Location: 00/1234"
*Mesg_Error0	asc "Wrote: $00 %12345678    Read: $00 %12345678"





                       mx           %01
PrintTestCurrent       pha
                       phy
                       stx          _stash                        ; save real X
                       sep          #$30                          ;in case?  there was a sec xce combo here
                       GOXY         #65;#12
                       lda          CurBank
                       sta          :corruptme+3
                       jsr          PRBYTE
                       lda          #"/"
                       jsr          COUT
                       lda          _stash+1
                       sta          :corruptme+2
                       jsr          PRBYTE
                       lda          _stash
                       sta          :corruptme+1
                       jsr          PRBYTE
* CORRUPTOR!
:kloop                 lda          KEY
                       cmp          #"c"                          ; REMOVE DEBUG
                       beq          :corruptor
                       cmp          #"C"
                       beq          :corruptor
                       bra          :nocorrupt
:corruptor             jsr          GetRandTrash
:corruptme             stal         $060000                       ; addr gets overwritten
                       inc          $c034
                       sta          STROBE                        ; we only clear if 'c' is hit
                       inc          _stash                        ; \
                       beq          :noroll                       ;  |- INX
                       inc          _stash+1                      ; /
:nocorrupt             cmp          #"p"                          ; check lower p
* @TODO make tolower for the comparisons
                       beq          :pause
                       cmp          #"P"
                       beq          :pause
                       bra          :nopause
:pause                 sta          STROBE
                       jsr          WaitKey
:nopause
                       cmp          #$9B
                       bne          :noquit
                       clc
                       xce
                       rep          $10
                       ldx          _stash
                       ply
                       pla
                       sec
                       rts
:noquit
:noroll
                       clc
                       xce
                       rep          $10
                       ldx          _stash
                       ply
                       pla
                       clc
                       rts



                       mx           %11
PRBIN                  pha
                       phx
                       ldx          #8
:loop                  asl
                       pha
                       bcc          :zero
:one                   lda          #"1"
                       jsr          COUT
                       bra          :ok
:zero                  lda          #"0"
                       jsr          COUT
:ok                    pla
                       dex
                       bne          :loop
                       plx
                       pla
                       rts

Pauser
                       PRINTXY      #55;#13;Mesg_Waiting
                       ldy          #60
                       ldx          TestRefreshPause
                       beq          :donepause
                       jsr          PrintTimerVal                 ; inaugural print before waiting 1 sec
:secondloop
:wait                  ldal         $e1c019
                       bpl          :wait
:wait2                 ldal         $e1c019
                       bmi          :wait2
                       dey
                       bne          :secondloop
                       dex
                       beq          :donepause
                       jsr          PrintTimerVal
                       ldy          #60
                       bra          :secondloop
:donepause
                       PRINTXY      #55;#13;Mesg_Blank
                       rts
PrintTimerVal
                       phx
                       phy
                       txa
                       GOXY         #65;#13
                       ply
                       plx
                       txa
                       jsr          PRBYTE
                       rts

GetRandTrash                                                      ; USE ONLY WITH CORRUPTOR
                       lda          _randomTrashByte
                       beq          :doEor
                       asl
                       bcc          :noEor
:doEor                 eor          #$1d
:noEor                 sta          _randomTrashByte
                       rts
_randomTrashByte       db           0
















*
*       ####  ###### ##### ##### # #    #  ####   ####
*      #      #        #     #   # ##   # #    # #
*       ####  #####    #     #   # # #  # #       ####
*           # #        #     #   # #  # # #  ###      #
*      #    # #        #     #   # #   ## #    # #    #
*       ####  ######   #     #   # #    #  ####   ####

*@todo better defaults
* 00 - Byte : Selected Value
* 01 - Byte : Number of values
* 02... - Words : Table of Addresses of possible values
TestTypeTbl            db           00                            ; actual CONST val
                       db           04                            ; number of possible values
                       da           _TestType_0,_TestType_1,_TestType_2,_TestType_3,00,00
_TestType_0            asc          "bit pattern",$00
_TestType_1            asc          " bit walk 1",$00
_TestType_2            asc          " bit walk 0",$00
_TestType_3            asc          "  random   ",$00

TestDirectionTbl       db           0
                       db           2
                       da           _testDirectionUp,_testDirectionDown,00,00
_testDirectionUp       asc          "up",$00
_testDirectionDown     asc          "dn",$00

TestSizeTbl
TestSize16Bit          db           01                            ;0=no ... 8bit,    1=yes ... 16 bit
                       db           02
                       da           _TestSize_0,_TestSize_1
_TestSize_0            asc          " 8-bit",$00
_TestSize_1            asc          "16-bit",$00

MenuStr_BeginTestJSR   da           TestInit                      ; MUST PRECEDE MENU STRING!  Yes, it's magicly inferred. (-2)
MenuStr_BeginTest      asc          " BEGIN TEST "
MenuStr_BeginTestL     equ          #*-MenuStr_BeginTest
MenuStr_BeginTestE     db           00

StartBank              db           #$06
EndBank                db           #$1F
CurBank                db           #0
StartAddr              dw           #$0000
EndAddr                dw           #$FFFF
HexPattern             dw           #$0000

TestDirection          dw           #0                            ; list
TestTwoPass            dw           #0                            ; bool is byte, but might change in future? :P
TestAdjacentWrite      dw           #0                            ; bool is byte, but might change in future? :P
TestRefreshPause       dw           #$00                          ; int
TestReadRepeat         dw           #$01                          ; int
TestWriteRepeat        dw           #$01                          ; int
TestIterations         dw           #$00                          ; int
TestErrorPause         dw           #0                            ;bool



*
*           #    # ###### #    # #    #
*           ##  ## #      ##   # #    #
*           # ## # #####  # #  # #    #
*           #    # #      #  # # #    #
*           #    # #      #   ## #    #
*           #    # ###### #    #  ####

MainMenuDefs
:StartBank             hex          19,05                         ; x,y
                       db           Menu_TypeHex                  ; 1=hex input
                       db           01                            ; memory size (bytes)
                       da           StartBank                     ; variable storage
:EndBank               hex          22,05                         ; x,y
                       db           Menu_TypeHex                  ; 1=hex input
                       db           01                            ; memory size (bytes)
                       da           EndBank                       ; variable storage
:StartAddr             hex          19,06                         ; x,y
                       db           Menu_TypeHex                  ; 1=hex input
                       db           02                            ; memory size (bytes)
                       da           StartAddr                     ; variable storage
:EndAddr               hex          20,06                         ; x,y
                       db           Menu_TypeHex                  ; 1=hex input
                       db           02                            ; memory size (bytes)
                       da           EndAddr                       ; variable storage
:TestType              hex          19,07                         ; x,y
                       db           Menu_TypeList                 ; 3=list input
                       db           11                            ; max len size (bytes), 3=option list
                       da           TestTypeTbl                   ; params definition & storage
:TestSize              hex          28,07                         ; x,y
                       db           Menu_TypeList                 ; 3=list input
                       db           6                             ; max len size (bytes), 3=option list
                       da           TestSizeTbl                   ; params definition & storage

:HexPattern            hex          19,08                         ; x,y
                       db           Menu_TypeHex                  ; 3=list input
_hexpatternsize        db           02                            ; max len size (bytes), 3=option list <- can change when 8 bit??
                       da           HexPattern                    ; params definition & storage
:BinPattern            hex          19,09                         ; x,y
                       db           Menu_TypeBin                  ; 5?=bin
_binpatternsize        db           02                            ; max len size (bytes), 3=option list <- can change when 8 bit??
                       da           HexPattern                    ; params definition & storage <- uses same space as above!! just different representation
:Direction             hex          12,0B
                       db           Menu_TypeList
                       db           2
                       da           TestDirectionTbl
:TestErrorPause        hex          28,0B                         ; x,y
                       db           Menu_TypeBool                 ; 1=hex input
                       db           2                             ; could be 8-bit or 16-bit bool
                       da           TestErrorPause                ; variable storage
:AdjacentWrite         hex          12,0C                         ; x,y
                       db           Menu_TypeBool                 ; 1=hex input
                       db           01                            ; memory size (bytes)
                       da           TestAdjacentWrite             ; variable storage
:TwoPass               hex          28,0C
                       db           Menu_TypeBool
                       db           2                             ; could be 8-bit or 16-bit bool
                       da           TestTwoPass

:ReadRepeat            hex          12,0D                         ; x,y
                       db           Menu_TypeInt                  ; 1=hex input
                       db           03                            ; display/entry width. ints are 16-bit internally
                       da           TestReadRepeat                ; variable storage
:WriteRepeat           hex          28,0D                         ; x,y
                       db           Menu_TypeInt                  ; 1=hex input
                       db           03                            ; display/entry width. ints are 16-bit internally
                       da           TestWriteRepeat               ; variable storage
:TestIterations        hex          12,0E                         ; x,y
                       db           Menu_TypeInt                  ; 1=hex input
                       db           03                            ; display/entry width. ints are 16-bit internally
                       da           TestIterations                ; variable storage
:TestRefreshPause      hex          28,0E                         ; x,y
                       db           Menu_TypeInt                  ; 1=hex input
                       db           03                            ; display/entry width. ints are 16-bit internally
                       da           TestRefreshPause              ; variable storage
:BeginTest             hex          3A,0E                         ; x,y
                       db           Menu_TypeAction               ; 2=action
                       db           MenuStr_BeginTestL            ; menu string length
                       da           MenuStr_BeginTest             ; string storage
MainMenuLen            equ          *-MainMenuDefs
MainMenuItems          equ          MainMenuLen/6
MainMenuEnd            dw           0000
Menu_ItemSelected      db           0

* special helper functions to update some input sizes when
* the user switches between 8 and 16 bit testing modes
* ... also disable AdjacentWrite if TwoPass
MenuUpdateConfig       lda          TestSize16Bit
                       bne          :is16bit
:is8bit                jmp          MenuSet8Bit
:is16bit               jmp          MenuSet16Bit
MenuSet16Bit           lda          #2
                       bra          MenuSetBits
MenuSet8Bit            jsr          MenuClearPatterns             ;clear leftover chars because strings are shorter now
                       lda          #1
MenuSetBits            sta          _hexpatternsize
                       sta          _binpatternsize

:checkTwoPass          lda          TestTwoPass                   ;now check TwoPass/AdjacentWrite conflict
                       cmp          _lastTwoPass                  ;i wish this was simpler code
                       beq          :checkAdjacentWrite           ;some computer science dude could probably help me out here
                       sta          _lastTwoPass
                       stz          TestAdjacentWrite
                       stz          _lastAdjacentWrite
                       bra          :done
:checkAdjacentWrite    lda          TestAdjacentWrite
                       cmp          _lastAdjacentWrite
                       beq          :done
                       sta          _lastAdjacentWrite
                       stz          TestTwoPass
                       stz          _lastTwoPass
:done                  rts
_lastTwoPass           db           0
_lastAdjacentWrite     db           0

* hack to allow for smaller portion of screen to update
MenuClearPatterns      PRINTXY      #$17;#$8;_clearstring
                       PRINTXY      #$17;#$9;_clearstring
                       rts
_clearstring           asc          "                         ",$00

MainMenuStrs
                       asc          " ______________________________________________________________________________",$8D,$00
                       asc          $1B,'ZV_@ZVWVWVWV_',"Mini Memory Tester v0.3",'ZVWVWVWVWVWVWVWVWVWVW_',"UltimateMicro",'ZWVWVWVW_',$18,$00
                       asc          $1B,'ZLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL_',$18,00
                       asc          $1B,'ZZ \GGGGGGGGGGGGG_',"Test  Settings",'ZGGGGGGGGGGGGG\ _'," ",'Z \GGGGGGGG_',"Info",'ZGGGGGGGG\ _'," ",'_',$18,00
                       asc          $1B,'ZZ',"                                              ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"  Start/End Bank    :       /                 ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"  Start/End Address :       /                 ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"  Test Type         :                         ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"       Hex Pattern  :                         ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"       Bin Pattern  :                         ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"                                              ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"  Direction            Wait on Error          ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"  Adjacent Wr.         Two-Pass R/W           ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"  Read Repeat          Write Repeat           ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"  Iterations           Refresh Pause          ",'_'," ",'Z',"     ([ BEGIN TEST ])     ",'_'," ",'_',$18,00
                       asc          $1B,'ZZ',"                                              ",'_'," ",'Z',"                          ",'_'," ",'_',$18,00
                       asc          $1B,'ZLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL_',$18,00
                       asc          $1B,'Z',"                                                                              ",'_',$18,00
                       asc          $1B,'Z',"                                                                              ",'_',$18,00
                       asc          $1B,'Z',"                                                                              ",'_',$18,00
                       asc          $1B,'Z',"                                                                              ",'_',$18,00
                       asc          $1B,'Z',"                                                                              ",'_',$18,00
                       asc          $1B,'Z',"                                                                             _",'_',$18,00
                       asc          $1B,'Z',"_____________________________________________________________________________",'_',$18,00
                       hex          00,00






* Creates a 256 byte map of each bank, "BankRam"
* The map shows whether it's Built-in RAM, ROM, Expansion RAM, etc.
DetectRam
                       lda          #BankRAMFastBuiltIn           ;these are universal to all IIgs
                       sta          BankMap+$00                   ;bank 00
                       sta          BankMap+$01                   ;bank 01
                       lda          #BankRAMSlowBuiltIn           ;
                       sta          BankMap+$e0                   ;bank e0
                       sta          BankMap+$e1                   ;bank e1
                       lda          #BankROMUsed
                       sta          BankMap+$FE                   ;bank FE
                       sta          BankMap+$FF                   ;bank FF

                       lda          GSROM
                       cmp          #3                            ;check for ROM3 IIgs
                       bne          :rom0or1
:rom3                  lda          #BankRAMFastBuiltIn
                       ldx          #$02                          ;bank 02
:builtinram            sta          BankMap,x                     ;bank 02
                       inx
                       cpx          #$10                          ;stop after bank 0F
                       bcc          :builtinram
                       lda          #BankROMUsed                  ;ROM 3 is 256KB, so 4 banks (2 additional)
                       sta          BankMap+$FC                   ;
                       sta          BankMap+$FD                   ;
                       ldx          #$10                          ;ROM3 starts scan at bank 10
                       bra          :detectloop

:rom0or1                                                          ;no additional mappings
                       lda          #$FE                          ;ROM1 end bank FE
                       sta          :endbankscan+1                ;but change our max scan bank
                       ldx          #$02                          ;ROM0/1 starts scan at bank 02

:detectloop            txa                                        ;we'll store the bank number
                       sta          :writer+3                     ;overwrite bank address
                       sta          :reader+3
                       sta          :compare+1
:writer                stal         $000000                       ;should overwrite first byte
:reader                ldal         $000000
:compare               cmp          #$00
                       bne          :notused
                       inc          BankExpansionRam              ;TotalMB++
                       lda          #BankRAMFastExpansion         ;store mapping
                       sta          BankMap,x
:continue              inx
                       cpx          #$E0                          ;skip banks $E0-$EF
                       bcc          :endbankscan                  ; <E0
                       cpx          #$F0
                       bcs          :endbankscan                  ; >= F0    (>EF)
                       ldx          #$F0                          ;skip to bank F0
                       bra          :detectloop
:endbankscan           cpx          #$FC                          ;ROM3 end bank (default)
                       bcc          :detectloop                   ;blt

                                                                  ;let's find low/high to simplify things
                       ldx          #$ff
:lowloop               lda          BankMap,x
                       cmp          #BankRAMFastExpansion
                       beq          :isRam
                       dex
                       cpx          #$ff
                       bne          :lowloop
                       bra          :checkhigh
:isRam                 stx          BankExpansionLowest
                       dex
                       bra          :lowloop

:checkhigh             ldx          #$00
:highloop              lda          BankMap,x
                       cmp          #BankRAMFastExpansion
                       beq          :isRam2
                       inx
                       bne          :highloop
                       bra          :done
:isRam2                stx          BankExpansionHighest
                       inx
                       bra          :highloop

:done                  bra          :findKB

:notused               lda          #BankNoRAM
                       sta          BankMap,x
                       bra          :continue

:findKB
                       lda          BankExpansionRam              ;number of banks
                       clc
                       xce
                       rep          #$30
                       mx           %00
                       and          #$00FF                        ;clear artifacts? can't remember state of B
                       asl                                        ;*2
                       asl                                        ;*4
                       asl                                        ;*8
                       asl                                        ;*16
                       asl                                        ;*32
                       asl                                        ;*64
                       sta          BankExpansionRamKB

                       lda          GSROM                         ;now check (hardcode really) build-in ram
                       cmp          #3
                       bne          :notrom3
:rom3                  lda          #1024
                       sta          BankBuiltInRamKB
                       rts
:notrom3               lda          #256
                       sta          BankBuiltInRamKB
                       sep          #$30

                       rts



* Takes address in X/Y and prints out Int stored there
PrintInt
                       stx          :loc+1
                       inx
                       stx          :loc2+1
                       sty          :loc+2
                       sty          :loc2+2

:loc                   ldx          $2000                         ;overwrite
:loc2                  ldy          $2000                         ;overwrite
                       jsr          BINtoBCD
                       phx
                       tya
                       jsr          PRBYTE
                       pla
                       jsr          PRBYTE
                       rts




Quit                   jsr          MLI                           ; first actual command, call ProDOS vector
                       dfb          $65                           ; with "quit" request ($65)
                       da           QuitParm
                       bcs          Error
                       brk          $00                           ; shouldn't ever  here!

QuitParm               dfb          4                             ; number of parameters
                       dfb          0                             ; standard quit type
                       da           $0000                         ; not needed when using standard quit
                       dfb          0                             ; not used
                       da           $0000                         ; not used

Error                  brk          $00                           ; shouldn't be here either

                       put          misc
                       put          strings.s
                       put          menu.s


                                                                  ;
BankROMUsed            =            1
BankROMReserved        =            2
BankRAMSlowBuiltIn     =            3
BankRAMFastBuiltIn     =            4
BankRAMFastExpansion   =            5
BankNoRAM              =            0



BorderColor            db           0

BankExpansionRamKB     ds           2
BankBuiltInRamKB       ds           2
BankExpansionRam       ds           1
BankExpansionLowest    ds           1
BankExpansionHighest   ds           1
                       ds           \
BankMap                ds           256                           ;page-align maps just to make them easier to see
_stash                 ds           256
                       ds           \
