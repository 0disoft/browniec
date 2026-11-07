module tests::m2::runtime_policy;
import runtime_policy as policy;
import runtime_policy_limits as limits;
import runtime_policy_json as j;
import std::bytes as bytes;
fn ref u8[] policy_fixture(usize i){
    if(i==0){return b"{\n  \"schema\": \"brownie.policy/0.3\",\n  \"compile\": {\n    \"source_bytes\": 262144,\n    \"modules\": 32,\n    \"depth\": 128,\n    \"tokens\": 131072,\n    \"functions\": 4096,\n    \"types\": 4096,\n    \"instructions\": 262144,\n    \"registers_per_function\": 1024,\n    \"working_bytes\": 67108864,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 2000,\n    \"diagnostics\": 32\n  },\n  \"engine\": {\n    \"memory_bytes\": 134217728,\n    \"control_bytes\": 1048576,\n    \"program_bytes\": 8388608,\n    \"total_program_bytes\": 67108864,\n    \"instances_bytes\": 67108864,\n    \"max_programs\": 64,\n    \"max_instances\": 64,\n    \"max_compiles\": 1\n  },\n  \"run\": {\n    \"memory_bytes\": 16777216,\n    \"object_bytes\": 4194304,\n    \"call_frames\": 128,\n    \"input_bytes\": 1048576,\n    \"output_bytes\": 1048576,\n    \"host_request_bytes\": 1048576,\n    \"host_response_bytes\": 1048576,\n    \"host_calls\": 256,\n    \"owner_entries\": 16384,\n    \"descriptor_entries\": 16384,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 1000\n  },\n  \"worker\": {\n    \"memory_bytes\": 201326592,\n    \"user_cpu_time_ms\": 5000,\n    \"max_processes\": 1,\n    \"transport_bytes\": 4194304,\n    \"startup_ms\": 2000,\n    \"io_idle_ms\": 1000,\n    \"shutdown_grace_ms\": 250,\n    \"session_ms\": 10000\n  },\n  \"capabilities\": []\n}\n";}
    if(i==1){return b"{\n  \"schema\": \"brownie.policy/0.3\",\n  \"compile\": {\n    \"source_bytes\": 262144,\n    \"modules\": 32,\n    \"depth\": 128,\n    \"tokens\": 131072,\n    \"functions\": 4096,\n    \"types\": 4096,\n    \"instructions\": 262144,\n    \"registers_per_function\": 1024,\n    \"working_bytes\": 67108864,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 2000,\n    \"diagnostics\": 32\n  },\n  \"engine\": {\n    \"memory_bytes\": 134217728,\n    \"control_bytes\": 1048576,\n    \"program_bytes\": 8388608,\n    \"total_program_bytes\": 67108864,\n    \"instances_bytes\": 67108864,\n    \"max_programs\": 64,\n    \"max_instances\": 64,\n    \"max_compiles\": 1\n  },\n  \"run\": {\n    \"memory_bytes\": 16777216,\n    \"object_bytes\": 4194304,\n    \"call_frames\": 128,\n    \"input_bytes\": 1048576,\n    \"output_bytes\": 1048576,\n    \"host_request_bytes\": 1048576,\n    \"host_response_bytes\": 1048576,\n    \"host_calls\": 256,\n    \"owner_entries\": 16384,\n    \"descriptor_entries\": 16384,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 1000\n  },\n  \"worker\": {\n    \"memory_bytes\": 201326592,\n    \"user_cpu_time_ms\": 5000,\n    \"max_processes\": 1,\n    \"transport_bytes\": 4194304,\n    \"startup_ms\": 2000,\n    \"io_idle_ms\": 1000,\n    \"shutdown_grace_ms\": 250,\n    \"session_ms\": 10000\n  },\n  \"capabilities\": [\n    \"brownie.output.emit\"\n  ]\n}\n";}
    if(i==2){return b"{\n  \"schema\": \"brownie.policy/0.3\",\n  \"compile\": {\n    \"source_bytes\": 262144,\n    \"modules\": 32,\n    \"depth\": 128,\n    \"tokens\": 131072,\n    \"functions\": 4096,\n    \"types\": 4096,\n    \"instructions\": 262144,\n    \"registers_per_function\": 1024,\n    \"working_bytes\": 67108864,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 2000,\n    \"diagnostics\": 32\n  },\n  \"engine\": {\n    \"memory_bytes\": 134217728,\n    \"control_bytes\": 1048576,\n    \"program_bytes\": 8388608,\n    \"total_program_bytes\": 67108864,\n    \"instances_bytes\": 67108864,\n    \"max_programs\": 64,\n    \"max_instances\": 64,\n    \"max_compiles\": 1\n  },\n  \"run\": {\n    \"memory_bytes\": 16777216,\n    \"object_bytes\": 4194304,\n    \"call_frames\": 128,\n    \"input_bytes\": 1048576,\n    \"output_bytes\": 1048576,\n    \"host_request_bytes\": 1048576,\n    \"host_response_bytes\": 1048576,\n    \"host_calls\": 256,\n    \"owner_entries\": 16384,\n    \"descriptor_entries\": 16384,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 1000\n  },\n  \"worker\": {\n    \"memory_bytes\": 201326592,\n    \"user_cpu_time_ms\": 5000,\n    \"max_processes\": 1,\n    \"transport_bytes\": 4194304,\n    \"startup_ms\": 2000,\n    \"io_idle_ms\": 1000,\n    \"shutdown_grace_ms\": 250,\n    \"session_ms\": 10000\n  },\n  \"capabilities\": [\n    \"host.example.check\"\n  ]\n}\n";}
    if(i==3){return b"{\n  \"schema\": \"brownie.policy/0.3\",\n  \"compile\": {\n    \"source_bytes\": 262144,\n    \"modules\": 32,\n    \"depth\": 128,\n    \"tokens\": 131072,\n    \"functions\": 4096,\n    \"types\": 4096,\n    \"instructions\": 262144,\n    \"registers_per_function\": 1024,\n    \"working_bytes\": 67108864,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 2000,\n    \"diagnostics\": 32\n  },\n  \"engine\": {\n    \"memory_bytes\": 134217728,\n    \"control_bytes\": 1048576,\n    \"program_bytes\": 8388608,\n    \"total_program_bytes\": 67108864,\n    \"instances_bytes\": 67108864,\n    \"max_programs\": 64,\n    \"max_instances\": 64,\n    \"max_compiles\": 1\n  },\n  \"run\": {\n    \"memory_bytes\": 16777216,\n    \"object_bytes\": 4194304,\n    \"call_frames\": 128,\n    \"input_bytes\": 1048576,\n    \"output_bytes\": 1048576,\n    \"host_request_bytes\": 1048576,\n    \"host_response_bytes\": 1048576,\n    \"host_calls\": 256,\n    \"owner_entries\": 16384,\n    \"descriptor_entries\": 16384,\n    \"fuel\": 100,\n    \"deadline_ms\": 60000\n  },\n  \"worker\": {\n    \"memory_bytes\": 201326592,\n    \"user_cpu_time_ms\": 5000,\n    \"max_processes\": 1,\n    \"transport_bytes\": 4194304,\n    \"startup_ms\": 2000,\n    \"io_idle_ms\": 1000,\n    \"shutdown_grace_ms\": 250,\n    \"session_ms\": 120000\n  },\n  \"capabilities\": []\n}\n";}
    if(i==4){return b"{\n  \"schema\": \"brownie.policy/0.3\",\n  \"compile\": {\n    \"source_bytes\": 262144,\n    \"modules\": 32,\n    \"depth\": 128,\n    \"tokens\": 131072,\n    \"functions\": 4096,\n    \"types\": 4096,\n    \"instructions\": 262144,\n    \"registers_per_function\": 1024,\n    \"working_bytes\": 67108864,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 2000,\n    \"diagnostics\": 32\n  },\n  \"engine\": {\n    \"memory_bytes\": 100663296,\n    \"control_bytes\": 1048576,\n    \"program_bytes\": 8388608,\n    \"total_program_bytes\": 8388608,\n    \"instances_bytes\": 16777216,\n    \"max_programs\": 1,\n    \"max_instances\": 1,\n    \"max_compiles\": 1\n  },\n  \"run\": {\n    \"memory_bytes\": 16777216,\n    \"object_bytes\": 4194304,\n    \"call_frames\": 128,\n    \"input_bytes\": 1048576,\n    \"output_bytes\": 1048576,\n    \"host_request_bytes\": 1048576,\n    \"host_response_bytes\": 1048576,\n    \"host_calls\": 256,\n    \"owner_entries\": 16384,\n    \"descriptor_entries\": 16384,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 1000\n  },\n  \"worker\": {\n    \"memory_bytes\": 201326592,\n    \"user_cpu_time_ms\": 5000,\n    \"max_processes\": 1,\n    \"transport_bytes\": 4194304,\n    \"startup_ms\": 2000,\n    \"io_idle_ms\": 1000,\n    \"shutdown_grace_ms\": 250,\n    \"session_ms\": 10000\n  },\n  \"capabilities\": [\n    \"brownie.output.emit\"\n  ]\n}\n";}
    return b"{\"schema\":\"brownie.policy/0.3\",\"compile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":268435456,\"fuel\":1000000000,\"deadline_ms\":60000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":1073741824,\"control_bytes\":4194304,\"program_bytes\":67108864,\"total_program_bytes\":536870912,\"instances_bytes\":536870912,\"max_programs\":1024,\"max_instances\":1024,\"max_compiles\":1},\"run\":{\"memory_bytes\":268435456,\"object_bytes\":16777216,\"call_frames\":4096,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":65535,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":1000000000000,\"deadline_ms\":60000},\"worker\":{\"memory_bytes\":2147483648,\"user_cpu_time_ms\":120000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":60000,\"io_idle_ms\":60000,\"shutdown_grace_ms\":5000,\"session_ms\":120000},\"capabilities\":[\"a.c0\",\"a.c1\",\"a.c2\",\"a.c3\",\"a.c4\",\"a.c5\",\"a.c6\",\"a.c7\",\"a.c8\",\"a.c9\",\"a.c10\",\"a.c11\",\"a.c12\",\"a.c13\",\"a.c14\",\"a.c15\",\"a.c16\",\"a.c17\",\"a.c18\",\"a.c19\",\"a.c20\",\"a.c21\",\"a.c22\",\"a.c23\",\"a.c24\",\"a.c25\",\"a.c26\",\"a.c27\",\"a.c28\",\"a.c29\",\"a.c30\",\"a.c31\",\"a.c32\",\"a.c33\",\"a.c34\",\"a.c35\",\"a.c36\",\"a.c37\",\"a.c38\",\"a.c39\",\"a.c40\",\"a.c41\",\"a.c42\",\"a.c43\",\"a.c44\",\"a.c45\",\"a.c46\",\"a.c47\",\"a.c48\",\"a.c49\",\"a.c50\",\"a.c51\",\"a.c52\",\"a.c53\",\"a.c54\",\"a.c55\",\"a.c56\",\"a.c57\",\"a.c58\",\"a.c59\",\"a.c60\",\"a.c61\",\"a.c62\",\"a.c63\",\"a.c64\"]}";
}
fn policy::Policy parsed_policy(ref u8[] source){
    return switch(policy::parse(source)){case .ok(p):{p}case .err(_):{assert(false);return parsed_policy(b"");}};
}
fn u8 code(j::Failure f){return switch(f){
    case .Json:{1}case .Limit:{2}case .Unknown:{3}case .Duplicate:{4}case .Missing:{5}
    case .Value:{6}case .Relation:{7}case .Authority:{8}case .Allocation:{9}case .Bounds:{10}
};}
fn bytes::Buffer mutated(ref u8[] original,usize begin,usize end,ref u8[] replacement){
    var bytes::Buffer out=bytes::empty();assert(bytes::append(ref mut out,original[..begin]).is_ok);
    assert(bytes::append(ref mut out,replacement).is_ok);assert(bytes::append(ref mut out,original[end..original.len]).is_ok);return out;
}
fn ref u8[] policy_base(){return b"{\"schema\":\"brownie.policy/0.3\",\"compile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":67108864,\"fuel\":10000000,\"deadline_ms\":2000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":134217728,\"control_bytes\":1048576,\"program_bytes\":8388608,\"total_program_bytes\":67108864,\"instances_bytes\":67108864,\"max_programs\":64,\"max_instances\":64,\"max_compiles\":1},\"run\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"worker\":{\"memory_bytes\":201326592,\"user_cpu_time_ms\":5000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":2000,\"io_idle_ms\":1000,\"shutdown_grace_ms\":250,\"session_ms\":10000},\"capabilities\":[]}";}
fn void policy_case(usize begin,usize end,ref u8[] replacement,bool accepted,u8 failure){
    let bytes::Buffer source=mutated(policy_base(),begin,end,replacement);let ref u8[] input=bytes::view(ref source);
    switch(policy::parse(input)){
        case .ok(p):{assert(accepted);assert(policy::allows_run(ref p,policy::run_limits(ref p)));}
        case .err(e):{assert(!accepted);assert(e.offset<=input.len);if(failure!=0){assert(code(e.kind)==failure);}}
    };
}

