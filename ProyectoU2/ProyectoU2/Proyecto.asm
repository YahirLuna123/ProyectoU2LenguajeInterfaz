; Sistema de Ventas e Inventario – Game Store (Unidad 2)
; **Materia:** Lenguajes de Interfaz
; **Horario:** 10:00-11:00
; **Alumno:** Yahir Luna Beltrán
; **Docente:** Dr. José Luis Medina Jiménez

INCLUDE Irvine32.inc

; ---------------------- CONSTANTES -----------------------------------
MAX_PROD     = 10          ; capacidad maxima del catalogo
LEN_CODIGO   = 7           ; ABC-123
LEN_NOMBRE   = 25          ; maximo de caracteres del nombre
MAX_PRECIO   = 999999      ; $9999.99 en centavos
MAX_EXIST    = 100         ; existencia maxima por producto

; Estructura de un registro de producto (tamano fijo = 44 bytes)
;   offset  0 : codigo   (8 bytes: 7 caracteres + 00h)
;   offset  8 : nombre   (26 bytes: 25 caracteres + 00h)
;   offset 34 : relleno  (2 bytes, alinea los DWORD)
;   offset 36 : precio   (DWORD, en centavos)
;   offset 40 : existencia (DWORD, unidades)
OFF_CODIGO   = 0
OFF_NOMBRE   = 8
OFF_PRECIO   = 36
OFF_EXIST    = 40
REC_SIZE     = 44

; Formato del archivo (TEXTO, inventario.txt):
;   linea 1 : GSV1                       (marca de formato)
;   lineas  : CODIGO|NOMBRE|CENTAVOS|EXISTENCIA     (una por producto)
;   ejemplo : ZLD-001|Zelda TOTK|129950|15
;   Cada linea termina en CR LF (tambien se acepta solo LF).
MAGIC        = 31565347h             ; "GSV1" como DWORD (bytes 47h 53h 56h 31h)
FILE_MAX     = 512                   ; maximo valido: 6 + 10*46 = 466 bytes

; Regla del negocio: descuento por cantidad
DESC_MIN_CANT = 3          ; desde 3 unidades de un mismo juego...
DESC_PORC     = 10         ; ...se descuenta el 10% del importe base

EOL         EQU <0Dh, 0Ah>

; ---------------------- DATOS ----------------------------------------
.data
; --- Catalogo en memoria: MAX_PROD registros contiguos, inicializados en 0
;     Producto i = catalogo + i * REC_SIZE   (ESI apunta al inicio del registro)
catalogo     BYTE MAX_PROD * REC_SIZE DUP(0)
numProd      DWORD 0           ; cuantos productos hay registrados
ingresos     DWORD 0           ; ingresos de la sesion, en centavos
hayCambios   BYTE  0           ; 1 = hay cambios sin guardar

; --- Buffer de captura (ReadString necesita tamano = max caracteres + 1)
BUF_SIZE     = 64
bufEntrada   BYTE BUF_SIZE DUP(0)
bufSalida    BYTE 40 DUP(0)    ; buffer para armar texto de salida

; --- Temporales del alta: el registro solo se escribe cuando TODO es valido
tmpCodigo    BYTE 8 DUP(0)
tmpNombre    BYTE 26 DUP(0)
tmpPrecio    DWORD 0
tmpExist     DWORD 0

; --- Mensajes de registrar / consultar
msgPideCodigo BYTE "Codigo (formato ABC-123, Enter vacio = cancelar): ", 0
msgCodigoMalo BYTE "Codigo invalido. Use 3 letras mayusculas, guion y 3 digitos (ej. PSX-001).", EOL, 0
msgDuplicado  BYTE "Ese codigo ya existe. Intente con otro.", EOL, 0
msgPideNombre BYTE "Nombre del videojuego (1 a 25 caracteres): ", 0
msgNombreMalo BYTE "Nombre invalido: no puede estar vacio, superar 25 caracteres ni contener '|'.", EOL, 0
msgPidePrecio BYTE "Precio en MXN (ej. 185.50, de 0.01 a 9999.99): ", 0
msgPrecioMalo BYTE "Precio invalido. Use pesos enteros o punto con 1 o 2 decimales, sin simbolos ni comas.", EOL, 0
msgPideExist  BYTE "Existencia inicial (0 a 100): ", 0
msgExistMala  BYTE "Existencia invalida. Escriba un entero de 0 a 100.", EOL, 0
msgRegOk      BYTE "Producto registrado correctamente.", EOL, 0
msgLleno      BYTE "Capacidad maxima alcanzada (10 productos). Registro rechazado.", EOL, 0
msgCancelado  BYTE "Registro cancelado.", EOL, 0
msgInvVacio   BYTE "No hay productos registrados.", EOL, 0
msgPideBuscar BYTE "Codigo a buscar (ABC-123): ", 0
msgNoEnc      BYTE "Producto no encontrado.", EOL, 0
msgSep        BYTE " | ", 0
msgEsp        BYTE " ", 0
msgPideCodRec BYTE "Codigo del producto que recibe mercancia: ", 0
msgPideCant   BYTE "Unidades recibidas (entero mayor que 0, Enter vacio = cancelar): ", 0
msgCantMala   BYTE "Cantidad invalida. Escriba un entero mayor que 0 (solo digitos).", EOL, 0
msgExcede     BYTE "Rechazado: la existencia no puede pasar de 100 unidades.", EOL, 0
msgActual     BYTE "Existencia actual: ", 0
msgPuedeRec   BYTE "Maximo que puede recibir: ", 0
msgRecOk      BYTE "Mercancia recibida. Inventario actualizado:", EOL, 0
msgRecCancel  BYTE "Recepcion cancelada. No se modifico el inventario.", EOL, 0
msgPideCodVta BYTE "Codigo del producto a vender: ", 0
msgPideCantV  BYTE "Unidades a vender (entero mayor que 0, Enter vacio = cancelar): ", 0
msgAgotado    BYTE "Rechazado: el producto esta agotado (existencia 0).", EOL, 0
msgSinExist   BYTE "Rechazado: no hay existencias suficientes.", EOL, 0
msgDisponible BYTE "Unidades disponibles: ", 0
msgDesbVenta  BYTE "Rechazado: el importe o los ingresos superan el limite permitido.", EOL, 0
msgVentaOk    BYTE EOL, "Venta aceptada.", EOL, 0
msgVProducto  BYTE "Producto : ", 0
msgVCantidad  BYTE "Cantidad : ", 0
msgVBase      BYTE "Importe base   : ", 0
msgVDesc      BYTE "Descuento 10%  : -", 0
msgVSinDesc   BYTE "Descuento       : ninguno (aplica desde 3 unidades)", EOL, 0
msgVFinal     BYTE "Importe final  : ", 0
tmpBase       DWORD 0          ; importe base de la venta o cotizacion (centavos)
tmpDesc       DWORD 0          ; descuento aplicado (centavos)

msgReglaTxt   BYTE EOL, "--- REGLA DEL NEGOCIO: DESCUENTO POR CANTIDAD ---", EOL
              BYTE "Al vender 3 o mas unidades de un mismo juego se descuenta el 10% del importe base.", EOL
              BYTE "Descuento = importe base x 10 / 100 (se descartan las fracciones de centavo).", EOL
              BYTE "Con 1 o 2 unidades no hay descuento.", EOL
              BYTE "Esta opcion solo COTIZA: no modifica el inventario ni los ingresos.", EOL, EOL, 0
msgPideCodCot BYTE "Codigo del producto a cotizar: ", 0
msgPideCantCot BYTE "Unidades a cotizar (1 a 100, Enter vacio = salir): ", 0
msgCantMalaCot BYTE "Cantidad invalida. Escriba un entero de 1 a 100.", EOL, 0
msgCotiza     BYTE EOL, "Cotizacion:", EOL, 0
msgVentaCanc  BYTE "Venta cancelada. No se modifico el inventario ni los ingresos.", EOL, 0
msgResTitulo  BYTE EOL, "--- RESUMEN ---", EOL, 0
msgResProd    BYTE "Productos registrados  : ", 0
msgResUnid    BYTE "Unidades disponibles   : ", 0
msgResValor   BYTE "Valor del inventario   : ", 0
msgResIngr    BYTE "Ingresos de la sesion  : ", 0
msgDesbResumen BYTE "No se pudo calcular el resumen: desbordamiento de 32 bits.", EOL, 0

