---
title: Fuel y límites de ejecución
description: Qué cuenta el Fuel, por qué los programas con arrays y structs necesitan presupuestos mayores y cómo se comporta el agotamiento de Fuel.
---

Piensa en **Fuel** (`--fuel N` en `browniec run`) como fichas prepagadas que la VM gasta conforme se ejecuta tu código. Cada instrucción, paso de bucle y configuración de arena descuenta una cantidad fija de Fuel.

## Qué es (y qué no es) el Fuel

- **Un presupuesto determinista de operaciones**: El mismo programa con el mismo `--fuel` siempre ejecuta la misma cantidad de trabajo y se detiene en el mismo punto.
- **No es un temporizador de reloj real (wall-clock)**: Fuel cuenta unidades lógicas de trabajo de la VM, no milisegundos.
- **Aislamiento de procesos en Windows**: AppContainer y los límites de Job se aplican al ejecutar código escalar con `--isolated`.

## Valor predeterminado (`256`) frente a presupuestos para arrays y registros

Si omites `--fuel`, la CLI usa `256` (el rango aceptado es `0..16000000`).

- Las reglas escalares simples (`answer.brc`, `branches.brc`) terminan sobradamente dentro de `256`.
- Los bucles (`loops.brc`) necesitan un aumento moderado, como `--fuel 1000`.
- **Arrays y registros**: Preparar la arena de agregados de 64 KiB antes de que se ejecute `main()` cuesta **65 537 de Fuel**, así que pasa `--fuel 100000` (o `--fuel 1000000` para recursión de registros y représtamo de slices).

## Qué ocurre cuando se agota el Fuel

Cuando el Fuel llega a cero:

1. La ejecución se detiene limpiamente sin devolver un `return_i32` parcial.
2. La CLI termina con el estado **`5`**.
3. Con `--json`, `"status"` es `"error"`, `"return_i32"` es `null` y `"error.kind"` es `"fuel"` con el `byte_offset` en el código fuente basado en cero:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"error","return_i32":null,"error":{"kind":"fuel","byte_offset":188}}
```

## Otros límites de ejecución

- **Profundidad de pila de llamadas**: Hasta `32` marcos anidados (`frame_limit`).
- **Tamaño del código fuente**: `4096` bytes en UTF-8 (`compile_limit`, salida `3`).
- **Trampas en ejecución**: El desbordamiento de enteros (`overflow`), la división por cero (`zero_divisor`) y el acceso fuera de rango (`bounds`) se detienen limpiamente con código de salida `5`.
