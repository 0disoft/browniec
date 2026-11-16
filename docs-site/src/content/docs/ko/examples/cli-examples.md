---
title: 공개 CLI 실행 예제
description: 현재 공개 browniec CLI로 바로 실행해 보며 문법을 익힐 수 있는 5가지 예제입니다.
---

문법을 눈으로만 읽는 것보다 짧은 예제를 직접 돌려보는 게 가장 빠릅니다. 아래 예제는 모두 `browniec` 저장소의 `examples/` 폴더에 실제로 들어 있는 파일들입니다.

## 1. 조건 분기·단락 평가·재귀 (`examples/branches.brc`)

`||`와 `&&`의 단락 평가(앞에서 결정되면 뒤쪽은 실행하지 않음) 덕분에 `1 / 0` 분기를 밟지 않고 재귀 함수 `factorial(5)`를 계산하는 예제입니다.

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
        answer = 77;
    } else {
        answer = 1 / 0;
    }
    return answer;
}
```

```powershell
./build/browniec.exe run examples/branches.brc --json
```

결과: `"status":"completed"`, `"return_i32":77`.

## 2. `?` 연산자로 `Option`/`Result` 이어 쓰기 (`examples/propagation.brc`)

`positive` 함수에서 `value? > 0`으로 `Option<i32>` 값을 꺼내고, `add` 함수에서 `left? + right?`로 두 `Result`를 더합니다. 중간에 하나라도 `.none`이나 `.err`면 바로 빠져나옵니다.

```c
module main;

fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}

fn i32 main() {
    switch (positive(.some(77))) {
        case .some(ok): {
            switch (add(.ok(30), .ok(47))) {
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

```powershell
./build/browniec.exe run examples/propagation.brc --json
```

결과: `"return_i32":77`.

## 3. UTF-8 바이트 검사 (`examples/array-utf8.brc`)

`var u8[3] bytes` 배열을 만들고 앞의 두 바이트를 고친 뒤, 올바른 UTF-8 문자열(`가` = `234, 176, 128`)인지 `text::valid_utf8`로 검사합니다.

```c
module main;

fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 77; }
    return 0;
}
```

배열 초기화에 `65,537` Fuel이 들기 때문에 `--fuel 100000`을 함께 넘겨 줍니다.

```powershell
./build/browniec.exe run examples/array-utf8.brc --fuel 100000 --json
```

결과: `"return_i32":77`.

## 4. 구조체 재귀와 가변 슬라이스 (`helper-records.brc`, `mutable-slice-reborrow.brc`)

구조체를 여러 번 만들어 반환하거나(`examples/helper-records.brc`), 가변 슬라이스를 다시 빌려 수정할 때(`examples/mutable-slice-reborrow.brc`)는 연산량이 조금 더 많습니다. 예를 들어 `helper-records.brc`는 `--fuel 100000`에서는 중간에 Fuel이 다 떨어지지만 `--fuel 1000000`을 주면 무리 없이 `77`을 반환하고 끝납니다.

```powershell
./build/browniec.exe run examples/helper-records.brc --fuel 1000000 --json
./build/browniec.exe run examples/mutable-slice-reborrow.brc --fuel 1000000 --json
```

> **참고 (`examples/projects/hello`):** 저장소 `examples/` 안에 있는 `projects/hello` 폴더(`project.json` 포함)는 향후 다중 파일·엔진 패키지 구성을 위한 예제이므로, 현재 단일 `.brc` 파일만 받는 공개 CLI로는 직접 실행하지 않습니다.