; --- Archivo de texto
nombreArchivo BYTE "inventario.txt", 0
bufArchivo    BYTE FILE_MAX + 2 DUP(0)  ; +1 para detectar bytes de mas, +1 para el 00h final
bytesArchivo  DWORD 0
bufCampo      BYTE 16 DUP(0)            ; campo numerico del texto
tmpCatalogo   BYTE MAX_PROD * REC_SIZE DUP(0)   ; catalogo temporal: se valida aqui antes de reemplazar
tmpCuenta     DWORD 0                   ; productos leidos en tmpCatalogo

msgGuardOk    BYTE "Catalogo guardado en inventario.txt. Productos: ", 0
msgErrCrear   BYTE "Error: no se pudo crear el archivo inventario.txt.", EOL, 0
msgErrEscr    BYTE "Error: no se escribieron todos los bytes solicitados.", EOL, 0
msgErrCerrar  BYTE "Error: no se pudo cerrar el archivo.", EOL, 0
msgConfCargar BYTE "Hay cambios sin guardar; cargar los reemplazara. Continuar? (S/N): ", 0
msgCargaCanc  BYTE "Carga cancelada. El catalogo actual no cambio.", EOL, 0
msgNoArchivo  BYTE "No se encontro el archivo inventario.txt. El catalogo actual no cambio.", EOL, 0
msgErrLeer    BYTE "Error al leer el archivo. El catalogo actual no cambio.", EOL, 0
msgArchInv    BYTE "Archivo invalido: ", 0
msgNoCambio   BYTE "El catalogo actual no cambio.", EOL, 0
msgCargaOk    BYTE "Catalogo cargado correctamente. Productos: ", 0

msgFE0        BYTE "error desconocido.", EOL, 0
msgFE1        BYTE "la primera linea debe ser GSV1.", EOL, 0
msgFE2        BYTE "hay mas de 10 productos.", EOL, 0
msgFE3        BYTE "una linea no tiene el formato CODIGO|NOMBRE|CENTAVOS|EXISTENCIA.", EOL, 0
msgFE4        BYTE "un codigo, nombre, precio (1 a 999999 centavos) o existencia (0 a 100) es invalido.", EOL, 0
msgFE5        BYTE "hay codigos duplicados.", EOL, 0
msgFE6        BYTE "el archivo es demasiado grande.", EOL, 0
tablaErrores  DWORD OFFSET msgFE0, OFFSET msgFE1, OFFSET msgFE2, OFFSET msgFE3
              DWORD OFFSET msgFE4, OFFSET msgFE5, OFFSET msgFE6
msgEncabezado BYTE EOL, "CODIGO  | NOMBRE", 19 DUP(' '), " | EXI | PRECIO", EOL, 0

; --- Mensajes 
msgTitulo    BYTE EOL, "=== GAME STORE - Inventario de Videojuegos ===", EOL, 0
msgMenu      BYTE EOL
             BYTE "--- MENU PRINCIPAL ---", EOL
             BYTE "1. Registrar y consultar", EOL
             BYTE "2. Recibir mercancia", EOL
             BYTE "3. Vender", EOL
             BYTE "4. Resumen", EOL
             BYTE "5. Regla del negocio (descuento por cantidad)", EOL
             BYTE "6. Guardar y cargar", EOL
             BYTE "0. Salir", EOL
             BYTE "Opcion: ", 0

msgMenuRC    BYTE EOL
             BYTE "--- REGISTRAR Y CONSULTAR ---", EOL
             BYTE "1. Registrar producto", EOL
             BYTE "2. Mostrar inventario", EOL
             BYTE "3. Buscar por codigo", EOL
             BYTE "0. Volver al menu principal", EOL
             BYTE "Opcion: ", 0

msgMenuGC    BYTE EOL
             BYTE "--- GUARDAR Y CARGAR ---", EOL
             BYTE "1. Guardar catalogo", EOL
             BYTE "2. Cargar catalogo", EOL
             BYTE "0. Volver al menu principal", EOL
             BYTE "Opcion: ", 0
msgInvalida  BYTE "Opcion invalida. Escriba un solo digito de los mostrados.", EOL, 0
msgPend      BYTE "[Funcion pendiente de implementar]", EOL, 0
msgSinGuardar BYTE "Hay cambios sin guardar. Salir de todos modos? (S/N): ", 0
msgAdios     BYTE EOL, "Hasta luego.", EOL, 0


.code

main PROC
    mov  edx, OFFSET msgTitulo
    call WriteString

MenuLoop:
    mov  edx, OFFSET msgMenu
    call WriteString

    call LeerOpcion              ; EAX = opcion (0-9), CF=1 si es invalida
    jc   OpcionMala

    cmp  eax, 0
    je   OpSalir
    cmp  eax, 1
    je   Op1
    cmp  eax, 2
    je   Op2
    cmp  eax, 3
    je   Op3
    cmp  eax, 4
    je   Op4
    cmp  eax, 5
    je   Op5
    cmp  eax, 6
    je   Op6
    jmp  OpcionMala              ; digito fuera de rango (7-9)

Op1: call MenuRegistrarConsultar
     jmp  MenuLoop
Op2: call RecibirMercancia
     jmp  MenuLoop
Op3: call VenderProducto
     jmp  MenuLoop
Op4: call MostrarResumen
     jmp  MenuLoop
Op5: call ReglaNegocio
     jmp  MenuLoop
Op6: call MenuGuardarCargar
     jmp  MenuLoop

OpcionMala:
    mov  edx, OFFSET msgInvalida
    call WriteString
    jmp  MenuLoop

OpSalir:
    call ConfirmarSalida         ; EAX = 1 salir, 0 volver al menu
    cmp  eax, 1
    jne  MenuLoop

    mov  edx, OFFSET msgAdios
    call WriteString
    exit
main ENDP

; ====================================== DESPLIEGA LAS OPCIONES ===============================================
LeerOpcion PROC
    push edx
    push ecx

    mov  edx, OFFSET bufEntrada  ; EDX = direccion del buffer
    mov  ecx, 2                  ; ECX = max caracteres a leer (buffer >= 3 bytes)
    call ReadString              ; EAX = cantidad de caracteres leidos

    cmp  eax, 1                  ; exactamente 1 caracter
    jne  LO_Error

    movzx eax, bufEntrada        ; primer caracter
    cmp  al, '0'
    jb   LO_Error
    cmp  al, '9'
    ja   LO_Error

    sub  eax, '0'                ; ASCII -> valor numerico
    clc                          ; CF = 0: valido
    jmp  LO_Fin

LO_Error:
    xor  eax, eax
    stc                          ; CF = 1: invalido

LO_Fin:
    pop  ecx                     ; POP no altera flags
    pop  edx
    ret
LeerOpcion ENDP


ConfirmarSalida PROC
    push edx
    push ecx

    cmp  hayCambios, 0
    je   CS_Salir                ; sin cambios pendientes: salir

CS_Preguntar:
    mov  edx, OFFSET msgSinGuardar
    call WriteString
    mov  edx, OFFSET bufEntrada
    mov  ecx, 2
    call ReadString
    cmp  eax, 1                  ; debe ser un solo caracter
    jne  CS_Preguntar            ; repetir si es invalido

    movzx eax, bufEntrada
    cmp  al, 'S'
    je   CS_Salir
    cmp  al, 's'
    je   CS_Salir
    cmp  al, 'N'
    je   CS_NoSalir
    cmp  al, 'n'
    je   CS_NoSalir
    jmp  CS_Preguntar            ; ni S ni N: repetir

CS_Salir:
    mov  eax, 1
    jmp  CS_Fin
CS_NoSalir:
    xor  eax, eax
CS_Fin:
    pop  ecx
    pop  edx
    ret
ConfirmarSalida ENDP

; ==================================== MENU DE REGISTRAR Y CONSULTAR ==============================================
MenuRegistrarConsultar PROC
MRC_Loop:
    mov  edx, OFFSET msgMenuRC
    call WriteString
    call LeerOpcion              ; EAX = opcion, CF=1 si invalida
    jc   MRC_Mala

    cmp  eax, 0
    je   MRC_Volver
    cmp  eax, 1
    je   MRC_1
    cmp  eax, 2
    je   MRC_2
    cmp  eax, 3
    je   MRC_3
    jmp  MRC_Mala                ; 4-9 no existen en este submenu

MRC_1: call RegistrarProducto
       jmp  MRC_Loop
