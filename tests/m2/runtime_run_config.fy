module tests::m2::runtime_run_config;
import runtime_run_config as run;
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
fn ref u8[] run_fixture(){return b"{\n  \"schema\": \"brownie.run/0.3\",\n  \"entry\": {\n    \"module\": \"main\",\n    \"function\": \"main\"\n  },\n  \"requires\": [],\n  \"grants\": [],\n  \"limits\": {\n    \"memory_bytes\": 16777216,\n    \"object_bytes\": 4194304,\n    \"call_frames\": 128,\n    \"input_bytes\": 1048576,\n    \"output_bytes\": 1048576,\n    \"host_request_bytes\": 1048576,\n    \"host_response_bytes\": 1048576,\n    \"host_calls\": 256,\n    \"owner_entries\": 16384,\n    \"descriptor_entries\": 16384,\n    \"fuel\": 10000000,\n    \"deadline_ms\": 1000\n  }\n}\n";}
fn ref u8[] run_base(){return b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"main\",\"function\":\"main\"},\"requires\":[],\"grants\":[],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}";}
fn void run_case(usize begin,usize end,ref u8[] replacement,bool accepted,u8 failure,usize fixture){
    let policy::Policy p=parsed_policy(policy_fixture(fixture));let bytes::Buffer source=mutated(run_base(),begin,end,replacement);
    let ref u8[] input=bytes::view(ref source);
    switch(run::parse(input,ref p)){
        case .ok(c):{assert(accepted);assert(run::narrowed_to(ref c,ref p));}
        case .err(e):{assert(!accepted);assert(e.offset<=input.len);if(failure!=0){assert(code(e.kind)==failure);}}
    };
}

@test fn void run_required(){
    // root.schema
    run_case(2,29,b"",false,5,0);
    // root.entry
    run_case(29,73,b"",false,5,0);
    // root.requires
    run_case(73,87,b"",false,5,0);
    // root.grants
    run_case(87,99,b"",false,5,0);
    // root.limits
    run_case(97,378,b"",false,5,0);
    // entry.module
    run_case(38,54,b"",false,5,0);
    // entry.function
    run_case(52,70,b"",false,5,0);
    // limits.memory_bytes
    run_case(109,133,b"",false,5,0);
    // limits.object_bytes
    run_case(133,156,b"",false,5,0);
    // limits.call_frames
    run_case(156,174,b"",false,5,0);
    // limits.input_bytes
    run_case(174,196,b"",false,5,0);
    // limits.output_bytes
    run_case(196,219,b"",false,5,0);
    // limits.host_request_bytes
    run_case(226,255,b"",false,5,0);
    // limits.host_response_bytes
    run_case(253,283,b"",false,5,0);
    // limits.host_calls
    run_case(278,295,b"",false,5,0);
    // limits.owner_entries
    run_case(295,317,b"",false,5,0);
    // limits.descriptor_entries
    run_case(317,344,b"",false,5,0);
    // limits.fuel
    run_case(344,360,b"",false,5,0);
    // limits.deadline_ms
    run_case(358,377,b"",false,5,0);
}

