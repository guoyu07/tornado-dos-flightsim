;****************************************************************************
;*
;* LARGEMAP.ASM
;*
;* Large moving map display.
;*
;* 13.04.1992 - KJB
;*
;****************************************************************************

		OPTION	M510		;<<<<< MASM v5.10 <<<<<

		PUBLIC	MapView
		PUBLIC	MapCompass

		EXTRN	UpdateMovingMap:FAR
		EXTRN	VSetViewport:FAR
		EXTRN	VSetRotation:FAR
		EXTRN	VQuickLineClip:FAR
		EXTRN	VDotClip:FAR
		EXTRN	SetPixel:FAR
		EXTRN	LineDraw:FAR
		EXTRN	HLineDraw:FAR
		EXTRN	VLineDraw:FAR
		EXTRN	Print$:FAR

		EXTRN	Xe:WORD
		EXTRN	Ye:WORD
		EXTRN	XCrt:WORD

		EXTRN	YCrt:BYTE
		EXTRN	KF_MapZoomIn:BYTE
		EXTRN	KF_MapZoomOut:BYTE

		EXTRN	MAP_BIG_DISP:ABS
		EXTRN	MAP_ZOOM1:ABS
		EXTRN	MAP_ZOOM6:ABS
		EXTRN	MAP_ORG_CENTRE:ABS

;============================================================================

		INCLUDE	\VISUAL\VISDATA.INC
		INCLUDE	\VISUAL\VSCREEN.INC
		INCLUDE	\VISUAL\PALETTES.INC

		INCLUDE	\LIB8086\KEYS.INC
		INCLUDE	\LIB8086\PRINT.INC

;============================================================================

DATA		SEGMENT PARA PUBLIC 'DATA'

MapZoom		DW	MAP_ZOOM1

VP		VIEWPORT <0,0,320,200,5,5>

Range$		LABEL	BYTE
		P_OVER1
		P_CHAR2
		PD_ATTR	000h,000h,000h,000h,000h,000h,COL_COMPASS,0
		PD_XY	148,114
		PP_STR	RangeValsPtr
		DB	"NM"
		P_END

;* ptr = OFFSET RangeVals$ + zoom level * 5 / 2

RangeValsPtr	DW	OFFSET RangeVals$

RangeVals$	DB	"10.0",0	;MAP_ZOOM1
		DB	" 5.0",0	;MAP_ZOOM2
		DB	" 2.5",0	;MAP_ZOOM3
		DB	" 1.2",0	;MAP_ZOOM4
		DB	" 0.6",0	;MAP_ZOOM5
		DB	" 0.3",0	;MAP_ZOOM6

		EVEN

DATA		ENDS

;============================================================================

PANCODE		SEGMENT BYTE PUBLIC 'CODE'
		ASSUME CS:PANCODE
		ASSUME DS:DATA

;* MapView
;*
;* pass: si -> VIEWPOINT data block
;* ret : nothing
;* kill: assume all

MapView		PROC	FAR

;---------------
;* sort map zoom
;---------------

		KTEST	KF_MapZoomIn	;zoom in?
		jz	SkipZoomIn	;no ->

		cmp	MapZoom,MAP_ZOOM6	;fully zoomed in?
		je	SkipZoomIn		;yes ->

		add	MapZoom,2

		jmp	SkipZoomOut

SkipZoomIn:	KTEST	KF_MapZoomOut	;zoom out?
		jz	SkipZoomOut	;no ->

		cmp	MapZoom,MAP_ZOOM1	;fully zoomed out?
		je	SkipZoomOut	    	;yes ->

		sub	MapZoom,2

;----------
;* draw map
;----------

SkipZoomOut:	mov	ax,MAP_BIG_DISP
		xor	cx,cx
		xor	bl,bl
		xor	bh,bh
		mov	dx,MapZoom
		mov	bp,MAP_ORG_CENTRE

		push	si
		call	UpdateMovingMap
		pop	si

		mov	ax,VP_HDG[si]
		mov	dx,MapZoom
		call	MapCompass

		ret

MapView		ENDP

;----------------------------------------------------------------------------

;* MapCompass
;*
;* pass: ax = heading (0 ..511)
;*       dx = map zoom
;* ret : nothing
;* kill: assume all

MapCompass	PROC	FAR

		push	ax		;store rotation angle