MRC_2: call MostrarInventario
       jmp  MRC_Loop
MRC_3: call BuscarProducto
       jmp  MRC_Loop

MRC_Mala:
    mov  edx, OFFSET msgInvalida
    call WriteString
    jmp  MRC_Loop

MRC_Volver:
    ret
MenuRegistrarConsultar ENDP

;============================== MENU DE GUARDAR Y CARGAR =================================================
MenuGuardarCargar PROC
MGC_Loop:
    mov  edx, OFFSET msgMenuGC
    call WriteString
    call LeerOpcion
    jc   MGC_Mala

    cmp  eax, 0
    je   MGC_Volver
    cmp  eax, 1
    je   MGC_1
    cmp  eax, 2
    je   MGC_2
    jmp  MGC_Mala                ; 3-9 no existen en este submenu

MGC_1: call GuardarCatalogo
       jmp  MGC_Loop
MGC_2: call CargarCatalogo
       jmp  MGC_Loop

MGC_Mala:
    mov  edx, OFFSET msgInvalida
    call WriteString
    jmp  MGC_Loop

MGC_Volver:
    ret
MenuGuardarCargar ENDP

; #####################################################################
;  UTILIDADES DE CONVERSION Y VALIDACION 
; #####################################################################

;================================================= LEER LAS LINEAS DE QUE INGRESAMOS ======================================
LeerLinea PROC
    push ecx
    push edx
    mov  edx, OFFSET bufEntrada  ; EDX = donde se guarda la entrada
    mov  ecx, BUF_SIZE - 1       ; ECX = maximo de caracteres (deja 1 byte para 00h)
    call ReadString              ; EAX = caracteres leidos
    pop  edx
    pop  ecx
    ret
LeerLinea ENDP

;======================================= COPIA LAS CADENAR =================================================
CopiarCadena PROC
    push eax
    push esi
    push edi
CCad_Loop:
    mov  al, [esi]
    mov  [edi], al
    inc  esi
    inc  edi
    cmp  al, 0
    jne  CCad_Loop
    pop  edi
    pop  esi
    pop  eax
    ret
CopiarCadena ENDP

; ============================================== VALIDA QUE EL FORMATO SEA EL CORRECTO ===============================================
ValidarCodigo PROC
    push esi
    push ecx

    mov  ecx, 3                  ; tres letras
VC_Letras:
    mov  al, [esi]
    cmp  al, 'A'
    jb   VC_Mal
    cmp  al, 'Z'
    ja   VC_Mal
    inc  esi
    loop VC_Letras

    cmp  BYTE PTR [esi], '-'
    jne  VC_Mal
    inc  esi

    mov  ecx, 3                  ; tres digitos
VC_Digitos:
    mov  al, [esi]
    cmp  al, '0'
    jb   VC_Mal
    cmp  al, '9'
    ja   VC_Mal
    inc  esi
    loop VC_Digitos

    cmp  BYTE PTR [esi], 0       ; no debe haber caracteres de mas
    jne  VC_Mal
    clc
    jmp  VC_Fin
VC_Mal:
    stc
VC_Fin:
    pop  ecx
    pop  esi
    ret
ValidarCodigo ENDP

; ========================================== VALIDA QUE EL NOMBRE ESTE CORRECTO =================================================
ValidarNombre PROC
    push ebx
    push ecx
    push esi

    xor  ecx, ecx                ; ECX = longitud
    xor  ebx, ebx                ; EBX = 1 si hay algun caracter distinto de espacio
VN_Loop:
    mov  al, [esi]
    cmp  al, 0
    je   VN_Fin
    cmp  al, '|'
    je   VN_Mal                  ; '|' es el separador del archivo de texto
    cmp  al, 20h
    jb   VN_Mal                  ; caracter de control
    je   VN_Sig                  ; espacio: cuenta pero no marca
    mov  ebx, 1
VN_Sig:
    inc  ecx
    inc  esi
    jmp  VN_Loop
VN_Fin:
    cmp  ebx, 0
    je   VN_Mal                  ; vacio o solo espacios
    cmp  ecx, LEN_NOMBRE
    ja   VN_Mal                  ; demasiado largo
    clc
    jmp  VN_Out
VN_Mal:
    stc
VN_Out:
    pop  esi
    pop  ecx
    pop  ebx
    ret
ValidarNombre ENDP

; ========================== VERIFICAION DE LA CADENA PARA QUE CONVERTA A ENTEROS Y VALIDE QUE NO SEA CERO ===========================
CadenaAEntero PROC
    push ebx
    push ecx
    push edx
    push esi

    xor  ecx, ecx                ; ECX = acumulador
    cmp  BYTE PTR [esi], 0
    je   CE_Mal                  ; cadena vacia
CE_Loop:
    movzx ebx, BYTE PTR [esi]
    cmp  bl, 0
    je   CE_Ok
    cmp  bl, '0'
    jb   CE_Mal
    cmp  bl, '9'
    ja   CE_Mal
    sub  ebx, '0'                ; ASCII -> digito
    mov  eax, ecx
    mov  edx, 10
    mul  edx                     ; EDX:EAX = acumulador * 10 ; CF=1 si EDX<>0
    jc   CE_Mal                  ; desbordamiento
    add  eax, ebx                ; + digito
    jc   CE_Mal                  ; desbordamiento
    mov  ecx, eax
    inc  esi
    jmp  CE_Loop
CE_Ok:
    mov  eax, ecx
    clc
    jmp  CE_Fin
CE_Mal:
    xor  eax, eax
    stc
CE_Fin:
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    ret
CadenaAEntero ENDP

; ======================== CONVIERTE LOS VALOES PARA QUE SEAN CENTAVOS ===================================
PrecioACentavos PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi

    xor  ecx, ecx                ; ECX = pesos
    xor  edx, edx                ; EDX = valor de los decimales
    xor  ebx, ebx                ; EBX = cantidad de decimales leidos
    xor  edi, edi                ; EDI = cantidad de digitos enteros

PA_Enteros:
    movzx eax, BYTE PTR [esi]
    cmp  al, '0'
    jb   PA_FinEnteros
    cmp  al, '9'
    ja   PA_FinEnteros
    sub  eax, '0'
    imul ecx, ecx, 10            ; pesos = pesos*10 + digito
    add  ecx, eax
    cmp  ecx, 9999
    ja   PA_Mal                  ; fuera de rango (evita desbordar)
    inc  edi
    inc  esi
    jmp  PA_Enteros

PA_FinEnteros:
    cmp  edi, 0
    je   PA_Mal                  ; sin digitos enteros (vacio, '$5', '.50')
    movzx eax, BYTE PTR [esi]
    cmp  al, 0
    je   PA_Calcular             ; solo pesos
    cmp  al, '.'
    jne  PA_Mal                  ; simbolo / coma / letra
    inc  esi                     ; saltar el punto

PA_Decimales:
    movzx eax, BYTE PTR [esi]
    cmp  al, 0
    je   PA_FinDec
    cmp  al, '0'
    jb   PA_Mal
    cmp  al, '9'
    ja   PA_Mal
    cmp  ebx, 2
    jae  PA_Mal                  ; tercer decimal
    sub  eax, '0'
    imul edx, edx, 10
    add  edx, eax
    inc  ebx
    inc  esi
    jmp  PA_Decimales

PA_FinDec:
    cmp  ebx, 0
    je   PA_Mal                  ; "185." sin decimales
    cmp  ebx, 1
    jne  PA_Calcular
    imul edx, edx, 10            ; ".5" equivale a 50 centavos

PA_Calcular:
    imul ecx, ecx, 100           ; pesos -> centavos
    add  ecx, edx                ; + centavos
    cmp  ecx, 1
    jb   PA_Mal                  ; 0.00 no permitido
    cmp  ecx, MAX_PRECIO
    ja   PA_Mal
    mov  eax, ecx
    clc
    jmp  PA_Fin
PA_Mal:
    xor  eax, eax
    stc
PA_Fin:
    pop  edi
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    ret
PrecioACentavos ENDP

; =====================================================================
; EnteroACadena
;   Convierte un entero sin signo a cadena decimal ASCII.
;   Divide entre 10: el residuo + 30h es el digito (salen en orden
;   inverso, por eso se apilan y luego se sacan).
;   Entrada : EAX = valor, EDI = destino (minimo 11 bytes)
;   Salida  : cadena terminada en 00h; EDI queda apuntando a ese 00h
;   Modifica: EDI, flags   (EAX, EBX, ECX y EDX se conservan)
; =====================================================================
EnteroACadena PROC
    push eax
    push ebx
    push ecx
    push edx

    mov  ebx, 10
    xor  ecx, ecx                ; ECX = cantidad de digitos
