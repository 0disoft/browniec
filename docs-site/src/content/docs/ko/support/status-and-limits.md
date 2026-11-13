---
title: 현재 지원 범위와 제한 사항
description: browniec --version --json이 보고하는 공개 범위, 단일 파일 용량 한계, OS 검증 상태 및 미지원 항목을 정리합니다.
---

Brownie C는 결정적인 임베디드 규칙 및 바이트 변환 런타임을 목표로 개발 중입니다. 정확한 현재 상태는 `browniec --version --json` 플래그에서도 직접 확인할 수 있습니다.

## 현재 보고되는 전달 플래그

`./build/browniec.exe --version --json`에서 확인된 값은 다음과 같습니다.

- `"core": true`: 현재 공개 CLI의 실험 부분집합(`brownie.m1-scalar/1`, `brownie.m2-array-*`, `brownie.m2-struct-*`, `brownie.m2-reference/1`)이 동작함을 뜻하며, 전체 목표 사양(`safe/0.3`) 완료를 인증하는 값은 아닙니다.
- `"restricted": false`: AppContainer/Job 기반 `--isolated` 격리 워커 실행은 아직 구현되지 않았습니다.
- `"embed": false`: 공개 C 임베딩 API는 아직 제공되지 않습니다(내부 네이티브 테스트 하니스에 `bc_get_abi_info_v2` 부트스트랩 심볼만 존재).
- `"inspect_ir": true`, `"fuel_default": 256`, `"fuel_limit": 16000000`.

## 공개 CLI의 현재 용량 한계

| 항목 | 현재 상한 |
| --- | --- |
| 소스 파일 | 단일 UTF-8 파일, 최대 `4,096`바이트 (`1,024` 토큰) |
| 진입 함수 | 인자 없는 `fn i32 main()` 고정 (CLI 게스트 `--input` 미구현) |
| 함수·IR | 함수 `16`개, 전역 값 레지스터 `128`개, 명령어 `256`개 |
| 호출 스택 | `32`프레임 |
| 배열·레코드 | 사이트 `16`개, 배열당 최대 `4,096`개 요소, `64 KiB` 통합 아레나 |
| Fuel 예산 | 기본 `256`, 최대 `16,000,000` |

## 플랫폼 검증 상태

- **Windows 11 x64 (`MSVC` 툴체인)**: `browniec.exe` 빌드와 검증이 수행되는 주 개발 플랫폼입니다.
- **Linux**: `toolchain.json`에 크로스 빌드된 `fairyc` 해시가 기록되어 있으나, 실제 Linux 환경에서의 설정·빌드·`browniec` 실행은 **아직 검증되지 않았습니다(`UNVERIFIED`)**.

## 현재 공개 CLI에서 불가한 항목 및 제외 사항

- 다중 파일 `--project`, 정책/권한 파일 로더, 외부 게스트 `--input` 바이트 전달, 게스트 출력 싱크.
- 내부 `Engine` / `Instance` / `step()`이나 게스트 `Buffer`를 공개 CLI에서 직접 구동하는 기능.
- 첫 프로파일에서 영구 제외된 기능: JIT, 가비지 컬렉션, 부동소수점(`f32`/`f64`), 원시 포인터(`ptr`), 임의 C FFI, 클로저, 스레드, 외부 바이트코드 로딩.
