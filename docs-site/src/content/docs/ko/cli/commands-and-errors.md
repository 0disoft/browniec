---
title: CLI 사용법과 자주 만나는 오류
description: 공개 browniec CLI 명령, JSON 스키마, 프로세스 종료 코드, 오류 종류별 해결 방법을 정리합니다.
---

공개 `browniec` CLI는 UTF-8 최대 4096바이트의 단일 `.brc` 파일에 대해 검사, IR 조회, 제한 실행 기능을 제공합니다.

## 공개 명령어

| 명령어 | 설명 |
| --- | --- |
| `browniec --version [--json]` | 활성화된 실험 프로파일 목록과 기능 메타데이터(`browniec.version/v1`) 출력 |
| `browniec --help` | CLI 사용법 출력 |
| `browniec check SOURCE [--json]` | 실행 없이 어휘·문법·타입·Flow·바이트코드 검증 수행 |
| `browniec run SOURCE [--fuel N] [--json]` | Fuel 예산 `N`(기본 `256`, 범위 `0..16000000`) 하에 `fn i32 main()` 실행 |
| `browniec inspect SOURCE --ir [--json]` | 실행 없이 검증된 비재로딩 내부 IR 진단 정보 출력 |

## 텍스트 모드 vs. `--json` 모드

- **텍스트 모드**: stdout을 비워 두고 `checked`, `return_i32=42`, 또는 오류 메시지를 stderr로 출력합니다.
- **`--json` 모드**: stderr를 비우고 stdout에 한 줄짜리 JSON 객체를 출력합니다.
  - `check`와 `run`은 `"schema":"browniec.result/v1"` 형식으로 `"command"`, `"profile"`, `"status"`(`"checked"`, `"completed"`, `"error"`), 완료 시 `"return_i32"`, 실패 시 `"error"`(`{"kind": ..., "byte_offset": ...}`)를 반환합니다.

## 프로세스 종료 코드

| 코드 | 의미 |
| --- | --- |
| `0` | `check`, `inspect`, `run` 정상 완료 (게스트 `return_i32`가 0이 아니어도 `0`) |
| `2` | 잘못된 CLI 인자 또는 옵션 형식 오류 |
| `3` | 어휘, 문법, 타입, Flow, 또는 컴파일 한도 초과 오류 |
| `4` | 정책, 권한, 진입점 거부 또는 미구현 기능(`unavailable`, 예: `--isolated`) |
| `5` | 게스트 트랩 또는 예산 초과 (`fuel`, `overflow`, `zero_divisor`, `bounds`, `frame_limit`, `array_limit`, `allocation`) |
| `6` | 내부 컴파일러 또는 VM 불변식 검증 실패 |
| `7` | 소스 파일 읽기 실패 등 입출력 오류(`input_io`) |

## 자주 만나는 오류와 해결

| 오류 `kind` / 증상 | 원인과 해결 방법 |
| --- | --- |
| 배열·반복문에서 `fuel` 오류 (종료 코드 `5`) | 기본 `--fuel`이 `256`인데 배열 아레나 준비만 `65,537` Fuel이 필요합니다. `--fuel 1000`, `--fuel 100000`, 또는 `--fuel 1000000`처럼 충분한 값을 지정하세요. |
| `unavailable` (종료 코드 `4`) | `--isolated`처럼 아직 공개 CLI에 구현되지 않은 옵션을 전달했습니다. 지원하지 않는 옵션은 대체 경로 없이 거부됩니다. |
| `compile_limit` (종료 코드 `3`) | 단일 파일 한도(`4096` UTF-8 바이트, 토큰 `1024`, 함수 `16`, 레지스터 `128`, 명령 `256`, 배열/레코드/슬라이스 사이트 `16`)를 초과했습니다. |
| `overflow` / `zero_divisor` / `bounds` (종료 코드 `5`) | 정수 오버플로, 0으로 나누기, 배열/슬라이스 인덱스 범위 초과입니다. |
| `frame_limit` (종료 코드 `5`) | 호출 깊이가 `32`프레임 상한을 넘었습니다. |
