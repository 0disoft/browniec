---
title: Uso de la CLI y errores frecuentes
description: Comandos públicos de browniec, códigos de salida y soluciones rápidas para los errores más habituales.
---

La CLI pública procesa un archivo fuente a la vez. `check` verifica sin ejecutar, `run` llama a `main()` y `eval-i32` llama a `evaluate(i32)`. La inspección compila y verifica el código sin ejecutarlo.

## Comandos públicos

<!-- cli-output:start -->
| Comando | Opción de salida | Canal | Esquema |
| --- | --- | --- | --- |
| `browniec --version` | — | `stdout` | — |
| `browniec --version` | `--json` | `stdout` | `browniec.version/v1` |
| `browniec check SOURCE` | — | `stderr` | — |
| `browniec check SOURCE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | — | `stderr` | — |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | — | `stderr` | — |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE` | — | `stderr` | — |
| `browniec check --project FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check --project FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin] [--output FILE]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin] [--output FILE]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec eval-i32 SOURCE N [--fuel N]` | — | `stderr` | — |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec inspect SOURCE --ir` | — | `stdout` | — |
| `browniec inspect SOURCE --ir` | `--json` | `stdout` | `browniec.ir/v1` |
| `browniec inspect SOURCE --limits` | `--json` | `stdout` | `browniec.limits/v1` |
<!-- cli-output:end -->

La tabla muestra la salida en caso de éxito. Un guion en la columna de opciones indica el modo de texto predeterminado. Los errores de texto van a stderr. Las opciones JSON escriben en stdout un solo objeto, también para los errores de código fuente.

## Códigos de salida

- **`0`**: Completado limpiamente (incluso cuando `return_i32` del huésped es distinto de cero)
- **`2`**: Flags de CLI incorrectas o `--fuel` fuera de `0..16000000`
- **`3`**: Error de compilación/tipos/préstamos o `compile_limit` superado
- **`4`**: Flag no implementada (`--isolated` → `unavailable`)
- **`5`**: Trampa en tiempo de ejecución o cuota agotada (`fuel`, `overflow`, `zero_divisor`, `bounds`, `frame_limit`)
- **`6`**: Error interno de invariante del compilador o de la VM
- **`7`**: Error de E/S al leer el archivo fuente (`input_io`)

## Errores frecuentes y soluciones

1. **Error `fuel` (salida `5`) en bucles o arrays**: Recuerda que la inicialización de arrays cuesta `65 537` de Fuel antes de que se ejecute `main()`. Pasa `--fuel 100000` o `--fuel 1000000`.
2. **`unavailable` (salida `4`) con `--isolated`**: Es el comportamiento esperado hoy: el aislamiento de trabajadores del sistema operativo aún no está habilitado (`restricted: false`).
3. **`compile_limit` (salida `3`) en archivos grandes**: La entrada de la CLI pública está limitada a `4096` bytes en UTF-8, `1024` tokens, `16` funciones y `256` instrucciones.
4. **Trampa en tiempo de ejecución (salida `5`)**: Revisa `error.kind` y `byte_offset` con `--json` para localizar `overflow`, `zero_divisor` o `bounds` fuera de rango.
