---
title: 메모리, 배열과 빌림
description: 포인터와 GC 없이 고정 배열, 일반 레코드, 바이트 리터럴, 슬라이스 빌림 검사로 메모리를 다루는 방식을 설명합니다.
---

공개 Brownie C는 원시 포인터(`ptr`), 임의의 힙 할당, 사용자 정의 `resource` 소멸자, 가비지 컬렉터를 모두 제외했습니다. 대신 **값 복사 기반 레코드**, **크기가 제한된 배열 아레나**, 그리고 **검증된 슬라이스 빌림**을 결합해 안전하게 메모리를 다룹니다.

## 값 의미론과 64 KiB 아레나

- **일반 `struct`**: 정해진 레지스터·프레임 한도 안에서 값으로 복사되며, `cleanup` 훅이 있는 `resource`를 포함할 수 없습니다.
- **고정 배열(`T[N]`)**: 실행 시 최대 **4096개 요소**를 담는 **65,536바이트(64 KiB)** 런타임 아레나를 사용합니다.
- 배열 카탈로그가 있는 프로그램은 `main()` 진입 전에 이 64 KiB 아레나를 준비하면서 **65,537 Fuel**을 먼저 소모합니다. 따라서 배열·레코드 예제를 실행할 때는 `--fuel 100000` 또는 `--fuel 1000000`처럼 충분한 예산을 함께 지정해야 합니다.

## 바이트 리터럴, UTF-8 검사, 슬라이스 뷰

`b"..."` 바이트 리터럴과 `"..."` 텍스트 리터럴, 그리고 경계 검사가 포함된 슬라이스 뷰(`ref u8[]`, `ref mut u8[]` 및 스칼라 슬라이스)를 사용할 수 있습니다.

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

슬라이스 뷰는 길이 조회(`.len`), 인덱스 접근(`view[i]`), 부분 범위(`[lo..hi]`), 함수 간 가변 슬라이스 전달과 재빌림(reborrow)을 지원합니다(`examples/mutable-slice-reborrow.brc`).

```c
fn void touch(ref mut i32[] values) {
    values[0] = 42;
}

fn i32 forward(ref mut i32[] values) {
    let ref mut i32[] alias = ref mut values;
    touch(alias);
    return alias[0];
}
```

## 공개 CLI vs. 내부 `Buffer` 구현 경계

저장소의 엔지니어링 문서를 참고할 때는 다음 차이를 기억해야 합니다.

- **공개 CLI**: 스칼라·고정 배열·구조체·불변 바이트/텍스트 리터럴 및 배열 슬라이스(`ref T[]`, `ref mut T[]`)까지 실행할 수 있습니다.
- **저장소 내부 구현 전용**: 게스트 `Buffer` 소유 값(`bytes::empty`, `bytes::copy`), `Buffer` 기반 `Result<Buffer, u8>`, 다중 소스 프로젝트 로더 등은 `src/` 내부 모듈과 네이티브 테스트용으로 구현 중이며 아직 공개 `browniec` CLI에서는 사용할 수 없습니다.