EA_Div:
    xor  edx, edx                ; dividendo = EDX:EAX
    div  ebx                     ; EAX = cociente, EDX = residuo (0-9)
    push edx                     ; guardar digito
    inc  ecx
    cmp  eax, 0
    jne  EA_Div
EA_Sacar:
    pop  edx                     ; saca el digito mas significativo primero
    add  dl, '0'                 ; digito -> ASCII
    mov  [edi], dl
    inc  edi
    loop EA_Sacar
    mov  BYTE PTR [edi], 0       ; terminador

    pop  edx
    pop  ecx
    pop  ebx
    pop  eax
    ret
EnteroACadena ENDP

; =====================================================================
; CentavosACadena
;   Arma "$pesos.cc MXN" a partir de centavos (5 centavos -> "$0.05 MXN").
;   DIV entre 100: EAX = pesos, EDX = centavos.
;   Entrada : EAX = importe en centavos, EDI = destino (minimo 20 bytes)
;   Salida  : cadena terminada en 00h; EDI queda apuntando a ese 00h
;   Modifica: EDI, flags   (EAX, EBX y EDX se conservan)
; =====================================================================
CentavosACadena PROC
    push eax
    push ebx
    push edx

    mov  ebx, 100
    xor  edx, edx
    div  ebx                     ; EAX = pesos, EDX = centavos (0-99)
    push edx                     ; guardar centavos

    mov  BYTE PTR [edi], '$'
    inc  edi
    call EnteroACadena           ; escribe los pesos (EAX)

    mov  BYTE PTR [edi], '.'
    inc  edi
    pop  edx
    mov  eax, edx                ; EAX = centavos
    cmp  eax, 10
    jae  CC_DosDigitos
    mov  BYTE PTR [edi], '0'     ; residuo < 10 -> anteponer '0' (5 -> "05")
    inc  edi
CC_DosDigitos:
    call EnteroACadena

    mov  BYTE PTR [edi], ' '
    inc  edi
    mov  BYTE PTR [edi], 'M'
    inc  edi
    mov  BYTE PTR [edi], 'X'
    inc  edi
    mov  BYTE PTR [edi], 'N'
    inc  edi
    mov  BYTE PTR [edi], 0

    pop  edx
    pop  ebx
    pop  eax
    ret
CentavosACadena ENDP

; #####################################################################
;  REGISTRAR Y CONSULTAR
; #####################################################################

; =================================== VERIFICA Y CATALOGA PARA BUSCAR EL PRODUCTO POR CODIGO ==============================
BuscarPorCodigo PROC
    push eax
    push ecx
    push edx

    mov  esi, OFFSET catalogo    ; ESI = primer registro
    mov  ecx, numProd            ; ECX = registros por revisar
    cmp  ecx, 0
    je   BC_NoEnc
BC_Registro:
    xor  edx, edx                ; EDX = indice de caracter
BC_Comparar:
    mov  al, BYTE PTR [esi + edx]   ; caracter del registro (el codigo esta en el offset 0)
    cmp  al, BYTE PTR [edi + edx]   ; caracter del codigo buscado
    jne  BC_Siguiente            ; distinto: pasar al siguiente registro
    cmp  al, 0
    je   BC_Enc                  ; llegaron juntos al 00h: iguales
    inc  edx
    jmp  BC_Comparar
BC_Siguiente:
    add  esi, REC_SIZE           ; ESI avanza un registro completo
    dec  ecx
    jnz  BC_Registro
BC_NoEnc:
    stc
    jmp  BC_Fin
BC_Enc:
    clc
BC_Fin:
    pop  edx
    pop  ecx
    pop  eax
    ret
BuscarPorCodigo ENDP

;  ====================================== IMPRIME EN FORMATO UNA LISTA DE LOS PRODUCTOS ===================================
ImprimirProducto PROC
    pushad

    lea  edx, [esi + OFF_CODIGO]
    call WriteString
    mov  edx, OFFSET msgSep
    call WriteString

    ; --- nombre rellenado con espacios hasta 25 caracteres
    lea  ebx, [esi + OFF_NOMBRE]
    mov  edi, OFFSET bufSalida
    mov  ecx, LEN_NOMBRE
IP_Nombre:
    mov  al, [ebx]
    cmp  al, 0
    je   IP_Relleno
    mov  [edi], al
    inc  ebx
    inc  edi
    loop IP_Nombre
    jmp  IP_NombreFin
IP_Relleno:
    mov  BYTE PTR [edi], ' '
    inc  edi
    loop IP_Relleno
IP_NombreFin:
    mov  BYTE PTR [edi], 0
    mov  edx, OFFSET bufSalida
    call WriteString
    mov  edx, OFFSET msgSep
    call WriteString

    ; --- existencia alineada a la derecha en 3 columnas
    cmp  DWORD PTR [esi + OFF_EXIST], 10
    jae  IP_Pad2
    mov  edx, OFFSET msgEsp
    call WriteString
IP_Pad2:
    cmp  DWORD PTR [esi + OFF_EXIST], 100
    jae  IP_Exist
    mov  edx, OFFSET msgEsp
    call WriteString
IP_Exist:
    mov  edi, OFFSET bufSalida
    mov  eax, [esi + OFF_EXIST]
    call EnteroACadena
    mov  edx, OFFSET bufSalida
    call WriteString
    mov  edx, OFFSET msgSep
    call WriteString

    ; --- precio en MXN
    mov  edi, OFFSET bufSalida
    mov  eax, [esi + OFF_PRECIO]
    call CentavosACadena
    mov  edx, OFFSET bufSalida
    call WriteString
    call Crlf

    popad
    ret
ImprimirProducto ENDP

; ============================= MUESTRA EL INVENTARIO QUE TENEMOS ====================================
MostrarInventario PROC
    pushad

    cmp  numProd, 0
    jne  MI_Hay
    mov  edx, OFFSET msgInvVacio
    call WriteString
    jmp  MI_Fin
MI_Hay:
    mov  edx, OFFSET msgEncabezado
    call WriteString
    mov  esi, OFFSET catalogo    ; ESI = primer registro
    mov  ecx, numProd            ; ECX = cuantos imprimir
MI_Loop:
    call ImprimirProducto        ; ESI = registro actual
    add  esi, REC_SIZE           ; siguiente registro
    loop MI_Loop
MI_Fin:
    popad
    ret
MostrarInventario ENDP

; ======================== BUSCA EL PRODUCTO CON EL CODIGO DE 3 LETRAS Y 3 DIGITOS =======================================
BuscarProducto PROC
    pushad

    mov  edx, OFFSET msgPideBuscar
    call WriteString
    call LeerLinea
    mov  esi, OFFSET bufEntrada
    call ValidarCodigo           ; tambien rechaza la entrada vacia
    jc   BP_Malo
    mov  edi, OFFSET bufEntrada
    call BuscarPorCodigo         ; CF=0 -> ESI = registro
    jc   BP_NoEnc
    mov  edx, OFFSET msgEncabezado
    call WriteString
    call ImprimirProducto
    jmp  BP_Fin
BP_Malo:
    mov  edx, OFFSET msgCodigoMalo
    call WriteString
    jmp  BP_Fin
BP_NoEnc:
    mov  edx, OFFSET msgNoEnc
    call WriteString
BP_Fin:
    popad
    ret
BuscarProducto ENDP

; ============================ CAPTURA Y VALIDA UN NUEVO PRODUCTO ======================================
RegistrarProducto PROC
    pushad

    cmp  numProd, MAX_PROD
    jb   RP_Codigo
    mov  edx, OFFSET msgLleno
    call WriteString
    jmp  RP_Fin

    ; ---------- codigo ----------
RP_Codigo:
    mov  edx, OFFSET msgPideCodigo
    call WriteString
    call LeerLinea
    cmp  eax, 0
    je   RP_Cancelar             ; Enter vacio: cancelar el alta
    mov  esi, OFFSET bufEntrada
    call ValidarCodigo
    jc   RP_CodigoMalo
    mov  edi, OFFSET bufEntrada
    call BuscarPorCodigo
    jnc  RP_Duplicado            ; CF=0 -> ya existe
    mov  esi, OFFSET bufEntrada
    mov  edi, OFFSET tmpCodigo
    call CopiarCadena
    jmp  RP_Nombre