@test fn void policy_numeric(){
    // compile.source_bytes.under
    policy_case(57,63,b"0",false,6);
    // compile.source_bytes.over
    policy_case(62,63,b"5",false,6);
    // compile.modules.under
    policy_case(74,76,b"0",false,6);
    // compile.modules.over
    policy_case(75,76,b"3",false,6);
    // compile.depth.under
    policy_case(85,88,b"0",false,6);
    // compile.depth.over
    policy_case(87,88,b"9",false,6);
    // compile.tokens.under
    policy_case(98,104,b"0",false,6);
    // compile.tokens.over
    policy_case(103,104,b"3",false,6);
    // compile.functions.under
    policy_case(117,121,b"0",false,6);
    // compile.functions.over
    policy_case(120,121,b"7",false,6);
    // compile.types.under
    policy_case(130,134,b"0",false,6);
    // compile.types.over
    policy_case(133,134,b"7",false,6);
    // compile.instructions.under
    policy_case(150,156,b"0",false,6);
    // compile.instructions.over
    policy_case(155,156,b"5",false,6);
    // compile.registers_per_function.under
    policy_case(182,186,b"0",false,6);
    // compile.registers_per_function.over
    policy_case(185,186,b"5",false,6);
    // compile.working_bytes.under
    policy_case(203,211,b"0",false,6);
    // compile.working_bytes.over
    policy_case(203,211,b"268435457",false,6);
    // compile.fuel.under
    policy_case(219,226,b"",false,6);
    // compile.fuel.over
    policy_case(227,227,b"01",false,6);
    // compile.deadline_ms.under
    policy_case(242,245,b"",false,6);
    // compile.deadline_ms.over
    policy_case(242,246,b"60001",false,6);
    // compile.diagnostics.under
    policy_case(261,263,b"0",false,6);
    // compile.diagnostics.over
    policy_case(262,263,b"3",false,6);
    // engine.memory_bytes.under
    policy_case(290,299,b"0",false,6);
    // engine.memory_bytes.over
    policy_case(291,299,b"073741825",false,6);
    // engine.control_bytes.under
    policy_case(316,323,b"0",false,6);
    // engine.control_bytes.over
    policy_case(316,323,b"4194305",false,6);
    // engine.program_bytes.under
    policy_case(340,347,b"0",false,6);
    // engine.program_bytes.over
    policy_case(340,347,b"67108865",false,6);
    // engine.total_program_bytes.under
    policy_case(370,378,b"0",false,6);
    // engine.total_program_bytes.over
    policy_case(370,378,b"536870913",false,6);
    // engine.instances_bytes.under
    policy_case(397,405,b"0",false,6);
    // engine.instances_bytes.over
    policy_case(397,405,b"536870913",false,6);
    // engine.max_programs.under
    policy_case(421,423,b"0",false,6);
    // engine.max_programs.over
    policy_case(421,423,b"1025",false,6);
    // engine.max_instances.under
    policy_case(440,442,b"0",false,6);
    // engine.max_instances.over
    policy_case(440,442,b"1025",false,6);
    // engine.max_compiles.under
    policy_case(458,459,b"0",false,6);
    // engine.max_compiles.over
    policy_case(458,459,b"2",false,6);
    // run.memory_bytes.under
    policy_case(483,491,b"0",false,6);
    // run.memory_bytes.over
    policy_case(483,491,b"268435457",false,6);
    // run.object_bytes.under
    policy_case(507,514,b"0",false,6);
    // run.object_bytes.over
    policy_case(507,514,b"16777217",false,6);
    // run.call_frames.under
    policy_case(529,532,b"0",false,6);
    // run.call_frames.over
    policy_case(529,532,b"4097",false,6);
    // run.input_bytes.under
    policy_case(547,554,b"-1",false,6);
    // run.input_bytes.over
    policy_case(553,554,b"7",false,6);
    // run.output_bytes.under
    policy_case(570,577,b"-1",false,6);
    // run.output_bytes.over
    policy_case(576,577,b"7",false,6);
    // run.host_request_bytes.under
    policy_case(599,606,b"0",false,6);
    // run.host_request_bytes.over
    policy_case(605,606,b"7",false,6);
    // run.host_response_bytes.under
    policy_case(629,636,b"0",false,6);
    // run.host_response_bytes.over
    policy_case(635,636,b"7",false,6);
    // run.host_calls.under
    policy_case(650,653,b"-1",false,6);
    // run.host_calls.over
    policy_case(650,652,b"6553",false,6);
    // run.owner_entries.under
    policy_case(670,675,b"0",false,6);
    // run.owner_entries.over
    policy_case(674,675,b"5",false,6);
    // run.descriptor_entries.under
    policy_case(697,702,b"0",false,6);
    // run.descriptor_entries.over
    policy_case(701,702,b"5",false,6);
    // run.fuel.under
    policy_case(710,717,b"",false,6);
    // run.fuel.over
    policy_case(718,718,b"00001",false,6);
    // run.deadline_ms.under
    policy_case(733,736,b"",false,6);
    // run.deadline_ms.over
    policy_case(733,737,b"60001",false,6);
    // worker.memory_bytes.under
    policy_case(764,773,b"0",false,6);
    // worker.memory_bytes.over
    policy_case(765,773,b"147483649",false,6);
    // worker.user_cpu_time_ms.under
    policy_case(793,796,b"",false,6);
    // worker.user_cpu_time_ms.over
    policy_case(793,797,b"120001",false,6);
    // worker.max_processes.under
    policy_case(814,815,b"0",false,6);
    // worker.max_processes.over
    policy_case(814,815,b"2",false,6);
    // worker.transport_bytes.under
    policy_case(840,841,b"3",false,6);
    // worker.transport_bytes.over
    policy_case(840,841,b"5",false,6);
    // worker.startup_ms.under
    policy_case(855,858,b"",false,6);
    // worker.startup_ms.over
    policy_case(855,859,b"60001",false,6);
    // worker.io_idle_ms.under
    policy_case(873,876,b"",false,6);
    // worker.io_idle_ms.over
    policy_case(873,877,b"60001",false,6);
    // worker.shutdown_grace_ms.under
    policy_case(898,900,b"",false,6);
    // worker.shutdown_grace_ms.over
    policy_case(898,901,b"5001",false,6);
    // worker.session_ms.under
    policy_case(915,919,b"",false,6);
    // worker.session_ms.over
    policy_case(916,920,b"20001",false,6);
}

