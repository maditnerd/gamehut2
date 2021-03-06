;----------------------------------------------------------
;		GAMEHUT SHELL
;		BY JON BURTON - APR 2018
;----------------------------------------------------------
		INCLUDE	SYSTEM.S		;INCLUDES LOTS OF SYSTEM CODE TO MAKE ALL THIS POSSIBLE

;----------------------------------------------------------
;		VRAM MEMORY MAP IN HEXADECIMAL
;		(NOTE: CHARACTERS ARE 8 X 8 PIXEL BLOCKS)
;----------------------------------------------------------
;		$0000-$0020			BLANK CHARACTER
;		$0020-$8000			CHARACTERS FOR PLAYFIELDS AND SPRITES
;		$C000-$D000			CHARACTER MAP FOR PLAYFIELD 1 (4096 BYTES)
;		$E000-$F000			CHARACTER MAP FOR PLAYFIELD 2 (4096 BYTES)
;		$F800				SPRITE TABLE (960 BYTES)

;----------------------------------------------------------
;		USER VARIABLES
;		- PUT ANY VARIABLES YOU NEED HERE
;----------------------------------------------------------
		RSSET	USERRAM
PLAYX:		RS.L	0
PLAY1X:		RS.W	1			;X POSITION OF PLAYFIELD 1
PLAY2X:		RS.W	1			;X POSITION OF PLAYFIELD 2
PLAYY:		RS.L	0
PLAY1Y:		RS.W	1			;Y POSITION OF PLAYFIELD 1
PLAY2Y:		RS.W	1			;Y POSITION OF PLAYFIELD 2
SONICX:		RS.W	1			;SONIC'S X POSITION
SONICY:		RS.W	1			;SONIC'S Y POSITION
SONICD:		RS.W	1			;SONIC'S DIRECTION
TEMPSCREEN:	RS.B	4096			;RAM TO BUILD TEMPORARY SCREEN MAP
ENDVARS:	RS.B	0

;----------------------------------------------------------
;		INITIALISE USER STUFF
;		- THIS IS WHERE YOU SET UP STUFF BEFORE YOU BEGIN
;----------------------------------------------------------
USERINIT:	MOVE.W	#0,PLAY1X		;SET START PLAYFIELD 1 X POSITION TO ZERO
		MOVE.W	#0,PLAY1Y		;SET START PLAYFIELD 1 Y POSITION TO ZERO

		DMADUMP	MAPGFX,4*32,$20		;DUMP 4 CHARACTERS (SIZE 32 BYTES EACH) TO VRAM LOCATION $20 (MAP GRAPHICS)
		DMADUMP	SPRITEGFX,8*32,$1000	;DUMP 8 CHARACTERS (SIZE 32 BYTES EACH) TO VRAM LOCATION $1000 (SPRITE GRAPHICS)

		LEA.L	TEMPSCREEN,A0		;POINT A0 TO TEMPORARY BUFFER IN RAM TO BUILD MAP BEFORE WE COPY TO VRAM
		MOVE.W	#8-1,D3			;WE'LL MAKE 8 COPIES OF THIS PATTERN
@L4:		LEA.L	CHARGFX,A1		;POINT A1 TO CHARGFX, WHICH IS THE 8 CHARACTER X 4 CHARACTER PATTERN WE'LL COPY MULITPLE TIMES
		MOVE.W	#4-1,D1			;4 ROWS
@L3:		MOVE.W	#8-1,D0			;COPY EACH ROW REPEATED ACROSS THE SCREEN 8 TIMES HORIZONTALLY
@L2:		MOVE.W	#4-1,D2			;4 LONG-WORDS = 8 CHARACTERS WIDE
@L1:		MOVE.L	(A1)+,(A0)+		;COPY FROM CHARGFX TO THE TEMPSCREEN. THE + MEANS INCREMENT THE POINTERS
		DBRA	D2,@L1			;LOOP BACK TO @L1
		SUB.L	#16,A1			;POINT BACK TO THE START OF THE CURRENT CHARGFX ROW
		DBRA	D0,@L2			;LOOP BACK TO @L2
		ADD.L	#16,A1			;MOVE ONTO THE NEXT CHARGFX ROW
		DBRA	D1,@L3			;LOOP BACK TO @L3
		DBRA	D3,@L4			;LOOP BACK TO @L4

		DMADUMP	TEMPSCREEN,4096,$C000	;COPY TEMPSCREEN WHICH IS 4096 BYTES IN SIZE TO VRAM ADDRESS $C000

		LEA.L	PALETTE1,A0		;DOWNLOAD A PALETTE FOR THE MAP TO USE
		BSR	SETPAL1			;OVERRIGHT FIRST PALETTE

		LEA.L	PALETTE2,A0		;DOWNLOAD A PALETTE FOR THE SPRITES TO USE
		BSR	SETPAL2			;OVERRIGHT SECOND PALETTE

		JSR	DUMPCOLS		;COPY ALL PALETTES TO CRAM (COLOUR RAM)

		MOVE.W	#$80+160-8,SONICX	;SONIC'S X START POSITION
		MOVE.W	#$80+112-13,SONICY	;SONIC'S Y START POSITION
		MOVE.W	#0,SONICD		;SONIC'S START DIRECTION

		RTS

