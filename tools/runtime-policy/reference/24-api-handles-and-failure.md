# 24. API handle과 실패 경계

## public handle namespace

bc_handle은 64-bit 값으로 low32 slot, high32 generation이다. slot 0과 generation 0은 invalid다. Engine/Program/Instance가 같은 process registry를 쓰고 record에 kind를 저장한다. type이 다른 handle을 인수에 넘기면 invalid handle이다. child의 Engine token과 호출 Engine token을 정확히 대조한다.

해제하면 generation을 증가시키고 이전 handle은 영구 무효화한다. generation 최대치에서는 해당 slot을 retire하며 wrap하지 않는다. registry는 live+free+retired를 포함해 최대 65536 slots, 총 4 MiB다. slot record는 최대 48바이트이며 page/index/lock overhead도 4 MiB에 포함한다. page 단위로 lazy allocation하고 작은 프로세스에서 최대 table을 먼저 확보하지 않는다. generation tombstone이 사라져 이전 handle이 부활하는 page 재생성은 허용하지 않는다.

registry bytes는 Engine 이전에 생기므로 별도 process budget이다. 각 Engine에 같은 전역 table을 중복 청구하지 않는다. native thread ID 재사용만으로 ownership이 돌아오지 않게 thread-local lifetime ticket을 함께 검사한다. thread transfer API는 제공하지 않는다. owner thread가 사라진 handle을 다른 thread가 이어받는 기능도 없다.

## registry 동기화

registry lookup·allocation·retirement는 짧은 process lock 아래에서 수행한다. lock 안에서 guest 실행·OS I/O·사용자 callback을 호출하지 않는다. kind/generation/thread/Engine 생존을 먼저 확인한 뒤 owner-thread 작업을 수행한다. 다른 thread의 잘못된 호출이 object pointer를 해제하거나 guest 상태를 바꾸지 않는다.

같은 owner thread의 재진입은 Engine busy guard로 거부한다. host callback을 VM이 직접 호출하지 않으므로 정상 흐름에서 재진입은 필요 없다. DLL unload는 모든 handle을 정리한 뒤에만 호스트가 수행한다. unload/reload 사이의 오래된 handle 검증은 지원하지 않는다.

## 구조체 쓰기 범위

bc_get_abi_info_v2는 requested_revision과 독립 out_capacity를 먼저 확인한다. wrong revision 또는 작은 capacity면 output bytes에 쓰지 않는다. 충분한 writable buffer라는 native caller 전제하에 알려진 정확한 구조체 크기만 쓴다. ABI2는 bootstrap export 이름도 bc_get_abi_info_v2로 분리한다. loader는 이 symbol이 존재한 뒤에만 ABI2 signature로 호출한다. ABI1의 같은 이름 함수에 새 argument 배치를 넘기는 자동 탐색은 하지 않는다. 나머지 API는 bootstrap 성공 뒤에만 연결한다.

다른 output struct의 struct_size는 caller가 정확한 값으로 초기화한다. runtime은 size field를 읽고 불일치하면 나머지 영역을 쓰지 않는다. 성공 시 size는 유지하고 의미 없는 field는 zero, 빈 slice는 NULL/0으로 만든다. diagnostic의 no-source는 UINT32_MAX와 byte 0/0이다. code=0이면 message는 빈 NUL 문자열이다.

진단용 UTF-8 message는 최대 239바이트와 NUL이다. source_index는 compile API에 전달된 source 배열의 원래 순서다. 내부 module 정렬은 index를 바꾸지 않는다. IPC source는 정렬된 descriptor 순서를 원래 순서로 삼는다. byte_start/end는 같은 원본 source 범위 안의 half-open byte span이다.

## API 오류와 상태 변화

| 결과 | 상태 규칙 |
| --- | --- |
| BC_ABI_MISMATCH/INVALID_HANDLE/WRONG_THREAD/BUSY | guest에 진입하지 않음, 허용된 고정 output 외 상태 불변 |
| BC_BAD_ARGUMENT | semantic 검증 전에 deadline checkpoint가 적용될 수 있음. checkpoint 통과 뒤 malformed reply는 불변 |
| BC_ALLOCATION_ERROR | reply 준비 단계라면 request/Fuel 유지. 다른 함수는 handle 미발급 |
| BC_RUN_TERMINATED | cancel/deadline/quota/Fuel로 STOPPING 또는 terminal |
| BC_ENGINE_POISONED | 새 작업 금지, 안전한 관리 정리만 가능 |
| BC_OK | 해당 함수의 commit 완료. 외부 I/O 성공이나 결과의 정당성까지 의미하지 않음 |

out handle은 writable 인수라는 전제에서 진입 때 0으로 만들고 성공 commit 때만 발급한다. C pointer의 유효성을 런타임이 임의로 탐색하지 않는다. header의 무조건적인 “오류는 상태를 바꾸지 않는다” 표현은 제거한다.

## terminal snapshot과 Engine poison

terminal event는 return/output/cause/diagnostic/Fuel/peak/elapsed를 한 번 캡처한다. polling과 cancel no-op은 이 snapshot을 바꾸지 않는다. 아직 terminal이 아닌 자식에 Engine poison이 전파되면 API가 그 첫 원인을 기록한다. 이전 terminal 결과를 다시 계산하거나 무효라고 덮어쓰지 않는다.

정상 입력 오류·quota·allocation 실패는 Engine 재사용을 허용한다. 검출된 내부 invariant 실패는 재사용을 차단한다. native corruption이 의심되면 확인되지 않은 pointer를 순회하는 복구 코드를 실행하지 않는다. restricted는 process 단위로 종료하며 embed는 host가 process 재시작 정책을 가진다.
