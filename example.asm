.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "SNAKE 2K22",0
area_width 	EQU 700
area_height EQU 700
area DD 0


tailX DD 100 dup(0)
tailY DD 100 dup(0)
tailK DD 100 dup(0)
ntail DD 12

SnakeX DD 350			 ; pozitia de pornire a snake-ului 
SnakeY DD 350

divizibil DD 0

dir DD 0
counter DD 0 ; numara evenimentele de tip timer
skore   DD 0 ; counter scor
death	DD 0; not dead yet

pctx DD 0
pcty DD 0

blk DD 0000000h
wht DD 0FFFFFFh
tmp dd 0
format db "[%d]",13,10,0

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp


; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

make_block macro x, y, color
	push color
	push y
	push x
	call proc_block
	add esp, 12
endm

proc_block proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg2]
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg1]
	shl eax, 2
	add eax, area
	mov ebx, 10
	for1:
		mov ecx, 10
			for2:
				mov edx, [ebp+arg3]
				mov dword ptr[eax+4*ecx], edx
			loop for2
		add eax, 4*area_width
	dec ebx
	cmp ebx, 0
	jne for1
	
	popa
	mov esp, ebp
	pop ebp
	ret
proc_block endp

pozRandom macro poz
	rdtsc
	mov ebx, 490
	mov edx, 0
	div ebx
	mov poz, edx
	add poz, 110
	mov eax, poz
	mov ebx, 10
	mov edx, 0
	div ebx
	sub poz, edx
endm

line macro x, y, lenght, thickness, color
local for1, for2
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x
	shl eax, 2
	add eax, area
	;mov dword ptr[eax], 0FF00FFh
	mov ebx, thickness
	for1:
		mov ecx, lenght
			for2:
				mov dword ptr[eax+4*ecx-4], color
			loop for2
		add eax, 4*area_width
	dec ebx
	cmp ebx, 0
	jne for1
endm

divby macro n, x, diviz
local atr, final
	mov diviz, 0
	mov edx, 0
	mov eax, n
	mov ebx, x
	div ebx
	cmp edx, 0
	je atr
	jmp final
	atr:
		mov diviz, 1
	final:
	
endm

drawCubes macro range, x, y, color1, color2
local bucDraw
	
	mov ecx, range
	bucDraw:
		line x, y, 10, 10, 0FFFFFFh
		add x, 10
		add y, 10
		line x, y, 10, 10, 0000000h
		add x, 10
		add y, 10
	loop bucDraw
	
endm

collisionWhite proc 
	push ebp
	mov ebp, esp
	pusha
	
	cmp dir, 1
	je coll_up
	cmp dir, 2
	je coll_dw
	cmp dir, 3
	je coll_lf ;  merge si pentru stanga
	cmp dir, 4
	je coll_rg ;  merge si pentru dreapta
	jmp final
	
	coll_up:
		mov eax, tailY[0]
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 0FFFFFFh
		je deadSnake
		jmp final
	coll_dw:
		mov eax, tailY[0]
		add eax, 10
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 0FFFFFFh
		je deadSnake
		jmp final
	coll_lf:
		mov eax, tailY[0]
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		shl eax, 2
		add eax, area
		
		cmp dword ptr[eax], 0FFFFFFh
		je deadSnake
		jmp final
	coll_rg:
		mov eax, tailY[0]
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		add eax, 10
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 0FFFFFFh
		je deadSnake
		jmp final
	
	deadSnake:
	;mov dword ptr[eax], 0FF00FFh
		mov death, 1
	final:
	popa
	mov esp, ebp
	pop ebp
	ret
collisionWhite endp

