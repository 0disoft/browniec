---
title: Structs, Option/Result y ?
description: Aprende sobre structs en Brownie C, abreviatura de campos (.x), registros anidados, Option<T>, Result<T, E> y propagación de errores con ?.
---

Cuando los programas modelan coordenadas, cabeceras o resultados de validación, combina registros `struct` con los tipos integrados `Option<T>` y `Result<T, E>`.

## 1. Structs y abreviatura de campos

Define registros con `struct` y constrúyelos con `Tipo { .campo = valor }`:

```c
module main;

struct Point {
    i32 x;
    i32 y;
}

fn i32 main() {
    var i32 x = 50;
    var i32 y = 27;

    // .x y .y son abreviaturas de .x = x y .y = y
    let Point p = Point { .x, .y };
    return p.x + p.y;    // 77
}
```

- Puedes mezclar `.x = 20` explícito y la abreviatura `.y` en el mismo constructor, siempre que cada campo aparezca en orden de declaración.
- Los structs simples se copian como valores independientes al asignarse o pasarse a funciones, de modo que las mutaciones posteriores en las variables de origen no afectan a la copia construida.

Los structs también pueden anidarse o devolverse limpiamente desde funciones auxiliares:

```c
struct Answer {
    bool ready;
    i32 value;
}

fn Answer make_answer(i32 v) {
    return Answer { .ready = true, .value = v };
}
```

## 2. `Option<T>` y `Result<T, E>`

Aunque no existen declaraciones `enum` personalizadas en Brownie C, los envoltorios etiquetados integrados cubren valores opcionales y fallos tipados:

- **`Option<T>`**: `.some(value)` o `.none`
- **`Result<T, E>`**: `.ok(value)` o `.err(error)`

Cuando el tipo de retorno o de variable esperado ya se conoce, omite el prefijo y escribe `.some(77)` o `.err(false)`. (En la CLI pública actual, los parámetros de tipo de `Option<T>` y `Result<T, E>` admiten `i32` y `bool`.)

## 3. Propagación limpia de errores con `?`

En lugar de anidar múltiples bloques `switch`, añade `?` para extraer los valores de éxito y retornar temprano ante `.none` o `.err`:

```c
fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

Si solo necesitas una comprobación booleana rápida sobre un `Result<T, E>`, también se admite `.is_ok` (`Option<T>` usa `switch` o `?`).

---

- Anterior: [Control de flujo y switch](../control-flow-and-switch/)
- Siguiente: [Arrays, slices y UTF-8](../arrays-slices-and-utf8/)
