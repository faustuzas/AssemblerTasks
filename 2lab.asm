.model small
.stack 100h

.data
    endl db 0Dh,0Ah, 24h
    helpMsg db "HELP: split <charsPerFile> file1 [file2 ...]$"
    openFileErrorMsg db "Cannot open file. Check if all file names provided exists$"
    readFileErrorMsg db "Cannot read file. Try again$"
    closeFileErrorMsg db "Cannot close file. Data will not be saved. Try again$"
    createFileErrorMsg db "Cannot create file. Try again$"
    writeFileErrorMsg db "Cannot write to file. Try again$"

    cmdArgs db 255 dup(' ')
    offsetInBuffer dw 1

    dataBuffer db 256 dup(?)
    dataBufferSize dw 0
    offsetInDataBuffer dw 0

    writingBuffer db 256 dup(?)
    writingBufferSize dw 256
    offsetWritingBuffer dw 0

    charsPerFile dw 0
    bytesWroteToFile dw 0

    srcFileName db 256 dup(0)
    dstFileName db 256 dup(0)
    srcFileHandler dw ?
    dstFileHandler dw ?
    dstFilesCounter db 0
    dstFilesCounterASCII db 256 dup('$')
.code
start:
    mov dx, @data
    mov ds, dx

; READ ARGUMENTS TO BUFFER
    xor cx, cx
    mov cl, es:[80h] ; kiek simboliu yra ivesta po komandos pavadinimo
    cmp cl, 0        ; jeigu 0, atspausdinam help ir baigiam
    jne readArgumentsToBuffer ; jeigu nelygu vykdyk toliau
    jmp printHelpAndEnd ; jei nieko nenuskaite sok i apacia

    readArgumentsToBuffer:
        mov si, 0081h ; i si isidedam adresa kur yra pradzia command args
        xor bx, bx
        readArgumentsToBuffer__loop:
            mov al, es:[si + bx]      ; i al isidedam simboli is cmd args
            mov ds:[cmdArgs + bx], al ; i global kintamaji rasom duomenis

            inc bx
        loop readArgumentsToBuffer__loop
; /READ ARGUMENTS TO BUFFER

; SEARCH FOR FLAG
    xor cx, cx
    xor bx, bx
    mov cl, es:[80h]
    searchForFlagMarker__loop:
        cmp [cmdArgs + bx], '/'
        je searchForFlagMarker__flagFound
        jmp searchForFlagMarker__loop__continue

        searchForFlagMarker__flagFound:
            cmp [cmdArgs + bx + 1], '?' ; help flag found
            jne searchForFlagMarker__loop__continue
            jmp printHelpAndEnd

        searchForFlagMarker__loop__continue:
        inc bx
    loop searchForFlagMarker__loop
; /SEARCH FOR FLAG

; GET CHARS PER FILE
    xor bx, bx
    getCharsPerFile:
        mov bx, offsetInBuffer
        xor dx, dx
        mov dl, [cmdArgs + bx]
        push dx ; gauta simboli pushinam i stacka
        inc offsetInBuffer
        inc bx

        cmp [cmdArgs + bx], ' ' ; paziurim ar priejom tarpa
        jne getCharsPerFile ; jeigu ne skaitom dar viena skaiciuka

        xor cx, cx
        mov cx, offsetInBuffer ; nukeliam i cl kiek simboliu nuskaitem
        dec cx ; sumazinam vienetu nes pradine offsetInBuffer reiksme buvo 1
        mov bx, 1 ; bx laikysime 10^n laipsni
        getCharsPerFile__loop:
            pop ax ; is stacko i ax isimetam nuskaityta simboli
            sub ax, '0' ; is simbolio atimam '0', kad gautume normalu skaiciu
            mul bx ; ax esancia reiksme padauginam is bx
            add charsPerFile, ax
            
            xor ax, ax ; nusinulinam ax
            mov ax, bx ; i ax isimetam bx, kad galetume dauginti
            mov bx, 10
            mul bx     ; padauginam ax is 10
            mov bx, ax
        loop getCharsPerFile__loop

        inc offsetInBuffer ; move offset one char to right to ignore space
        
        cmp charsPerFile, 0
        jne checkAnyArgsLeft
        jmp printHelpAndEnd
; /GET CHARS PER FILE

; CHECK IF THERE IS ANY FILE NAMES PROVIDED
    checkAnyArgsLeft:
        xor cx, cx
        mov cl, es:[80h]
        cmp offsetInBuffer, cx
        jb checkIfValidSymbol
        jmp printHelpAndEnd

    checkIfValidSymbol:
        xor cx, cx
        xor bx, bx
        mov bx, offsetInBuffer
        mov cl, [cmdArgs + bx]
        cmp [cmdArgs + bx], ' '
        jne chunkFiles
        jmp printHelpAndEnd
