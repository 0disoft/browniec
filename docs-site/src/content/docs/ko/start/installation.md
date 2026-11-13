---
title: 설치와 환경 준비
description: Windows에서 고정된 Fairy C 툴체인을 준비하고 browniec.exe를 빌드하는 순서입니다.
---

Brownie C 역시 별도 설치 프로그램 없이 저장소에서 바로 `browniec.exe`를 빌드해 사용합니다. 전역 `PATH`에 Fairy C가 미리 깔려 있지 않아도, 저장소 안의 Python 스크립트가 정해진 버전의 `fairyc`를 알아서 준비해 줍니다.

## 필요한 도구

1. **Windows 11 x64 + MSVC x64 툴체인 & Windows SDK**: `fairyc`가 네이티브 바이너리를 링크할 때 필요합니다.
2. **Python 3.10+**: 툴체인 준비 스크립트 실행용(`python3` 또는 `py -3`)입니다.
3. **Go (`go1.27.1`) 및 Git**: 이미 검증된 `--compiler-file`을 넘기지 않고 소스에서 컴파일러를 빌드할 때 필요합니다(같은 상위 폴더에 `../fairyc`가 있으면 우선 사용하고, 없으면 원격 Git에서 가져옵니다).

## 1. 컴파일러 준비하고 `browniec.exe` 빌드하기

`browniec` 저장소 루트에서 아래 두 명령을 차례대로 실행합니다.

```powershell
python3 tools/setup-toolchain.py
./build/toolchain/fairyc.exe build
```

첫 번째 명령이 `build/toolchain/fairyc.exe`를 준비하고, 두 번째 명령이 `./build/browniec.exe`를 만들어 줍니다.

> **참고:** Linux 환경에 대한 설정 정보는 들어 있지만, 실제 Linux 호스트에서의 빌드와 `browniec` 실행은 아직 검증되지 않았습니다.

## 2. 잘 빌드됐는지 확인하기

```powershell
./build/browniec.exe --version
./build/browniec.exe --version --json
```

`--version`을 실행하면 현재 지원하는 프로파일 이름이 출력됩니다. `--version --json`에서는 `"fuel_default": 256`, `"fuel_limit": 16000000`, 그리고 아직 미구현인 `"restricted": false`, `"embed": false` 상태를 함께 확인할 수 있습니다.
