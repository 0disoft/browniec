---
title: Introducción
description: Por qué existe Brownie C, qué sintaxis comparte con Fairy C y qué funciona hoy en la CLI pública.
---

A veces una aplicación necesita evaluar una regla pequeña o validar unos bytes sin permitir que ese código toque archivos, abra sockets ni se quede atascado en un bucle infinito.

Brownie C es un **lenguaje embebido de reglas y transformación de bytes + VM acotada** construido en Fairy C precisamente para ese tipo de evaluación contenida.

## Qué hace diferente a Brownie C

- **Sintaxis familiar similar a Fairy C**: Usa `let`/`var`, `if`/`switch`, `for`/`while`, `struct` simples y `Option`/`Result`.
- **Restringido a propósito**: Quedan excluidos los punteros sin procesar (`ptr`), la FFI arbitraria con C, los tipos `resource` de usuario, los números de punto flotante, los hilos y el recolector de basura (GC).
- **Aritmética verificada y medición con `--fuel`**: El desbordamiento de enteros, la división por cero y los accesos fuera de rango en arrays se detienen limpiamente, mientras que `--fuel` limita el total de operaciones de la VM.
- **Retorno de datos, no código de salida del sistema operativo**: Devolver `77` desde `fn i32 main()` informa `return_i32=77` manteniendo el código de salida del proceso CLI en `0`.

## CLI pública frente a lo que sigue siendo interno o planificado

La CLI pública actual de `browniec` trabaja sobre archivos `.brc` individuales (de hasta 4096 bytes en UTF-8) mediante `check`, `run [--fuel N]` e `inspect --ir`, con soporte para escalares, `Option`/`Result` con `?`, arrays de tamaño fijo, structs simples, literales de bytes y texto, y slices (`ref u8[]`, `ref mut T[]`).

Las API internas `Engine`/`Instance`, el tipo `Buffer` para el huésped, los trabajadores con `--isolated` (AppContainer/Job), las flags `--project`/`--input` y la ABI de incrustación en C (`embed: false`, `restricted: false`) son componentes internos del repositorio o hitos planificados. Ten en cuenta que **Fuel cuenta operaciones de la VM: no es un límite de tiempo real (wall-clock) ni un entorno de aislamiento de seguridad del sistema operativo**.
