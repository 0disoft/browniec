---
title: 언어 기초
description: 공개 Brownie C에서 지원하는 변수, 타입, 구조체, Option/Result, 제어문, 검사 산술과 제외된 기능을 정리합니다.
---

Brownie C는 C와 유사한 표면 문법을 사용하지만, 결정성과 실행 예산 제어를 위해 단일 **4096바이트 UTF-8 파일** 안의 엄격한 부분집합만 허용합니다.

공개 CLI용 프로그램은 모두 `module main;`과 인자 없는 `fn i32 main()`으로 시작합니다.

## 변수 바인딩과 지원 타입

- **바인딩**: 불변 값은 `let`, 가변 값은 `var`로 선언합니다. 지원되는 스칼라·배열·레코드·생성자 초기화에서는 타입 추론(`let x = ...;`)도 동작합니다.
- **스칼라 타입**: `i32`, `u32`, `i64`, `u64`, `isize`, `usize`, `bool`.
- **고정 배열과 레코드**: 고정 길이 배열 `T[N]`(`[21; 2]` 또는 요소 목록)과 복사 가능한 필드로 구성된 일반 명목 `struct`.
- **태그 래퍼**: `Option<T>`(`.some(v)` / `.none`), `Result<T, E>`(`.ok(v)` / `.err(e)`).

```c
module main;

struct Point { i32 x; i32 y; }

fn Option<i32> check_positive(i32 value) {
    if (value > 0) { return .some(value); }
    return .none;
}
```

## 함수, 제어문, 검사 산술

- **분기와 반복**: `if` / `else`(조건부 값 표현식 포함), `switch` 문 및 표현식, `while`, `for`(`break`, `continue` 포함).
- **`void` 함수와 명시적 폐기**: 반환값이 없는 `void` 함수와 `_ = expr;` 폐기 문법을 지원합니다.
- **검사된 산술**: 정수 오버플로와 0으로 나누기는 조용히 감싸지 않고 런타임 트랩(`overflow`, `zero_divisor`, CLI 종료 코드 `5`)으로 중단됩니다.
- **`?` 전파와 `.is_ok`**: `?` 연산자로 `Option`/`Result`를 간결하게 조기 반환할 수 있으며, `.is_ok`로 소비 없이 상태를 검사할 수 있습니다.

```c
fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

## 의도적으로 제외된 기능

컴파일과 VM 검증을 예측 가능한 경계 안에 두기 위해 다음 기능은 포함되지 않습니다.

- 부동소수점(`f32`, `f64`)
- 사용자 `resource` 타입, 사용자 `enum`, 사용자 제네릭
- 원시 포인터(`ptr`), 임의 C FFI(`extern C`), 동적 라이브러리 로딩
- 클로저, 스레드, 맵, 정규식, 가비지 컬렉션, JIT 컴파일
