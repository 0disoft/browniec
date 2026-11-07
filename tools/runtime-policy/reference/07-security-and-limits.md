# 07. 보안과 제한

## 신뢰 경계

소스·입력·프로젝트와 child 메시지는 불신한다. Fairy compiler와 Brownie native binary, platform allocator, 부모 broker와 host adapter는 TCB다. 외부 코드는 parser부터 restricted worker 안에 둔다. C ABI는 신뢰하는 native caller용이며 임의 pointer를 안전하게 탐색하는 보안 API가 아니다.

reachable_required ⊆ declared requires ⊆ run grants ⊆ Engine capability ceiling을 만족해야 한다. entry call graph는 최적화 전 보수적으로 계산한다. manifest는 권한 부여가 아니다. catalog hash는 binding identity이며 authorization은 별도 grant와 adapter scope 검사다.

## 초기 정책

| 항목 | 기본 상한 |
| --- | --- |
| source / modules / tokens / depth | 256 KiB / 32 / 131072 / 128 |
| compile working / Fuel / deadline | 64 MiB / 10,000,000 / 2000 ms |
| Engine global / Instance 집합 / Program 집합 | 128 MiB / 64 MiB / 64 MiB |
| Program 하나 / Instance 하나 / object backing | 8 MiB / 16 MiB / 4 MiB |
| input / output / request / reply | 각 1 MiB, host TLV header 포함 |
| run frames / owners / descriptors / host calls | 128 / 16384 / 16384 / 256 |
| run Fuel / deadline | 10,000,000 / 1000 ms |
| 제한 worker commit / user CPU / transport | 192 MiB / 5000 ms / 4 MiB |

수치는 미측정 시작 정책이다. policy schema의 component·global 관계를 강제한다. 큰 최대값을 모든 항목에서 동시에 사용할 수 있다는 뜻이 아니다. `engine + transport + ABI registry 최대치 + 32 MiB headroom <= worker commit`을 제한 워커에서 검사한다. 실제 CRT·allocator 관측에 따라 headroom을 늘린다.

프로세스 전체 public handle registry는 4 MiB, 기본 부모 broker는 memory 32 MiB·동시 session 4개·child commit 예약 합 768 MiB를 별도로 관리한다. broker에는 run별 host request/reply 누적 8 MiB씩과 host operation timeout 1000 ms를 둔다. 이 값은 guest가 선택하거나 확대할 수 없다.

## 자원 제한의 적용 지점

allocation 전에 길이와 reservation을 검사한다. typed transfer template의 metadata 순회도 제한한다. Fuel은 계산량이고 wall time은 별도다. blocking host 작업은 VM Fuel로 중단되지 않으므로 부모가 adapter timeout과 session deadline을 집행한다. 큰 응답을 모두 받아 놓고 크기를 확인하지 않는다. [E3](14-sources-and-evidence.md)

metadata JSON은 byte·depth·token·working memory를 입력 처리 중 제한한다. duplicate key, unknown field, invalid UTF-8, lone surrogate, BOM, trailing data, fraction/exponent/-0를 거부한다. 정수는 schema 범위와 고정 token 길이를 만족해야 한다. 개발용 Python JSON 모델은 이 생산 parser의 공간 안전성을 입증하지 않는다.

## 내부 오류와 외부 효과

guest trap은 Instance에 한정한다. 런타임 자체의 reference/ledger invariant 오류는 Engine poison으로 확산을 막는다. 네이티브 메모리 손상 자체의 복구는 보장하지 않는다. 서로 적대적인 코드는 별도 process에 둔다.

권한을 가진 host operation도 매 요청의 경로·레코드 수·금액·도메인 등 adapter-specific 한도를 검사한다. `read`라는 effect가 부작용 없음이나 저비용이라는 뜻은 아니다. 외부 효과의 automatic retry·rollback·exactly-once는 제공하지 않는다.

## 격리와 취소

AppContainer 접근 제한과 Job 자원 제한을 조합한다. Job commit, user CPU, parent wall deadline을 구분한다. 부모 취소가 확정된 뒤 도착한 정상 RESULT는 공개하지 않는다. 이미 완료된 side effect는 취소 성공으로 숨기지 않는다.

Windows I/O 취소는 완료와 다르다. OVERLAPPED와 buffer를 완료 전 해제하지 않고, 정리 중 session도 부모의 동시 실행 상한에 포함한다. [E7, E8](14-sources-and-evidence.md) 정상 RESULT의 형식 검사는 반환 데이터의 정당성을 보증하지 않는다.
