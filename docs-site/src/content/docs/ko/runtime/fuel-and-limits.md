---
title: Fuel 사용법, 소진 결과와 한계
description: Fuel 계량의 동작 원리, 배열·레코드에서 더 큰 예산이 필요한 이유, 소진 시 결과, 그리고 시간·보안 격리와의 차이를 설명합니다.
---

Brownie C는 `browniec run`의 `--fuel N` 인자로 가상 머신 실행량을 계량합니다.

## Fuel이란 무엇이며 무엇이 아닌가

- **Fuel은 연산량 계량기입니다**: VM 명령어, 아레나 초기화, 배열·레코드 복사, 슬라이스 호출마다 정해진 Fuel이 차감됩니다.
- **실제 시간 제한(wall-clock timeout)이 아닙니다**: 밀리초 단위 경과 시간이 아니라 논리적 작업량을 셉니다.
- **OS 수준 보안 격리가 아닙니다**: Fuel은 실행량 상한만 강제하며, AppContainer·Job 같은 OS 샌드박스는 별도의 제한 워커 기능(`restricted: false`) 영역입니다.

## 기본값(`256`)과 상한(`16,000,000`)

`browniec --version --json`은 `"fuel_default": 256`과 `"fuel_limit": 16000000`을 보고합니다. `0..16000000` 범위를 벗어난 값은 CLI 인자 오류(종료 코드 `2`)가 됩니다.

프로그램 유형별 예산 기준:

- **짧은 스칼라 규칙**: 기본값 `256`으로도 실행됩니다(`examples/answer.brc`, `examples/branches.brc`).
- **반복문이 많은 스칼라 코드**: `examples/loops.brc`처럼 `--fuel 1000` 등을 명시해야 합니다.
- **배열·레코드 포함 프로그램**: `main()` 실행 전 **65,536바이트(64 KiB) 아레나**를 준비하는 데만 **65,537 Fuel**이 듭니다. 따라서 기본값 `256`으로 실행하면 사용자 코드 완료 전에 Fuel이 소진됩니다.
- **중첩 레코드·가변 슬라이스**: `examples/helper-records.brc`, `examples/mutable-slice-reborrow.brc`처럼 연산이 많은 경우 `--fuel 1000000` 같은 더 큰 예산이 필요합니다.

## Fuel 소진 시 동작

남은 Fuel이 부족해지면 VM은 다음처럼 종료합니다.

1. 부분 결과를 반환하지 않고 실행을 즉시 중단합니다.
2. 프로세스 종료 코드 **`5`**로 종료합니다.
3. `--json` 모드에서는 `"status":"error"`, `"return_i32":null`, `"error":{"kind":"fuel","byte_offset":...}`를 출력합니다.

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"error","return_i32":null,"error":{"kind":"fuel","byte_offset":188}}
```

예를 들어 `examples/array-read.brc`를 기본 `256`으로 실행하면 준비 단계 `"byte_offset":0`에서, `examples/helper-records.brc`를 `--fuel 100000`으로 실행하면 `"byte_offset":212`에서 `fuel` 오류가 발생합니다.

## 기타 컴파일·런타임 한도

- **호출 스택**: 최대 `32`프레임 (`frame_limit`, 종료 코드 `5`).
- **단일 파일 컴파일 한도**: `4,096` UTF-8 바이트, `1,024` 토큰, `16` 함수, `128` 레지스터, `256` 명령 (`compile_limit`, 종료 코드 `3`).
- **집합체 한도**: 배열/레코드/슬라이스 사이트 `16`개, 배열당 최대 `4,096` 요소, `64 KiB` 통합 아레나 (`array_limit`, `bounds`, `allocation`, 종료 코드 `5`).
- **산술 트랩**: 오버플로(`overflow`)와 0으로 나누기(`zero_divisor`)도 종료 코드 `5`로 중단됩니다.
