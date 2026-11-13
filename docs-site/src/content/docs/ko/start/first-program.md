---
title: 첫 프로그램
description: 5줄짜리 .brc 파일을 검사하고, IR을 살펴보고, 실행해 보면서 동작 방식을 익힙니다.
---

Brownie C는 프로젝트 폴더 대신 **`.brc` 파일 하나**를 CLI에 바로 넘겨 실행합니다(최대 4096바이트 UTF-8). 아주 짧은 예제부터 실행해 봅시다.

## 1. 첫 코드 살펴보기 (`examples/answer.brc`)

공개 CLI에서 실행할 수 있는 모든 `.brc` 파일에는 `module main;`과 인자 없는 `fn i32 main()`이 있어야 합니다.

```c
module main;

fn i32 main() {
    return 6 * 7;
}
```

## 2. 검사(`check`)와 실행(`run`)

먼저 문법과 타입에 문제가 없는지 확인해 봅시다.

```powershell
./build/browniec.exe check examples/answer.brc
```

문제가 없으면 `checked`가 출력됩니다. 이제 직접 실행해 볼까요?

```powershell
./build/browniec.exe run examples/answer.brc
```

출력:

```text
return_i32=42
```

프로그램에서 쓰기 좋은 한 줄짜리 JSON으로 결과를 받고 싶다면 `--json`을 붙입니다.

```powershell
./build/browniec.exe run examples/answer.brc --json
```

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

여기서 재미있는 점 하나! Fairy C와 달리 Brownie C에서는 **`return 42;`가 OS 종료 코드 42를 뜻하지 않습니다.** 실행 자체는 정상 완료되었으므로 프로세스 종료 코드는 `0`이고, `42`는 결과 데이터(`return_i32`)로 돌려받습니다.

## 3. 생성된 IR 엿보기 (`inspect --ir`)

코드를 실제로 돌리지 않고 VM용 명령어가 어떻게 만들어졌는지 구경할 수도 있습니다.

```powershell
./build/browniec.exe inspect examples/answer.brc --ir
```

```text
Brownie C private IR diagnostics; not reloadable
profile=brownie.m1-scalar/1
entry=0 instructions=4 registers=3 literal_bytes=0
...
```

## 4. 반복문에서 `--fuel` 늘려 보기

`examples/loops.brc`처럼 반복을 많이 도는 코드를 기본값(`256` Fuel) 그대로 실행하면 중간에 예산이 바닥나면서 에러(`fuel`)로 멈춥니다. `--fuel 1000`처럼 예산을 넉넉히 주면 정상 완료됩니다.

```powershell
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
```

## 처음 해 볼 때 자주 헷갈리는 점

- **반환값이 exit code라고 생각함**: 게스트가 반환한 숫자는 `return_i32` 데이터로 나오고, 프로세스 exit code `2`~`7`은 에러 종류를 뜻합니다.
- **배열·반복문에서 `--fuel`을 깜빡함**: 배열이 들어간 코드는 시작 준비에만 `65,537` Fuel을 쓰므로 `--fuel 100000` 이상을 주어야 합니다.
- **4096바이트 초과 또는 미지원 옵션**: 단일 파일 크기 상한을 넘거나 `--isolated` 같은 미구현 플래그를 넘기면 오류로 거부됩니다.
