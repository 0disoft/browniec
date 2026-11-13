---
title: Brownie C
description: Un lenguaje embebido de reglas y transformación de bytes con una VM acotada, implementado en Fairy C.
---

Brownie C es un pequeño **lenguaje embebido de reglas y transformación de bytes junto con una máquina virtual (VM) acotada**, implementado en Fairy C.

Con la CLI pública de `browniec` actual, puedes verificar un único archivo `.brc` (de hasta 4096 bytes en UTF-8), inspeccionar el IR generado y ejecutarlo bajo un presupuesto explícito de operaciones llamado **Fuel** para obtener un resultado `i32`.

## Por dónde empezar

- **Primeros pasos**: [Introducción](./start/introduction/) · [Instalación y configuración](./start/installation/) · [Primer programa](./start/first-program/)
- **Aprende el lenguaje**: [Variables, tipos y funciones](./language/basics/) · [Control de flujo y switch](./language/control-flow-and-switch/) · [Structs, Option/Result y ?](./language/structs-and-error-handling/) · [Arrays, slices y UTF-8](./language/arrays-slices-and-utf8/) · [Préstamos, représtamos y tiempos de vida](./language/memory-and-resources/)
- **Ejemplos**: [Ejemplos de la CLI pública](./examples/cli-examples/)
- **Runtime, CLI y estado**: [Fuel y límites de ejecución](./runtime/fuel-and-limits/) · [Integración con el host, aislamiento e incrustación](./runtime/host-isolation-embedding/) · [Uso de la CLI y errores frecuentes](./cli/commands-and-errors/) · [Soporte actual y limitaciones](./support/status-and-limits/)

## En qué se diferencia de Fairy C

Brownie C comparte la sintaxis de estilo C con **Fairy C**, y el propio `browniec` está escrito en Fairy C. Sin embargo, a diferencia de Fairy C, los programas en Brownie C no se compilan a ejecutables nativos ni llaman a funciones de C: se ejecutan dentro de una VM acotada que devuelve un valor de datos `i32` sin acceder a archivos ni a la red.
