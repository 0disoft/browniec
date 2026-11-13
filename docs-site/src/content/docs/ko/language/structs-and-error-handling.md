---
title: 3. 구조체, Option/Result, ?
description: Brownie C의 struct 선언과 필드 단축 문법(.x), 중첩 구조체, Option/Result 및 ? 에러 전파 연산자를 익힙니다.
---

숫자 몇 개가 아니라 좌표, 패킷 헤더, 검사 결과처럼 여러 값을 묶어 다루고 싶을 때는 `struct`와 `Option`/`Result`를 조합해 씁니다.

## 1. 구조체(`struct`)와 필드 단축 초기화

`struct` 안에 필요한 필드를 선언하고, 생성할 때는 `타입명 { .필드 = 값 }` 형태로 씁니다.

```c
module main;

struct Point {
    i32 x;
    i32 y;
}

fn i32 main() {
    var i32 x = 50;
    var i32 y = 27;

    // 변수 이름과 필드 이름이 같다면 .x, .y 처럼 줄여 쓸 수 있습니다.
    let Point p = Point { .x, .y };
    return p.x + p.y;    // 77
}
```

- `.x = 20`처럼 직접 값을 주는 방식과 `.y` 단축 방식을 한 생성자 안에 섞어 쓸 수 있습니다.
- 단, 선언한 필드 순서대로 모든 필드를 빠짐없이 채워야 합니다.
- 일반 구조체는 다른 변수에 대입하거나 함수 인자/반환값으로 넘길 때 독립된 값으로 복사되므로, 원본을 나중에 고쳐도 복사본이 오염되지 않습니다.

중첩 구조체나 함수에서 구조체를 만들어 돌려주는 것도 자연스럽게 동작합니다.

```c
struct Answer {
    bool ready;
    i32 value;
}

fn Answer make_answer(i32 v) {
    return Answer { .ready = true, .value = v };
}
```

## 2. `Option<T>`와 `Result<T, E>`

아직 Brownie C에서는 사용자가 직접 새로운 `enum` 타입을 정의할 수는 없지만, 내장 제네릭 타입인 `Option<T>`와 `Result<T, E>`가 기본적으로 제공됩니다.

- **`Option<T>`**: 값이 있으면 `.some(값)`, 없으면 `.none`
- **`Result<T, E>`**: 성공하면 `.ok(값)`, 실패하면 `.err(오류값)`

함수 반환 타입으로 `Option<i32>`나 `Result<i32, bool>`을 적으면, `return .some(77);`나 `return .err(false);`처럼 앞의 타입 이름을 생략하고 짧게 쓸 수 있습니다.

## 3. `?` 연산자로 깔끔하게 에러 전파하기

중간 단계마다 `switch`를 여러 번 중첩하면 코드가 금방 깊어집니다. 이럴 때는 실패하면 즉시 함수를 끝내고 바깥으로 넘겨주는 후위 `?` 연산자를 씁니다.

```c
fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

`left?`는 `left`가 `.ok(x)`면 `x`를 꺼내어 `+ right?` 계산으로 이어 가고, `.err(e)`면 즉시 `add` 함수를 종료하면서 `.err(e)`를 호출자에게 돌려줍니다.

성공 여부만 간단히 확인하고 싶을 때는 `.is_ok` 속성도 사용할 수 있습니다.

---

다음 장에서는 고정 배열 `T[N]`, 슬라이스 뷰 `ref T[]`/`ref mut T[]`, UTF-8 검증, 그리고 `b"..."` / `"..."` 리터럴을 다룹니다.
- 이전: [2. 조건문, 반복문, switch](../control-flow-and-switch/)
- 다음: [4. 배열, 슬라이스, UTF-8 리터럴](../arrays-slices-and-utf8/)