; /CHECK IF THERE IS ANY FILE NAMES PROVIDED

chunkFiles:
    call getNextSrcFileName
    jc chunkFiles_fileDoesntExist
    call openFile
    jc chunkFiles_fileDoesntExist
    jmp chunkFiles_fileExists

    chunkFiles_fileDoesntExist:
        jmp endProgram

    chunkFiles_errorsInSrc:
        jmp chunkFiles__finishSrc

    chunkFiles_errorsInDst:
        jmp chunkFiles__finishDst

    chunkFiles_fileExists:
        mov srcFileHandler, ax
        call readFile
        jc chunkFiles_errorsInSrc
        cmp dataBufferSize, 0
        je chunkFiles_errorsInSrc
        mov dstFilesCounter, 0
        call openNextDst
        jc chunkFiles_errorsInDst

    chunkFiles_loop:
        mov bx, offsetInDataBuffer
        cmp bx, dataBufferSize
        je chunkFiles__loop__dataBufferUsed

        mov bx, offsetWritingBuffer
        cmp bx, writingBufferSize
        je chuckFiles__loop__writingBufferFull

        mov bx, bytesWroteToFile
        add bx, offsetWritingBuffer
        cmp bx, charsPerFile
        je chunkFiles__loop__charsPerFileCompleted

        jmp chunkFiles__loop__saveByteInBuffers

        chunkFiles__loop__dataBufferUsed:
            call readFile
            jc chunkFiles__finishSrc
            cmp dataBufferSize, 0
            je chunkFiles__finishWritingInDst
            jmp chunkFiles_loop

        chuckFiles__loop__writingBufferFull:
            call writeFile
            jc chunkFiles__finishDst
            jmp chunkFiles_loop

        chunkFiles__loop__charsPerFileCompleted:
            call writeFile
            jc chunkFiles__finishDst
            call closeDst
            jc chunkFiles__finishSrc
            call openNextDst
            jc chunkFiles__finishSrc

            jmp chunkFiles_loop

        chunkFiles__loop__saveByteInBuffers:
            mov bx, offsetInDataBuffer
            mov si, offsetWritingBuffer
            mov dl, [dataBuffer + bx]
            mov [writingBuffer + si], dl
            inc offsetInDataBuffer
            inc offsetWritingBuffer
            jmp chunkFiles_loop

    chunkFiles__finishWritingInDst:
        call writeFile
        jmp chunkFiles__finishDst

    chunkFiles__finishDst:
        call closeDst
        jmp chunkFiles__finishSrc

    chunkFiles__finishSrc:
        mov bx, srcFileHandler
        call closeFile
        jc endProgram
        jmp chunkFiles

endProgram:
    mov dx, offset endl
    mov ah, 09h
    int 21h

    mov ah, 4ch
    mov al, 0
    int 21h

printHelpAndEnd:
    mov dx, offset helpMsg
    mov ah, 09h
    int 21h
    jmp endProgram

openFile:                       ; PARAMS: pointer to filename in DX
                                ; RESULT: file handle in AX
                                ; May produce error

    lea dx, srcFileName
    mov ax, 3d00h               ; open file with handle function
    xor cx, cx
    int 21h                
    jc openFileError            ; jump if error
    ret

    openFileError: 
        mov dx, offset openFileErrorMsg  ; print error function
        mov ah, 09h
        int 21h
        stc
        ret

readFile:                       ; PARAMS:
                                ; RESULT: Bytes read in dataBufferSize, data read in dataBuffer
                                ; May produce errors
    mov ax, 3f00h               ; read from file function
    mov bx, srcFileHandler
    mov cx, 256
    lea dx, dataBuffer          ; set up pointer to data buffer
    int 21h
    jc readFileError            ; jump if error
    mov dataBufferSize, ax
    mov offsetInDataBuffer, 0
    ret

    readFileError:
        lea dx, readFileErrorMsg ; print error function
        mov ah, 09h
        int 21h
        stc
        ret



writeFile:                      ; PARAMS:
                                ; RESULT: CX symbols written
    mov bx, offsetWritingBuffer
    add bytesWroteToFile, bx

    mov ax, 4000h
    mov cx, offsetWritingBuffer
    lea dx, writingBuffer
    mov bx, dstFileHandler
    int 21h
    jc writeFileError          ; jump if error
    mov offsetWritingBuffer, 0
    ret

    writeFileError:
        lea dx, writeFileErrorMsg ; set up pointer to error message
        mov ah, 09h               ; display string function
        int 21h
        stc                       ; set error flag
        ret

