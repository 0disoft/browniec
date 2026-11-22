module main;

import cli_input as input;
import compiler as compiler;
import array_source as arrays;
import verifier as verifier;
import vm as vm;
import ir as ir;
import source_features as features;
import errors as errors;
import lexer as lexer;
import render as render;
import program_image as programs;
import static_image as images;
import fuel as meter;
import std::process as process;
import std::num as num;
import std::io as io;
import ir_inspect as inspect;
import cli_project as projects;
import cli_project_input as project_input;
import cli_source_input as source_input;
import cli_configured_project as configured;
import cli_host_command as hosts;
import worker_scalar_command as worker;
import worker_scalar_broker as broker;
import worker_project_command as project_worker;
import worker_project_broker as project_broker;

@effects(console)
fn i32 fail(render::Format format, bool run, u8 kind) {
    return render::selected_outcome(format,run,true,0,errors::absent(kind,0),0);
}
@effects(console, filesystem)
fn i32 main() {
    let usize argc = process::arg_count();
    if (argc < 2) { return fail(.Text, false, 10); }
    var u8[64] command = [0; 64];
    let usize command_length = switch (process::arg(1, ref mut command)) {
        case .ok(n): { n } case .err(_): { return fail(.Text, false, 10); }
    };
    let ref u8[] command_view = ref command;
    if(lexer::equal(command_view[..command_length],b"worker")){
        if(argc!=2){return 4;}
        return worker::execute();
    }
    if((argc==4 || argc==5) && lexer::equal(command_view[..command_length],b"--internal-scalar-broker")){
        return broker::execute(argc==5);
    }
    if(argc==2 && lexer::equal(command_view[..command_length],b"--internal-project-worker")){
        return project_worker::execute();
    }
    if((argc==4 || argc==6 || argc==7) && lexer::equal(command_view[..command_length],b"--internal-project-broker")){
        return project_broker::execute(argc>=6,argc==7,false,false);
    }
    if(argc>=7 && argc<=9 && lexer::equal(command_view[..command_length],b"--internal-project-host-broker")){
        return project_broker::execute(true,argc==9,true,false);
    }
    if(argc>=10 && lexer::equal(command_view[..command_length],b"--internal-project-process-broker")){
        return project_broker::execute(true,(argc-7)%3==1,true,true);
    }
    if (lexer::equal(command_view[..command_length], b"--version")) {
        if (argc == 2) {
            return if (io::write("Brownie C experimental: brownie.m1-scalar/1, brownie.m2-array-read/1, brownie.m2-array-write/1, brownie.m2-array-copy/1, brownie.m2-struct-read/1, brownie.m2-struct-write/1, brownie.m2-struct-copy/1, brownie.m2-struct-nested/1\n").is_ok) { 0 } else { 7 };
        }
        var u8[16] option = [0; 16];
        let usize size = switch (process::arg(2, ref mut option)) {
            case .ok(n): { n } case .err(_): { return fail(.Text, false, 10); }
        };
        let ref u8[] view = ref option;
        if (argc != 3 || !lexer::equal(view[..size], b"--json")) { return fail(.Text, false, 10); }
        return render::version("{\"schema\":\"browniec.version/v1\",\"profile\":\"brownie.m1-scalar/1\",\"array_profile\":\"brownie.m2-array-read/1\",\"array_write_profile\":\"brownie.m2-array-write/1\",\"array_copy_profile\":\"brownie.m2-array-copy/1\",\"array_element_list_declarations\":true,\"array_element_list_arguments\":true,\"array_element_list_returns\":true,\"array_element_list_temporary_borrows\":true,\"array_element_list_replacement\":true,\"array_literal_projections\":true,\"array_expression_projections\":true,\"array_grouped_values\":true,\"grouped_assignment_targets\":true,\"scalar_local_compound_assignment\":true,\"array_selected_place_assignment\":true,\"array_element_compound_assignment\":true,\"array_utf8_element_lists\":true,\"struct_read_profile\":\"brownie.m2-struct-read/1\",\"struct_write_profile\":\"brownie.m2-struct-write/1\",\"struct_selected_place_assignment\":true,\"struct_field_compound_assignment\":true,\"struct_copy_profile\":\"brownie.m2-struct-copy/1\",\"struct_nested_profile\":\"brownie.m2-struct-nested/1\",\"struct_child_binding_initializers\":true,\"struct_child_path_initializers\":true,\"struct_subrecord_initializers\":true,\"struct_subrecord_assignment\":true,\"struct_subrecord_assignment_atomic\":true,\"struct_constructor_assignment\":true,\"struct_subrecord_constructor_assignment\":true,\"struct_helper_locals\":true,\"struct_parameters\":true,\"struct_field_shorthand\":true,\"struct_results\":true,\"record_expression_projections\":true,\"record_grouped_values\":true,\"if_expressions\":true,\"array_if_expressions\":true,\"record_if_expressions\":true,\"array_switch_expressions\":true,\"record_switch_expressions\":true,\"constructor_join_inference\":true,\"void_functions\":true,\"result_is_ok\":true,\"explicit_discard\":true,\"array_utf8_predicate\":true,\"array_utf8_call_results\":true,\"array_utf8_literals\":true,\"array_utf8_ranges\":true,\"array_utf8_temporary_ranges\":true,\"array_utf8_open_ranges\":true,\"array_utf8_dynamic_ranges\":true,\"array_utf8_temporary_dynamic_ranges\":true,\"array_utf8_computed_ranges\":true,\"array_utf8_temporary_computed_ranges\":true,\"array_utf8_slices\":true,\"array_slice_length\":true,\"array_slice_index\":true,\"array_slice_sub\":true,\"array_slice_alias\":true,\"array_slice_parameters\":true,\"array_slice_scalar_elements\":true,\"array_slice_mutable\":true,\"slice_selected_place_assignment\":true,\"slice_element_compound_assignment\":true,\"array_slice_mutable_parameters\":true,\"array_slice_mutable_reborrow\":true,\"array_slice_reborrow_owned_arguments\":true,\"array_slice_reborrow_array_results\":true,\"array_slice_reborrow_record_results\":true,\"array_slice_array_arguments\":true,\"array_slice_array_range_arguments\":true,\"array_slice_named_range_arguments\":true,\"array_slice_temporary_arguments\":true,\"reference_profile\":\"brownie.m2-reference/1\",\"byte_literals\":true,\"text_literals\":true,\"immutable_byte_views\":true,\"shared_byte_parameters\":true,\"shared_byte_results\":true,\"core\":true,\"restricted\":false,\"restricted_scalar\":true,\"embed\":false");
    }
    if (lexer::equal(command_view[..command_length], b"--help") && argc == 2) {
        return if (io::write("browniec check SOURCE [--json|--json-v2]\nbrowniec check SOURCE --catalog FILE --policy FILE --run FILE [--json|--json-v2]\nbrowniec run SOURCE [--input FILE|--stdin] [--fuel N] [--json|--json-v2]\nbrowniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE [--json|--json-v2]\nbrowniec run SOURCE --catalog FILE --policy FILE --run FILE --host-adapter ID REVISION EXE [--json|--json-v2]\nbrowniec check --project FILE [--json|--json-v2]\nbrowniec check --project FILE --catalog FILE --policy FILE --run FILE [--json|--json-v2]\nbrowniec check --project FILE --policy FILE --run FILE [--json|--json-v2]\nbrowniec run --project FILE [--input FILE|--stdin] [--fuel N] [--json|--json-v2]\nbrowniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE [--input FILE|--stdin] [--output FILE|--output-text FILE] [--json|--json-v2]\nbrowniec run --project FILE --catalog FILE --policy FILE --run FILE --host-adapter ID REVISION EXE [--input FILE|--stdin] [--output FILE|--output-text FILE] [--json|--json-v2]\nbrowniec run --project FILE --policy FILE --run FILE [--input FILE|--stdin] [--output FILE|--output-text FILE] (--json|--json-v2)\nbrowniec check SOURCE --isolated [--json|--json-v2]\nbrowniec run SOURCE --isolated [--fuel N] [--json|--json-v2]\nbrowniec check --project FILE --isolated [--json|--json-v2]\nbrowniec run --project FILE --isolated [--fuel N] [--json|--json-v2]\nbrowniec check --project FILE --isolated --policy FILE --run FILE [--json|--json-v2]\nbrowniec run --project FILE --isolated --policy FILE --run FILE [--input FILE] (--json|--json-v2)\nbrowniec eval-i32 SOURCE N [--fuel N] [--json|--json-v2]\nbrowniec inspect SOURCE --ir [--json]\nbrowniec inspect SOURCE --limits --json\nOrdinary commands are for trusted local source. Windows --isolated supports scalar source and bounded projects.\nLiteral/reference execution uses the canonical Fuel schedule; use --fuel 16000000 for larger programs.\n").is_ok) { 0 } else { 7 };
    }
    if(lexer::equal(command_view[..command_length],b"inspect")){return inspect::cli();}
    let bool eval=lexer::equal(command_view[..command_length],b"eval-i32");
    let bool run = eval || lexer::equal(command_view[..command_length], b"run");
    if (!run && !lexer::equal(command_view[..command_length], b"check")) {
        return fail(.Text, false, 10);
    }
    if (argc < 3) { return fail(.Text, run, 10); }
    let bool project=!eval && projects::selected();
    var render::Format format = .Text;
    var bool fuel_seen = false;
    var bool isolated = false;
    var usize catalog_file=0;
    var usize reply_file=0;
    var usize adapter_arg=0;
    var configured::Selection settings=configured::Selection{.policy_file=0,.run_file=0,.output_file=0,.output_text=false};
    var project_input::Selection payload=project_input::Selection{.argument=0,.stdin=false};
    var usize fuel = meter::cli_default();
    var usize at = if(eval || project){4}else{3};
    while (at < argc) {
        var u8[64] option = [0; 64];
        let usize length = switch (process::arg(at, ref mut option)) {
            case .ok(n): { n } case .err(_): { return command_failure(format,run,eval,10); }
        };
        let ref u8[] view = ref option;
        if (lexer::equal(view[..length], b"--json") && render::text_mode(format)) { format=.Json; }
        else if (lexer::equal(view[..length], b"--json-v2") && render::text_mode(format)) { format=.JsonV2; }
        else if (run && !eval && payload.argument==0 && !payload.stdin &&
                 lexer::equal(view[..length],b"--input") && at+1<argc) {
            at+=1;
            payload.argument=at;
        }
        else if (run && !eval && payload.argument==0 && !payload.stdin && lexer::equal(view[..length],b"--stdin")) {
            payload.stdin=true;
        }
        else if (run && project && settings.output_file==0 && at+1<argc &&
                 (lexer::equal(view[..length],b"--output") || lexer::equal(view[..length],b"--output-text"))) {
            settings.output_text=lexer::equal(view[..length],b"--output-text");
            at+=1;
            settings.output_file=at;
        }
        else if (!eval && settings.policy_file==0 && at+1<argc && lexer::equal(view[..length],b"--policy")) {
            at+=1;
            settings.policy_file=at;
        }
        else if (!eval && settings.run_file==0 && at+1<argc && lexer::equal(view[..length],b"--run")) {
            at+=1;
            settings.run_file=at;
        }
        else if (!eval && catalog_file==0 && at+1<argc && lexer::equal(view[..length],b"--catalog")) {
            at+=1;
            catalog_file=at;
        }
        else if (run && !eval && reply_file==0 && at+1<argc && lexer::equal(view[..length],b"--host-replies")) {
            at+=1;
            reply_file=at;
        }
        else if (run && !eval && adapter_arg==0 && at+3<argc && lexer::equal(view[..length],b"--host-adapter")) {
            adapter_arg=at+1;
            at+=3;
        }
        else if (lexer::equal(view[..length], b"--fuel") && run && !fuel_seen && at + 1 < argc) {
            at += 1;
            var u8[20] raw = [0; 20];
            let usize count = switch (process::arg(at, ref mut raw)) {
                case .ok(n): { n } case .err(_): { return command_failure(format,run,eval,10); }
            };
            let ref u8[] number = ref raw;
            let i64 parsed = switch (num::parse_i64_decimal(number[..count])) {
                case .ok(n): { n } case .err(_): { return command_failure(format,run,eval,10); }
            };
            if (parsed < 0) { return command_failure(format,run,eval,10); }
            fuel = switch (num::usize_from_i64(parsed)) {
                case .ok(n): { n } case .err(_): { return command_failure(format,run,eval,10); }
            };
            if (fuel > meter::cli_limit()) { return command_failure(format,run,eval,10); }
            fuel_seen = true;
        } else if (!isolated && lexer::equal(view[..length], b"--isolated")) { isolated=true; }
        else { return command_failure(format,run,eval,10); }
        at += 1;
    }
    if(isolated){
        if(eval || payload.stdin || catalog_file!=0 || settings.output_file!=0 ||
            reply_file!=0 || adapter_arg!=0){
            return command_failure(format,run,eval,11);
        }
        if(settings.policy_file!=0 || settings.run_file!=0){
            if(!project){return fail(format,run,11);}
            if(settings.policy_file==0 || settings.run_file==0 || fuel_seen || (run && render::text_mode(format))){
                return fail(format,run,10);
            }
            return project_broker::execute_configured(format,run,settings,payload.argument);
        }
        if(payload.argument!=0){return fail(format,run,11);}
        if(project){return project_broker::execute_managed(format,run,fuel);}
        return broker::execute_managed(format,run,fuel);
    }
    if(eval){
        let i64 argument=switch(decimal_argument()){
            case .ok(v):{v}case .err(_):{return command_failure(format,run,true,10);}
        };
        return evaluate(argument,format,fuel);
    }
    if(catalog_file!=0 || reply_file!=0 || adapter_arg!=0 || (!project && (settings.policy_file!=0 || settings.run_file!=0))){
        if(catalog_file==0 || settings.policy_file==0 || settings.run_file==0 ||
           run!=(reply_file!=0 || adapter_arg!=0) || (reply_file!=0 && adapter_arg!=0) ||
           fuel_seen || (!project && (payload.argument!=0 || payload.stdin)) ||
           (settings.output_file!=0 && render::text_mode(format))){
            return fail(format,run,10);
        }
        return hosts::execute(format,settings,catalog_file,reply_file,adapter_arg,project,payload);
    }
    if(settings.policy_file!=0 || settings.run_file!=0){
        if(settings.policy_file==0 || settings.run_file==0 || fuel_seen || (run && render::text_mode(format))){
            return fail(format,run,10);
        }
        return projects::execute_configured(format,run,settings,payload);
    }
    if(settings.output_file!=0){return fail(format,run,10);}
    if(project){return projects::execute(format,run,fuel,payload);}
    let input::Source source = switch (input::read_source(2)) {
        case .ok(value): { value } case .err(e): { return render::selected_outcome(format,run,true,0,e,0); }
    };
    let ref u8[] source_view = ref source.data;
    if(payload.argument!=0 || payload.stdin){return source_input::run(source_view[..source.length],format,fuel,payload);}
    let bool retained=switch(features::retained(source_view[..source.length])){
        case .ok(v):{v}case .err(e):{return render::selected_outcome(format,run,true,0,e,0);}
    };
    if(retained){return retained_source(source_view[..source.length],format,run,fuel);}
    return legacy_source(source_view[..source.length],format,run,fuel);
}
// Keep the retained Program's large return slots off the legacy parser stack.
// The legacy compiler/verification/VM route keeps its existing source limits.
@effects(console)
fn i32 legacy_source(ref u8[] source,render::Format format,bool run,usize fuel){
    let program=switch(compiler::compile(source)){
        case .ok(v):{v}case .err(e):{return render::selected_outcome(format,run,true,0,e,0);}
    };
    let u8 profile=arrays::profile(ref program);
    if(!run){
        let usize verified=switch(verifier::verify(ref program)){
            case .ok(v):{v}case .err(e):{return render::selected_outcome(format,false,true,0,e,profile);}
        };
        return render::selected_outcome(format,false,false,0,errors::make(0,0),profile);
    }
    return switch(vm::run(ref program,fuel)){
        case .ok(v):{render::selected_outcome(format,true,false,v,errors::make(0,0),profile)}
        case .err(e):{render::selected_outcome(format,true,true,0,e,profile)}
    };
}
@effects(console)
fn i32 retained_source(ref u8[] source,render::Format format,bool run,usize fuel){
    let programs::ReferenceReturnProgram program=switch(compiler::compile_reference_returns(source,images::metadata_charge()+images::byte_limit())){
        case .ok(value):{value}case .err(error):{let errors::Error e=compiler::public_error(error);return render::selected_outcome(format,run,true,0,e,0);}
    };
    let u8 profile=8;
    if(!run){return render::selected_outcome(format,false,false,0,errors::make(0,0),profile);}
    return switch(programs::run_public_references(ref program,fuel)){
        case .ok(value):{render::selected_outcome(format,true,false,value,errors::make(0,0),profile)}
        case .err(e):{render::selected_outcome(format,true,true,0,e,profile)}
    };
}