collisionGreen proc 
	push ebp
	mov ebp, esp
	pusha
	
	cmp dir, 1
	je coll_up
	cmp dir, 2
	je coll_dw
	cmp dir, 3
	je coll_lf ;  merge si pentru stanga
	cmp dir, 4
	je coll_rg ;  merge si pentru dreapta
	jmp final
	
	coll_up:
		mov eax, tailY[0]
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 000FF00h
		je deadSnake
		jmp final
	coll_dw:
		mov eax, tailY[0]
		add eax, 10
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 000FF00h
		je deadSnake
		jmp final
	coll_lf:
		mov eax, tailY[0]
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		shl eax, 2
		add eax, area
		
		cmp dword ptr[eax], 000FF00h
		je deadSnake
		jmp final
	coll_rg:
		mov eax, tailY[0]
		mov ebx, area_width
		mul ebx
		add eax, tailX[0]
		add eax, 10
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 000FF00h
		je deadSnake
		jmp final
	
	deadSnake:
	;mov dword ptr[eax], 0FF00FFh
		mov death, 1
	final:
	popa
	mov esp, ebp
	pop ebp
	ret
collisionGreen endp

movement proc
	push ebp
	mov ebp, esp
	pusha
	
	
	cmp dir, 1
	je up
	cmp dir, 2
	je down
	cmp dir, 3
	je left
	cmp dir, 4
	je right
	jmp final
	
	up:	
		sub tailY[0], 10
		jmp print
	down:
		add tailY[0], 10
		jmp print
	left:
		sub tailX[0], 10
		jmp print
	right:
		add tailX[0], 10
	
	print:
	make_block tailX[0], tailY[0], tailK[0]	
	mov ebx, ntail
	bucAdd:
		make_block tailX[ebx], tailY[ebx], tailK[ebx]
		sub ebx, 4
		cmp ebx, 0
		jne bucAdd
	
	mov ebx, ntail
	mov ecx, ntail
	sub ecx, 4
	bucSh:
		mov eax, tailX[ecx]
		mov tailX[ebx], eax
		mov eax, tailY[ecx]
		mov tailY[ebx], eax
		sub ecx, 4
		sub ebx, 4
		cmp ebx, 0
		jne bucSh
		
	final:
	popa
	mov esp, ebp
	pop ebp
	ret
movement endp
; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	cmp eax, 3
	je evt_kby
	
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 0
	push area
	call memset
	add esp, 12
game:
    ; start point
	genAnotherApple:
		pozRandom pctx
		pozRandom pcty
		mov eax, pcty
		mov ebx, area_width
		mul ebx
		add eax, pctx
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 000FF00h 	; daca-i verde
		je genAnotherApple
		cmp dword ptr[eax], 0FFFFFFh	; daca-i alb
		je genAnotherApple
		
	make_block pctx, pcty, 0FF0000h
	
evt_click:
	mov edi, area
	mov ecx, area_height
	mov ebx, [ebp+arg3]
	and ebx, 7
	inc ebx

	
evt_timer:
	call collisionGreen
	call collisionWhite
	;Game Over
	cmp death, 1
	je GameOver
	
	inc counter
	
	call movement
	jmp afisare_litere


evt_kby:
	mov edi, [ebp+arg2]
	cmp edi, 'W'
	je sus
	
	cmp edi, 'S'
	je jos
	
	cmp edi, 'A'
	je stg
	
	cmp edi, 'D'
	je drp
	jmp afisare_litere

sus:
	cmp dir, 2
	je afisare_litere
	mov dir, 1
	jmp afisare_litere
jos:
	cmp dir, 1
	je afisare_litere
	mov dir, 2
	jmp afisare_litere
stg:
	cmp dir, 4
	je afisare_litere
	mov dir, 3
	jmp afisare_litere
drp:
	cmp dir, 3
	je afisare_litere
	mov dir, 4
	jmp afisare_litere


afisare_litere:
	; afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	; cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	; cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	; cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10

	
