---
title: Uso de la CLI y errores frecuentes
description: Comandos públicos de browniec, códigos de salida y soluciones rápidas para los errores más habituales.
---

La CLI pública de `browniec` trabaja directamente sobre archivos `.brc` individuales con cuatro comandos principales: `--version`, `check`, `run` e `inspect`.

## Comandos públicos

| Comando | Propósito |
| --- | --- |
| `browniec --version [--json]` | Imprime los perfiles activos y los ajustes de Fuel predeterminado y máximo |
| `browniec check file.brc [--json]` | Verifica la sintaxis, los tipos y los préstamos sin ejecutar |
| `browniec run file.brc [--fuel N] [--json]` | Ejecuta `fn i32 main()` bajo el presupuesto de Fuel `N` (predeterminado `256`, máximo `16000000`) |
| `browniec inspect file.brc --ir [--json]` | Imprime el diagnóstico del IR privado generado sin ejecutar |

El modo de texto escribe líneas de estado (`checked`, `return_i32=77`) en stderr y deja stdout vacío. Añadir `--json` emite un objeto JSON (`browniec.result/v1`) en stdout con stderr vacío.

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