RP_CodigoMalo:
    mov  edx, OFFSET msgCodigoMalo
    call WriteString
    jmp  RP_Codigo
RP_Duplicado:
    mov  edx, OFFSET msgDuplicado
    call WriteString
    jmp  RP_Codigo

    ; ---------- nombre ----------
RP_Nombre:
    mov  edx, OFFSET msgPideNombre
    call WriteString
    call LeerLinea
    mov  esi, OFFSET bufEntrada
    call ValidarNombre
    jc   RP_NombreMalo
    mov  edi, OFFSET tmpNombre
    call CopiarCadena
    jmp  RP_Precio
RP_NombreMalo:
    mov  edx, OFFSET msgNombreMalo
    call WriteString
    jmp  RP_Nombre

    ; ---------- precio ----------
RP_Precio:
    mov  edx, OFFSET msgPidePrecio
    call WriteString
    call LeerLinea
    mov  esi, OFFSET bufEntrada
    call PrecioACentavos         ; EAX = centavos
    jc   RP_PrecioMalo
    mov  tmpPrecio, eax
    jmp  RP_Exist
RP_PrecioMalo:
    mov  edx, OFFSET msgPrecioMalo
    call WriteString
    jmp  RP_Precio

    ; ---------- existencia ----------
RP_Exist:
    mov  edx, OFFSET msgPideExist
    call WriteString
    call LeerLinea
    mov  esi, OFFSET bufEntrada
    call CadenaAEntero           ; EAX = valor
    jc   RP_ExistMala
    cmp  eax, MAX_EXIST
    ja   RP_ExistMala            ; fuera de 0..100
    mov  tmpExist, eax
    jmp  RP_Guardar
RP_ExistMala:
    mov  edx, OFFSET msgExistMala
    call WriteString
    jmp  RP_Exist

    ; ---------- confirmar el alta: copiar temporales al catalogo ----------
RP_Guardar:
    mov  eax, numProd
    mov  ebx, REC_SIZE
    mul  ebx                     ; EAX = numProd * REC_SIZE
    lea  ebx, [catalogo + eax]   ; EBX = direccion del nuevo registro

    mov  esi, OFFSET tmpCodigo
    lea  edi, [ebx + OFF_CODIGO]
    call CopiarCadena
    mov  esi, OFFSET tmpNombre
    lea  edi, [ebx + OFF_NOMBRE]
    call CopiarCadena
    mov  eax, tmpPrecio
    mov  [ebx + OFF_PRECIO], eax
    mov  eax, tmpExist
    mov  [ebx + OFF_EXIST], eax

    inc  numProd
    mov  hayCambios, 1
    mov  edx, OFFSET msgRegOk
    call WriteString
    jmp  RP_Fin

RP_Cancelar:
    mov  edx, OFFSET msgCancelado
    call WriteString
RP_Fin:
    popad
    ret
RegistrarProducto ENDP

; =====================================================================
; ImprimirNumero
;   Muestra un entero sin signo en decimal (usa EnteroACadena + WriteString).
;   Entrada : EAX = valor
;   Salida  : texto en pantalla
;   Modifica: ninguno (EAX, EDX y EDI se conservan)
; =====================================================================
ImprimirNumero PROC
    push edx
    push edi
    mov  edi, OFFSET bufSalida
    call EnteroACadena           ; EAX se conserva
    mov  edx, OFFSET bufSalida
    call WriteString
    pop  edi
    pop  edx
    ret
ImprimirNumero ENDP

; ==================== DESPLIEGA LA OPCION DE RECIBIR LA MERCANCIA PARA AÑADIR MAS UNIDADES DE PRODUCTOS YA EXISTENTES ===============
RecibirMercancia PROC
    pushad

    cmp  numProd, 0
    jne  RM_Codigo
    mov  edx, OFFSET msgInvVacio
    call WriteString
    jmp  RM_Fin

    ; ---------- localizar el producto ----------
RM_Codigo:
    mov  edx, OFFSET msgPideCodRec
    call WriteString
    call LeerLinea
    mov  esi, OFFSET bufEntrada
    call ValidarCodigo           ; tambien rechaza la entrada vacia
    jc   RM_CodigoMalo
    mov  edi, OFFSET bufEntrada
    call BuscarPorCodigo         ; CF=0 -> ESI = registro
    jc   RM_NoEnc
    mov  ebx, esi                ; EBX = registro del producto (ESI se reutiliza)

    ; ---------- capturar la cantidad ----------
RM_Cantidad:
    mov  edx, OFFSET msgPideCant
    call WriteString
    call LeerLinea
    cmp  eax, 0
    je   RM_Cancelar             ; Enter vacio: cancelar
    mov  esi, OFFSET bufEntrada
    call CadenaAEntero           ; EAX = cantidad, CF=1 si no es entero valido
    jc   RM_CantidadMala
    cmp  eax, 0
    je   RM_CantidadMala         ; debe ser mayor que cero

    ; ---------- comprobar limite y desbordamiento ----------
    add  eax, [ebx + OFF_EXIST]  ; nueva existencia = actual + cantidad
    jc   RM_Excede               ; desbordamiento de 32 bits
    cmp  eax, MAX_EXIST
    ja   RM_Excede               ; mas de 100 unidades

    ; ---------- todo valido: actualizar ----------
    mov  [ebx + OFF_EXIST], eax
    mov  hayCambios, 1
    mov  edx, OFFSET msgRecOk
    call WriteString
    mov  edx, OFFSET msgEncabezado
    call WriteString
    mov  esi, ebx
    call ImprimirProducto
    jmp  RM_Fin

RM_CantidadMala:
    mov  edx, OFFSET msgCantMala
    call WriteString
    jmp  RM_Cantidad

RM_Excede:
    mov  edx, OFFSET msgExcede
    call WriteString
    mov  edx, OFFSET msgActual
    call WriteString
    mov  eax, [ebx + OFF_EXIST]
    call ImprimirNumero
    call Crlf
    mov  edx, OFFSET msgPuedeRec
    call WriteString
    mov  eax, MAX_EXIST
    sub  eax, [ebx + OFF_EXIST]
    call ImprimirNumero
    call Crlf
    jmp  RM_Cantidad             ; otra captura; Enter vacio cancela

RM_CodigoMalo:
    mov  edx, OFFSET msgCodigoMalo
    call WriteString
    jmp  RM_Fin
RM_NoEnc:
    mov  edx, OFFSET msgNoEnc
    call WriteString
    jmp  RM_Fin
RM_Cancelar:
    mov  edx, OFFSET msgRecCancel
    call WriteString
RM_Fin:
    popad
    ret
RecibirMercancia ENDP

; ========================== APLICA EL DESCUENTO DE LA REGLA DEL NEGOCIO =======================================
AplicarDescuento PROC
    push ebx
    push ecx

    mov  ebx, eax                ; EBX = importe base
    xor  edx, edx                ; descuento = 0 por omision
    cmp  ecx, DESC_MIN_CANT
    jb   AD_Fin                  ; menos de 3 unidades: sin descuento

    mov  edx, DESC_PORC
    mul  edx                     ; EDX:EAX = base * 10
    jc   AD_Sin                  ; (no ocurre con los limites del sistema)
    mov  ecx, 100
    xor  edx, edx
    div  ecx                     ; EAX = base*10/100 (cociente), EDX = residuo (se descarta)
    mov  edx, eax                ; EDX = descuento
    sub  ebx, edx                ; importe final = base - descuento
    jmp  AD_Fin
AD_Sin:
    xor  edx, edx
AD_Fin:
    mov  eax, ebx                ; EAX = importe final
    pop  ecx
    pop  ebx
    ret
AplicarDescuento ENDP

; ====================== DESPLIEGA LA OPCION DE VENDER PARA TOMAR TODO EL PROGRESO =============================
VenderProducto PROC
    pushad

    cmp  numProd, 0
    jne  VP_Codigo
    mov  edx, OFFSET msgInvVacio
    call WriteString
    jmp  VP_Fin

    ; ---------- localizar el producto ----------
