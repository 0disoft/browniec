---
title: Instalación y configuración
description: Prepara la cadena de herramientas fijada de Fairy C y compila browniec.exe en Windows.
---

Brownie C todavía no distribuye un instalador precompilado. En su lugar, un script auxiliar prepara el compilador fijado de Fairy C dentro del repositorio y, a partir de ahí, compilas `build/browniec.exe`.

## Requisitos previos

1. **Cadena de herramientas MSVC x64 + Windows SDK** en Windows 11 x64.
2. **Python 3.10+** (`python3` o `py -3`) para ejecutar `tools/setup-toolchain.py`.
3. **Go (`go1.27.1`) y Git** si vas a compilar desde el código fuente el compilador fijado `fairyc` en lugar de pasar `--compiler-file path/to/fairyc.exe`.

## 1. Preparar `fairyc` y compilar `browniec.exe`

Desde la raíz del repositorio `browniec`:

```powershell
python3 tools/setup-toolchain.py
./build/toolchain/fairyc.exe build
```

Esto prepara `build/toolchain/fairyc.exe` y compila `./build/browniec.exe`.

> **Nota:** En `toolchain.json` existen hashes de la cadena de herramientas para Linux, pero la compilación y ejecución nativas de `browniec` en Linux aún no están verificadas.

## 2. Verificar el binario

```powershell
./build/browniec.exe --version
./build/browniec.exe --version --json
```

En la salida de `--version --json`, verás `"fuel_default": 256`, `"fuel_limit": 16000000`, `"core": true` y `"restricted": false` / `"embed": false` (lo que refleja que el aislamiento de trabajadores del sistema operativo y la incrustación en C todavía no están habilitados).
