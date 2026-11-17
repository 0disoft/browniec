module tests::m2::public_compile_stack;
import compiler as compiler;
import program_image as programs;

// Check admission independently of the large execution frame in the older
// combined image-quota/runtime fixture. Keep that original fixture unchanged.
fn void admission(ref u8[] source,usize limit,bool accepted){
    switch(compiler::compile_program(source,limit)){
        case .ok(program):{assert(accepted && programs::public_profile(ref program)==8);}
        case .err(error):{assert(!accepted && error.kind==4);}
    };
}
@test fn void deferred_publication_preserves_exact_image_quota_errors_and_success(){
    let ref u8[] one=b"module main;fn i32 main(){return b\"*\"[0] as i32;}";
    admission(one,576,false);admission(one,577,true);
    let ref u8[] empty=b"module main;fn i32 main(){if(b\"\".len==0){return 42;}return 0;}";
    admission(empty,575,false);admission(empty,576,true);
}

fn void profile(ref u8[] source,u8 expected){
    switch(compiler::compile_program(source,65536)){
        case .ok(program):{assert(programs::public_profile(ref program)==expected);}
        case .err(_):{assert(false);}
    };
}
@test fn void deferred_publication_keeps_scalar_array_literal_and_reference_admission_profiles(){
    profile(b"module main;fn i32 main(){return 42;}",0);
    profile(b"module main;fn i32 main(){let i32[1] a=[42;1];return a[0];}",1);
    profile(b"module main;fn i32 main(){return b\"*\"[0] as i32;}",8);
    profile(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){return same(ref [42;1])[0] as i32;}",8);
}
