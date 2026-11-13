---
title: 언어 기초
description: Brownie C의 변수, 지원 타입, 함수, 조건문·반복문, Option/Result 사용법과 제외된 문법을 살펴봅니다.
---

Brownie C는 Fairy C와 닮은 C 스타일 문법을 씁니다. 다만 호스트 안에서 안전하고 가볍게 돌아가야 하므로, 큰 시스템 프로그래밍 문법 대신 꼭 필요한 문법 위주로 알차게 구성되어 있습니다.

## 1. 변수 선언과 지원 타입

`let`은 값을 바꾸지 않을 때, `var`는 값을 바꿀 때 씁니다. 초기값에서 타입이 분명할 때는 타입을 생략하고 `let x = 10;`처럼 적을 수도 있습니다.

- **숫자와 참/거짓**: `i32`, `u32`, `i64`, `u64`, `isize`, `usize`, `bool`
- **고정 배열과 구조체**: `T[N]` (`[21; 2]` 또는 `[1, 2, 3]`), 평범한 `struct`
- **없음/오류 표현**: `Option<T>` (`.some(v)` / `.none`), `Result<T, E>` (`.ok(v)` / `.err(e)`)

```c
module main;

struct Point { i32 x; i32 y; }

fn Option<i32> check_positive(i32 value) {
    if (value > 0) { return .some(value); }
    return .none;
}
```

## 2. 함수, 분기, 반복문, 검사 산술

- **조건문과 `switch`**: `if` / `else`와 `switch`를 문장으로도 쓰고, 양쪽 가지의 타입이 같다면 값을 돌려주는 식(`let x = if (...) { 1 } else { 2 };`)으로도 쓸 수 있습니다.
- **반복문**: `while`, `for` 문과 그 안에서의 `break`, `continue`를 지원합니다.
- **`void` 함수와 값 버리기**: 반환값이 없는 `void` 도우미 함수와 `_ = expr;` 버리기 표현을 쓸 수 있습니다.
- **오버플로 방지**: 정수가 자료형 범위를 넘거나 `0`으로 나누려고 하면, 엉뚱한 값이 나오는 대신 실행이 안전하게 멈춥니다(`overflow`, `zero_divisor`).

## 3. `Option` / `Result` 편하게 다루기 (`?`, `.is_ok`)

규칙 검사 코드를 짜다 보면 중간에 실패했을 때 바로 빠져나와야 할 때가 많습니다. `?` 연산자를 붙이면 실패(`.err` / `.none`)일 때 곧장 함수를 종료하고 바깥으로 돌려보내 줍니다.

```c
fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

결과를 꺼내지 않고 성공 여부만 먼저 보고 싶다면 `.is_ok`를 쓸 수 있습니다.

## 4. 의도적으로 뺀 기능

VM 검증을 단순하고 예측 가능하게 유지하기 위해, 다음 기능은 Brownie C에 들어 있지 않습니다.

- 부동소수점(`f32`, `f64`)
- 사용자 `resource`, 사용자 `enum`, 사용자 제네릭
- 원시 포인터(`ptr`), 임의 C 함수 호출(`extern C`), 동적 라이브러리 로딩
- 클로저, 스레드, 맵, 정규식, 가비지 컬렉터(GC), JIT 컴파일러
