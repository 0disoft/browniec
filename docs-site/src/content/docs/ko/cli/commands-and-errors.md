---
title: CLI 사용법과 자주 만나는 오류
description: browniec 공개 명령어 사용법, 종료 코드, 그리고 자주 부딪히는 오류 원인과 해결 방법입니다.
---

공개 CLI는 한 번에 소스 파일 하나를 다룹니다. `check`는 실행 없이 검사하고, `run`은 `main()`을, `eval-i32`는 `evaluate(i32)`를 호출합니다. `inspect`는 컴파일과 검증까지만 수행합니다.

## 기본 명령어

<!-- cli-output:start -->
| 명령 | 출력 옵션 | 채널 | 스키마 |
| --- | --- | --- | --- |
| `browniec --version` | — | `stdout` | — |
| `browniec --version` | `--json` | `stdout` | `browniec.version/v1` |
| `browniec check SOURCE` | — | `stderr` | — |
| `browniec check SOURCE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | — | `stderr` | — |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | — | `stderr` | — |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE` | — | `stderr` | — |
| `browniec check --project FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check --project FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin] [--output FILE\|--output-text FILE]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin] [--output FILE\|--output-text FILE]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec eval-i32 SOURCE N [--fuel N]` | — | `stderr` | — |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec inspect SOURCE --ir` | — | `stdout` | — |
| `browniec inspect SOURCE --ir` | `--json` | `stdout` | `browniec.ir/v1` |
| `browniec inspect SOURCE --limits` | `--json` | `stdout` | `browniec.limits/v1` |
<!-- cli-output:end -->

표는 성공 시 출력을 보여 줍니다. 출력 옵션의 대시는 기본 텍스트 모드입니다. 텍스트 오류는 stderr로 나가고, JSON 옵션은 소스 오류도 stdout에 객체 하나로 출력합니다.

## 종료 코드 읽기

- **`0`**: 정상 완료 (게스트 `main()`이 `77`처럼 0이 아닌 값을 돌려줘도 정상 실행이면 `0`)
- **`2`**: CLI 플래그를 잘못 적음 (`--fuel` 범위 초과 등)
- **`3`**: 소스 문법·타입·빌림 오류 또는 `4096`바이트 크기 제한 초과
- **`4`**: 아직 공개되지 않은 기능 호출(`--isolated` → `unavailable`)
- **`5`**: 실행 도중 멈춤 (`fuel` 부족, `overflow`, `zero_divisor`, `bounds`, `frame_limit`)
- **`6`**: 내부 컴파일러/VM 불변식 오류
- **`7`**: 소스 파일을 못 읽는 등 파일 입출력 오류

## 자주 만나는 오류 해결하기

1. **배열 코드인데 `fuel` 에러(종료 코드 `5`)가 뜰 때**: 기본 예산 `256`으로는 배열 64 KiB 아레나도 준비할 수 없습니다(`65,537` 필요). `--fuel 100000` 또는 `--fuel 1000000`을 함께 주세요.
2. **`--isolated`를 붙였는데 `unavailable`(종료 코드 `4`)가 뜰 때**: 아직 OS 워커 격리가 공개되지 않았다는 뜻이므로 정상입니다. 현재는 일반 `browniec run`으로만 테스트할 수 있습니다.
3. **큰 예제를 붙여 넣었더니 `compile_limit`(종료 코드 `3`)이 뜰 때**: 공개 단일 파일은 UTF-8 기준 `4096`바이트(토큰 `1024`, 함수 `16`, 명령 `256`)까지만 받습니다. 규칙 단위를 작게 쪼개 보세요.
4. **숫자 계산이나 배열 접근에서 멈출 때(종료 코드 `5`)**: 오버플로(`overflow`), `0`으로 나누기(`zero_divisor`), 배열 인덱스 초과(`bounds`) 중 하나입니다. `--json` 결과의 `error.kind`와 `byte_offset`을 보면 정확한 지점을 바로 찾을 수 있습니다.
