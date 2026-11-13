---
title: 첫 프로그램
description: 공개 browniec CLI로 첫 .brc 파일을 검사하고 IR을 확인하며 실행하는 과정을 다룹니다.
---

Brownie C 공개 CLI는 최대 **4096바이트** UTF-8 단일 `.brc` 파일을 입력으로 받습니다. Fairy C처럼 패키지 디렉터리를 만드는 대신, `.brc` 파일 경로를 `check`, `run`, `inspect` 명령에 바로 전달합니다.

## 1. 최소 예제 (`examples/answer.brc`)

공개 CLI에서 실행할 모든 프로그램은 `module main;`과 인자 없는 `fn i32 main()`을 정의해야 합니다.

```c
module main;

fn i32 main() {
    return 6 * 7;
}
```

## 2. 정적 검사와 검증 실행

```powershell
./build/browniec.exe check examples/answer.brc
```

정상 통과 시 stderr에 다음이 출력되고 프로세스 종료 코드는 `0`이 됩니다.

```text
checked
```

`--json`을 붙이면 stderr 대신 stdout에 한 줄짜리 JSON 결과를 출력합니다.

```powershell
./build/browniec.exe check examples/answer.brc --json
```

## 3. 제한된 VM에서 실행

```powershell
./build/browniec.exe run examples/answer.brc
```

예상 출력:

```text
return_i32=42
```

`--json`으로 실행하면 다음 JSON이 출력됩니다.

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

여기서 `return_i32=42`는 게스트가 반환한 **결과 데이터**이며, 실행이 정상 완료되었으므로 CLI 프로세스 자체의 종료 코드는 `0`입니다.

## 4. 생성된 내부 IR 검사

실행하지 않고 컴파일된 레지스터 바이트코드 구조를 확인할 수 있습니다.

```powershell
./build/browniec.exe inspect examples/answer.brc --ir
```

출력 상단 예시:

```text
Brownie C private IR diagnostics; not reloadable
profile=brownie.m1-scalar/1
entry=0 instructions=4 registers=3 literal_bytes=0
```

## 5. 반복문·배열 실행 시 `--fuel` 지정

기본 Fuel 한도는 **256**이므로 `answer.brc` 같은 짧은 스칼라 예제는 기본값으로 실행되지만, 반복 횟수가 많은 코드나 배열 코드는 `--fuel`을 크게 주어야 합니다(상한 `16000000`). 예를 들어 `examples/loops.brc`는 다음처럼 실행합니다.

```powershell
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
```

## 처음 시작할 때 자주 겪는 실수

- **반환값 `42`가 프로세스 종료 코드가 된다고 오해**: 게스트 `i32`는 `return_i32` 데이터로 전달됩니다. 프로세스 종료 코드 `2`~`7`은 CLI 사용 오류, 컴파일 오류, 트랩, 입출력 실패를 뜻합니다.
- **반복문이나 배열 코드에서 `--fuel` 생략**: 배열이 포함된 프로그램은 시작 전에 64 KiB 아레나 준비 비용 `65,537` Fuel이 들기 때문에, 기본값 `256`으로 실행하면 `fuel` 오류(종료 코드 `5`)가 납니다.
- **미구현 플래그 전달**: `--isolated` 등 아직 공개되지 않은 플래그는 조용히 무시되지 않고 오류로 거부됩니다.
- **4096바이트 초과**: 공개 단일 파일 입력은 UTF-8 기준 4096바이트를 넘길 수 없습니다.