VP_Codigo:
    mov  edx, OFFSET msgPideCodVta
    call WriteString
    call LeerLinea
    mov  esi, OFFSET bufEntrada
    call ValidarCodigo
    jc   VP_CodigoMalo
    mov  edi, OFFSET bufEntrada
    call BuscarPorCodigo         ; CF=0 -> ESI = registro
    jc   VP_NoEnc
    mov  ebx, esi                ; EBX = registro del producto

    cmp  DWORD PTR [ebx + OFF_EXIST], 0
    je   VP_Agotado

    ; ---------- capturar la cantidad ----------
VP_Cantidad:
    mov  edx, OFFSET msgPideCantV
    call WriteString
    call LeerLinea
    cmp  eax, 0
    je   VP_Cancelar             ; Enter vacio: cancelar
    mov  esi, OFFSET bufEntrada
    call CadenaAEntero           ; EAX = cantidad
    jc   VP_CantidadMala
    cmp  eax, 0
    je   VP_CantidadMala         ; debe ser mayor que cero
    cmp  eax, [ebx + OFF_EXIST]
    ja   VP_SinExist             ; pide mas de lo que hay
    mov  ecx, eax                ; ECX = cantidad aceptada

    ; ---------- importe = precio x cantidad ----------
    mov  eax, [ebx + OFF_PRECIO]
    mul  ecx                     ; EDX:EAX = precio * cantidad
    jc   VP_Desborda             ; EDX <> 0: no cabe en 32 bits

    mov  tmpBase, eax            ; importe base
    call AplicarDescuento        ; EAX = importe final, EDX = descuento
    mov  tmpDesc, edx
    mov  esi, eax                ; ESI = importe final

    ; ---------- comprobar ingresos ANTES de modificar nada ----------
    mov  eax, ingresos
    add  eax, esi                ; ingresos nuevos
    jc   VP_Desborda             ; desbordamiento: rechazar la venta

    ; ---------- todo valido: aplicar los dos cambios juntos ----------
    mov  ingresos, eax
    sub  [ebx + OFF_EXIST], ecx
    mov  hayCambios, 1

    ; ---------- comprobante ----------
    mov  edx, OFFSET msgVentaOk
    call WriteString
    mov  edx, OFFSET msgVProducto
    call WriteString
    lea  edx, [ebx + OFF_NOMBRE]
    call WriteString
    call Crlf
    mov  edx, OFFSET msgVCantidad
    call WriteString
    mov  eax, ecx
    call ImprimirNumero
    call Crlf
    call MostrarDesglose         ; base, descuento (si hubo) e importe final
    jmp  VP_Fin

VP_CantidadMala:
    mov  edx, OFFSET msgCantMala
    call WriteString
    jmp  VP_Cantidad

VP_SinExist:
    mov  edx, OFFSET msgSinExist
    call WriteString
    mov  edx, OFFSET msgDisponible
    call WriteString
    mov  eax, [ebx + OFF_EXIST]
    call ImprimirNumero
    call Crlf
    jmp  VP_Cantidad             ; otra captura; Enter vacio cancela

VP_Desborda:
    mov  edx, OFFSET msgDesbVenta
    call WriteString
    jmp  VP_Fin
VP_Agotado:
    mov  edx, OFFSET msgAgotado
    call WriteString
    jmp  VP_Fin
VP_CodigoMalo:
    mov  edx, OFFSET msgCodigoMalo
    call WriteString
    jmp  VP_Fin
VP_NoEnc:
    mov  edx, OFFSET msgNoEnc
    call WriteString
    jmp  VP_Fin
VP_Cancelar:
    mov  edx, OFFSET msgVentaCanc
    call WriteString
VP_Fin:
    popad
    ret
VenderProducto ENDP

; =====================================================================
; MostrarResumen
;   Recorre el catalogo con ESI acumulando:
;     - unidades disponibles = suma de existencias
;     - valor del inventario = suma de (precio x existencia), en centavos
;   y muestra ademas los ingresos acumulados de la sesion.
;   Entrada : ninguna (usa catalogo, numProd e ingresos)
;   Salida  : resumen en pantalla
;   Modifica: ninguno (usa PUSHAD/POPAD)
;   Registros internos: EBX = unidades, EDI = valor (centavos), ECX = contador
; =====================================================================
MostrarResumen PROC
    pushad

    xor  ebx, ebx                ; EBX = unidades disponibles
    xor  edi, edi                ; EDI = valor del inventario (centavos)
    mov  esi, OFFSET catalogo    ; ESI = primer registro
    mov  ecx, numProd
    cmp  ecx, 0
    je   MR_Mostrar              ; sin productos: todo en cero

MR_Loop:
    mov  eax, [esi + OFF_EXIST]
    add  ebx, eax                ; unidades += existencia
    mov  eax, [esi + OFF_PRECIO]
    mul  DWORD PTR [esi + OFF_EXIST]   ; EDX:EAX = precio * existencia
    jc   MR_Desborda
    add  edi, eax                ; valor += precio * existencia
    jc   MR_Desborda
    add  esi, REC_SIZE           ; siguiente registro
    dec  ecx
    jnz  MR_Loop

MR_Mostrar:
    mov  edx, OFFSET msgResTitulo
    call WriteString

    mov  edx, OFFSET msgResProd
    call WriteString
    mov  eax, numProd
    call ImprimirNumero
    call Crlf

    mov  edx, OFFSET msgResUnid
    call WriteString
    mov  eax, ebx
    call ImprimirNumero
    call Crlf

    mov  edx, OFFSET msgResValor
    call WriteString
    mov  eax, edi                ; EAX = valor (antes de reutilizar EDI)
    mov  edi, OFFSET bufSalida
    call CentavosACadena
    mov  edx, OFFSET bufSalida
    call WriteString
    call Crlf

    mov  edx, OFFSET msgResIngr
    call WriteString
    mov  eax, ingresos
    mov  edi, OFFSET bufSalida
    call CentavosACadena
    mov  edx, OFFSET bufSalida
    call WriteString
    call Crlf
    jmp  MR_Fin

MR_Desborda:
    mov  edx, OFFSET msgDesbResumen
    call WriteString
MR_Fin:
    popad
    ret
MostrarResumen ENDP

; #####################################################################
;  GUARDAR Y CARGAR (archivo binario inventario.dat)
; #####################################################################

; =====================================================================
; PreguntarSN
;   Muestra un mensaje y repite hasta recibir S/s o N/n.
;   Entrada : EDX = mensaje terminado en 00h
;   Salida  : EAX = 1 si respondio S, 0 si respondio N
;   Modifica: EAX, flags   (ECX y EDX se conservan)
; =====================================================================
PreguntarSN PROC
    push ecx
    push edx
PS_Preguntar:
    call WriteString             ; EDX = mensaje (LeerLinea conserva EDX)
    call LeerLinea
    cmp  eax, 1
    jne  PS_Preguntar
    movzx eax, bufEntrada
    cmp  al, 'S'
    je   PS_Si
    cmp  al, 's'
    je   PS_Si
    cmp  al, 'N'
    je   PS_No
    cmp  al, 'n'
    je   PS_No
    jmp  PS_Preguntar
PS_Si:
    mov  eax, 1
    jmp  PS_Fin
PS_No:
    xor  eax, eax
PS_Fin:
    pop  edx
    pop  ecx
    ret
PreguntarSN ENDP

; =====================================================================
; ComparaCodigo
;   Compara los 8 bytes de dos campos de codigo.
;   Entrada : ESI = codigo 1, EDI = codigo 2
;   Salida  : ZF = 1 si son iguales, ZF = 0 si son distintos
;   Modifica: flags   (EAX, ECX, ESI y EDI se conservan)
; =====================================================================
ComparaCodigo PROC
    push eax
    push ecx
    push esi
    push edi
    mov  ecx, 8
CK_Loop:
    mov  al, [esi]
    cmp  al, [edi]
    jne  CK_Fin                  ; ZF = 0: distintos
    inc  esi
    inc  edi
    loop CK_Loop
    cmp  al, al                  ; iguales: forzar ZF = 1 (INC lo habia alterado)
CK_Fin:
    pop  edi                     ; POP no altera flags
    pop  esi
    pop  ecx
    pop  eax
    ret
ComparaCodigo ENDP

