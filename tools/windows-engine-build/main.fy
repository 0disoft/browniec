module main;
import runtime_engine as engine;
import runtime_input as input;
import runtime_policy as policies;
import runtime_run_config as runs;
import cli_run_configuration as config;
import anchored_source_loader as anchors;
import project_manifest as manifests;
import std::bytes as bytes;
import std::process as process;

@effects(filesystem)
fn i32 main(){
    let policies::Policy ceiling=switch(config::read_policy(1)){case .ok(v):{v}case .err(_):{return 1;}};
    let runs::RunConfig run=switch(config::read_run(2,ref ceiling)){case .ok(v):{v}case .err(_):{return 2;}};
    var engine::Engine e=switch(engine::create_with_policy(ceiling)){case .ok(v):{v}case .err(_):{return 3;}};
    var u8[3072] path=[0;3072];
    let usize length=switch(process::arg(3,ref mut path)){case .ok(v):{v}case .err(_):{return 4;}};
    var u8[2048] raw=[0;2048];
    var anchors::Root anchor=switch(anchors::open_project(ref path[..length],ref mut raw)){
        case .ok(v):{v}case .err(_):{return 5;}
    };
    let manifests::Project project=switch(manifests::parse(ref raw[..anchors::manifest_bytes(ref anchor)])){
        case .ok(v):{v}case .err(_):{return 6;}
    };
    let usize program=switch(engine::compile_anchored_project_output(ref mut e,ref project,ref mut anchor,ref run,65536)){
        case .ok(v):{v}case .err(_):{return 7;}
    };
    var usize no_charge=0;
    let input::Snapshot payload=switch(input::snapshot(b"A\x00",2,0,ref mut no_charge)){
        case .ok(v):{v}case .err(_):{return 8;}
    };
    let usize instance=switch(engine::prepare_granted_instance(ref mut e,program,ref run,payload)){
        case .ok(v):{v}case .err(_):{return 9;}
    };
    while(true){
        let engine::Event event=switch(engine::step_instance(ref mut e,instance,4096)){
            case .ok(v):{v}case .err(_):{return 10;}
        };
        if(event.kind==4){continue;}
        if(event.kind!=1 || event.value!=77){return 11;}
        break;
    }
    let engine::Output result=switch(engine::take_output(ref mut e,instance)){
        case .ok(v):{v}case .err(_):{return 12;}
    };
    assert(engine::output_available(ref result) && bytes::equal(engine::output_view(ref result),b"A\x00"));
    assert(engine::destroy_instance(ref mut e,instance).is_ok);
    assert(engine::release_program(ref mut e,program).is_ok);
    assert(engine::destroy(ref mut e).is_ok);
    return 0;
}