;------------------------------
;	MAIN GAME LOOP
;------------------------------
MAIN:		WAITVBI					;WAITS FOR THE START OF THE NEXT FRAME
		ADD.W	#1,PLAY1X			;SCROLL PLAYFIELD 1 RIGHT BY ONE PIXEL
		ADD.W	#1,PLAY1Y			;SCROLL PLAYFIELD 1 UP BY ONE PIXEL
;ADD SPRITES
		LEA.L	SPRITETEMP,A1			;POINT TO TEMPORARY MEMORY TO BUILD SPRITE LIST

		MOVE.W	SONICY,(A1)+			;Y POSITION ($80 IS TOP OF SCREEN)
		MOVE.W	#S_2X4+1,(A1)+			;SIZE 2X4 CHARACTERS, NEXT SPRITE NUMBER = 1
		MOVE.W	#S_PAL2+$1000/32,D0		;PALETTE NUMBER+GRAPHIC VRAM LOCATION/32
		ADD.W	SONICD,D0
		MOVE.W	D0,(A1)+			;ADD SONIC'S DIRECTION
		MOVE.W	SONICX,(A1)+			;X POSITION ($80 IS LEFT OF SCREEN)

		MOVE.L	#$10000,(A1)+			;TERMINATE SPRITE LIST
		MOVE.L	#1,(A1)+			;	"  "

;MOVE SONIC
		BTST	#J_RIGHT,JOYPAD0
		BNE.S	@MOVE1
		ADD.W	#1,SONICX
		MOVE.W	#0,SONICD
@MOVE1:
		BTST	#J_LEFT,JOYPAD0
		BNE.S	@MOVE2
		SUB.W	#1,SONICX
		MOVE.W	#$800,SONICD
@MOVE2:
		BTST	#J_DOWN,JOYPAD0
		BNE.S	@MOVE3
		ADD.W	#1,SONICY
@MOVE3:
		BTST	#J_UP,JOYPAD0
		BNE.S	@MOVE4
		SUB.W	#1,SONICY
@MOVE4:

		BRA	MAIN				;LOOP BACK TO WAIT FOR NEXT FRAME

;----------------------------------------------------------
;		USER VBI ROUTINES
;		- PUT TIME CRITICAL CODE THAT MUST CALLED DURING THE VERTICAL BLANK HERE
;----------------------------------------------------------
USERVBI:	LEA.L	VDP_DATA,A1
		LEA.L	VDP_CONTROL,A2
;SET HORIZONTAL OFFSETS
		MOVE.L	#$7C000003,(A2)
		MOVE.L	PLAYX,(A1)		;THIS TELLS THE VDP (VISUAL DISPLAY PROCESSOR) WHAT X POSITION THE PLAYFIELDS SHOULD BE AT

;SET VERTICAL OFFSETS
		MOVE.L	#$40000010,(A2)		;THIS TELLS THE VDP WHAT Y POSITION THE PLAYFIELDS SHOULD BE AT
		MOVE.L	PLAYY,(A1)

;COPY SPRITE TABLE TO VRAM
		JSR	SPRITEDUMP
;READ JOYPAD
		BSR	READJOY			;READ THE JOYPAD

		RTS

;----------------------------------------------------------
;		PUT DATA BELOW HERE
;----------------------------------------------------------

;----------------------------------------------------------
;		CHARACTER CODES TO BUILD OUR PATTERN
;
;		THE CODE IS IN THE FORMAT $NNNN
;
;		THE LAST TWO NUMBERS ($00NN) REFER TO THE CHARACTER NUMBER IN VRAM TO USE
;		(THE CHARACTER NUMBER IS THE VRAM ADDRESS DIVIDED BY 32 (OR DIVIDED BY $20 HEXADECIMAL))
;
;		IF THE FIRST NUMBER  ($N000) IS '1' IT MEANS MIRROR THE CHARACTER VERTICALLY
;		IF THE SECOND NUMBER ($0N00) IS '8' IT MEANS MIRROR THE CHARACTER HORIZONTALLY
;
;		SO WHEN WE HAVE A DIAGONAL CHARACTER LINE THIS - / WE CAN MIRROR IT TO GET THIS \
;		SO WE CAN BUILD THIS - /\
;				       \/   USING ONE DIAGONAL AND MIRRORING
;----------------------------------------------------------
CHARGFX:	DC.W	$0003,$0004,$0001,$0001,$0801,$0801,$0804,$0803
		DC.W	$0002,$0002,$0003,$0004,$0804,$0803,$0802,$0802
		DC.W	$1002,$1002,$1003,$1004,$1804,$1803,$1802,$1802
		DC.W	$1003,$1004,$1001,$1001,$1801,$1801,$1804,$1803

