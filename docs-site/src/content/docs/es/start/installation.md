---
title: Instalación y configuración
description: Prepara la cadena de herramientas fijada de Fairy C y compila browniec.exe en Windows.
---

Brownie C todavía no distribuye un instalador precompilado. En su lugar, un script auxiliar prepara el compilador fijado de Fairy C dentro del repositorio y, a partir de ahí, compilas `build/browniec.exe`.

## Requisitos previos

1. **Cadena de herramientas MSVC x64 + Windows SDK** en Windows 11 x64.
2. **Python 3.10+** (`python3` o `py -3`) para ejecutar `tools/setup-toolchain.py`.
3. **Go (`go1.27.1`) y Git** si vas a compilar desde el código fuente el compilador fijado `fairyc` en lugar de pasar `--compiler-file path/to/fairyc.exe`.

## 1. Clonar el repositorio

Si aún no tienes el código fuente en local, clona el [repositorio de browniec en GitHub](https://github.com/0disoft/browniec) y entra en la raíz del proyecto:

```powershell
git clone https://github.com/0disoft/browniec.git
cd browniec
```

## 2. Preparar `fairyc` y compilar `browniec.exe`

Desde la raíz del repositorio `browniec`:

```powershell
python3 tools/setup-toolchain.py
./build/toolchain/fairyc.exe build
```

Esto prepara `build/toolchain/fairyc.exe` y compila `./build/browniec.exe`.

> **Nota:** En `toolchain.json` existen hashes de la cadena de herramientas para Linux, pero la compilación y ejecución nativas de `browniec` en Linux aún no están verificadas.

## 3. Verificar el binario

```powershell
./build/browniec.exe --version
./build/browniec.exe --version --json
```

`restricted_scalar: true` identifica el aislamiento escalar de un solo archivo en Windows. El perfil restringido ampliado y la incrustación en C están pendientes. La versión JSON también indica `"fuel_default": 256` y `"fuel_limit": 16000000`.
