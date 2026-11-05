module tests::m2::captured_call_stack;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import program_image as programs;
import std::bytes as bytes;

fn void append(ref mut bytes::Buffer b,ref u8[] value){assert(bytes::append(b,value).is_ok);}
fn void retained(ref u8[] source,bool pass){
    switch(compiler::compile_program(source,65536)){
        case .ok(p):{
            assert(pass);
            switch(programs::run_public(ref p,16000000)){
                case .ok(value):{assert(value==42);}case .err(_):{assert(false);}
            };
        }
        case .err(e):{assert(!pass && e.kind==4);}
    };
}
fn void depth(usize count,bool pass,bool image,bool first,bool mutable,bool record){
    var bytes::Buffer source=bytes::empty();
    append(ref mut source,b"module main;");if(record){append(ref mut source,b"struct P{i32 x;}");}
    append(ref mut source,b"fn i32 id(");
    if(first){append(ref mut source,if(record){b"P a,i32 x"}else{b"i32[1] a,i32 x"});}
    else{append(ref mut source,if(record){b"i32 x,P a"}else{b"i32 x,i32[1] a"});}
    append(ref mut source,b"){return x;}fn i32 main(){");
    append(ref mut source,if(mutable){b"var "}else{b"let "});
    append(ref mut source,if(record){b"P a=P{.x=0};"}else{b"i32[1] a=[0;1];"});
    if(image){append(ref mut source,b"let ref u8[] marker=b\"*\";");}append(ref mut source,b"return ");
    var usize i=0;while(i<count){append(ref mut source,if(first){b"id(a,"}else{b"id("});i+=1;}
    append(ref mut source,b"42");i=0;
    while(i<count){append(ref mut source,if(first){b")"}else{b",a)"});i+=1;}append(ref mut source,b";}");
    if(image){retained(bytes::view(ref source),pass);return;}
    switch(compiler::compile(bytes::view(ref source))){
        case .ok(p):{
            assert(pass && verifier::verify(ref p).is_ok);
            switch(vm::run_with_array_limit(ref p,16000000,1024)){
                case .ok(value):{assert(value==42);}case .err(_):{assert(false);}
            };
        }
        case .err(e):{assert(!pass && e.kind==4);}
    };
}
@test fn void owned_second_formal_is_legal_without_simultaneous_temporary_owners(){
    depth(1,true,false,false,false,false);depth(2,true,false,false,false,false);
    depth(1,true,true,false,false,false);depth(2,true,true,false,false,false);
}
@test fn void captured_calls_keep_the_32_deep_limit_and_reject_33(){
    depth(32,true,false,false,false,false);depth(33,false,false,false,false,false);
}
@test fn void retained_captured_calls_keep_the_32_deep_limit_and_reject_33(){
    depth(32,true,true,false,false,false);depth(33,false,true,false,false,false);
}
@test fn void leading_immutable_array_arguments_keep_the_same_depth_boundary(){
    depth(32,true,false,true,false,false);depth(33,false,false,true,false,false);
    depth(32,true,true,true,false,false);depth(33,false,true,true,false,false);
}
@test fn void immutable_record_arguments_keep_the_same_depth_boundary_in_both_positions(){
    depth(32,true,false,false,false,true);depth(33,false,false,false,false,true);
    depth(32,true,true,false,false,true);depth(33,false,true,false,false,true);
    depth(32,true,false,true,false,true);depth(33,false,false,true,false,true);
    depth(32,true,true,true,false,true);depth(33,false,true,true,false,true);
}
@test fn void actual_captures_still_obey_the_original_owner_catalog_capacity(){
    depth(14,true,false,true,true,false);depth(15,false,false,true,true,false);
    depth(14,true,true,true,true,false);depth(15,false,true,true,true,false);
}
