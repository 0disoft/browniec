---
title: Ejemplos de la CLI pública
description: Recorre cinco ejemplos ejecutables .brc sobre ramificaciones, propagación con ?, validación UTF-8, structs y slices mutables.
---

Leer programas pequeños que funcionan es la forma más rápida de sentirte cómodo con Brownie C. Cada ejemplo siguiente vive en `examples/` y se ejecuta directamente con `./build/browniec.exe`.

## 1. Ramificaciones, lógica en cortocircuito y recursión (`examples/branches.brc`)

Los operadores en cortocircuito `||` y `&&` evitan evaluar `1 / 0`, mientras que la función recursiva `factorial(5)` produce `120`:

```c
module main;

fn i32 factorial(i32 n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

fn i32 main() {
    var i32 answer = 0;
    let bool ready = true || (1 / 0 == 0);
    if (ready && factorial(5) == 120) {
        answer = 42;
    } else {
        answer = 1 / 0;
    }
    return answer;
}
```

```powershell
./build/browniec.exe run examples/branches.brc --json
```

Salida: `"status":"completed"`, `"return_i32":42`.

## 2. Propagación de `Option` y `Result` (`examples/propagation.brc`)

Usar `?` extrae `.some` / `.ok` en línea o retorna temprano si un paso es `.none` o `.err`:

```c
module main;

fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}

fn i32 main() {
    switch (positive(.some(42))) {
        case .some(ok): {
            switch (add(.ok(20), .ok(22))) {
                case .ok(value): {
                    if (ok) { return value; }
                    return 0;
                }
                case .err(_): { return 0; }
            }
        }
        case .none: { return 0; }
    }
}
```

```powershell
./build/browniec.exe run examples/propagation.brc --json
```

Salida: `"return_i32":42`.

## 3. Validación de bytes UTF-8 (`examples/array-utf8.brc`)

Construye una secuencia UTF-8 de 3 bytes en `var u8[3]` y la valida con `text::valid_utf8`:

```c
module main;

fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 42; }
    return 0;
}
```

Como los programas con arrays pagan `65 537` de Fuel por adelantado para inicializar la arena de 64 KiB, pasa `--fuel 100000`:

```powershell
./build/browniec.exe run examples/array-utf8.brc --fuel 100000 --json
```

Salida: `"return_i32":42`.

## 4. Registros auxiliares (`helper-records.brc`) y slices mutables (`mutable-slice-reborrow.brc`)

La construcción recursiva de structs y el représtamo de slices consumen más Fuel que las lecturas simples de arrays (`helper-records.brc` se queda sin Fuel con `--fuel 100000` y termina limpiamente con `--fuel 1000000`):

```powershell
./build/browniec.exe run examples/helper-records.brc --fuel 1000000 --json
./build/browniec.exe run examples/mutable-slice-reborrow.brc --fuel 1000000 --json
```

Ambos devuelven `"return_i32":42` con código de salida `0`.

> **Nota** (`examples/projects/hello`): El directorio multiarchivo `examples/projects/hello` (`project.json`) pertenece al trabajo futuro o interno de paquetes y no está pensado para pasarse directamente a la CLI pública actual de archivo único.
