# 기계 계약의 소유권

| 원본 | 소유하는 규칙 |
| --- | --- |
| profile.json | source profile, revision, 고정 admission 상한 |
| opcodes.json | IR2 번호·operand·metering class·table 필드 |
| value-layout.json / vectors | VM byte layout 규칙과 수동 기대값 |
| policy.schema.json / policy.*.json | Engine/compile/run/worker 정책과 출발 예시 |
| broker.policy.schema.json / broker.policy.json | 부모 전역·session·I/O·host 비용의 trusted 상한 |
| project.schema.json / run-config.schema.json | source 프로젝트와 실행별 축소 권한 |
| host-abi.h / abi-layout.json | ABI2 선언과 Windows x64 예상 size/offset |
| lifecycle.json / engine-lifecycle.json | Instance·Engine 상태의 기계 식별자 |
| broker-lifecycle.json | 부모 공개 barrier와 lease 반환 조건 |
| host-catalog.* / catalog-vector.json | catalog1 binding identity·schema·golden |
| host-wire-vectors.json | TLV1 정확한 bytes 기대값 |
| ipc.schema.json / ipc-vectors.json | IPC2 metadata와 framing golden |
| builtins.json / diagnostics.json | 함수 signature·effect와 오류 공간 |
| arithmetic-vectors.json / model-vectors.json | 기존 산술·상태·quota·copy 검산 |
| utf8-vectors.json / review-model-vectors.json | chunk·경합·응답·진단의 독립 기대값 |
| conformance.json | 실행 전 source 사례·입력·기대 결과 |
| evidence.schema.json | 실제 구현 milestone 기록 형식 |

JSON schema는 관계·의미 검사를 대체하지 않는다. quota의 부분합, parent subset, source bounds, opcode 수명·ownership은 prose/검사기가 함께 정의한다. 정책은 ceiling이며 run 설정이 늘릴 수 없다. 예시 숫자는 배포 환경에서 측정해 조정한다.

IR2의 value layout과 ABI2의 native struct layout, TLV1의 wire encoding은 서로 다른 규격이다. 캐스팅으로 공유하지 않는다. IPC2 magic BRC2의 숫자는 design 버전으로 자동 치환하지 않는다. catalog/TLV의 원본 golden도 변경하지 않았다.

Python 검사는 작은 입력에 대한 reference model이다. strict_json은 production secure streaming parser가 아니며 metadata를 먼저 큰 DOM으로 만든 뒤 검사하는 구현을 채택하라는 예제가 아니다. 실제 native parser는 allocation 전에 budget을 적용한다.
