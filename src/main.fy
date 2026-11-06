module main;

import cli_input as input;
import compiler as compiler;
import array_source as arrays;
import verifier as verifier;
import vm as vm;
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

@effects(console)
fn i32 fail(bool json, bool run, u8 kind, usize offset) {
    return render::outcome(json, run, true, 0, errors::make(kind, offset));
}
@effects(console, filesystem)
fn i32 main() {
    let usize argc = process::arg_count();
    if (argc < 2) { return fail(false, false, 10, 0); }
    var u8[64] command = [0; 64];
    let usize command_length = switch (process::arg(1, ref mut command)) {
        case .ok(n): { n } case .err(_): { return fail(false, false, 10, 0); }
    };
    let ref u8[] command_view = ref command;
    if (lexer::equal(command_view[..command_length], b"--version")) {
        if (argc == 2) {
            return if (io::write("Brownie C experimental: brownie.m1-scalar/1, brownie.m2-array-read/1, brownie.m2-array-write/1, brownie.m2-array-copy/1, brownie.m2-struct-read/1, brownie.m2-struct-write/1, brownie.m2-struct-copy/1, brownie.m2-struct-nested/1\n").is_ok) { 0 } else { 7 };
        }
        var u8[16] option = [0; 16];
        let usize size = switch (process::arg(2, ref mut option)) {
            case .ok(n): { n } case .err(_): { return fail(false, false, 10, 0); }
        };
        let ref u8[] view = ref option;
        if (argc != 3 || !lexer::equal(view[..size], b"--json")) { return fail(false, false, 10, 0); }
        return render::version("{\"schema\":\"browniec.version/v1\",\"profile\":\"brownie.m1-scalar/1\",\"array_profile\":\"brownie.m2-array-read/1\",\"array_write_profile\":\"brownie.m2-array-write/1\",\"array_copy_profile\":\"brownie.m2-array-copy/1\",\"array_element_list_declarations\":true,\"array_element_list_arguments\":true,\"array_element_list_returns\":true,\"array_element_list_temporary_borrows\":true,\"array_element_list_replacement\":true,\"array_literal_projections\":true,\"array_expression_projections\":true,\"array_grouped_values\":true,\"array_utf8_element_lists\":true,\"struct_read_profile\":\"brownie.m2-struct-read/1\",\"struct_write_profile\":\"brownie.m2-struct-write/1\",\"struct_copy_profile\":\"brownie.m2-struct-copy/1\",\"struct_nested_profile\":\"brownie.m2-struct-nested/1\",\"struct_child_binding_initializers\":true,\"struct_child_path_initializers\":true,\"struct_subrecord_initializers\":true,\"struct_subrecord_assignment\":true,\"struct_subrecord_assignment_atomic\":true,\"struct_constructor_assignment\":true,\"struct_subrecord_constructor_assignment\":true,\"struct_helper_locals\":true,\"struct_parameters\":true,\"struct_field_shorthand\":true,\"struct_results\":true,\"record_expression_projections\":true,\"record_grouped_values\":true,\"if_expressions\":true,\"array_if_expressions\":true,\"record_if_expressions\":true,\"array_switch_expressions\":true,\"record_switch_expressions\":true,\"constructor_join_inference\":true,\"void_functions\":true,\"array_utf8_predicate\":true,\"array_utf8_call_results\":true,\"array_utf8_literals\":true,\"array_utf8_ranges\":true,\"array_utf8_temporary_ranges\":true,\"array_utf8_open_ranges\":true,\"array_utf8_dynamic_ranges\":true,\"array_utf8_temporary_dynamic_ranges\":true,\"array_utf8_computed_ranges\":true,\"array_utf8_temporary_computed_ranges\":true,\"array_utf8_slices\":true,\"array_slice_length\":true,\"array_slice_index\":true,\"array_slice_sub\":true,\"array_slice_alias\":true,\"array_slice_parameters\":true,\"array_slice_scalar_elements\":true,\"array_slice_mutable\":true,\"array_slice_mutable_parameters\":true,\"array_slice_mutable_reborrow\":true,\"array_slice_reborrow_owned_arguments\":true,\"array_slice_reborrow_array_results\":true,\"array_slice_reborrow_record_results\":true,\"array_slice_array_arguments\":true,\"array_slice_array_range_arguments\":true,\"array_slice_named_range_arguments\":true,\"array_slice_temporary_arguments\":true,\"reference_profile\":\"brownie.m2-reference/1\",\"byte_literals\":true,\"text_literals\":true,\"immutable_byte_views\":true,\"shared_byte_parameters\":true,\"shared_byte_results\":true,\"core\":true,\"restricted\":false,\"embed\":false");
    }
    if (lexer::equal(command_view[..command_length], b"--help") && argc == 2) {
        return if (io::write("browniec check SOURCE [--json]\nbrowniec run SOURCE [--fuel N] [--json]\nTrusted local source only; experimental scalar/aggregate functions, byte/text literals and shared byte results.\nLiteral/reference execution uses the canonical Fuel schedule; use --fuel 16000000 for larger programs.\n").is_ok) { 0 } else { 7 };
    }
    let bool run = lexer::equal(command_view[..command_length], b"run");
    if (!run && !lexer::equal(command_view[..command_length], b"check")) {
        return fail(false, false, 10, 0);
    }
    if (argc < 3) { return fail(false, run, 10, 0); }
    var bool json = false;
    var bool fuel_seen = false;
    var usize fuel = meter::cli_default();
    var usize at = 3;
    while (at < argc) {
        var u8[64] option = [0; 64];
        let usize length = switch (process::arg(at, ref mut option)) {
            case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
        };
        let ref u8[] view = ref option;
        if (lexer::equal(view[..length], b"--json") && !json) { json = true; }
        else if (lexer::equal(view[..length], b"--fuel") && run && !fuel_seen && at + 1 < argc) {
            at += 1;
            var u8[20] raw = [0; 20];
            let usize count = switch (process::arg(at, ref mut raw)) {
                case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
            };
            let ref u8[] number = ref raw;
            let i64 parsed = switch (num::parse_i64_decimal(number[..count])) {
                case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
            };
            if (parsed < 0) { return fail(json, run, 10, 0); }
            fuel = switch (num::usize_from_i64(parsed)) {
                case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
            };
            if (fuel > meter::cli_limit()) { return fail(json, run, 10, 0); }
            fuel_seen = true;
        } else if (lexer::equal(view[..length], b"--isolated")) { return fail(json, run, 11, 0); }
        else { return fail(json, run, 10, 0); }
        at += 1;
    }
    let input::Source source = switch (input::read_source(2)) {
        case .ok(value): { value } case .err(e): { return fail(json, run, e.kind, e.offset); }
    };
    let ref u8[] source_view = ref source.data;
    let bool retained=switch(features::retained(source_view[..source.length])){
        case .ok(v):{v}case .err(e):{return fail(json,run,e.kind,e.offset);}
    };
    if(retained){return retained_source(source_view[..source.length],json,run,fuel);}
    return legacy_source(source_view[..source.length],json,run,fuel);
}
// Keep the retained Program's large return slots off the legacy parser stack.
// The legacy compiler/verification/VM route keeps its existing source limits.
@effects(console)
fn i32 legacy_source(ref u8[] source,bool json,bool run,usize fuel){
    let program=switch(compiler::compile(source)){
        case .ok(v):{v}case .err(e):{return fail(json,run,e.kind,e.offset);}
    };
    let u8 profile=arrays::profile(ref program);
    if(!run){
        let usize verified=switch(verifier::verify(ref program)){
            case .ok(v):{v}case .err(e):{return render::selected_outcome(json,false,true,0,e,profile);}
        };
        return render::selected_outcome(json,false,false,0,errors::make(0,0),profile);
    }
    return switch(vm::run(ref program,fuel)){
        case .ok(v):{render::selected_outcome(json,true,false,v,errors::make(0,0),profile)}
        case .err(e):{render::selected_outcome(json,true,true,0,e,profile)}
    };
}
@effects(console)
fn i32 retained_source(ref u8[] source,bool json,bool run,usize fuel){
    let programs::ReferenceReturnProgram program=switch(compiler::compile_reference_returns(source,images::metadata_charge()+images::byte_limit())){
        case .ok(value):{value}case .err(error):{let errors::Error e=compiler::public_error(error);return fail(json,run,e.kind,e.offset);}
    };
    let u8 profile=8;
    if(!run){return render::selected_outcome(json,false,false,0,errors::make(0,0),profile);}
    return switch(programs::run_public_references(ref program,fuel)){
        case .ok(value):{render::selected_outcome(json,true,false,value,errors::make(0,0),profile)}
        case .err(e):{render::selected_outcome(json,true,true,0,e,profile)}
    };
}
