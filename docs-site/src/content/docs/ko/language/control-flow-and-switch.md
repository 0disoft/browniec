---
title: 조건문, 반복문, switch
description: Brownie C의 if/else, for/while 루프, break/continue, 그리고 값을 돌려주는 switch 표현식 문법을 익힙니다.
---

규칙 검사나 상태 판별 코드를 짤 때 가장 많이 쓰는 것이 조건 분기와 반복문입니다. Brownie C의 `if`와 `switch`는 단순 흐름 분기뿐 아니라 **값 자체를 계산해서 돌려주는 표현식**으로도 쓸 수 있어 코드가 아주 깔끔해집니다.

## 1. `if / else` 문과 표현식

조건식에는 반드시 괄호 `(...)`를 붙이고 결과 타입은 `bool`이어야 합니다.

```c
fn i32 sign(i32 n) {
    // 문장으로 쓰는 경우
    if (n < 0) { return -1; }

    // 표현식으로 쓰는 경우 (마지막 줄 세미콜론 생략)
    return if (n > 0) { 1 } else { 0 };
}
```

표현식으로 쓸 때는 `else if (...) { ... }` 연쇄도 가능하며, 모든 갈래(`if`, `else if`, `else`)가 같은 타입의 값을 내놓아야 합니다.

## 2. 반복문: `for`, `while`, `break`, `continue`

```c
fn i32 main() {
    var i32 total = 0;

    for (var i32 i = 0; i < 10; i = i + 1) {
        if (i == 3) { continue; }   // 이번 회차 건너뛰기
        total += i;
    }

    while (total < 77) {
        total += 1;
    }

    return total;                   // 77
}
```

주의할 점이 하나 있습니다. Brownie C는 실행량을 **Fuel**이라는 단위로 세므로, 무한 루프처럼 아주 오래 도는 `while`이나 `for`를 실행할 때는 `--fuel` 한도에 걸려 멈출 수 있습니다.

## 3. `switch` 문과 `switch` 표현식

Brownie C의 `switch`는 `Option<T>`나 `Result<T, E>` 값을 안전하게 풀 때 씁니다(C처럼 임의의 정수나 사용자 정의 `enum` 분기에는 쓰지 않습니다). C의 `switch`와 달리 `break`를 적을 필요가 없고, 빠진 분기(`.none`이나 `.err` 등)가 있으면 컴파일러가 바로 알려 줍니다.

```c
fn Result<i32, bool> answer(Option<i32> value) {
    return switch (value) {
        case .some(number): {
            let i32 next = number + 1;
            .ok(next)
        }
        case .none: { .err(false) }
    };
}
```

- **표현식으로 쓰기**: 각 `case { ... }` 안에는 `let`/`var` 선언이나 간단한 대입, 심지어 `if`나 `for` 루프까지 넣을 수 있고, 맨 마지막 줄에 세미콜론 없이 값을 남기면 `switch` 전체의 결과값이 됩니다.
- **필요 없는 값 버리기**: `case .err(_): { 0 }`처럼 `_`를 쓰면 에러 payload를 바인딩하지 않고 깔끔히 무시할 수 있습니다.
- **조기 반환 섞어 쓰기**: 한쪽 `case`에서 값을 내는 대신 `return ...;`으로 함수를 바로 끝내는 것도 가능합니다(단, 모든 `case`가 죄다 `return`으로만 끝날 때는 문장 `switch`로 씁니다).

---

다음 장에서는 여러 값을 묶는 `struct`와 `.field` 단축 문법, 그리고 `Option`·`Result`·`?` 에러 전파를 배웁니다.
- 이전: [변수, 타입, 연산자와 함수](../basics/)
- 다음: [구조체, Option/Result, ?](../structs-and-error-handling/)
