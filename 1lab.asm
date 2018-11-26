.model small
.stack 100h

.data
    input           db      255, 0, 255 dup("$")    ; Pirmas skaicius, koks dydis atlaisvintos atminties
                                                    ; Antras - nuskaitant irasys, kiek baitu buvo nuskaityta
                                                    ; Likusi dalis uzpildoma $, kad skaitant duomenis sustotu

    vowelCount      dw      0h
    numberCount     dw      0h
    consonantCount  dw      0h

    newLine         db      13, 10, 24h
.code
start:
    mov         dx, @data           ; perkelti adresa, kuriame saugomi kintamieji i registra dx
    mov         ds, dx              ; perkelti dx (data) i data segmenta


    mov         dx, offset input    ; perkeliam kintamojo, i kuri norim rasyt, adresa i DX registra.
    mov         ah, 0Ah             ; i ah registra nukeliam instrukcija, kad reiks skaityt is klaviaturos
    int         21h                 ; ivykdom interupta, jo metu bus skaitoma is klaviaturos

    call        printNewLine        ; kvieciam funkcija, kuri atspausdins nauja eilute

    xor         cx, cx              ; nunulinam cx registra, jis bus naudojamas loopui
    mov         cl, [input+1]       ; i cx registro jaunesniaja dali nukeliam, kiek simboliu buvo nuskaityta - kiek kartu reikes sukti cikla

    xor         bx, bx              ; nunulinam bx registra. Jis bus loopo indeksas
    mainLoop:
        cmp             [input + 2 + bx], '9' ; ar simbolis yra lygus arba mazesnis '9', tada padidinam index
        jbe             numberFound

        mov             al, [input + 2 + bx]
        jmp             checkForVowel
        vowelNotFound:            

        inc             consonantCount ; kadangi nerasta, nei skaiciu, nei balsiu - radome priebalse
        continueMainLoop:
        inc             bx          ; padidinam bx vienetu
    loop mainLoop


    mov         ax, numberCount
    call        printNumber
    call        printSpace

    mov         ax, vowelCount
    call        printNumber
    call        printSpace

    mov         ax, consonantCount
    call        printNumber

    mov         ah, 4ch             ; griztame i dos'a
    mov         al, 0               ; be klaidu
    int         21h                 ; dos'o INTeruptas

printNewLine:
    mov         dx, offset newLine
    mov         ah, 09h
    int         21h
    ret

printSpace: 
    mov     ah, 2                         ; 2 yra funkcijos skaicius spausdinti simboli
    mov     dx, ' '                       ; i dx idedam tarpa
    int     21h                           ; spausdinam
    ret

numberFound:
    inc         numberCount
    jmp         continueMainLoop

vowelFound:
    inc         vowelCount
    jmp         continueMainLoop

checkForVowel:                            ; patikrins ar ASCII simbolis al registre yra balse
                                          ; jeigu taip -  padidins balses counteri ir soks i continueMainLoop
                                          ; jeigu ne soks i - vowelNotFound

    cmp         al, 'A'
    je          vowelFound

    cmp         al, 'a'
    je          vowelFound

    cmp         al, 'E'
    je          vowelFound

    cmp         al, 'e'
    je          vowelFound

    cmp         al, 'I'
    je          vowelFound

    cmp         al, 'i'
    je          vowelFound

    cmp         al, 'O'
    je          vowelFound

    cmp         al, 'o'
    je          vowelFound

    cmp         al, 'Y'
    je          vowelFound

    cmp         al, 'y'
    je          vowelFound

    cmp         al, 'U'
    je          vowelFound

    cmp         al, 'u'
    je          vowelFound 

    jmp         vowelNotFound   

printNumber:                              ; atspausdina skaiciu is ax
    xor     cx, cx                        ; nusinulinam cx, skaiciuosime kiek skaitmenu turime
    mov     bx, 10                        ; bx bus daliklis lygus 10
    
    pushNumbersSymbolsToStack:
        xor     dx, dx                    ; nusinulinam dx
        div     bx                        ; ax esancia reiksme dalinam is bx, sveikoji dalis paliekama ax, liekana perkeliama i dx

        add     dl, '0'                   ; pridedam '0', kad dx esantis skaicius taptu ASCII

        push    dx                        ; skaiciai bus atvirkscia tvarka, todel pushinam i stacka
        inc     cx                        ; skaiciuojam kiek skaiciu yra stacke
        cmp     ax, 0                     ; jeigu ax 0 baigiam
        jnz     pushNumbersSymbolsToStack ; jei ne nulis kartojame dar

    mov     ah, 2                         ; 2 yra funkcijos skaicius spausdinti simboli
    printSymbolsFromStack:
        pop     dx                        ; popinam is stacko skaiciaus ASCII i dx
        int     21h                       ; atspausdinam simboli is dx
    loop    printSymbolsFromStack         ; loopinam tiek kartu kiek buvo skaiciu stacke (cx)

    ret                                   ; griztam i main
end start