; =====================================================================
; LeerCampo
;   Copia caracteres del texto hasta encontrar un terminador de campo:
;   '|', CR (0Dh), LF (0Ah) o 00h. El terminador NO se copia.
;   Entrada : ESI = posicion actual del texto, EDI = destino,
;             ECX = maximo de caracteres permitidos en el campo
;   Salida  : CF = 0: campo copiado en [EDI] terminado en 00h y ESI queda
;                     apuntando al terminador que lo cerro
;             CF = 1: el campo supera el maximo permitido
;   Modifica: ESI, flags   (EAX, ECX y EDI se conservan)
; =====================================================================
LeerCampo PROC
    push eax
    push ecx
    push edi
LC_Loop:
    mov  al, [esi]
    cmp  al, '|'
    je   LC_Fin
    cmp  al, 0Dh
    je   LC_Fin
    cmp  al, 0Ah
    je   LC_Fin
    cmp  al, 0
    je   LC_Fin
    cmp  ecx, 0
    je   LC_Largo                ; ya no caben mas caracteres
    mov  [edi], al
    inc  esi
    inc  edi
    dec  ecx
    jmp  LC_Loop
LC_Fin:
    mov  BYTE PTR [edi], 0       ; cerrar el campo con 00h
    clc
    jmp  LC_Salir
LC_Largo:
    stc
LC_Salir:
    pop  edi
    pop  ecx
    pop  eax
    ret
LeerCampo ENDP

; =====================================================================
; AgregarCadena
;   Agrega una cadena (sin su 00h) al final del texto que se esta armando.
;   Entrada : EDX = cadena origen terminada en 00h, EDI = posicion de escritura
;   Salida  : EDI queda despues del ultimo caracter copiado
;   Modifica: EDI, flags   (EAX y EDX se conservan)
; =====================================================================
AgregarCadena PROC
    push eax
    push edx
AG_Loop:
    mov  al, [edx]
    cmp  al, 0
    je   AG_Fin
    mov  [edi], al
    inc  edx
    inc  edi
    jmp  AG_Loop
AG_Fin:
    pop  edx
    pop  eax
    ret
AgregarCadena ENDP

; =====================================================================
; ParsearTexto
;   Interpreta el texto de bufArchivo (terminado en 00h) y lo convierte en
;   registros dentro de tmpCatalogo, SIN tocar el catalogo real.
;   Valida: marca GSV1, maximo 10 productos, formato de 4 campos por linea,
;   codigo, nombre, precio 1..999999, existencia 0..100 y codigos unicos.
;   Entrada : bufArchivo con el texto leido
;   Salida  : CF = 0 valido: tmpCatalogo y tmpCuenta listos
;             CF = 1 invalido: EAX = codigo de error (1..5)
;   Modifica: EAX, flags   (EBX, ECX, EDX, ESI y EDI se conservan)
;   Registros internos: ESI = posicion en el texto, EBX = registro destino
; =====================================================================
ParsearTexto PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; ---------- limpiar el catalogo temporal ----------
    mov  edi, OFFSET tmpCatalogo
    mov  ecx, MAX_PROD * REC_SIZE
    xor  eax, eax
    cld
    rep  stosb
    mov  tmpCuenta, 0

    ; ---------- primera linea: GSV1 ----------
    cmp  DWORD PTR [bufArchivo], MAGIC
    jne  PT_E1
    mov  esi, OFFSET bufArchivo + 4
    mov  al, [esi]
    cmp  al, 0
    je   PT_Ok                   ; solo la marca: catalogo vacio
    cmp  al, 0Dh
    je   PT_Saltar
    cmp  al, 0Ah
    jne  PT_E1                   ; tras GSV1 debe haber fin de linea

    ; ---------- saltar fines de linea (y lineas en blanco) ----------
PT_Saltar:
    mov  al, [esi]
    cmp  al, 0Dh
    je   PT_Avanza
    cmp  al, 0Ah
    jne  PT_Linea
PT_Avanza:
    inc  esi
    jmp  PT_Saltar

    ; ---------- una linea = un producto ----------
PT_Linea:
    cmp  al, 0
    je   PT_Ok                   ; fin del texto
    mov  eax, tmpCuenta
    cmp  eax, MAX_PROD
    jae  PT_E2                   ; un producto 11
    mov  edx, REC_SIZE
    mul  edx                     ; EAX = tmpCuenta * REC_SIZE
    lea  ebx, [tmpCatalogo + eax]   ; EBX = registro destino

    ; campo 1: codigo (hasta 7 caracteres)
    lea  edi, [ebx + OFF_CODIGO]
    mov  ecx, LEN_CODIGO
    call LeerCampo
    jc   PT_E3
    cmp  BYTE PTR [esi], '|'
    jne  PT_E3
    inc  esi

    ; campo 2: nombre (hasta 25 caracteres)
    lea  edi, [ebx + OFF_NOMBRE]
    mov  ecx, LEN_NOMBRE
    call LeerCampo
    jc   PT_E3
    cmp  BYTE PTR [esi], '|'
    jne  PT_E3
    inc  esi

    ; campo 3: precio en centavos
    mov  edi, OFFSET bufCampo
    mov  ecx, 10
    call LeerCampo
    jc   PT_E3
    cmp  BYTE PTR [esi], '|'
    jne  PT_E3
    inc  esi
    push esi                     ; CadenaAEntero necesita ESI = cadena
    mov  esi, OFFSET bufCampo
    call CadenaAEntero
    pop  esi                     ; POP no altera CF
    jc   PT_E3
    cmp  eax, 1
    jb   PT_E4
    cmp  eax, MAX_PRECIO
    ja   PT_E4
    mov  [ebx + OFF_PRECIO], eax

    ; campo 4: existencia (ultimo: no debe seguir un '|')
    mov  edi, OFFSET bufCampo
    mov  ecx, 10
    call LeerCampo
    jc   PT_E3
    cmp  BYTE PTR [esi], '|'
    je   PT_E3                   ; sobran campos
    push esi
    mov  esi, OFFSET bufCampo
    call CadenaAEntero
    pop  esi
    jc   PT_E3
    cmp  eax, MAX_EXIST
    ja   PT_E4
    mov  [ebx + OFF_EXIST], eax

    ; validar formato de codigo y nombre
    push esi
    lea  esi, [ebx + OFF_CODIGO]
    call ValidarCodigo
    pop  esi
    jc   PT_E4
    push esi
    lea  esi, [ebx + OFF_NOMBRE]
    call ValidarNombre
    pop  esi
    jc   PT_E4

    ; codigo repetido entre los registros anteriores
    mov  edi, OFFSET tmpCatalogo
PT_Duplicado:
    cmp  edi, ebx
    jae  PT_Siguiente            ; llego al registro actual
    push esi
    mov  esi, ebx                ; ComparaCodigo: ESI = codigo actual, EDI = previo
    call ComparaCodigo
    pop  esi                     ; POP no altera ZF
    je   PT_E5
    add  edi, REC_SIZE
    jmp  PT_Duplicado

PT_Siguiente:
    inc  tmpCuenta
    jmp  PT_Saltar

PT_Ok:
    clc
    jmp  PT_Fin
PT_E1: mov eax, 1
       jmp PT_Error
PT_E2: mov eax, 2
       jmp PT_Error
PT_E3: mov eax, 3
       jmp PT_Error
PT_E4: mov eax, 4
       jmp PT_Error
PT_E5: mov eax, 5
PT_Error:
    stc
PT_Fin:
    pop  edi
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    ret
ParsearTexto ENDP

; ========================== GUARDA EL INVENTARIO EN UN ARCHIVO .TXT ==========================================
GuardarCatalogo PROC
    pushad

    ; ---------- armar el texto en memoria ----------
    mov  DWORD PTR [bufArchivo], MAGIC       ; "GSV1"
    mov  edi, OFFSET bufArchivo + 4
    mov  BYTE PTR [edi], 0Dh
    inc  edi
    mov  BYTE PTR [edi], 0Ah
    inc  edi

    mov  esi, OFFSET catalogo    ; ESI = primer registro
    mov  ecx, numProd
    cmp  ecx, 0
    je   GC_Escribir             ; catalogo vacio: solo la marca
GC_Registro:
    lea  edx, [esi + OFF_CODIGO]
    call AgregarCadena           ; codigo
    mov  BYTE PTR [edi], '|'
    inc  edi
    lea  edx, [esi + OFF_NOMBRE]
    call AgregarCadena           ; nombre
    mov  BYTE PTR [edi], '|'
    inc  edi
    mov  eax, [esi + OFF_PRECIO]
    call EnteroACadena           ; centavos (EDI queda en el 00h)
    mov  BYTE PTR [edi], '|'
    inc  edi
    mov  eax, [esi + OFF_EXIST]
    call EnteroACadena           ; existencia
    mov  BYTE PTR [edi], 0Dh     ; fin de linea CR LF
    inc  edi
    mov  BYTE PTR [edi], 0Ah
    inc  edi
    add  esi, REC_SIZE           ; siguiente registro
    dec  ecx
    jnz  GC_Registro