@test fn void policy_required(){
    // compile.source_bytes
    policy_case(43,65,b"",false,5);
    // compile.modules
    policy_case(65,78,b"",false,5);
    // compile.depth
    policy_case(78,90,b"",false,5);
    // compile.tokens
    policy_case(90,106,b"",false,5);
    // compile.functions
    policy_case(106,123,b"",false,5);
    // compile.types
    policy_case(123,136,b"",false,5);
    // compile.instructions
    policy_case(136,158,b"",false,5);
    // compile.registers_per_function
    policy_case(158,188,b"",false,5);
    // compile.working_bytes
    policy_case(188,213,b"",false,5);
    // compile.fuel
    policy_case(213,229,b"",false,5);
    // compile.deadline_ms
    policy_case(230,249,b"",false,5);
    // compile.diagnostics
    policy_case(246,263,b"",false,5);
    // engine.memory_bytes
    policy_case(276,301,b"",false,5);
    // engine.control_bytes
    policy_case(301,325,b"",false,5);
    // engine.program_bytes
    policy_case(325,349,b"",false,5);
    // engine.total_program_bytes
    policy_case(349,380,b"",false,5);
    // engine.instances_bytes
    policy_case(380,407,b"",false,5);
    // engine.max_programs
    policy_case(411,429,b"",false,5);
    // engine.max_instances
    policy_case(429,448,b"",false,5);
    // engine.max_compiles
    policy_case(442,459,b"",false,5);
    // run.memory_bytes
    policy_case(469,493,b"",false,5);
    // run.object_bytes
    policy_case(493,516,b"",false,5);
    // run.call_frames
    policy_case(516,534,b"",false,5);
    // run.input_bytes
    policy_case(534,556,b"",false,5);
    // run.output_bytes
    policy_case(556,579,b"",false,5);
    // run.host_request_bytes
    policy_case(586,615,b"",false,5);
    // run.host_response_bytes
    policy_case(613,643,b"",false,5);
    // run.host_calls
    policy_case(638,655,b"",false,5);
    // run.owner_entries
    policy_case(655,677,b"",false,5);
    // run.descriptor_entries
    policy_case(677,704,b"",false,5);
    // run.fuel
    policy_case(704,720,b"",false,5);
    // run.deadline_ms
    policy_case(718,737,b"",false,5);
    // worker.memory_bytes
    policy_case(750,775,b"",false,5);
    // worker.user_cpu_time_ms
    policy_case(775,799,b"",false,5);
    // worker.max_processes
    policy_case(799,817,b"",false,5);
    // worker.transport_bytes
    policy_case(817,843,b"",false,5);
    // worker.startup_ms
    policy_case(843,861,b"",false,5);
    // worker.io_idle_ms
    policy_case(861,879,b"",false,5);
    // worker.shutdown_grace_ms
    policy_case(880,904,b"",false,5);
    // worker.session_ms
    policy_case(901,920,b"",false,5);
    // root.schema
    policy_case(2,32,b"",false,5);
    // root.compile
    policy_case(32,266,b"",false,5);
    // root.engine
    policy_case(266,462,b"",false,5);
    // root.run
    policy_case(462,740,b"",false,5);
    // root.worker
    policy_case(740,923,b"",false,5);
    // root.capabilities
    policy_case(921,939,b"",false,5);
}

