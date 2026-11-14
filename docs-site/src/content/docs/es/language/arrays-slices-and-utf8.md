---
title: Arrays, slices y UTF-8
description: Aprende sobre arrays fijos T[N], .len, vistas slice mutables y compartidas ref T[] / ref mut T[], text::valid_utf8 y literales de bytes y texto en Brownie C.
---

Como Brownie C se centra en la evaluación de reglas y el procesamiento de bytes, los arrays y las vistas slice son fundamentales en el código del día a día.

## 1. Arrays fijos (`T[N]`) y `.len`

Declara arrays de tamaño fijo como `Tipo[Cantidad]`, usando elementos explícitos `[10, 20, 12]` o la sintaxis de repetición `[0; 4]`:

```c
module main;

fn i32 main() {
    var i32[4] values = [0; 4];
    let i32[3] fixed = [30, 40, 7];

    for (var usize i = 0; i < fixed.len; i = i + 1) {
        values[i] = fixed[i];
    }
    return values[0] + values[1] + values[2]; // 77
}
```

- `.len` devuelve la longitud del array como `usize`.
- Los arrays mutables con el mismo tipo de elemento y longitud (`var T[N]`) admiten asignación de copia completa (`values = other;`).
- Las lecturas o escrituras fuera de rango se detienen limpiamente con `bounds` en lugar de leer memoria arbitraria.

## 2. Vistas slice (`ref T[]`, `ref mut T[]`)

Toma prestado todo un array o parte de él sin copiarlo en un array nuevo:

```c
fn i32 update(ref mut i32[] selected) {
    selected[0] = 77;
    return selected[0];
}

fn i32 main() {
    var i32[4] values = [0; 4];
    let ref mut i32[] parent = ref mut values[1..4];   // elementos 1, 2, 3
    return update(ref mut parent[1..2]);               // escribe en values[2]
}
```

- `ref T[]`: Vista slice de solo lectura.
- `ref mut T[]`: Vista slice mutable exclusiva.
- Los rangos semiabiertos admiten `arr[start..end]`, `arr[..end]` y `arr[start..]`.
- También puedes tomar prestado un slice directamente de un array temporal devuelto por una función (`update(ref mut make()[1..2])`).

## 3. Validación UTF-8 y literales de bytes y texto

Comprueba si un array de bytes contiene UTF-8 válido con la función integrada `text::valid_utf8`:

```c
module main;

fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 77; }
    return 0;
}
```

También puedes enlazar literales estáticos de bytes (`b"..."`) y de texto (`"..."`) directamente como vistas inmutables `ref u8[]` o `ref str`:

```c
let ref u8[] sig = b"OK";
let i32 first = sig[0] as i32;   // 79 ('O')
let bool same = text::equal(text::bytes("OK"), sig);
```

- Los programas que usan literales de bytes o texto entran en el perfil de referencias retenidas (`brownie.m2-reference/1`), así que pasa un presupuesto mayor como `--fuel 1000000` (el valor predeterminado `256` es demasiado pequeño para los costos de entrada y salida).
- Usa `text::bytes("OK")` para obtener una vista de bytes desde texto, y `text::equal(a, b)` para comparar dos vistas inmutables de bytes.
- Ambos tipos de literales admiten secuencias de escape `\\`, `\"`, `\n`, `\r`, `\t`, `\0` y `\xHH`, mientras que `"..."` también acepta `\u{...}` (los literales `c"..."` se rechazan).

---

- Anterior: [Structs, Option/Result y ?](../structs-and-error-handling/)
- Siguiente: [Préstamos, représtamos y tiempos de vida](../memory-and-resources/)