closeFile:                      ; PARAMS: file handle in BX
                                ; May produce errors

    mov ah, 3eh                 ; close file with handle function
    int 21H
    jc closeFileError           ; jump if error
    ret
    closeFileError:  
        lea dx, closeFileErrorMsg ; set up pointer to error message
        mov ah, 09h               ; display string function
        int 21h
        stc                       ; set error flag
        ret

getNextSrcFileName:             ; PARAMS: -
                                ; RESULTS: Next src file name in srcFileName
    xor si, si
    xor dx, dx

    mov bx, offsetInBuffer
    mov dl, ds:[cmdArgs + bx]
    cmp dl, ' '
    je getNextSrcFileName__notFound

    getNextSrcFileName__readName:
        mov bx, offsetInBuffer
        mov dl, ds:[cmdArgs + bx]
        cmp dl, ' '
        je getNextSrcFileName__spaceFound

        mov [srcFileName + si], dl
        inc offsetInBuffer
        inc si
        jmp getNextSrcFileName__readName

    getNextSrcFileName__spaceFound:
        inc si
        mov [srcFileName + si], 0 ; 0 is required for filename end
        inc offsetInBuffer
        ret

    getNextSrcFileName__notFound:
        stc
        ret

getNextDstFileName:             ; PARAMS: -
                                ; RESULTS: generates dstFileName from 
                                ; dstFilesCounterASCII and srcFileName
    call createASCIIdestFilesCounter
    
    xor si, si                  ; index in resultName
    xor dx, dx
    getNextDstFileName__number:
        mov dl, [dstFilesCounterASCII + si]
        cmp dx, '$'
        je getNextDstFileName__number__end

        mov [dstFileName + si], dl
        inc si
        jmp getNextDstFileName__number
    getNextDstFileName__number__end:

    xor bx, bx                  ; index in srcFileName
    getNextDstFileName__src:
        mov dl, [srcFileName + bx]
        cmp dx, 0
        je getNextDstFileName__src__end

        mov [dstFileName + si], dl
        inc si
        inc bx
        jmp getNextDstFileName__src
    getNextDstFileName__src__end:

    mov [dstFileName + si + 1], 0
    ret

createASCIIdestFilesCounter:    ; PARAMS: -
                                ; RESULTS: creates ASCII representation in dstFilesCounterASCII 
                                ; of number found in dstFilesCounter
    xor     ax, ax
    mov     al, dstFilesCounter
    xor     cx, cx                        ; nusinulinam cx, skaiciuosime kiek skaitmenu turime
    mov     bx, 10                        ; bx bus daliklis lygus 10
    
    pushNumbersSymbolsToStack:
        xor dx, dx                    ; nusinulinam dx
        div bx                        ; ax esancia reiksme dalinam is bx, sveikoji dalis paliekama ax, liekana perkeliama i dx

        add dl, '0'                   ; pridedam '0', kad dx esantis skaicius taptu ASCII

        push dx                       ; skaiciai bus atvirkscia tvarka, todel pushinam i stacka
        inc cx                        ; skaiciuojam kiek skaiciu yra stacke
        cmp ax, 0                     ; jeigu ax 0 baigiam
        jnz pushNumbersSymbolsToStack ; jei ne nulis kartojame dar

    xor si, si
    saveSymbolsFromStack:
        pop dx                              ; popinam is stacko skaiciaus ASCII i dx
        mov [dstFilesCounterASCII + si], dl ; atspausdinam simboli is dx
        inc si
    loop saveSymbolsFromStack               ; loopinam tiek kartu kiek buvo skaiciu stacke (cx)

    mov [dstFilesCounterASCII + si], "$"

    ret                                     ; griztam i main

openNextDst:
    inc dstFilesCounter
    call getNextDstFileName
    mov bytesWroteToFile, 0

    lea dx, dstFileName
    xor cx, cx                  ; Access rights
    mov ax, 3C00h               ; Create file function
    int 21h
    jc openNextDstError
    mov dstFileHandler, ax
    ret

    openNextDstError:
        lea dx, createFileErrorMsg ;set up pointer to error message
        mov ax, 0900h             ;display string function
        int 21h
        stc                     ;set error flag
        ret
closeDst:
    mov bx, dstFileHandler
    call closeFile
    jc closeDstError
    ret

    closeDstError:
        stc
        ret


end start