;----------------------------------------------------------
;		MAP GRAPHICS
;----------------------------------------------------------
MAPGFX:		DC.B	$66,$66,$66,$66		;01	FULL CHARACTER USING COLOUR 6
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66

		DC.B	$77,$77,$77,$77		;02	FULL CHARACTER USING COLOUR 7
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77

		DC.B	$FF,$66,$66,$66		;03	HALF OF THE DIAGONAL LINE
		DC.B	$77,$FF,$66,$66
		DC.B	$77,$77,$FF,$66
		DC.B	$77,$77,$77,$FF
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77
		DC.B	$77,$77,$77,$77

		DC.B	$66,$66,$66,$66		;04	OTHER HALF OF THE DIAGONAL LINE
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66
		DC.B	$66,$66,$66,$66
		DC.B	$FF,$66,$66,$66
		DC.B	$77,$FF,$66,$66
		DC.B	$77,$77,$FF,$66
		DC.B	$77,$77,$77,$FF

;----------------------------------------------------------
;		SPRITE GRAPHICS
;		2 X 4 CHARACTERS ARRANGED AS FOLLOWS -
;
;		1 5
;		2 6
;		3 7
;		4 8
;----------------------------------------------------------
SPRITEGFX:	DC.B	$00,$11,$11,$11		;1
		DC.B	$01,$22,$22,$22
		DC.B	$00,$12,$22,$13
		DC.B	$00,$01,$22,$13
		DC.B	$00,$00,$12,$13
		DC.B	$00,$01,$22,$22
		DC.B	$00,$12,$22,$22
		DC.B	$01,$22,$22,$22

		DC.B	$00,$11,$12,$22		;2
		DC.B	$00,$01,$22,$22
		DC.B	$00,$12,$22,$23
		DC.B	$01,$22,$22,$23
		DC.B	$11,$11,$11,$11
		DC.B	$00,$00,$00,$13
		DC.B	$00,$00,$01,$31
		DC.B	$00,$00,$13,$14

		DC.B	$00,$00,$11,$44		;3
		DC.B	$00,$00,$01,$44
		DC.B	$00,$00,$00,$14
		DC.B	$00,$00,$00,$01
		DC.B	$00,$00,$00,$11
		DC.B	$00,$00,$01,$44
		DC.B	$00,$00,$01,$44
		DC.B	$00,$00,$16,$66

		DC.B	$00,$00,$16,$66		;4
		DC.B	$00,$00,$11,$11
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00

		DC.B	$11,$00,$11,$00		;5
		DC.B	$22,$11,$21,$00
		DC.B	$22,$22,$21,$00
		DC.B	$32,$22,$21,$00
		DC.B	$22,$22,$22,$10
		DC.B	$24,$42,$22,$40
		DC.B	$44,$44,$22,$40
		DC.B	$44,$45,$24,$50

		DC.B	$44,$41,$24,$10		;6
		DC.B	$24,$45,$41,$11
		DC.B	$34,$44,$33,$10
		DC.B	$34,$44,$31,$00
		DC.B	$33,$33,$10,$00
		DC.B	$11,$11,$00,$00
		DC.B	$12,$33,$11,$00
		DC.B	$41,$33,$44,$10

		DC.B	$44,$13,$14,$10		;7
		DC.B	$44,$11,$41,$00
		DC.B	$41,$21,$10,$00
		DC.B	$11,$10,$00,$00
		DC.B	$21,$11,$10,$00
		DC.B	$21,$44,$10,$00
		DC.B	$41,$16,$61,$10
		DC.B	$64,$41,$16,$61

		DC.B	$46,$66,$61,$66		;8
		DC.B	$11,$11,$11,$11
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00
		DC.B	$00,$00,$00,$00

;----------------------------------------------------------
;		USER PALETTES
;----------------------------------------------------------
PALETTE1:	DC.W	$0000,$0044,$0066,$0088
		DC.W	$00AA,$00EE
		DC.W	$0888,$0F00		;THESE TWO ARE THE ONES WE USE FOR THE TWO TILE COLOURS
		DC.W	$0EEE,$0CCC,$0AAA,$0888
		DC.W	$0666,$0444,$0222,$0000

PALETTE2:	DC.W	$0000,$0000,$0F80,$08CE	;SPRITE PALETTE
		DC.W	$0EEE,$00E0,$000E,$0000
		DC.W	$0000,$0000,$0000,$0000
		DC.W	$0000,$0000,$0000,$0000