GC_Escribir:
    sub  edi, OFFSET bufArchivo  ; EDI = longitud del texto
    mov  bytesArchivo, edi

    ; ---------- crear y escribir ----------
    mov  edx, OFFSET nombreArchivo
    call CreateOutputFile        ; EAX = handle o INVALID_HANDLE_VALUE
    cmp  eax, INVALID_HANDLE_VALUE
    je   GC_ErrCrear
    mov  ebx, eax                ; EBX = handle

    mov  edx, OFFSET bufArchivo
    mov  ecx, bytesArchivo
    call WriteToFile             ; EAX = bytes realmente escritos
    mov  esi, eax                ; guardar el resultado

    mov  eax, ebx
    call CloseFile               ; EAX <> 0 si cerro bien
    cmp  eax, 0
    je   GC_ErrCerrar
    cmp  esi, bytesArchivo
    jne  GC_ErrEscr              ; no se escribieron todos los bytes

    mov  hayCambios, 0
    mov  edx, OFFSET msgGuardOk
    call WriteString
    mov  eax, numProd
    call ImprimirNumero
    call Crlf
    jmp  GC_Fin

GC_ErrCrear:
    mov  edx, OFFSET msgErrCrear
    call WriteString
    jmp  GC_Fin
GC_ErrCerrar:
    mov  edx, OFFSET msgErrCerrar
    call WriteString
    jmp  GC_Fin
GC_ErrEscr:
    mov  edx, OFFSET msgErrEscr
    call WriteString
GC_Fin:
    popad
    ret
GuardarCatalogo ENDP

; ============================ CARGA EL DOCUMENTO .TXT PARA AÑADIRLO AL INVENTARIO ================================
CargarCatalogo PROC
    pushad

    cmp  hayCambios, 0
    je   CA_Abrir
    mov  edx, OFFSET msgConfCargar
    call PreguntarSN             ; EAX = 1 si el usuario acepta
    cmp  eax, 0
    je   CA_Cancelar

CA_Abrir:
    mov  edx, OFFSET nombreArchivo
    call OpenInputFile           ; EAX = handle o INVALID_HANDLE_VALUE
    cmp  eax, INVALID_HANDLE_VALUE
    je   CA_NoExiste
    mov  ebx, eax                ; EBX = handle

    mov  edx, OFFSET bufArchivo
    mov  ecx, FILE_MAX + 1       ; capacidad: un byte mas que el maximo valido
    call ReadFromFile            ; CF=0: EAX = bytes leidos; CF=1: error
    jc   CA_ErrLeer
    mov  esi, eax                ; ESI = bytes leidos (distinto de la capacidad)

    mov  eax, ebx
    call CloseFile
    cmp  esi, FILE_MAX
    ja   CA_Grande               ; leyo mas del maximo valido
    mov  BYTE PTR [bufArchivo + esi], 0   ; 00h tras los datos: el texto es una cadena

    call ParsearTexto            ; CF=1 -> EAX = codigo de error
    jc   CA_Invalido

    ; ---------- texto valido: reemplazar el catalogo ----------
    mov  eax, tmpCuenta
    mov  numProd, eax
    mov  esi, OFFSET tmpCatalogo
    mov  edi, OFFSET catalogo
    mov  ecx, MAX_PROD * REC_SIZE
    cld
    rep  movsb                   ; copiar el catalogo temporal ya validado

    mov  hayCambios, 0
    mov  edx, OFFSET msgCargaOk
    call WriteString
    mov  eax, numProd
    call ImprimirNumero
    call Crlf
    jmp  CA_Fin

CA_Grande:
    mov  eax, 6
    jmp  CA_Invalido
CA_ErrLeer:
    mov  eax, ebx
    call CloseFile
    mov  edx, OFFSET msgErrLeer
    call WriteString
    jmp  CA_Fin
CA_Invalido:
    mov  edx, OFFSET msgArchInv
    call WriteString
    mov  edx, [tablaErrores + eax * 4]   ; motivo segun el codigo
    call WriteString
    mov  edx, OFFSET msgNoCambio
    call WriteString
    jmp  CA_Fin
CA_NoExiste:
    mov  edx, OFFSET msgNoArchivo
    call WriteString
    jmp  CA_Fin
CA_Cancelar:
    mov  edx, OFFSET msgCargaCanc
    call WriteString
CA_Fin:
    popad
    ret
CargarCatalogo ENDP

; =====================================================================
; MostrarDesglose
;   Muestra importe base, descuento (o "ninguno") e importe final.
;   Entrada : variables tmpBase y tmpDesc (centavos)
;   Salida  : texto en pantalla
;   Modifica: ninguno (usa PUSHAD/POPAD)
; =====================================================================
MostrarDesglose PROC
    pushad

    mov  edx, OFFSET msgVBase
    call WriteString
    mov  eax, tmpBase
    mov  edi, OFFSET bufSalida
    call CentavosACadena
    mov  edx, OFFSET bufSalida
    call WriteString
    call Crlf

    cmp  tmpDesc, 0
    je   MD_Sin
    mov  edx, OFFSET msgVDesc
    call WriteString
    mov  eax, tmpDesc
    mov  edi, OFFSET bufSalida
    call CentavosACadena
    mov  edx, OFFSET bufSalida
    call WriteString
    call Crlf
    jmp  MD_Final
MD_Sin:
    mov  edx, OFFSET msgVSinDesc
    call WriteString

MD_Final:
    mov  edx, OFFSET msgVFinal
    call WriteString
    mov  eax, tmpBase
    sub  eax, tmpDesc            ; final = base - descuento
    mov  edi, OFFSET bufSalida
    call CentavosACadena
    mov  edx, OFFSET bufSalida
    call WriteString
    call Crlf

    popad
    ret
MostrarDesglose ENDP

; ========================== EXPLICA EL DESCUENTO QUE SE HACE ==================================
ReglaNegocio PROC
    pushad

    mov  edx, OFFSET msgReglaTxt
    call WriteString

    cmp  numProd, 0
    jne  RG_Codigo
    mov  edx, OFFSET msgInvVacio
    call WriteString
    jmp  RG_Fin

RG_Codigo:
    mov  edx, OFFSET msgPideCodCot
    call WriteString
    call LeerLinea
    mov  esi, OFFSET bufEntrada
    call ValidarCodigo
    jc   RG_CodigoMalo
    mov  edi, OFFSET bufEntrada
    call BuscarPorCodigo         ; CF=0 -> ESI = registro
    jc   RG_NoEnc
    mov  ebx, esi                ; EBX = registro del producto

RG_Cantidad:
    mov  edx, OFFSET msgPideCantCot
    call WriteString
    call LeerLinea
    cmp  eax, 0
    je   RG_Fin                  ; Enter vacio: terminar
    mov  esi, OFFSET bufEntrada
    call CadenaAEntero
    jc   RG_CantidadMala
    cmp  eax, 0
    je   RG_CantidadMala
    cmp  eax, MAX_EXIST
    ja   RG_CantidadMala
    mov  ecx, eax                ; ECX = unidades a cotizar

    mov  eax, [ebx + OFF_PRECIO]
    mul  ecx                     ; importe base = precio * cantidad
    jc   RG_CantidadMala
    mov  tmpBase, eax
    call AplicarDescuento        ; EAX = final, EDX = descuento
    mov  tmpDesc, edx

    mov  edx, OFFSET msgCotiza
    call WriteString
    call MostrarDesglose
    jmp  RG_Cantidad             ; otra cotizacion

RG_CantidadMala:
    mov  edx, OFFSET msgCantMalaCot
    call WriteString
    jmp  RG_Cantidad
RG_CodigoMalo:
    mov  edx, OFFSET msgCodigoMalo
    call WriteString
    jmp  RG_Fin
RG_NoEnc:
    mov  edx, OFFSET msgNoEnc
    call WriteString
RG_Fin:
    popad
    ret
ReglaNegocio ENDP

Pendiente PROC
    push edx
    mov  edx, OFFSET msgPend
    call WriteString
    pop  edx
    ret
Pendiente ENDP

END main