@test fn void policy_duplicate(){
    // compile.source_bytes
    policy_case(43,43,b"\\u0073ource_bytes\":262144,\"",false,4);
    // compile.modules
    policy_case(43,43,b"\\u006dodules\":32,\"",false,4);
    // compile.depth
    policy_case(43,43,b"\\u0064epth\":128,\"",false,4);
    // compile.tokens
    policy_case(43,43,b"\\u0074okens\":131072,\"",false,4);
    // compile.functions
    policy_case(43,43,b"\\u0066unctions\":4096,\"",false,4);
    // compile.types
    policy_case(43,43,b"\\u0074ypes\":4096,\"",false,4);
    // compile.instructions
    policy_case(43,43,b"\\u0069nstructions\":262144,\"",false,4);
    // compile.registers_per_function
    policy_case(43,43,b"\\u0072egisters_per_function\":1024,\"",false,4);
    // compile.working_bytes
    policy_case(43,43,b"\\u0077orking_bytes\":67108864,\"",false,4);
    // compile.fuel
    policy_case(43,43,b"\\u0066uel\":10000000,\"",false,4);
    // compile.deadline_ms
    policy_case(43,43,b"\\u0064eadline_ms\":2000,\"",false,4);
    // compile.diagnostics
    policy_case(43,43,b"\\u0064iagnostics\":32,\"",false,4);
    // engine.memory_bytes
    policy_case(276,276,b"\\u006demory_bytes\":134217728,\"",false,4);
    // engine.control_bytes
    policy_case(276,276,b"\\u0063ontrol_bytes\":1048576,\"",false,4);
    // engine.program_bytes
    policy_case(276,276,b"\\u0070rogram_bytes\":8388608,\"",false,4);
    // engine.total_program_bytes
    policy_case(276,276,b"\\u0074otal_program_bytes\":67108864,\"",false,4);
    // engine.instances_bytes
    policy_case(276,276,b"\\u0069nstances_bytes\":67108864,\"",false,4);
    // engine.max_programs
    policy_case(276,276,b"\\u006dax_programs\":64,\"",false,4);
    // engine.max_instances
    policy_case(276,276,b"\\u006dax_instances\":64,\"",false,4);
    // engine.max_compiles
    policy_case(276,276,b"\\u006dax_compiles\":1,\"",false,4);
    // run.memory_bytes
    policy_case(469,469,b"\\u006demory_bytes\":16777216,\"",false,4);
    // run.object_bytes
    policy_case(469,469,b"\\u006fbject_bytes\":4194304,\"",false,4);
    // run.call_frames
    policy_case(469,469,b"\\u0063all_frames\":128,\"",false,4);
    // run.input_bytes
    policy_case(469,469,b"\\u0069nput_bytes\":1048576,\"",false,4);
    // run.output_bytes
    policy_case(469,469,b"\\u006futput_bytes\":1048576,\"",false,4);
    // run.host_request_bytes
    policy_case(469,469,b"\\u0068ost_request_bytes\":1048576,\"",false,4);
    // run.host_response_bytes
    policy_case(469,469,b"\\u0068ost_response_bytes\":1048576,\"",false,4);
    // run.host_calls
    policy_case(469,469,b"\\u0068ost_calls\":256,\"",false,4);
    // run.owner_entries
    policy_case(469,469,b"\\u006fwner_entries\":16384,\"",false,4);
    // run.descriptor_entries
    policy_case(469,469,b"\\u0064escriptor_entries\":16384,\"",false,4);
    // run.fuel
    policy_case(469,469,b"\\u0066uel\":10000000,\"",false,4);
    // run.deadline_ms
    policy_case(469,469,b"\\u0064eadline_ms\":1000,\"",false,4);
    // worker.memory_bytes
    policy_case(750,750,b"\\u006demory_bytes\":201326592,\"",false,4);
    // worker.user_cpu_time_ms
    policy_case(750,750,b"\\u0075ser_cpu_time_ms\":5000,\"",false,4);
    // worker.max_processes
    policy_case(750,750,b"\\u006dax_processes\":1,\"",false,4);
    // worker.transport_bytes
    policy_case(750,750,b"\\u0074ransport_bytes\":4194304,\"",false,4);
    // worker.startup_ms
    policy_case(750,750,b"\\u0073tartup_ms\":2000,\"",false,4);
    // worker.io_idle_ms
    policy_case(750,750,b"\\u0069o_idle_ms\":1000,\"",false,4);
    // worker.shutdown_grace_ms
    policy_case(750,750,b"\\u0073hutdown_grace_ms\":250,\"",false,4);
    // worker.session_ms
    policy_case(750,750,b"\\u0073ession_ms\":10000,\"",false,4);
    // root.schema
    policy_case(2,2,b"\\u0073chema\":\"brownie.policy/0.3\",\"",false,4);
    // root.compile
    policy_case(2,2,b"\\u0063ompile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":67108864,\"fuel\":10000000,\"deadline_ms\":2000,\"diagnostics\":32},\"",false,4);
    // root.engine
    policy_case(2,2,b"\\u0065ngine\":{\"memory_bytes\":134217728,\"control_bytes\":1048576,\"program_bytes\":8388608,\"total_program_bytes\":67108864,\"instances_bytes\":67108864,\"max_programs\":64,\"max_instances\":64,\"max_compiles\":1},\"",false,4);
    // root.run
    policy_case(2,2,b"\\u0072un\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"",false,4);
    // root.worker
    policy_case(2,2,b"\\u0077orker\":{\"memory_bytes\":201326592,\"user_cpu_time_ms\":5000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":2000,\"io_idle_ms\":1000,\"shutdown_grace_ms\":250,\"session_ms\":10000},\"",false,4);
    // root.capabilities
    policy_case(2,2,b"\\u0063apabilities\":[],\"",false,4);
}

@test fn void policy_grammar(){
    // unknown.None
    policy_case(939,939,b",\"unknown\":0",false,3);
    // unknown.compile
    policy_case(263,263,b",\"unknown\":0",false,3);
    // unknown.engine
    policy_case(459,459,b",\"unknown\":0",false,3);
    // unknown.run
    policy_case(737,737,b",\"unknown\":0",false,3);
    // unknown.worker
    policy_case(920,920,b",\"unknown\":0",false,3);
    // integer.-0
    policy_case(710,717,b"-",false,0);
    // integer.-1
    policy_case(710,718,b"-1",false,0);
    // integer.01
    policy_case(710,718,b"01",false,0);
    // integer.1.0
    policy_case(711,717,b".",false,0);
    // integer.1e0
    policy_case(711,717,b"e",false,0);
    // integer.1E+0
    policy_case(711,717,b"E+",false,0);
    // integer.18446744073709551615
    policy_case(711,718,b"8446744073709551615",false,0);
    // integer.18446744073709551616
    policy_case(711,718,b"8446744073709551616",false,0);
    // integer.9999999999999999999999999
    policy_case(710,718,b"9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999",false,0);
    // integer.9223372036854775808
    policy_case(710,718,b"9223372036854775808",false,0);
    // integer.true
    policy_case(710,718,b"true",false,0);
    // integer.null
    policy_case(710,718,b"null",false,0);
    // integer."1"
    policy_case(710,718,b"\"1\"",false,0);
    // empty
    policy_case(0,940,b"",false,0);
    // array
    policy_case(0,940,b"[]",false,0);
    // null
    policy_case(0,940,b"null",false,0);
    // bom
    policy_case(0,0,b"\xef\xbb\xbf",false,0);
    // trailing-root
    policy_case(940,940,b"{}",false,0);
    // trailing-garbage
    policy_case(940,940,b"x",false,0);
    // root-comma
    policy_case(939,939,b",",false,0);
    // missing-comma
    policy_case(30,31,b" ",false,0);
    // missing-colon
    policy_case(9,10,b" ",false,0);
    // bad-escape
    policy_case(11,25,b"\\q",false,0);
    // unpaired-high
    policy_case(11,25,b"\\ud800",false,0);
    // unpaired-low
    policy_case(11,25,b"\\udc00",false,0);
    // invalid-utf8
    policy_case(11,25,b"\xff",false,0);
    // raw-control
    policy_case(11,25,b"\x01",false,0);
    // nested-unknown
    policy_case(2,938,b"unknown\":[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[0]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",false,0);
    // empty-object
    policy_case(1,939,b"",false,0);
}

@test fn void policy_accepted(){
    // maxima
    policy_case(203,938,b"268435456,\"fuel\":1000000000,\"deadline_ms\":60000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":1073741824,\"control_bytes\":4194304,\"program_bytes\":67108864,\"total_program_bytes\":536870912,\"instances_bytes\":536870912,\"max_programs\":1024,\"max_instances\":1024,\"max_compiles\":1},\"run\":{\"memory_bytes\":268435456,\"object_bytes\":16777216,\"call_frames\":4096,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":65535,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":1000000000000,\"deadline_ms\":60000},\"worker\":{\"memory_bytes\":2147483648,\"user_cpu_time_ms\":120000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":60000,\"io_idle_ms\":60000,\"shutdown_grace_ms\":5000,\"session_ms\":120000},\"capabilities\":[\"a.c0\",\"a.c1\",\"a.c2\",\"a.c3\",\"a.c4\",\"a.c5\",\"a.c6\",\"a.c7\",\"a.c8\",\"a.c9\",\"a.c10\",\"a.c11\",\"a.c12\",\"a.c13\",\"a.c14\",\"a.c15\",\"a.c16\",\"a.c17\",\"a.c18\",\"a.c19\",\"a.c20\",\"a.c21\",\"a.c22\",\"a.c23\",\"a.c24\",\"a.c25\",\"a.c26\",\"a.c27\",\"a.c28\",\"a.c29\",\"a.c30\",\"a.c31\",\"a.c32\",\"a.c33\",\"a.c34\",\"a.c35\",\"a.c36\",\"a.c37\",\"a.c38\",\"a.c39\",\"a.c40\",\"a.c41\",\"a.c42\",\"a.c43\",\"a.c44\",\"a.c45\",\"a.c46\",\"a.c47\",\"a.c48\",\"a.c49\",\"a.c50\",\"a.c51\",\"a.c52\",\"a.c53\",\"a.c54\",\"a.c55\",\"a.c56\",\"a.c57\",\"a.c58\",\"a.c59\",\"a.c60\",\"a.c61\",\"a.c62\",\"a.c63\",\"a.c64\"",true,0);
    // minima
    policy_case(57,920,b"1,\"modules\":1,\"depth\":1,\"tokens\":1,\"functions\":1,\"types\":1,\"instructions\":1,\"registers_per_function\":1,\"working_bytes\":1,\"fuel\":1,\"deadline_ms\":1,\"diagnostics\":1},\"engine\":{\"memory_bytes\":1,\"control_bytes\":1,\"program_bytes\":1,\"total_program_bytes\":1,\"instances_bytes\":1,\"max_programs\":1,\"max_instances\":1,\"max_compiles\":1},\"run\":{\"memory_bytes\":1,\"object_bytes\":1,\"call_frames\":1,\"input_bytes\":0,\"output_bytes\":0,\"host_request_bytes\":1,\"host_response_bytes\":1,\"host_calls\":0,\"owner_entries\":1,\"descriptor_entries\":1,\"fuel\":1,\"deadline_ms\":1},\"worker\":{\"memory_bytes\":41943041,\"user_cpu_time_ms\":1,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":1,\"io_idle_ms\":1,\"shutdown_grace_ms\":1,\"session_ms\":1",true,0);
    // 128-byte-capability
    policy_case(938,938,b"\"a.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"",true,0);
    // decoded-schema-key-and-value
    policy_case(2,12,b"\\u0073chema\":\"\\u0062",true,0);
}

@test fn void policy_relations(){
    // 0.run.object_bytes
    policy_case(484,514,b",\"object_bytes\":16777216",false,7);
    // 1.run.input_bytes
    policy_case(484,491,b"",false,7);
    // 2.run.output_bytes
    policy_case(484,491,b"",false,7);
    // 3.run.host_request_bytes
    policy_case(484,491,b"",false,7);
    // 4.run.host_response_bytes
    policy_case(484,491,b"",false,7);
    // 5.run.memory_bytes
    policy_case(484,491,b"34217728",false,7);
    // 6.engine.program_bytes
    policy_case(340,378,b"67108864,\"total_program_bytes\":1",false,7);
    // 7.compile.working_bytes
    policy_case(203,211,b"268435456",false,7);
    // 8.engine.control_bytes
    policy_case(291,323,b",\"control_bytes\":4194304",false,7);
    // 9.engine.total_program_bytes
    policy_case(370,378,b"536870912",false,7);
    // 10.engine.instances_bytes
    policy_case(397,405,b"536870912",false,7);
    // 11.worker.memory_bytes
    policy_case(764,773,b"1",false,7);
    // 12.compile.source_bytes
    policy_case(203,211,b"1",false,7);
    // 13.worker.startup_ms
    policy_case(855,856,b"60",false,7);
    // 14.compile.deadline_ms
    policy_case(242,243,b"60",false,7);
    // 15.run.deadline_ms
    policy_case(733,734,b"60",false,7);
}

@test fn void policy_capabilities(){
    // ['a.b', 'a.b']
    policy_case(938,938,b"\"a.b\",\"a.b\"",false,4);
    // ['a']
    policy_case(938,938,b"\"a\"",false,6);
    // ['A.b']
    policy_case(938,938,b"\"A.b\"",false,6);
    // ['a..b']
    policy_case(938,938,b"\"a..b\"",false,6);
    // ['a.b_']
    policy_case(938,938,b"\"a.b_\"",false,6);
    // ['a.1']
    policy_case(938,938,b"\"a.1\"",false,6);
    // ['a.b.']
    policy_case(938,938,b"\"a.b.\"",false,6);
    // [1]
    policy_case(938,938,b"1",false,6);
    // ['a.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    policy_case(938,938,b"\"a.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"",false,2);
    // ['a.c0', 'a.c1', 'a.c2', 'a.c3', 'a.c4', 'a.c5', 'a.c6', 'a.
    policy_case(938,938,b"\"a.c0\",\"a.c1\",\"a.c2\",\"a.c3\",\"a.c4\",\"a.c5\",\"a.c6\",\"a.c7\",\"a.c8\",\"a.c9\",\"a.c10\",\"a.c11\",\"a.c12\",\"a.c13\",\"a.c14\",\"a.c15\",\"a.c16\",\"a.c17\",\"a.c18\",\"a.c19\",\"a.c20\",\"a.c21\",\"a.c22\",\"a.c23\",\"a.c24\",\"a.c25\",\"a.c26\",\"a.c27\",\"a.c28\",\"a.c29\",\"a.c30\",\"a.c31\",\"a.c32\",\"a.c33\",\"a.c34\",\"a.c35\",\"a.c36\",\"a.c37\",\"a.c38\",\"a.c39\",\"a.c40\",\"a.c41\",\"a.c42\",\"a.c43\",\"a.c44\",\"a.c45\",\"a.c46\",\"a.c47\",\"a.c48\",\"a.c49\",\"a.c50\",\"a.c51\",\"a.c52\",\"a.c53\",\"a.c54\",\"a.c55\",\"a.c56\",\"a.c57\",\"a.c58\",\"a.c59\",\"a.c60\",\"a.c61\",\"a.c62\",\"a.c63\",\"a.c64\",\"a.c65\"",false,2);
    // escaped-value-duplicate
    policy_case(938,938,b"\"a.b\",\"\\u0061.b\"",false,4);
}

@test fn void zip_originals_and_all_typed_fields(){
    {
        let policy::Policy p=parsed_policy(policy_fixture(0));
        let limits::CompileLimits compile=policy::compile_limits(ref p);
        assert(compile.source_bytes==262144);
        assert(compile.modules==32);
        assert(compile.depth==128);
        assert(compile.tokens==131072);
        assert(compile.functions==4096);
        assert(compile.types==4096);
        assert(compile.instructions==262144);
        assert(compile.registers_per_function==1024);
        assert(compile.working_bytes==67108864);
        assert(compile.fuel==10000000);
        assert(compile.deadline_ms==2000);
        assert(compile.diagnostics==32);
        let limits::EngineLimits engine=policy::engine_limits(ref p);
        assert(engine.memory_bytes==134217728);
        assert(engine.control_bytes==1048576);
        assert(engine.program_bytes==8388608);
        assert(engine.total_program_bytes==67108864);
        assert(engine.instances_bytes==67108864);
        assert(engine.max_programs==64);
        assert(engine.max_instances==64);
        assert(engine.max_compiles==1);
        let limits::RunLimits run=policy::run_limits(ref p);
        assert(run.memory_bytes==16777216);
        assert(run.object_bytes==4194304);
        assert(run.call_frames==128);
        assert(run.input_bytes==1048576);
        assert(run.output_bytes==1048576);
        assert(run.host_request_bytes==1048576);
        assert(run.host_response_bytes==1048576);
        assert(run.host_calls==256);
        assert(run.owner_entries==16384);
        assert(run.descriptor_entries==16384);
        assert(run.fuel==10000000);
        assert(run.deadline_ms==1000);
        let limits::WorkerLimits worker=policy::worker_limits(ref p);
        assert(worker.memory_bytes==201326592);
        assert(worker.user_cpu_time_ms==5000);
        assert(worker.max_processes==1);
        assert(worker.transport_bytes==4194304);
        assert(worker.startup_ms==2000);
        assert(worker.io_idle_ms==1000);
        assert(worker.shutdown_grace_ms==250);
        assert(worker.session_ms==10000);
        assert(policy::capability_count(ref p)==0);
        assert(!policy::capability(ref p,0).is_ok);
    }
    {
        let policy::Policy p=parsed_policy(policy_fixture(5));
        let limits::CompileLimits compile=policy::compile_limits(ref p);
        assert(compile.source_bytes==262144);
        assert(compile.modules==32);
        assert(compile.depth==128);
        assert(compile.tokens==131072);
        assert(compile.functions==4096);
        assert(compile.types==4096);
        assert(compile.instructions==262144);
        assert(compile.registers_per_function==1024);
        assert(compile.working_bytes==268435456);
        assert(compile.fuel==1000000000);
        assert(compile.deadline_ms==60000);
        assert(compile.diagnostics==32);
        let limits::EngineLimits engine=policy::engine_limits(ref p);
        assert(engine.memory_bytes==1073741824);
        assert(engine.control_bytes==4194304);
        assert(engine.program_bytes==67108864);
        assert(engine.total_program_bytes==536870912);
        assert(engine.instances_bytes==536870912);
        assert(engine.max_programs==1024);
        assert(engine.max_instances==1024);
        assert(engine.max_compiles==1);
        let limits::RunLimits run=policy::run_limits(ref p);
        assert(run.memory_bytes==268435456);
        assert(run.object_bytes==16777216);
        assert(run.call_frames==4096);
        assert(run.input_bytes==1048576);
        assert(run.output_bytes==1048576);
        assert(run.host_request_bytes==1048576);
        assert(run.host_response_bytes==1048576);
        assert(run.host_calls==65535);
        assert(run.owner_entries==16384);
        assert(run.descriptor_entries==16384);
        assert(run.fuel==1000000000000);
        assert(run.deadline_ms==60000);
        let limits::WorkerLimits worker=policy::worker_limits(ref p);
        assert(worker.memory_bytes==2147483648);
        assert(worker.user_cpu_time_ms==120000);
        assert(worker.max_processes==1);
        assert(worker.transport_bytes==4194304);
        assert(worker.startup_ms==60000);
        assert(worker.io_idle_ms==60000);
        assert(worker.shutdown_grace_ms==5000);
        assert(worker.session_ms==120000);
        assert(policy::capability_count(ref p)==65);
        assert(policy::contains_capability(ref p,b"a.c0"));
        assert(!policy::capability(ref p,65).is_ok);
    }
    var usize i=1;while(i<5){let policy::Policy p=parsed_policy(policy_fixture(i));assert(policy::capability_count(ref p)==if(i==3){0}else{1});let limits::RunLimits r=policy::run_limits(ref p);assert(r.fuel==if(i==3){100}else{10000000});i+=1;}
}

@test fn void input_and_token_budgets_and_no_silent_defaults(){
    var bytes::Buffer source=bytes::empty();assert(bytes::append(ref mut source,policy_fixture(0)).is_ok);
    while(bytes::len(ref source)<65536){assert(bytes::append(ref mut source,b" ").is_ok);}
    assert(policy::parse(bytes::view(ref source)).is_ok);
    assert(bytes::append(ref mut source,b" ").is_ok);assert(!policy::parse(bytes::view(ref source)).is_ok);
    var j::Cursor cursor=j::Cursor{.token=switch(j::start(b"{}")){case .ok(v):{v.token}case .err(_):{assert(false);return;}},.tokens=8192};
    assert(!j::next(b"{}",ref mut cursor).is_ok);
    assert(j::byte_limit()==65536 && j::token_limit()==8192 && j::capability_limit()==65);
}
@test fn void accepted_data_owns_decoded_strings_and_rejections_do_not_mutate_policy(){
    var bytes::Buffer source=bytes::empty();assert(bytes::append(ref mut source,policy_fixture(2)).is_ok);
    let policy::Policy p=parsed_policy(bytes::view(ref source));assert(bytes::append(ref mut source,b"invalid").is_ok);
    assert(policy::contains_capability(ref p,b"host.example.check"));
    let ref u8[] cap=switch(policy::capability(ref p,0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(bytes::equal(cap,b"host.example.check"));assert(!policy::contains_capability(ref p,b"host.example"));
    var limits::RunLimits zero=policy::run_limits(ref p);zero.fuel=0;assert(!policy::allows_run(ref p,zero));
}
