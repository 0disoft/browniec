---
title: Primer programa
description: Verifica, inspecciona y ejecuta tu primer archivo de reglas .brc con la CLI de browniec.
---

Brownie C recibe directamente un único archivo `.brc` (de hasta 4096 bytes en UTF-8): la CLI pública no necesita ningún directorio de paquete ni archivo de manifiesto.

## 1. Un ejemplo de 5 líneas (`examples/answer.brc`)

Todo archivo `.brc` público define `module main;` y una función sin argumentos `fn i32 main()`:

```c
module main;

fn i32 main() {
    return 6 * 7;
}
```

## 2. Verificar y ejecutar

Primero verifica la sintaxis, los tipos y las reglas de comprobación:

```powershell
./build/browniec.exe check examples/answer.brc
```

Imprime `checked` y termina con código `0`. Ahora ejecútalo en la VM:

```powershell
./build/browniec.exe run examples/answer.brc
```

Salida:

```text
return_i32=42
```

Añade `--json` para obtener una salida legible por máquina:

```powershell
./build/browniec.exe run examples/answer.brc --json
```

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

Fíjate en que `return 42;` **no establece el código de salida del sistema operativo en 42**. La CLI termina con `0` porque la ejecución tuvo éxito, mientras que `42` se devuelve dentro de `return_i32`.

## 3. Echar un vistazo al IR compilado

Para inspeccionar las instrucciones de la VM generadas sin ejecutar nada:

```powershell
./build/browniec.exe inspect examples/answer.brc --ir
```

```text
Brownie C private IR diagnostics; not reloadable
profile=brownie.m1-scalar/1
entry=0 instructions=4 registers=3 literal_bytes=0
...
```

## 4. Dar más `--fuel` a los bucles

El presupuesto de Fuel predeterminado es `256`. Ejecutar un bucle como `examples/loops.brc` con el Fuel predeterminado se detiene a mitad de camino con un error `fuel`, mientras que pasar `--fuel 1000` finaliza limpiamente:

```powershell
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
```

## Errores comunes de principiante

- **Esperar que `return 42;` sea el código de salida del proceso**: Los retornos del programa huésped son datos (`return_i32`); los códigos de salida del proceso distintos de cero (`2`..`7`) indican errores.
- **Olvidar `--fuel` con arrays**: La inicialización de arrays consume `65 537` de Fuel antes de que se ejecute `main()`, así que pasa `--fuel 100000` o un valor mayor.
- **Superar los 4096 bytes o pasar `--isolated`**: La CLI pública rechaza los archivos que exceden el tamaño y las flags no implementadas en lugar de ignorarlos en silencio.
