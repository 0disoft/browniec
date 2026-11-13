---
title: Préstamos, représtamos y tiempos de vida
description: Comprende los préstamos compartidos ref frente a los exclusivos ref mut, représtamos por bloque, orígenes de retorno y características excluidas en Brownie C.
---

Brownie C no tiene aritmética de punteros sin procesar (`*ptr`) ni recolector de basura. En su lugar, las reglas en tiempo de compilación en torno a los préstamos **`ref`** (compartidos) y **`ref mut`** (exclusivos) garantizan que los datos no puedan ser leídos y modificados al mismo tiempo mediante alias en conflicto.

## 1. Lecturas compartidas frente a escrituras exclusivas

- **`ref T` / `ref T[]`**: Solo lectura; varios lectores pueden tomar prestado a la vez.
- **`ref mut T` / `ref mut T[]`**: Escribible; solo se permite un escritor activo a la vez.

```c
fn i64 sum(ref i64[] values) {
    return values[0] + values[1];
}

fn i32 main() {
    let i64[2] values = [70, 7];
    let ref i64[] part = ref values;
    if (sum(ref part) == 77) { return 77; }
    return 0;
}
```

Mientras haya una vista compartida activa, modificar el propietario subyacente se rechaza en tiempo de compilación.

## 2. Représtamo por ámbito de bloque

Cuando tomas prestado un slice completo (`parent`), pasas un sub-slice más estrecho (`child`) a una función auxiliar para modificarlo y luego vuelves a leer `parent`, envuelve el préstamo hijo en su propio bloque `{ ... }`:

```c
fn i32 set_answer(ref mut i32[] selected) {
    selected[0] = 77;
    return selected[0];
}

fn i32 main() {
    var i32[3] values = [0; 3];
    let ref mut i32[] parent = ref mut values;
    {
        let ref mut i32[] child = ref mut parent[1..2];
        let i32 answer = set_answer(ref mut child);
        if (child[0] != answer) { return 0; }
    }   // el préstamo de child termina aquí
    return parent[1];   // parent puede volver a leerse de forma segura (77)
}
```

## 3. Devolver vistas prestadas (reglas de origen)

En la ruta pública de referencias (`brownie.m2-reference/1`), las funciones que reciben parámetros `ref u8[]` pueden devolver una subvista cortada (`fn ref u8[]`) vinculada de vuelta al origen del llamador. Devolver una referencia a un array local dentro de la función se rechaza para que las vistas colgantes sean imposibles.

## 4. Características excluidas

Para mantener la verificación de la VM pequeña y predecible, estas características están ausentes intencionalmente de la CLI pública de Brownie C:

- Tipos `resource` / `cleanup` personalizados, `enum` personalizados y genéricos de usuario
- Punteros sin procesar (`ptr`), FFI de C (`extern C`) y carga dinámica de bibliotecas
- Closures, hilos, arenas `region` y recolección de basura

---

- Anterior: [Arrays, slices y UTF-8](../arrays-slices-and-utf8/)
- Siguiente: [Ejemplos de la CLI pública](../../examples/cli-examples/)
