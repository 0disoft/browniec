module cli_test_i32;

import cli_input as input;
import cli_local_file as files;
import compiler as compiler;
import errors as errors;
import fuel as meter;
import lexer as lexer;
import render as render;
import vm as vm;
import std::io as io;
import std::num as num;
import std::process as process;

fn Result<i64,usize> decimal(ref u8[] text){
    let i64 n=switch(num::parse_i64_decimal(text)){
        case .ok(v):{v} case .err(_):{return .err(0);}
    };
    if(n< -2147483648 || n>2147483647){return .err(0);}
    return .ok(n);
}

fn Result<vm::EvalCase,usize> test_case(ref u8[] line){
    if(line.len==0 || line.len>32){return .err(0);}
    var usize comma=0;
    while(comma<line.len && line[comma]!=44){comma+=1;}
    if(comma==line.len){return .err(0);}
    let i64 argument=decimal(line[..comma])?;
    let i64 expected=decimal(line[comma+1..])?;
    return .ok(vm::EvalCase{.input=argument,.expected=expected});
}

fn Result<usize,usize> parse_cases(ref u8[] data,ref mut vm::EvalCase[] cases){
    var usize row=0;
    var usize start=0;
    while(start<data.len){
        if(row==cases.len){return .err(row+1);}
        var usize end=start;
        while(end<data.len && data[end]!=10 && end-start<=33){end+=1;}
        if(end-start>33){return .err(row+1);}
        let bool newline=end<data.len && data[end]==10;
        let usize content=if(newline && end>start && data[end-1]==13){end-1}else{end};
        cases[row]=switch(test_case(data[start..content])){
            case .ok(v):{v} case .err(_):{return .err(row+1);}
        };
        row+=1;
        start=if(newline){end+1}else{end};
    }
    if(row==0){return .err(1);}
    return .ok(row);
}

fn Result<usize,usize> fuel_argument(usize argc){
    if(argc==4){return .ok(meter::cli_default());}
    if(argc!=6){return .err(0);}
    var u8[6] flag=[0;6];
    let usize size=switch(process::arg(4,ref mut flag)){
        case .ok(v):{v} case .err(_):{return .err(0);}
    };
    let ref u8[] option=ref flag;
    if(!lexer::equal(option[..size],b"--fuel")){return .err(0);}
    var u8[20] raw=[0;20];
    let usize count=switch(process::arg(5,ref mut raw)){
        case .ok(v):{v} case .err(_):{return .err(0);}
    };
    let ref u8[] number=ref raw;
    let i64 n=decimal(number[..count])?;
    let usize fuel=switch(num::usize_from_i64(n)){
        case .ok(v):{v} case .err(_):{return .err(0);}
    };
    if(fuel>meter::cli_limit()){return .err(0);}
    return .ok(fuel);
}

@effects(console)
fn bool row_prefix(usize row){
    return io::write_stderr("test-i32: row ").is_ok &&
        io::write_stderr_usize(row).is_ok && io::write_stderr(": ").is_ok;
}

@effects(console)
fn i32 fail(errors::Error e){return render::eval_outcome(.Text,true,0,e);}

@effects(console,filesystem)
pub fn i32 cli(usize argc){
    let errors::Error usage=errors::absent(10,0);
    let usize fuel=switch(fuel_argument(argc)){case .ok(v):{v} case .err(_):{return fail(usage);}};
    let files::File file=switch(files::open(3,34000,usage.kind)){
        case .ok(v):{v} case .err(e):{return fail(e);}
    };
    var vm::EvalCase[1000] cases=[vm::EvalCase{.input=0,.expected=0};1000];
    let usize count=switch(parse_cases(files::view(ref file),ref mut cases)){
        case .ok(v):{v}
        case .err(row):{if(!row_prefix(row)){return 7;} return fail(usage);}
    };
    if(fuel>meter::cli_limit()/count){return fail(usage);}
    let ref vm::EvalCase[] rows=ref cases;
    return run_cases(rows[..count],fuel);
}

@effects(console,filesystem)
fn i32 run_cases(ref vm::EvalCase[] cases,usize fuel){
    let input::Source source=switch(input::read_source(2)){
        case .ok(v):{v} case .err(e):{return fail(e);}
    };
    let ref u8[] view=ref source.data;
    let program=switch(compiler::compile_eval_i32(view[..source.length])){
        case .ok(v):{v} case .err(e):{return fail(e);}
    };
    return switch(vm::test_i32(ref program,cases,fuel)){
        case .ok(count):{
            if(!io::write_stderr("test-i32: ").is_ok || !io::write_stderr_usize(count).is_ok ||
                !io::write_stderr(" cases passed\n").is_ok){return 7;}
            0
        }
        case .err(e):{
            if(e.row!=0 && !row_prefix(e.row)){return 7;}
            if(e.error.kind!=0){return fail(e.error);}
            if(!io::write_stderr("expected ").is_ok ||
                !io::write_stderr_i64(cases[e.row-1].expected).is_ok ||
                !io::write_stderr(", got ").is_ok || !io::write_stderr_i64(e.actual).is_ok ||
                !io::write_stderr("\n").is_ok){return 7;}
            1
        }
    };
}