@effects(console)
fn i32 command_failure(render::Format format,bool run,bool eval,u8 kind){
    if(eval){return render::eval_outcome(format,true,0,errors::absent(kind,0));}
    return fail(format,run,kind);
}
fn Result<i64,errors::Error> decimal_argument(){
    var u8[20] raw=[0;20];
    let usize size=switch(process::arg(3,ref mut raw)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(10,0));}
    };
    let ref u8[] number=ref raw;
    let i64 value=switch(num::parse_i64_decimal(number[..size])){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(10,0));}
    };
    if(value< -2147483648 || value>2147483647){return .err(errors::absent(10,0));}
    return .ok(value);
}
@effects(console,filesystem)
fn i32 evaluate(i64 argument,render::Format format,usize fuel){
    let input::Source source=switch(input::read_source(2)){
        case .ok(v):{v}case .err(e):{return render::eval_outcome(format,true,0,e);}
    };
    let ref u8[] view=ref source.data;
    let ir::Program p=switch(compiler::compile_eval_i32(view[..source.length])){
        case .ok(v):{v}case .err(e):{return render::eval_outcome(format,true,0,e);}
    };
    return switch(vm::eval_i32(ref p,argument,fuel)){
        case .ok(v):{render::eval_outcome(format,false,v,errors::absent(0,0))}
        case .err(e):{render::eval_outcome(format,true,0,e)}
    };
}
