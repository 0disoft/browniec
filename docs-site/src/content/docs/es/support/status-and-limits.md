---
title: Soporte actual y limitaciones
description: Límites de capacidad públicos, estado en Windows frente a Linux y características permanentemente fuera del alcance de Brownie C.
---

Brownie C mantiene límites estrictos de compilación y tiempo de ejecución a propósito para que la evaluación del código huésped siga siendo pequeña y predecible. Esto es lo que soporta hoy la CLI pública.

> **Referencia verificada**: `2026-11-16` · commit [`f5e13f9`](https://github.com/0disoft/browniec/commit/f5e13f9)

## Qué funciona hoy

En `browniec --version --json`, `"core": true` refleja los subconjuntos experimentales públicos activos (escalares, arrays fijos, structs simples, literales de bytes y texto, y slices verificados), no la finalización completa del lenguaje.

## Capacidades de la CLI pública

| Elemento | Límite actual |
| --- | --- |
| Entrada de código fuente | 1 archivo `.brc` en UTF-8 de hasta `4096` bytes (`1024` tokens) |
| Punto de entrada | `fn i32 main()` sin argumentos (todavía sin flag `--input` en la CLI) |
| Funciones e IR | `16` funciones, `128` registros globales, `256` instrucciones |
| Marcos de llamada | `32` marcos anidados |
| Arrays y structs | `16` sitios de agregados, hasta `4096` elementos por array, arena de `64 KiB` |
| Presupuesto de Fuel | Predeterminado `256`, máximo `16 000 000` |

## Estado de plataformas y características

- **Windows 11 x64 (`MSVC`)**: Entorno principal de desarrollo y ejecución.
- **Linux**: Existen metadatos de compilación cruzada fijados en `toolchain.json`, pero la compilación y ejecución nativas en Linux siguen sin estar verificadas.
- Windows admite el aislamiento con AppContainer y Job para `check` y `run` escalares de un solo archivo. `restricted: false` y `embed: false` indican que el perfil restringido ampliado y la incrustación en C están pendientes.
- **Fuera de alcance**: JIT, GC, punto flotante (`f32`/`f64`), punteros sin procesar (`ptr`), FFI arbitraria de C e hilos.
