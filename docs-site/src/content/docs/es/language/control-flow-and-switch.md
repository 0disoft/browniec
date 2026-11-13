---
title: Control de flujo y switch
description: Aprende sentencias y expresiones if/else, bucles for y while, break/continue y expresiones switch en Brownie C.
---

Los motores de reglas y los procesadores de bytes dependen en gran medida de ramificaciones claras y bucles acotados. En Brownie C, tanto `if` como `switch` pueden actuar como sentencias o como expresiones que producen un valor.

## 1. Sentencias y expresiones `if / else`

Las condiciones requieren paréntesis `(...)` y deben evaluarse a `bool`:

```c
fn i32 sign(i32 n) {
    // Forma de sentencia
    if (n < 0) { return -1; }

    // Forma de expresión (expresión final sin ;)
    return if (n > 0) { 1 } else { 0 };
}
```

Cuando `if` produce un valor, ambas ramas deben devolver exactamente el mismo tipo.

## 2. Bucles: `for`, `while`, `break`, `continue`

```c
fn i32 main() {
    var i32 total = 0;

    for (var i32 i = 0; i < 10; i = i + 1) {
        if (i == 3) { continue; }   // salta esta iteración
        total += i;
    }

    while (total < 77) {
        total += 1;
    }

    return total;                   // 77
}
```

Recuerda que la VM mide el trabajo de ejecución con **Fuel**: los bucles largos o infinitos alcanzarán tu presupuesto de `--fuel` y terminarán limpiamente en lugar de colgarse.

## 3. Sentencias y expresiones `switch`

Brownie C utiliza bloques `switch` exhaustivos para hacer coincidir valores de `Option<T>` y `Result<T, E>` sin errores por caída entre casos (fallthrough):

```c
fn Result<i32, bool> answer(Option<i32> value) {
    return switch (value) {
        case .some(number): {
            let i32 next = number + 1;
            .ok(next)
        }
        case .none: { .err(false) }
    };
}
```

- **Ramas que producen valor**: El bloque de una rama puede ejecutar enlaces `let`/`var`, asignaciones e incluso sentencias `if` o `for` anidadas antes de producir su valor final sin punto y coma.
- **Ignorar cargas útiles**: Usa `_` (`case .err(_): { 0 }`) cuando no necesites el valor del error.
- **Combinar con `return` temprano**: Una rama puede salir de la función que la contiene mediante `return ...;` mientras la rama restante produce el valor de la expresión (siempre que al menos una rama produzca un valor cuando se usa como expresión).

---

- Anterior: [Variables, tipos y funciones](../basics/)
- Siguiente: [Structs, Option/Result y ?](../structs-and-error-handling/)
