---
title: Integración con el host, aislamiento e incrustación
description: Distingue qué ejecuta hoy la CLI pública, qué vive en el código interno de Engine y qué sigue planificado.
---

Al leer el repositorio de Brownie C, verás componentes como `Engine`, `Instance`, `Buffer`, `--isolated` y una ABI de incrustación en C. Como las características se incorporan de forma incremental, ayuda distinguir qué puedes ejecutar realmente hoy desde la CLI pública y qué permanece interno o planificado.

## Desglose de estado

| Área | CLI pública hoy | Código interno del repositorio (privado) | Planificado (`unavailable` hoy) |
| --- | --- | --- | --- |
| Compilación y ejecución | Un único `.brc` (`<= 4096` bytes), `fn i32 main()` | `Engine`, `Program`, `Instance`, cuantos de paso, cargador de proyectos | CLI pública `--project` y archivos de políticas |
| Entrada/salida del huésped | Ninguna (solo devuelve `return_i32`) | `Snapshot` de entrada de `1 MiB` y `output::emit` en pruebas | `--input` en CLI, `output_b64`, sumideros de salida |
| Búferes de bytes | Arrays fijos, structs simples, literales de bytes, slices | `Buffer` del huésped (`bytes::empty`, `bytes::copy`) | Compilación pública de `Buffer` |
| Llamadas al host y políticas | Denegadas por defecto (sin llamadas al host) | Códec TLV host-wire y analizadores JSON de políticas | Despacho al host desde la VM y aplicación de permisos |
| Aislamiento del SO | `check/run --isolated` escalar de un solo archivo en Windows (`restricted_scalar: true`) | AppContainer / Job | Ejecución restringida ampliada (`restricted: false`) |
| ABI de incrustación en C | **Aún no** (`embed: false`) | Metadatos `bc_get_abi_info_v2` y pruebas de 64 ranuras de manejadores | Exportaciones completas en C para Engine/Program/Instance |

## Dos reglas prácticas

1. **Las API internas `Engine` / `Buffer` todavía no son características públicas de la CLI.** Permanecen restringidas dentro de módulos internos y bancos de pruebas nativos hasta que se completen la vinculación de políticas y la contabilidad.
2. **Un fallo al preparar el aislamiento detiene la ejecución.** La CLI devuelve `unavailable` (salida `4`) y no ejecuta el código fuera del proceso aislado.
