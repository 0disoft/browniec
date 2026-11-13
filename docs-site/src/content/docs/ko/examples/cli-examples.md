---
title: 공개 CLI 실행 예제
description: 현재 공개 browniec CLI로 바로 검증하고 실행할 수 있는 규칙·바이트 처리 예제를 정리합니다.
---

아래 예제는 모두 현재 단일 파일 `browniec` CLI(`./build/browniec.exe`, Windows 기준)에서 직접 실행해 결과를 확인할 수 있습니다.

## 1. 분기, 단락 평가, 재귀 (`examples/branches.brc`)

단락 평가(`||`, `&&`)로 0으로 나누기 분기를 피하면서 재귀 함수 `factorial(5)`를 평가하는 규칙 예제입니다.

```c
module main;

fn i32 factorial(i32 n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

fn i32 main() {
    var i32 answer = 0;
    let bool ready = true || (1 / 0 == 0);
    if (ready && factorial(5) == 120) {
        answer = 42;
    } else {
        answer = 1 / 0;
    }
    return answer;
}
```

기본 Fuel(`256`)로 실행합니다.

```powershell
./build/browniec.exe run examples/branches.brc --json
```

실측 출력:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

## 2. `Option` / `Result` `?` 전파 (`examples/propagation.brc`)

무작정 언래핑하지 않고 `?` 연산자로 실패/없음을 안전하게 전파하는 예제입니다.

```c
module main;

fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}

fn i32 main() {
    switch (positive(.some(42))) {
        case .some(ok): {
            switch (add(.ok(20), .ok(22))) {
                case .ok(value): {
                    if (ok) { return value; }
                    return 0;
                }
                case .err(_): { return 0; }
            }
        }
        case .none: { return 0; }
    }
}
```

실행 명령:

```powershell
./build/browniec.exe run examples/propagation.brc --json
```

결과: `"profile":"brownie.m1-scalar/1"`, `"return_i32":42`.

## 3. UTF-8 바이트 배열 검증 (`examples/array-utf8.brc`)

가변 `u8[3]` 배열에 3바이트 UTF-8 시퀀스를 채운 뒤 `text::valid_utf8`로 유효성을 검사합니다.

```c
module main;

fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 42; }
    return 0;
}
```

배열이 있는 프로그램은 시작 전 64 KiB 아레나 준비에만 `65,537` Fuel을 사용하므로 `--fuel 100000`을 지정합니다.

```powershell
./build/browniec.exe run examples/array-utf8.brc --fuel 100000 --json
```

실측 출력:

```json
{"schema":"browniec.result/v1","profile":"brownie.m2-array-write/1","command":"run","status":"completed","return_i32":42,"error":null}
```

## 4. 레코드(`examples/helper-records.brc`) 및 가변 슬라이스(`examples/mutable-slice-reborrow.brc`)

구조체 생성/선택이나 가변 슬라이스 재빌림은 단순 배열 읽기보다 더 큰 Fuel 예산이 필요합니다(예: `helper-records.brc`는 `--fuel 100000`에서 바이트 오프셋 `212` 지점에서 `fuel` 오류로 멈추며, `--fuel 1000000`에서 정상 완료됩니다).

```powershell
./build/browniec.exe run examples/helper-records.brc --fuel 1000000 --json
./build/browniec.exe run examples/mutable-slice-reborrow.brc --fuel 1000000 --json
```

두 예제 모두 종료 코드 `0`, `"return_i32":42`를 반환합니다(프로파일은 각각 `brownie.m2-struct-read/1`, `brownie.m2-array-write/1`).
