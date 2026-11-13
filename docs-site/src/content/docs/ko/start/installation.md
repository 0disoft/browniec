---
title: 설치와 환경 준비
description: 고정된 Fairy C 툴체인을 준비하고 Windows에서 browniec.exe를 빌드하는 방법입니다.
---

Brownie C는 아직 별도 설치 관리자나 배포용 다운로드 아카이브를 제공하지 않습니다. 저장소의 `toolchain.json` 매니페스트로 고정된 Fairy C 컴파일러를 준비한 뒤, Windows 11 x64 환경에서 `build/browniec.exe`를 직접 빌드합니다.

## 필요한 도구

1. **MSVC x64 툴체인 + Windows SDK**: Fairy C가 최종 네이티브 바이너리를 링크할 때 필요합니다.
2. **Python 3.10+**: `tools/setup-toolchain.py` 실행에 필요합니다(Windows에서는 `py -3` 사용 가능).
3. **Go (`go1.27.1`) 및 Git**: 검증된 `--compiler-file`을 가져오지 않고 소스에서 고정된 `fairyc`를 빌드할 때 필요합니다. 로컬 `../fairyc` 저장소에 일치하는 리비전이 있으면 우선 사용하고, 없으면 지정된 HTTPS Git 원격 저장소를 사용합니다.

## 1. 고정 Fairy C 컴파일러 준비

`browniec` 저장소 루트에서 다음 명령을 실행합니다.

```powershell
python3 tools/setup-toolchain.py
```

Windows 환경에서 `python3` 대신 `py -3 tools/setup-toolchain.py`를 사용할 수도 있습니다. 이 스크립트는 SHA-256과 컴파일러 정체성을 검증한 뒤 `build/toolchain/fairyc.exe`를 준비하므로, 전역 `PATH`에 `fairyc`가 설치되어 있지 않아도 됩니다.

- 이미 검증된 실행 파일을 지정하려면 `--compiler-file path/to/fairyc.exe`를 전달합니다.
- 참고: `toolchain.json`에 Linux 크로스 빌드 해시가 포함되어 있으나, **Linux 호스트에서의 설정·빌드·`browniec` 실행은 아직 검증되지 않았습니다(`UNVERIFIED`).**

## 2. `browniec.exe` 빌드

`build/toolchain/fairyc.exe`가 준비되면 루트 `fairy.toml`을 빌드합니다.

```powershell
./build/toolchain/fairyc.exe build
```

빌드가 완료되면 `./build/browniec.exe`가 생성됩니다.

## 3. 설치 확인

버전과 지원 프로파일 플래그를 확인합니다.

```powershell
./build/browniec.exe --version
./build/browniec.exe --version --json
```

`--version` 출력 예시:

```text
Brownie C experimental: brownie.m1-scalar/1, brownie.m2-array-read/1, brownie.m2-array-write/1, brownie.m2-array-copy/1, brownie.m2-struct-read/1, brownie.m2-struct-write/1, brownie.m2-struct-copy/1, brownie.m2-struct-nested/1
```

`--version --json`에서는 `"schema":"browniec.version/v1"`과 함께 `"core":true`, `"restricted":false`, `"embed":false`, `"fuel_default":256`, `"fuel_limit":16000000`, `"inspect_ir":true`를 확인할 수 있습니다. 여기서 `restricted: false`와 `embed: false`는 워커 격리와 C 임베딩이 아직 비활성화되어 있음을 뜻하며, `core: true` 역시 전체 목표 사양이 아니라 현재 공개된 실험 부분집합만 의미합니다.

## 다음 단계

[첫 프로그램](../first-program/)으로 이동해 `.brc` 파일을 검사하고 실행해 봅니다.