;---------------
;* display range
;---------------

		mov	ax,dx
		shl	ax,1		;*2
		shl	ax,1		;*4
		add	ax,dx		;*5
		shr	ax,1		;/2

		add	ax,OFFSET RangeVals$

		mov	RangeValsPtr,ax

		mov	si,OFFSET Range$
		call	Print$

;---------------------
;* draw aircraft datum
;---------------------

		mov	al,COL_COMPASS
		mov	cx,160
		mov	bl,100-4
		mov	bh,100+3
		call	VLineDraw

		mov	al,COL_COMPASS
		mov	cx,160-4
		mov	dx,160+4
		mov	bl,100-2
		call	HLineDraw

		mov	al,COL_COMPASS
		mov	cx,160-2
		mov	dx,160+2
		mov	bl,100+2
		call	HLineDraw

;---------------
;* init viewport
;---------------

		xor	ax,ax		;no rotation
		mov	si,OFFSET VP
		call	VSetViewport

;--------------------------------
;* draw circumference graduations
;--------------------------------

		mov	cx,32

		xor	ax,ax		;0 .. 496 step 16
		
GradLoop:	push	ax
		push	cx

		call	VSetRotation

		mov	Xe[0],0
		mov	Ye[0],30

		call	VDotClip
		jc	@F		;non-visible ->

		mov	al,COL_COMPASS
		call	SetPixel

@@:		pop	cx
		pop	ax

		add	ax,16

		loop	GradLoop

;-----------------
;* draw N, S, E, W
;-----------------

		pop	ax

		neg	ax   		;negate hdg
		and 	ax,001ffh

		call	VSetRotation

;* draw letter N

		mov	Xe[0],-3
		mov	Ye[0],38
		mov	Xe[2],-3
		mov	Ye[2],32

		call	VQuickLineClip
		jc	@F		;non-visible ->

		mov	al,COL_COMPASS
		mov	cx,XCrt[0]
		mov	bl,YCrt[0]
		mov	dx,XCrt[2]
		mov	bh,YCrt[2]
		call	LineDraw

@@: 		mov	Xe[0],3
		mov	Ye[0],38
		mov	Xe[2],3
		mov	Ye[2],32

		call	VQuickLineClip
		jc	@F		;non-visible ->

		mov	al,COL_COMPASS
		mov	cx,XCrt[0]
		mov	bl,YCrt[0]
		mov	dx,XCrt[2]
		mov	bh,YCrt[2]
		call	LineDraw

@@:		mov	Xe[0],-3
		mov	Ye[0],38
		mov	Xe[2],3
		mov	Ye[2],32

		call	VQuickLineClip
		jc	@F		;non-visible ->

		mov	al,COL_COMPASS
		mov	cx,XCrt[0]
		mov	bl,YCrt[0]
		mov	dx,XCrt[2]
		mov	bh,YCrt[2]
		call	LineDraw

;* draw S tick

@@:		mov	Xe[0],0
		mov	Ye[0],-32
		mov	Xe[2],0
		mov	Ye[2],-35

		call	VQuickLineClip
		jc	@F		;non-visible ->

		mov	al,COL_COMPASS
		mov	cx,XCrt[0]
		mov	bl,YCrt[0]
		mov	dx,XCrt[2]
		mov	bh,YCrt[2]
		call	LineDraw

;* draw E tick

@@:		mov	Xe[0],32
		mov	Ye[0],0
		mov	Xe[2],35
		mov	Ye[2],0

		call	VQuickLineClip
		jc	@F		;non-visible ->

		mov	al,COL_COMPASS
		mov	cx,XCrt[0]
		mov	bl,YCrt[0]
		mov	dx,XCrt[2]
		mov	bh,YCrt[2]
		call	LineDraw

;* draw W tick

@@:		mov	Xe[0],-32
		mov	Ye[0],0
		mov	Xe[2],-35
		mov	Ye[2],0

		call	VQuickLineClip
		jc	@F		;non-visible ->

		mov	al,COL_COMPASS
		mov	cx,XCrt[0]
		mov	bl,YCrt[0]
		mov	dx,XCrt[2]
		mov	bh,YCrt[2]
		call	LineDraw

@@:		ret

MapCompass	ENDP

PANCODE		ENDS

;============================================================================

		END