score:				; if snake eat apple (point) :  snake.poz == apple.poz -> inc score
	mov edx, pctx
	cmp tailX[0], edx
	je inc_skore
	jmp afis_skore
	inc_skore:
		mov ecx, pcty
		cmp tailY[0], ecx
		jne afis_skore
	
	; next point	
	newPoint:		
		genNewPoint:
		pozRandom pctx
		pozRandom pcty
		mov eax, pcty
		mov ebx, area_width
		mul ebx
		add eax, pctx
		shl eax, 2
		add eax, area
		cmp dword ptr[eax], 000FF00h 	; daca-i verde
		je genNewPoint
		cmp dword ptr[eax], 0FFFFFFh	; daca-i alb
		je genNewPoint
		make_block pctx, pcty, 0FF0000h 
	
	skorepp:
	inc skore	; incrementare scor
	addTail:
		mov eax, ntail
		mov tailK[eax], 000FF00h
		add ntail, 4
		mov eax, ntail
		mov tailK[eax], 0000000h
		
	
	; afisare scor	
	afis_skore:			
	make_text_macro 'S', area, 500, 615
	make_text_macro 'C', area, 510, 615
	make_text_macro 'O', area, 520, 615
	make_text_macro 'R', area, 530, 615
	make_text_macro 'E', area, 540, 615
	
	mov ebx, 10
	mov eax, skore
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 580, 615
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 570, 615
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 560, 615
	
	
	
map:
	make_text_macro 'S', area, 110, 615
	make_text_macro 'E', area, 120, 615
	make_text_macro 'R', area, 130, 615
	make_text_macro 'G', area, 140, 615
	make_text_macro 'I', area, 150, 615
	make_text_macro 'U', area, 160, 615
	
	make_text_macro 'I', area, 180, 615
	make_text_macro 'S', area, 190, 615
	make_text_macro 'A', area, 200, 615
	make_text_macro 'C', area, 210, 615
	
	line 100, 100, 500, 10, 0FFFFFFh	;s
    line 100, 600, 500, 10, 0FFFFFFh   	;j    
	line 100, 110, 10, 500, 0FFFFFFh	;st
	line 590, 100, 10, 500, 0FFFFFFh	;dr
	
	;obstacole
	line 160, 200, 90, 10, 0FFFFFFh
	line 200, 160, 10, 90, 0FFFFFFh
	line 200, 350, 10, 150, 0FFFFFFh
	line 400, 200, 100, 10, 0FFFFFFh
	line 320, 500, 220, 10, 0FFFFFFh
	line 490, 450, 10, 100, 0FFFFFFh
	line 490, 280, 10, 70, 0FFFFFFh
	
jmp final_draw
GameOver:
	line 300, 320, 100, 10, 0FFFFFFh
	line 300, 390, 100, 10, 0FFFFFFh
	line 300, 320, 10 , 70, 0FFFFFFh
	line 390, 320, 10 , 70, 0FFFFFFh
	
	make_text_macro 'G', area, 330, 340
	make_text_macro 'A', area, 340, 340
	make_text_macro 'M', area, 350, 340
	make_text_macro 'E', area, 360, 340
	make_text_macro 'O', area, 330, 360
	make_text_macro 'V', area, 340, 360
	make_text_macro 'E', area, 350, 360
	make_text_macro 'R', area, 360, 360
	
	line 290, 310, 10, 10, 0FFFFFFh
	line 290, 400, 10, 10, 0FFFFFFh
	line 400, 400, 10, 10, 0FFFFFFh
	line 400, 310, 10, 10, 0FFFFFFh
	
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	
	mov ebx, SnakeX
	mov tailX[0], ebx
	mov ebx, SnakeY
	mov tailY[0], ebx
	mov tailK[0], 000aa55h
	
	mov ebx, SnakeX
	mov tailX[4], ebx
	mov ebx, SnakeY
	mov tailY[4], ebx
	mov tailK[4], 000c639h
	
	mov ebx, SnakeX
	mov tailX[8], ebx
	mov ebx, SnakeY
	add ebx, 10
	mov tailY[8], ebx
	mov tailK[8], 000e31ch
	
	mov ebx, SnakeX
	mov tailX[12], ebx
	mov ebx, SnakeY
	add ebx, 20
	mov tailY[12], ebx
	mov tailK[12], 0000000h
	
	
	
	;alocam memorie pentru zona de desenat 
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
