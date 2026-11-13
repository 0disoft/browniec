module tests::m2::record_metadata_lowering;
import struct_value_source as records;
import record_leaf_source_work as leaf;
import record_field_source_work as field;
import record_path_source_work as path;
import source_context as context;
import lexer as lexer;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
fn void same_number(Result<usize,errors::Error> a,Result<usize,errors::Error> b){switch(a){
    case .ok(v):{switch(b){case .ok(x):{assert(v==x);}case .err(_):{assert(false);}};}
    case .err(e):{switch(b){case .ok(_):{assert(false);}case .err(x):{assert(e.kind==x.kind && e.offset==x.offset);}};}};}
fn void same_leaf(Result<records::Leaf,errors::Error> a,Result<records::Leaf,errors::Error> b){switch(a){
    case .ok(v):{switch(b){case .ok(x):{assert(v.ordinal==x.ordinal && v.tag==x.tag && v.record==x.record);}case .err(_):{assert(false);}};}
    case .err(e):{switch(b){case .ok(_):{assert(false);}case .err(x):{assert(e.kind==x.kind && e.offset==x.offset);}};}};}
fn Result<usize,errors::Error> leaf_work(ref ir::Program p,usize root,usize at){var leaf::State w=leaf::begin(root,at);var budget::State m=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut m,at)?;let bool done=leaf::advance(p,ref mut w,ref mut m)?;}return leaf::prepared(ref w);}
fn Result<usize,errors::Error> field_work(ref u8[] source,ref ir::Program p,ref context::Table scope,usize record,usize a,usize b){
    var field::State w=field::begin(record,a,b);var budget::State m=budget::empty();while(!w.done){let usize allowance=budget::reset(ref mut m,a)?;
        let bool done=field::advance(source,p,scope,ref mut w,ref mut m)?;}return field::prepared(ref w);}
fn Result<records::Leaf,errors::Error> path_work(ref u8[] source,ref mut lexer::State s,ref ir::Program p,ref context::Table scope,usize root,usize at){
    var path::State w=path::begin_path(root,at);var budget::State m=budget::empty();while(!w.done){let usize allowance=budget::reset(ref mut m,at)?;
        let bool done=path::advance(source,s,p,scope,ref mut w,ref mut m)?;}return path::prepared(ref w);}
fn Result<records::Leaf,errors::Error> project_work(ref u8[] source,ref ir::Program p,ref context::Table scope,records::Leaf parent,usize a,usize b){
    var path::State w=path::begin_project(parent,a,b);var lexer::State s=lexer::empty();var budget::State m=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut m,a)?;let bool done=path::advance(source,ref mut s,p,scope,ref mut w,ref mut m)?;}return path::prepared(ref w);}
@test fn void leaf_depth_leaf_count_and_cycles_match_raw(){
    let u8[16] next=[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];var usize mode=0;while(mode<5){var ir::Program p=ir::empty();p.records.layouts.count=17;
        if(mode<3){var usize i=0;while(i<16){p.records.layouts.fields[i]=1;p.records.layouts.kinds[i*16]=1;p.records.layouts.types[i*16]=next[i];i+=1;}
            if(mode==0){p.records.layouts.kinds[15*16]=0;}if(mode==2){p.records.layouts.types[15*16]=0;}}
        else{p.records.layouts.fields[0]=16;if(mode==4){p.records.layouts.kinds[15]=1;p.records.layouts.types[15]=1;p.records.layouts.fields[1]=2;}}
        same_number(records::leaf_count_raw(ref p,0,77),leaf_work(ref p,0,77));mode+=1;}
}
@test fn void leaf_budget_and_terminal_do_not_replay(){var ir::Program p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=1;
    var leaf::State w=leaf::begin(0,7);var budget::State m=budget::empty();assert(!leaf::prepared(ref w).is_ok);
    assert(budget::admit(ref mut m,1,0).is_ok);assert(leaf::advance(ref p,ref mut w,ref mut m).is_ok && w.visits==0);
    while(!w.done){assert(budget::reset(ref mut m,0).is_ok && leaf::advance(ref p,ref mut w,ref mut m).is_ok);}
    assert(w.count==1);let usize before=m.total;assert(leaf::advance(ref p,ref mut w,ref mut m).is_ok && m.total==before);}
@test fn void fields_paths_and_projection_match_raw(){let ref u8[] source=b"module main;struct P{i32 x;i32 y;}.x";var context::Table scope=context::empty();
    var ir::Program p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=1;p.records.layouts.types[1]=1;
    assert(records::field_raw(source,ref p,0,35,36,ref scope).is_ok && field_work(source,ref p,ref scope,0,35,36).is_ok);
    same_number(records::field_raw(source,ref p,0,35,36,ref scope),field_work(source,ref p,ref scope,0,35,36));
    same_number(records::field_raw(source,ref p,0,0,1,ref scope),field_work(source,ref p,ref scope,0,0,1));
    var lexer::State a=lexer::empty();a.cursor=34;assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
    let Result<records::Leaf,errors::Error> x=records::path_raw(source,ref mut a,ref p,0,4,ref scope);
    let Result<records::Leaf,errors::Error> y=path_work(source,ref mut b,ref p,ref scope,0,4);assert(x.is_ok && y.is_ok);same_leaf(x,y);
    assert(a.kind==b.kind && a.begin==b.begin && a.end==b.end && a.cursor==b.cursor && a.tokens==b.tokens);
    let records::Leaf parent=records::Leaf{.ordinal=0,.tag=0,.record=0};
    assert(records::project_raw(source,ref p,parent,35,36,ref scope).is_ok && project_work(source,ref p,ref scope,parent,35,36).is_ok);
    same_leaf(records::project_raw(source,ref p,parent,35,36,ref scope),project_work(source,ref p,ref scope,parent,35,36));
    same_leaf(records::project_raw(source,ref p,parent,0,1,ref scope),project_work(source,ref p,ref scope,parent,0,1));
}
