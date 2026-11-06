module tests::m2::aggregate_place_cleanup;
import aggregate_place_source as stores;
import place_source as places;
import array_source as arrays;
import record_expression_source as expressions;
import struct_value_source as records;
import ir as ir;
import locals as locals;
import errors as errors;
import verifier as verifier;
import vm as vm;
import static_call_ir as calls;
import static_image as images;
import program_image as programs;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void done(Result<i64,errors::Error> r){assert(switch(r){case .ok(n):{n==42}case .err(_):{false}});}
fn void finish(ref mut ir::Program p){let usize count=p.count;let usize regs=p.registers;p.ends[0]=count;p.register_ends[0]=regs;}
fn void shape(ref mut ir::Program p){p.function_count=1;p.return_types[0]=1;
    p.records.layouts.count=1;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=1;p.records.layouts.types[1]=1;}
fn images::Image image(){let images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,65536)){case .ok(v):{v}case .err(_):{assert(false);image()}};}
fn void both(ref ir::Program p){assert(verifier::verify(p).is_ok);done(vm::run_with_array_limit(p,16000000,32));
    let calls::Program unit=calls::Program{.body=*p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    switch(programs::retain_reference_returns(ref unit,image(),65536)){
        case .ok(code):{done(programs::run_public_references(ref code,16000000));}case .err(_):{assert(false);}
    };
}
fn expressions::Value value(usize id,bool owned){return expressions::Value{.id=id,.owned=owned,.record=0,.ordinal=0,.tag=0,.slots=[0;16],.depth=0};}
fn ir::Program store(u8 mode){
    var ir::Program p=ir::empty();shape(ref mut p);var locals::Table names=locals::empty();
    let usize zero=built(ir::literal(ref mut p,0,0));let usize zero2=built(ir::literal(ref mut p,0,0));
    let usize x=built(ir::literal(ref mut p,20,0));let usize y=built(ir::literal(ref mut p,22,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize array=built(ir::array(ref mut p,1,2,true,0));let usize init=built(ir::array_init(ref mut p,array,zero,0));
    let usize outer=built(places::select(ref mut p,ref mut names,array,index,0));
    if(mode<3){
        let usize root=if(mode==0){built(ir::array(ref mut p,1,2,false,0))}else{16};
        if(mode==0){let usize initialized=built(ir::array_init(ref mut p,root,answer,0));}
        let usize selected=built(places::array(ref mut p,ref mut names,array,77));assert(selected==1);
        let usize start=p.count;var usize stored=0;
        if(mode==0){stored=built(stores::copy_array(ref mut p,ref mut names,selected,array,root,true,77));
            assert(p.code[(stored+1)*8]==86 && p.code[(stored+2)*8]==37);}
        else if(mode==1){stored=built(stores::fill_array(ref mut p,ref mut names,selected,array,answer,77));}
        else{let usize[2] values=[x,y];stored=built(stores::list_array(ref mut p,ref mut names,selected,array,ref values,77));}
        assert(stored==start && names.pending_places==1);
        let usize ended=built(places::end(ref mut p,ref mut names,outer,0));
        let usize first=built(ir::array_read(ref mut p,array,index,0));var usize result=first;
        if(mode==2){let usize at=built(ir::integer(ref mut p,1,12,0));let usize second=built(ir::array_read(ref mut p,array,at,0));result=built(ir::emit(ref mut p,2,first,second,0));}
        let usize dropped=built(ir::array_drop(ref mut p,array,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));
    }else{
        let usize root=built(ir::record(ref mut p,0,true,0));let usize initialized=built(ir::record_init(ref mut p,root,zero,0));
        let usize source=if(mode==3){built(ir::record(ref mut p,0,false,0))}else{16};
        if(mode==3){let usize init_source=built(ir::record_init(ref mut p,source,x,0));}
        let usize selected=built(places::record_value(ref mut p,ref mut names,root,0,0,77));assert(selected==1);
        var expressions::Value rhs=value(source,mode==3);
        if(mode==4){let usize a=built(ir::slot(ref mut p,1,0));let usize b=built(ir::slot(ref mut p,1,0));
            let usize sa=built(ir::raw(ref mut p,18,a,x,0,0));let usize sb=built(ir::raw(ref mut p,18,b,y,0,0));rhs.slots[0]=a;rhs.slots[1]=b;}
        let records::Leaf target=records::Leaf{.ordinal=0,.tag=0,.record=0};
        let usize stored=built(stores::record(ref mut p,ref mut names,selected,root,target,ref rhs,77));
        assert(p.code[(stored+1)*8]==86 && names.pending_places==1);
        if(mode==3){assert(p.code[(stored+2)*8]==45);}else{assert(p.code[(stored-1)*8]==17 && p.code[(stored-2)*8]==17);}
        let usize ended=built(places::end(ref mut p,ref mut names,outer,0));
        let usize a=built(ir::record_read(ref mut p,root,0,0));let usize b=built(ir::record_read(ref mut p,root,1,0));
        let usize result=built(ir::emit(ref mut p,2,a,b,0));let usize dr=built(ir::record_drop(ref mut p,root,0));
        let usize da=built(ir::array_drop(ref mut p,array,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));
    }
    finish(ref mut p);return p;
}
@test fn void all_five_stores_end_only_their_selection_before_anonymous_owner_cleanup(){
    var u8 mode=0;while(mode<5){let ir::Program p=store(mode);both(ref p);mode+=1;}
}
@test fn void all_five_kinds_share_sixteen_ids_without_consuming_sixty_four_names(){
    var ir::Program p=ir::empty();shape(ref mut p);var locals::Table names=locals::empty();
    let usize zero=built(ir::literal(ref mut p,0,0));let usize answer=built(ir::literal(ref mut p,42,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,2,12,0));
    let usize root=built(ir::array(ref mut p,1,2,true,0));let usize other=built(ir::array(ref mut p,1,2,true,0));
    let usize init=built(ir::array_init(ref mut p,root,zero,0));let usize init2=built(ir::array_init(ref mut p,other,zero,0));
    let usize slice=built(ir::exclusive_slice(ref mut p,other,0));let usize opened=built(ir::slice_open(ref mut p,slice,lo,hi,0));
    let usize record=built(ir::record(ref mut p,0,true,0));let usize init3=built(ir::record_init(ref mut p,record,zero,0));
    let usize ba=built(locals::declare(ref mut names,0,0,128+root,true));let usize bb=built(locals::declare(ref mut names,0,0,128+other,true));
    let usize bs=built(locals::declare(ref mut names,0,0,160+slice,false));let usize br=built(locals::declare(ref mut names,0,0,144+record,true));
    while(names.count<64){let usize name=built(locals::declare(ref mut names,0,0,zero,false));}
    var usize i=0;while(i<16){let usize id=if(i%5==0){built(places::select(ref mut p,ref mut names,root,lo,0))}
        else if(i%5==1){built(places::slice(ref mut p,ref mut names,slice,lo,0))}
        else if(i%5==2){built(places::record(ref mut p,ref mut names,record,0,0))}
        else if(i%5==3){built(places::array(ref mut p,ref mut names,root,0))}
        else{built(places::record_value(ref mut p,ref mut names,record,0,0,0))};assert(id==i);i+=1;}
    let usize count=p.count;assert(!places::array(ref mut p,ref mut names,root,77).is_ok);
    assert(p.count==count && names.count==64 && names.pending_places==65535);
    let usize ended=built(places::end(ref mut p,ref mut names,7,0));assert(built(places::record_value(ref mut p,ref mut names,record,0,0,0))==7);
    let usize exit=p.count;let usize dropped=built(arrays::release_visible(ref names,ref mut p,0));
    assert(dropped==20 && p.code[exit*8]==86 && p.code[(exit+15)*8+1]==0 && p.code[(exit+16)*8]==45);
    assert(names.pending_places==65535 && names.count==64);let usize ret=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p);both(ref p);
}
