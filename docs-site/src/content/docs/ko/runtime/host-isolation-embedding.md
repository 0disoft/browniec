---
title: 호스트 연동·격리·임베딩 범위
description: 공개 CLI로 지금 쓸 수 있는 것, 저장소 내부 Engine 코드에만 있는 것, 앞으로 추가될 격리·임베딩 기능을 구분해 줍니다.
---

Brownie C 저장소 문서를 살펴보면 `Engine`, `Instance`, `Buffer`, `--isolated`, C 임베딩 ABI 같은 단어가 자주 보입니다. 이 기능들은 한꺼번에 공개되는 것이 아니라 단계별로 붙고 있어서, <strong>“지금 CLI에서 바로 써볼 수 있는가?”</strong>를 구분해서 이해하는 편이 좋습니다.

## 한눈에 보는 현재 단계

| 영역 | 지금 공개 CLI에서 가능한 것 | 내부 코드/테스트에만 있는 것 | 앞으로 추가될 예정 (`unavailable`) |
| --- | --- | --- | --- |
| 실행 방식 | 단일 `.brc` 파일 (`<= 4096`B), `fn i32 main()` | `Engine`, `Program`, `Instance`, 스텝 실행, 다중 파일 로더 | 공개 `--project` CLI 및 정책/권한 파일 |
| 데이터 입출력 | 인자 없음 (`return_i32` 정수 반환만 가능) | `1 MiB` 입력 스냅샷, `output::emit` 바이트 출력 | CLI `--input`, `output_b64` 출력 싱크 |
| 바이트 다루기 | 고정 배열, 평범한 `struct`, 바이트 리터럴, 슬라이스 | 동적 소유형 `Buffer` (`bytes::empty`, `bytes::copy`) | 공개 CLI에서의 `Buffer` 문법 개방 |
| 호스트 호출 | 기본 차단 (파일·네트워크·C 호출 불가) | TLV 코덱, 요청/응답 조정기, 정책 파서 | VM 호스트 호출 브리지 및 권한 강제 |
| OS 프로세스 격리 | **미제공** (`--isolated`는 `unavailable`로 거부) | Windows AppContainer/Job 설계 | 실제 `--isolated` 격리 워커 (`restricted: true`) |
| C 임베딩 API | **미제공** (`embed: false`) | `bc_get_abi_info_v2` 정보 조회 + 64슬롯 핸들 테이블 테스트 | 전체 Engine/Program/Instance C 라이브러리 (`embed: true`) |

## 꼭 알아둘 두 가지

1. **내부 `Engine`이나 `Buffer`는 아직 CLI로 부를 수 없습니다.** 설계와 내부 모듈 구현이 진행 중이지만, 정책 검사와 메모리 회계가 다 맞물리기 전까지는 공개 CLI에서 의도적으로 닫아 둔 상태입니다.
2. **`--isolated`를 주면 몰래 일반 실행으로 넘기지 않고 바로 거부합니다.** 미지원 옵션을 조용히 무시했다가 "격리된 줄 알고 안심하는 사고"가 나지 않도록 종료 코드 `4`(`unavailable`)로 확실하게 막아 줍니다.
