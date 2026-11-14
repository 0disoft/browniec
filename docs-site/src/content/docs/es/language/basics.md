---
title: Variables, tipos y funciones
description: Aprende module main, enlaces let frente a var, tipos escalares y bool, operaciones bit a bit, conversiones explícitas con as y funciones en Brownie C.
---

Brownie C comparte la sintaxis limpia de estilo C de Fairy C, manteniendo la superficie del lenguaje enfocada en una ejecución determinista y verificable en la VM.

## 1. Cabecera de módulo y variables (`let`, `var`)

Todo archivo fuente `.brc` comienza con `module main;`. Usa `let` para enlaces que permanecen fijos y `var` para variables que vas a reasignar.

```c
module main;

fn i32 main() {
    let i32 base = 70;      // no se puede reasignar
    var i32 bonus = 5;      // variable local mutable
    bonus = bonus + 2;
    return base + bonus;    // 77
}
```

Toda variable debe tener un inicializador, y se puede omitir el tipo cuando queda claro a partir del inicializador (`let x = 10;`).

## 2. Tipos escalares soportados y conversiones explícitas con `as`

La CLI pública soporta enteros y booleanos (el punto flotante `f32`/`f64` queda excluido deliberadamente para que el comportamiento sea idéntico en todos los hosts):

| Tipo | Descripción | Usos habituales |
| --- | --- | --- |
| `i32`, `i64` | Enteros con signo | Aritmética general, valores de 64 bits |
| `u8`, `u32`, `usize` | Enteros sin signo | Valores de byte (`u8`), longitudes e índices de array (`usize`) |
| `bool` | Booleano (`true`, `false`) | Condiciones y banderas |

Los distintos tipos de enteros nunca se mezclan de forma implícita; usa `as` para conversiones de ampliación que preservan el valor:

```c
let u8 byte_val = 21;
let u32 wide = byte_val as u32;
let usize count = wide as usize;
let i64 big = byte_val as i64;
```

Actualmente `as` admite solo siete pares estrictamente de ampliación (`u8 -> i32/i64/u32/usize`, `u32 -> i64/usize`, `i32 -> i64`). Se rechazan las conversiones al mismo tipo (`i32 as i32`), las conversiones de reducción, `usize as i64`, las conversiones entre `bool` y enteros, y `1 as u8` (ya que `as` no infiere el tipo de su literal izquierdo a partir del tipo de destino).

## 3. Operadores y comprobaciones de seguridad en tiempo de ejecución

- **Aritmética**: `+`, `-`, `*`, `/`, `%`. El desbordamiento y la división por cero detienen la ejecución de forma segura (`overflow`, `zero_divisor`) en lugar de desbordarse en silencio.
- **Asignación compuesta**: `+=`, `-=`, `*=`, `/=`, `%=`, `<<=`, `>>=`, `&=`, `^=`, `|=` sobre enlaces `var` o ubicaciones mutables.
- **Operadores unarios**: `-`, `+`, `!`, `~` (el `-` unario se rechaza en tipos sin signo como `u8`, `u32` y `usize`).
- **Bit a bit**: `&`, `|`, `^`, `~`, `<<`, `>>` sobre tipos enteros (`u8`, `u32`, `i32`, etc.).
- **Lógicos y comparaciones**: `&&`, `||`, `!` con evaluación en cortocircuito. Se rechazan las comparaciones encadenadas (`0 < x < 10`) —escribe `(0 < x) && (x < 10)`— y las condiciones en `if`/`while` deben ser de tipo `bool`.
- **Literales enteros y comentarios**: Los literales enteros aceptan solo dígitos decimales (aún no se admiten `1_000`, `0xFF` ni `0b1010`). Se admiten comentarios de línea (`//`) y comentarios de bloque anidados (`/* ... */`).

```c
let u8 flags = 72;
let u8 selected = (flags & 127) | 5; // 77
```

## 4. Funciones (`fn`), recursión y `_ = expr;`

Declara funciones con `fn TipoRetorno nombre(Parámetros)` (con soporte para recursión), o `fn void` cuando no se devuelve ningún valor:

```c
fn i32 factorial(i32 n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

fn void touch(ref mut i32 value) {
    *value += 1;
}
```

Para descartar intencionalmente el resultado de una expresión que no es `void`, indícalo explícitamente con `_ = expr;`.

---

Siguiente: [Control de flujo y switch](../control-flow-and-switch/)
