# Sistema de Ventas e Inventario – Game Store (Unidad 2)
* **Materia:** Lenguajes de Interfaz
* **Alumno:** Yahir Luna Beltrán
* **Docente:** Dr. José Luis Medina Jiménez


### Informe del Proyecto

### Giro y Propósito del Sistema
* **Negocio:** Tienda de videojuegos
* **Objetivo:** Permitir el registro de productos, consulta individual y general, recepción de mercancía, procesamiento de ventas con cálculo automático de promociones, despliegue de resúmenes operativos y persistencia en disco.

### Regla Adicional del Negocio
* **Descuento por Volumen:** Al vender **3 o más unidades** de un mismo producto, se aplica automáticamente un **10% de descuento** sobre el importe base de la transacción
* **Implementación:** El cálculo se realiza mediante división entera (`DIV 100`), descartando las fracciones de centavo para mantener la exactitud de los montos sin requerir operaciones de punto flotante

### Organización de Datos en Memoria
* **Estructura Contigua:** El catálogo se almacena en el segmento `.data` como un arreglo lineal de 10 registros contiguos de tamaño fijo (**44 bytes por producto**).
* **Distribución de Campos por Registro:**
  * `Offset  0` (8 bytes): Código del producto (`ABC-123` + terminador `00h`).
  * `Offset  8` (26 bytes): Nombre del videojuego (hasta 25 caracteres + terminador `00h`).
  * `Offset 34` (2 bytes): Relleno de alineación de memoria para asegurar que los valores numéricos queden alineados a 32 bits.
  * `Offset 36` (4 bytes / `DWORD`): Precio unitario almacenado en **centavos enteros** (ej. $1,299.50 \rightarrow 129950$).
  * `Offset 40` (4 bytes / `DWORD`): Existencia actual en almacén (unidades de 0 a 100).
* **Navegación:** Se emplea el registro **`ESI`** como puntero base al catálogo, desplazándose dinámicamente entre registros mediante saltos de `REC_SIZE` (44 bytes).

### Formato y Persistencia en Archivo
* **Estructura del Archivo (`inventario.txt`):**
  * **Firma de Encabezado:** La primera línea contiene la marca de seguridad `GSV1` (`31565347h`), la cual se valida durante la lectura para evitar la carga de archivos corruptos o ajenos al sistema.
  * **Registros de Datos:** Cada producto ocupa una línea con los campos delimitados por plecas (`|`): `CODIGO|NOMBRE|CENTAVOS|EXISTENCIA`.
  * **Fin de Línea:** Formato estándar `CR LF` (`0Dh, 0Ah`).
* **Estrategia de Carga Segura:** Durante la lectura del archivo, los datos se parsean y validan en un **catálogo temporal** (`tmpCatalogo`). El catálogo activo en RAM solo se reemplaza si la totalidad del archivo pasa las comprobaciones de formato, límites y ausencia de códigos duplicados.

