---
title: Brownie C
description: Fairy C로 구현 중인 임베디드 규칙·바이트 변환 언어와 제한된 가상 머신 런타임입니다.
---

Brownie C는 **Fairy C**로 구현 중인 임베디드 규칙·바이트 변환 언어이자, 검증기와 제한된 가상 머신(VM)을 포함한 런타임입니다.

현재 공개 `browniec` CLI에서는 단일 `.brc` 소스 파일(최대 4096바이트 UTF-8)을 명시적 **Fuel** 예산 안에서 컴파일·검증·실행하고, 생성된 내부 IR을 검사할 수 있습니다.

## 시작하기

- **시작**: [소개](./start/introduction/) · [설치와 환경 준비](./start/installation/) · [첫 프로그램](./start/first-program/)

## Fairy C와의 관계

Brownie C 문법은 **Fairy C**의 엄격하고 제한된 부분집합과 닮아 있으며, `browniec` 컴파일러·검증기·VM 자체도 Fairy C로 작성되어 있습니다. 다만 Brownie C 코드는 네이티브 실행 파일이나 C FFI로 컴파일되지 않고, 제한된 VM 안에서 실행되어 `i32` 결과 데이터를 반환합니다.
