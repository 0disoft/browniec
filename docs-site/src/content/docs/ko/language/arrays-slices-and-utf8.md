---
title: 배열, 슬라이스, UTF-8 리터럴
description: Brownie C의 고정 배열 T[N], .len, 슬라이스 뷰 ref T[] / ref mut T[], text::valid_utf8, 바이트·문자열 리터럴을 배웁니다.
---

Brownie C는 바이트 패킷이나 규칙 데이터를 안전하게 검사·가공하도록 설계된 만큼, 배열과 바이트 슬라이스 문법이 아주 실용적으로 갖춰져 있습니다.

## 1. 고정 배열 (`T[N]`)과 `.len`

고정 길이 배열은 `요소타입[개수]` 형태로 만듭니다. 반복 초기화 `[값; 개수]`도 지원합니다.

```c
module main;

fn i32 main() {
    var i32[4] values = [0; 4];    // 0으로 4칸 채우기
    let i32[3] fixed = [30, 40, 7];

    for (var usize i = 0; i < fixed.len; i = i + 1) {
        values[i] = fixed[i];
    }
    return values[0] + values[1] + values[2]; // 77
}
```

- 배열의 길이 `.len`은 `usize` 타입입니다.
- 실행 중에 배열 길이 이상의 인덱스에 접근하면 VM이 경계 검사(`bounds`) 오류로 즉시 멈춥니다.

## 2. 슬라이스 뷰 (`ref T[]`, `ref mut T[]`)

배열의 전체 혹은 일부 구간만 잘라서 함수에 넘기고 싶다면 슬라이스 뷰를 씁니다.

```c
fn i32 update(ref mut i32[] selected) {
    selected[0] = 77;
    return selected[0];
}

fn i32 main() {
    var i32[4] values = [0; 4];
    let ref mut i32[] parent = ref mut values[1..4];   // 1, 2, 3번 칸
    return update(ref mut parent[1..2]);               // 원래 values[2] 수정
}
```

- `ref T[]`: 읽기 전용 슬라이스입니다. 여러 곳에 동시에 빌려줄 수 있습니다.
- `ref mut T[]`: 값을 바꿀 수 있는 가변 슬라이스입니다.
- `values[1..4]`, `values[..2]`, `values[1..]`처럼 시작/끝을 생략한 범위 표현도 쓸 수 있습니다(`end`는 포함되지 않는 반열린 구간).

## 3. UTF-8 검사와 바이트·문자열 리터럴

바이트 배열이 올바른 UTF-8인지 확인하고 싶을 때는 내장 `text::valid_utf8`을 씁니다.

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

또한 정적 바이트 리터럴(`b"..."`)과 텍스트 리터럴(`"..."`)을 불변 뷰로 바로 바인딩해 읽는 것도 가능합니다.

```c
let ref u8[] sig = b"OK";
let i32 first = sig[0] as i32;   // 79 ('O')
```

- 리터럴·참조 경로(`brownie.m2-reference/1`)가 동작할 때는 내부 VM 진입/퇴장 비용 때문에 `--fuel`을 `1000000`처럼 충분히 크게 주어야 실행됩니다(기본 `256`에서는 Fuel 부족으로 멈춥니다).
- `"..."` 텍스트 리터럴에서 바이트 뷰를 꺼낼 때는 `text::bytes(...)`를, 두 불변 바이트 뷰를 비교할 때는 `text::equal(...)`을 사용할 수 있습니다.

---

다음 장에서는 Brownie C가 빌림(`ref`/`ref mut`)과 재빌림(Reborrow), 그리고 함수에서의 참조 반환을 어떻게 검증하는지 정리합니다.
- 이전: [구조체, Option/Result, ?](../structs-and-error-handling/)
- 다음: [빌림(ref), 재빌림과 수명](../memory-and-resources/)