@test fn void run_duplicate(){
    // root.schema
    run_case(2,2,b"\\u0073chema\":\"brownie.run/0.3\",\"",false,4,0);
    // root.entry
    run_case(2,2,b"\\u0065ntry\":{\"module\":\"main\",\"function\":\"main\"},\"",false,4,0);
    // root.requires
    run_case(2,2,b"\\u0072equires\":[],\"",false,4,0);
    // root.grants
    run_case(2,2,b"\\u0067rants\":[],\"",false,4,0);
    // root.limits
    run_case(2,2,b"\\u006cimits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"",false,4,0);
    // entry.module
    run_case(38,38,b"\\u006dodule\":\"main\",\"",false,4,0);
    // entry.function
    run_case(38,38,b"\\u0066unction\":\"main\",\"",false,4,0);
    // limits.memory_bytes
    run_case(109,109,b"\\u006demory_bytes\":16777216,\"",false,4,0);
    // limits.object_bytes
    run_case(109,109,b"\\u006fbject_bytes\":4194304,\"",false,4,0);
    // limits.call_frames
    run_case(109,109,b"\\u0063all_frames\":128,\"",false,4,0);
    // limits.input_bytes
    run_case(109,109,b"\\u0069nput_bytes\":1048576,\"",false,4,0);
    // limits.output_bytes
    run_case(109,109,b"\\u006futput_bytes\":1048576,\"",false,4,0);
    // limits.host_request_bytes
    run_case(109,109,b"\\u0068ost_request_bytes\":1048576,\"",false,4,0);
    // limits.host_response_bytes
    run_case(109,109,b"\\u0068ost_response_bytes\":1048576,\"",false,4,0);
    // limits.host_calls
    run_case(109,109,b"\\u0068ost_calls\":256,\"",false,4,0);
    // limits.owner_entries
    run_case(109,109,b"\\u006fwner_entries\":16384,\"",false,4,0);
    // limits.descriptor_entries
    run_case(109,109,b"\\u0064escriptor_entries\":16384,\"",false,4,0);
    // limits.fuel
    run_case(109,109,b"\\u0066uel\":10000000,\"",false,4,0);
    // limits.deadline_ms
    run_case(109,109,b"\\u0064eadline_ms\":1000,\"",false,4,0);
}

@test fn void run_numeric(){
    // memory_bytes.under
    run_case(123,131,b"0",false,6,0);
    // memory_bytes.over-schema
    run_case(123,131,b"268435457",false,6,0);
    // object_bytes.under
    run_case(147,154,b"0",false,6,0);
    // object_bytes.over-schema
    run_case(147,154,b"16777217",false,6,0);
    // call_frames.under
    run_case(169,172,b"0",false,6,0);
    // call_frames.over-schema
    run_case(169,172,b"4097",false,6,0);
    // input_bytes.under
    run_case(187,194,b"-1",false,6,0);
    // input_bytes.over-schema
    run_case(193,194,b"7",false,6,0);
    // output_bytes.under
    run_case(210,217,b"-1",false,6,0);
    // output_bytes.over-schema
    run_case(216,217,b"7",false,6,0);
    // host_request_bytes.under
    run_case(239,246,b"0",false,6,0);
    // host_request_bytes.over-schema
    run_case(245,246,b"7",false,6,0);
    // host_response_bytes.under
    run_case(269,276,b"0",false,6,0);
    // host_response_bytes.over-schema
    run_case(275,276,b"7",false,6,0);
    // host_calls.under
    run_case(290,293,b"-1",false,6,0);
    // host_calls.over-schema
    run_case(290,292,b"6553",false,6,0);
    // owner_entries.under
    run_case(310,315,b"0",false,6,0);
    // owner_entries.over-schema
    run_case(314,315,b"5",false,6,0);
    // descriptor_entries.under
    run_case(337,342,b"0",false,6,0);
    // descriptor_entries.over-schema
    run_case(341,342,b"5",false,6,0);
    // fuel.under
    run_case(350,357,b"",false,6,0);
    // fuel.over-schema
    run_case(358,358,b"00001",false,6,0);
    // deadline_ms.under
    run_case(373,376,b"",false,6,0);
    // deadline_ms.over-schema
    run_case(373,377,b"60001",false,6,0);
}

@test fn void run_narrowing(){
    // memory_bytes.over-policy
    run_case(130,131,b"7",false,8,0);
    // object_bytes.over-policy
    run_case(153,154,b"5",false,8,0);
    // call_frames.over-policy
    run_case(171,172,b"9",false,8,0);
    // host_calls.over-policy
    run_case(292,293,b"7",false,8,0);
    // fuel.over-policy
    run_case(357,358,b"1",false,8,0);
    // deadline_ms.over-policy
    run_case(376,377,b"1",false,8,0);
    // missing-grant
    run_case(84,84,b"\"host.example.check\"",false,8,2);
    // not-in-policy
    run_case(96,96,b"\"host.example.check\"",false,8,0);
    // exact
    run_case(84,96,b"\"host.example.check\"],\"grants\":[\"host.example.check\"",true,0,2);
    // extra-grant
    run_case(96,96,b"\"host.example.check\"",true,0,2);
    // requires-outside
    run_case(84,96,b"\"a.b\"],\"grants\":[\"host.example.check\"",false,8,2);
    // output
    run_case(84,96,b"\"brownie.output.emit\"],\"grants\":[\"brownie.output.emit\"",true,0,1);
    // memory-cross-field
    run_case(124,131,b"",false,7,0);
}

@test fn void run_grammar(){
    // unknown.None
    run_case(378,378,b",\"unknown\":0",false,3,0);
    // unknown.entry
    run_case(70,70,b",\"unknown\":0",false,3,0);
    // unknown.limits
    run_case(377,377,b",\"unknown\":0",false,3,0);
    // bad-entry.225c75643833645c756465303022
    run_case(47,51,b"\\ud83d\\ude00",false,0,0);
    // bad-entry.225c756438303022
    run_case(47,51,b"\\ud800",false,0,0);
    // bad-entry.22615c753030303022
    run_case(47,51,b"a\\u0000",false,0,0);
    // bad-entry.225c7122
    run_case(47,51,b"\\q",false,0,0);
    // bad-entry.22ff22
    run_case(47,51,b"\xff",false,0,0);
    // bad-entry.22c3a922
    run_case(47,51,b"\xc3\xa9",false,0,0);
    // empty
    run_case(0,379,b"",false,0,0);
    // array
    run_case(0,379,b"[]",false,0,0);
    // empty-object
    run_case(1,378,b"",false,0,0);
    // bom
    run_case(0,0,b"\xef\xbb\xbf",false,0,0);
    // trailing-root
    run_case(379,379,b"{}",false,0,0);
    // comma
    run_case(378,378,b",",false,0,0);
    // entry-comma
    run_case(70,70,b",",false,0,0);
    // array-comma
    run_case(84,84,b"\"a.b\",",false,0,0);
    // missing-comma
    run_case(27,28,b" ",false,0,0);
    // wrong-schema
    run_case(25,26,b"4",false,0,0);
    // integer.-0
    run_case(350,357,b"-",false,0,0);
    // integer.01
    run_case(350,358,b"01",false,0,0);
    // integer.1.0
    run_case(351,357,b".",false,0,0);
    // integer.1e1
    run_case(351,358,b"e1",false,0,0);
    // integer.18446744073709551616
    run_case(351,358,b"8446744073709551616",false,0,0);
    // integer.9999999999999999999999999
    run_case(350,358,b"9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999",false,0,0);
    // integer.true
    run_case(350,358,b"true",false,0,0);
    // integer.null
    run_case(350,358,b"null",false,0,0);
}

@test fn void run_capabilities(){
    // requires['a.b', 'a.b']
    run_case(84,84,b"\"a.b\",\"a.b\"",false,4,0);
    // requires['A.b']
    run_case(84,84,b"\"A.b\"",false,6,0);
    // requires['a']
    run_case(84,84,b"\"a\"",false,6,0);
    // requires['a..b']
    run_case(84,84,b"\"a..b\"",false,6,0);
    // requires['a.b_']
    run_case(84,84,b"\"a.b_\"",false,6,0);
    // requires[1]
    run_case(84,84,b"1",false,6,0);
    // requires['a.c0', 'a.c1', 'a.c2', 'a.c3', 'a.c4', 'a.c
    run_case(84,84,b"\"a.c0\",\"a.c1\",\"a.c2\",\"a.c3\",\"a.c4\",\"a.c5\",\"a.c6\",\"a.c7\",\"a.c8\",\"a.c9\",\"a.c10\",\"a.c11\",\"a.c12\",\"a.c13\",\"a.c14\",\"a.c15\",\"a.c16\",\"a.c17\",\"a.c18\",\"a.c19\",\"a.c20\",\"a.c21\",\"a.c22\",\"a.c23\",\"a.c24\",\"a.c25\",\"a.c26\",\"a.c27\",\"a.c28\",\"a.c29\",\"a.c30\",\"a.c31\",\"a.c32\",\"a.c33\",\"a.c34\",\"a.c35\",\"a.c36\",\"a.c37\",\"a.c38\",\"a.c39\",\"a.c40\",\"a.c41\",\"a.c42\",\"a.c43\",\"a.c44\",\"a.c45\",\"a.c46\",\"a.c47\",\"a.c48\",\"a.c49\",\"a.c50\",\"a.c51\",\"a.c52\",\"a.c53\",\"a.c54\",\"a.c55\",\"a.c56\",\"a.c57\",\"a.c58\",\"a.c59\",\"a.c60\",\"a.c61\",\"a.c62\",\"a.c63\",\"a.c64\",\"a.c65\"",false,2,0);
    // requires.escaped-duplicate
    run_case(84,84,b"\"a.b\",\"\\u0061.b\"",false,4,0);
    // grants['a.b', 'a.b']
    run_case(96,96,b"\"a.b\",\"a.b\"",false,4,0);
    // grants['A.b']
    run_case(96,96,b"\"A.b\"",false,6,0);
    // grants['a']
    run_case(96,96,b"\"a\"",false,6,0);
    // grants['a..b']
    run_case(96,96,b"\"a..b\"",false,6,0);
    // grants['a.b_']
    run_case(96,96,b"\"a.b_\"",false,6,0);
    // grants[1]
    run_case(96,96,b"1",false,6,0);
    // grants['a.c0', 'a.c1', 'a.c2', 'a.c3', 'a.c4', 'a.c
    run_case(96,96,b"\"a.c0\",\"a.c1\",\"a.c2\",\"a.c3\",\"a.c4\",\"a.c5\",\"a.c6\",\"a.c7\",\"a.c8\",\"a.c9\",\"a.c10\",\"a.c11\",\"a.c12\",\"a.c13\",\"a.c14\",\"a.c15\",\"a.c16\",\"a.c17\",\"a.c18\",\"a.c19\",\"a.c20\",\"a.c21\",\"a.c22\",\"a.c23\",\"a.c24\",\"a.c25\",\"a.c26\",\"a.c27\",\"a.c28\",\"a.c29\",\"a.c30\",\"a.c31\",\"a.c32\",\"a.c33\",\"a.c34\",\"a.c35\",\"a.c36\",\"a.c37\",\"a.c38\",\"a.c39\",\"a.c40\",\"a.c41\",\"a.c42\",\"a.c43\",\"a.c44\",\"a.c45\",\"a.c46\",\"a.c47\",\"a.c48\",\"a.c49\",\"a.c50\",\"a.c51\",\"a.c52\",\"a.c53\",\"a.c54\",\"a.c55\",\"a.c56\",\"a.c57\",\"a.c58\",\"a.c59\",\"a.c60\",\"a.c61\",\"a.c62\",\"a.c63\",\"a.c64\",\"a.c65\"",false,2,0);
    // grants.escaped-duplicate
    run_case(96,96,b"\"a.b\",\"\\u0061.b\"",false,4,0);
}

@test fn void run_names(){
    // module.std
    run_case(47,51,b"std",true,0,0);
    // module.brownie::if
    run_case(47,51,b"brownie::if",true,0,0);
    // module._______________
    run_case(47,51,b"________________________________________________________________________________________________________________________________",true,0,0);
    // module.AAAAAAAAAAAAAAA
    run_case(47,51,b"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA::B",true,0,0);
    // module.a::
    run_case(47,51,b"a::",false,0,0);
    // module.::a
    run_case(47,51,b"::a",false,0,0);
    // module.a:b
    run_case(47,51,b"a:b",false,0,0);
    // module.9a
    run_case(47,51,b"9a",false,0,0);
    // module.a-b
    run_case(47,51,b"a-b",false,0,0);
    // module.a::1b
    run_case(47,51,b"a::1b",false,0,0);
    // module.AAAAAAAAAAAAAAA
    run_case(47,51,b"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",false,0,0);
    // module.a.
    run_case(47,51,b"a.",false,0,0);
    // function.if
    run_case(65,69,b"if",true,0,0);
    // function._______________
    run_case(65,69,b"________________________________________________________________",true,0,0);
    // function._______________
    run_case(65,69,b"_________________________________________________________________",false,0,0);
    // function.9a
    run_case(65,69,b"9a",false,0,0);
    // function.a::b
    run_case(65,69,b"a::b",false,0,0);
    // function.a-b
    run_case(65,69,b"a-b",false,0,0);
    // function.
    run_case(65,69,b"",false,0,0);
    // decoded-entry
    run_case(38,66,b"\\u006dodule\":\"\\u006dain\",\"function\":\"\\u006d",true,0,0);
}

@test fn void run_accepted(){
    // maxima
    run_case(123,374,b"268435456,\"object_bytes\":16777216,\"call_frames\":4096,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":65535,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":1000000000000,\"deadline_ms\":60",true,0,5);
    // minima
    run_case(124,377,b",\"object_bytes\":1,\"call_frames\":1,\"input_bytes\":0,\"output_bytes\":0,\"host_request_bytes\":1,\"host_response_bytes\":1,\"host_calls\":0,\"owner_entries\":1,\"descriptor_entries\":1,\"fuel\":1,\"deadline_ms\":1",true,0,5);
    // 65-capabilities
    run_case(84,96,b"\"a.c0\",\"a.c1\",\"a.c2\",\"a.c3\",\"a.c4\",\"a.c5\",\"a.c6\",\"a.c7\",\"a.c8\",\"a.c9\",\"a.c10\",\"a.c11\",\"a.c12\",\"a.c13\",\"a.c14\",\"a.c15\",\"a.c16\",\"a.c17\",\"a.c18\",\"a.c19\",\"a.c20\",\"a.c21\",\"a.c22\",\"a.c23\",\"a.c24\",\"a.c25\",\"a.c26\",\"a.c27\",\"a.c28\",\"a.c29\",\"a.c30\",\"a.c31\",\"a.c32\",\"a.c33\",\"a.c34\",\"a.c35\",\"a.c36\",\"a.c37\",\"a.c38\",\"a.c39\",\"a.c40\",\"a.c41\",\"a.c42\",\"a.c43\",\"a.c44\",\"a.c45\",\"a.c46\",\"a.c47\",\"a.c48\",\"a.c49\",\"a.c50\",\"a.c51\",\"a.c52\",\"a.c53\",\"a.c54\",\"a.c55\",\"a.c56\",\"a.c57\",\"a.c58\",\"a.c59\",\"a.c60\",\"a.c61\",\"a.c62\",\"a.c63\",\"a.c64\"],\"grants\":[\"a.c0\",\"a.c1\",\"a.c2\",\"a.c3\",\"a.c4\",\"a.c5\",\"a.c6\",\"a.c7\",\"a.c8\",\"a.c9\",\"a.c10\",\"a.c11\",\"a.c12\",\"a.c13\",\"a.c14\",\"a.c15\",\"a.c16\",\"a.c17\",\"a.c18\",\"a.c19\",\"a.c20\",\"a.c21\",\"a.c22\",\"a.c23\",\"a.c24\",\"a.c25\",\"a.c26\",\"a.c27\",\"a.c28\",\"a.c29\",\"a.c30\",\"a.c31\",\"a.c32\",\"a.c33\",\"a.c34\",\"a.c35\",\"a.c36\",\"a.c37\",\"a.c38\",\"a.c39\",\"a.c40\",\"a.c41\",\"a.c42\",\"a.c43\",\"a.c44\",\"a.c45\",\"a.c46\",\"a.c47\",\"a.c48\",\"a.c49\",\"a.c50\",\"a.c51\",\"a.c52\",\"a.c53\",\"a.c54\",\"a.c55\",\"a.c56\",\"a.c57\",\"a.c58\",\"a.c59\",\"a.c60\",\"a.c61\",\"a.c62\",\"a.c63\",\"a.c64\"",true,0,5);
}

@test fn void original_run_getters_and_policy_recheck(){
    let policy::Policy p=parsed_policy(policy_fixture(0));
    let run::RunConfig c=switch(run::parse(run_fixture(),ref p)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(bytes::equal(run::module_name(ref c),b"main"));assert(bytes::equal(run::function_name(ref c),b"main"));
    assert(run::requires_count(ref c)==0 && run::grants_count(ref c)==0);
    assert(!run::requirement(ref c,0).is_ok && !run::grant(ref c,0).is_ok);
    assert(!run::declares(ref c,b"a.b") && !run::grants(ref c,b"a.b"));
    let limits::RunLimits l=run::run_limits(ref c);
    assert(l.memory_bytes==16777216);
    assert(l.object_bytes==4194304);
    assert(l.call_frames==128);
    assert(l.input_bytes==1048576);
    assert(l.output_bytes==1048576);
    assert(l.host_request_bytes==1048576);
    assert(l.host_response_bytes==1048576);
    assert(l.host_calls==256);
    assert(l.owner_entries==16384);
    assert(l.descriptor_entries==16384);
    assert(l.fuel==10000000);
    assert(l.deadline_ms==1000);
}
@test fn void capability_getters_are_owned_and_engine_policy_must_be_rechecked(){
    let policy::Policy p=parsed_policy(policy_fixture(2));let policy::Policy denied=parsed_policy(policy_fixture(0));
    var bytes::Buffer source=bytes::empty();assert(bytes::append(ref mut source,b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"main\",\"function\":\"main\"},\"requires\":[\"host.example.check\"],\"grants\":[\"host.example.check\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}").is_ok);
    let run::RunConfig c=switch(run::parse(bytes::view(ref source),ref p)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(bytes::append(ref mut source,b"invalid").is_ok);
    assert(run::narrowed_to(ref c,ref p));assert(!run::narrowed_to(ref c,ref denied));
    assert(run::requires_count(ref c)==1 && run::grants_count(ref c)==1);
    assert(run::declares(ref c,b"host.example.check") && run::grants(ref c,b"host.example.check"));
    let ref u8[] required=switch(run::requirement(ref c,0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let ref u8[] granted=switch(run::grant(ref c,0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(bytes::equal(required,b"host.example.check") && bytes::equal(granted,required));
    assert(!run::requirement(ref c,1).is_ok && !run::grant(ref c,1).is_ok);
    assert(!run::declares(ref c,b"host.example") && !run::grants(ref c,b"host.example"));
}
@test fn void run_input_byte_budget(){
    let policy::Policy p=parsed_policy(policy_fixture(0));var bytes::Buffer source=bytes::empty();
    assert(bytes::append(ref mut source,run_fixture()).is_ok);
    while(bytes::len(ref source)<65536){assert(bytes::append(ref mut source,b" ").is_ok);}
    assert(run::parse(bytes::view(ref source),ref p).is_ok);assert(bytes::append(ref mut source,b" ").is_ok);
    assert(!run::parse(bytes::view(ref source),ref p).is_ok);
}
