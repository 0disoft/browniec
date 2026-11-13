---
title: Brownie C
description: Fairy C로 구현 중인 작고 결정적인 임베디드 규칙·바이트 변환 언어와 가상 머신 런타임입니다.
---

Brownie C는 프로그램 안에 끼워 넣어 **작은 규칙 계산이나 바이트 데이터 검사를 안전하게 돌리기 위해 만든 미니 언어와 VM 런타임**입니다. 언어 자체의 컴파일러·검증기·VM이 모두 Fairy C로 작성되고 있습니다.

현재 공개 `browniec` CLI에서는 `.brc` 파일 하나(UTF-8 기준 최대 4096바이트)를 받아 문법과 빌림을 검사하고, **Fuel**이라는 실행 예산 안에서 코드를 돌려 `i32` 결과를 받아 볼 수 있습니다.

## 어디부터 볼까요?

- **시작하기**: [소개](./start/introduction/) · [설치와 환경 준비](./start/installation/) · [첫 프로그램](./start/first-program/)
- **문법 배우기**: [변수, 타입, 연산자와 함수](./language/basics/) · [조건문, 반복문, switch](./language/control-flow-and-switch/) · [구조체, Option/Result, ?](./language/structs-and-error-handling/) · [배열, 슬라이스, UTF-8 리터럴](./language/arrays-slices-and-utf8/) · [빌림(ref), 재빌림과 수명](./language/memory-and-resources/)
- **예제**: [공개 CLI 실행 예제](./examples/cli-examples/)
- **런타임·CLI·지원 현황**: [Fuel 사용법, 소진 결과와 한계](./runtime/fuel-and-limits/) · [호스트 연동·격리·임베딩 범위](./runtime/host-isolation-embedding/) · [CLI 사용법과 자주 만나는 오류](./cli/commands-and-errors/) · [현재 지원 범위와 제한 사항](./support/status-and-limits/)

## Fairy C와 어떻게 다른가요?

Brownie C 문법은 **Fairy C**의 일부 문법을 그대로 닮았기 때문에 Fairy C 코드를 조금 본 분이라면 금방 읽을 수 있습니다. 다만 네이티브 `.exe`를 만들거나 C 함수를 부르는 대신, **바깥 세계(파일·네트워크·C FFI)가 완전히 차단된 작은 가상 머신 안에서 `i32` 판단 결과만 계산해 돌려준다**는 점이 다릅니다.
