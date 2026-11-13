---
title: 빌림(ref), 재빌림과 수명
description: Brownie C의 읽기·쓰기 빌림 규칙, 블록 스코프 기반 재빌림(reborrow), 참조 반환 origin 규칙을 배웁니다.
---

Brownie C에는 C 스타일 포인터(`*ptr`) 연산이나 가비지 컬렉터가 없습니다. 대신 <strong><code>ref</code>(읽기 빌림)</strong>와 <strong><code>ref mut</code>(쓰기 빌림)</strong> 규칙을 컴파일 시점에 검사해, 하나의 데이터를 여러 곳이 동시에 고치다 망가뜨리는 실수를 막습니다.

## 1. 읽기는 여러 곳, 쓰기는 딱 한 곳

- **`ref T` / `ref T[]`**: 값을 읽기만 하므로 여러 변수나 함수 인자로 동시에 넘겨도 안전합니다.
- **`ref mut T` / `ref mut T[]`**: 값을 고칠 수 있으므로 **한 순간에는 단 한 곳**만 빌려 가질 수 있습니다.

```c
fn i64 sum(ref i64[] values) {
    return values[0] + values[1];
}

fn i32 main() {
    let i64[2] values = [70, 7];
    let ref i64[] part = ref values;
    if (sum(ref part) == 77) { return 77; }
    return 0;
}
```

읽기 전용 뷰를 빌려 둔 상태에서 원본 배열을 수정하려고 하면 컴파일 시점에 거절됩니다.

## 2. 재빌림(Reborrow)으로 부모·자식 순서 지키기

실무에서는 큰 버퍼 전체(`parent`)를 빌려 온 뒤, 잠깐 일부 구간(`child`)만 도우미 함수에 넘겨 수정하고, 다시 `parent`를 읽어야 하는 경우가 많습니다. 이럴 때 중괄호 `{ ... }` 스코프로 재빌림 구간을 감싸면 깔끔합니다.

```c
fn i32 set_answer(ref mut i32[] selected) {
    selected[0] = 77;
    return selected[0];
}

fn i32 main() {
    var i32[3] values = [0; 3];
    let ref mut i32[] parent = ref mut values;
    {
        let ref mut i32[] child = ref mut parent[1..2];
        let i32 answer = set_answer(ref mut child);
        if (child[0] != answer) { return 0; }
    }   // 여기서 child 빌림이 끝납니다!
    return parent[1];   // 다시 parent를 안전하게 읽을 수 있습니다 (77)
}
```

안쪽 블록 `{ ... }`을 빠져나오면서 `child`의 빌림이 회수되므로, 그 다음 줄에서 다시 `parent[1]`에 접근할 수 있습니다.

## 3. 함수에서 빌린 참조 되돌려주기(Origin 규칙)

공개 CLI의 참조 반환 경로(`brownie.m2-reference/1`)에서는 입력으로 받은 `ref u8[]` 뷰에서 일부를 잘라 `fn ref u8[]`로 되돌려주는 것도 지원합니다.

- 함수 안에서 새로 만든 지역 배열의 참조를 바깥으로 `return`하는 것은 금지됩니다(함수가 끝나면 사라질 메모리이기 때문).
- 매개변수로 빌려 온 원본(origin)에서 나온 뷰만 반환할 수 있으므로 댕글링 포인터가 생기지 않습니다.

## 4. 지원하지 않는 메모리/언어 기능

Brownie C는 가볍고 검증 가능한 실행을 목표로 하므로, 다음 문법은 공개 CLI 범위에 들어 있지 않습니다.

- 사용자 정의 `resource` / `cleanup`, 사용자 정의 `enum`, 사용자 정의 제네릭
- 원시 포인터(`ptr`)와 C FFI(`extern C`), 동적 라이브러리 로딩
- 클로저, 스레드, `region` 블록, 가비지 컬렉터

각 예제를 실제로 실행해 보려면 다음 장의 공개 CLI 예제로 넘어가 보세요.

- 이전: [배열, 슬라이스, UTF-8 리터럴](../arrays-slices-and-utf8/)
- 다음: [공개 CLI 예제](../../examples/cli-examples/)
