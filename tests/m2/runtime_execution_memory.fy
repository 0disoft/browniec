module tests::m2::runtime_execution_memory;
import runtime_execution_memory as memory;
import ir as ir;
import errors as errors;

fn void planned(ref ir::Program p,bool input,bool output,usize limit,usize scratch,usize staged,usize peak){
    switch(memory::prepare(p,input,output,limit)){
        case .ok(v):{assert(v.scratch==scratch && v.output==staged && v.peak==peak);}
        case .err(_):{assert(false);}
    };
}
fn void rejected(ref ir::Program p,bool input,bool output,usize limit,usize offset){
    switch(memory::prepare(p,input,output,limit)){
        case .ok(_):{assert(false);}
        case .err(e):{assert(e.kind==5 && e.offset==offset);}
    };
}
// Shape fixtures exercise allocation requirements, not executable-IR admission.
fn ir::Program array(u8 tag,usize length){
    var ir::Program p=ir::empty();p.arrays.count=1;
    p.arrays.elements[0]=tag;p.arrays.lengths[0]=length;return p;
}
fn ir::Program list(u8 tag,usize length){
    var ir::Program p=array(tag,length);p.count=1;p.code[0]=80;p.list_used=length;return p;
}

@test
fn void empty_variants_keep_input_metadata_and_reserved_output_independent(){
    let ir::Program p=ir::empty();
    planned(ref p,false,false,0,0,0,0);
    planned(ref p,true,false,0,18432,0,18432);
    planned(ref p,false,true,0,0,616,616);
    planned(ref p,false,true,1,0,617,617);
    planned(ref p,false,true,1048576,0,1049192,1049192);
    planned(ref p,true,true,0,18432,616,19048);
    planned(ref p,true,true,1048576,18432,1049192,1067624);
    assert(p.count==0 && p.arrays.count==0 && p.records.count==0 && p.list_used==0);
}

@test
fn void declared_arrays_and_records_share_one_arena_without_per_owner_or_depth_heap(){
    var ir::Program p=array(10,1);
    planned(ref p,false,false,0,65536,0,65536);
    p.arrays.lengths[0]=4096;p.arrays.elements[0]=9;
    planned(ref p,false,false,0,65536,0,65536);
    p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
    p.records.count=1;
    planned(ref p,false,false,0,65536,0,65536);
    p.records.count=16;p.arrays.count=16;
    var usize i=0;while(i<16){p.arrays.elements[i]=10;p.arrays.lengths[i]=1;i+=1;}
    p.function_count=16;p.call_count=32;
    planned(ref p,true,false,0,83968,0,83968);
    planned(ref p,true,true,1,83968,617,84585);
}

@test
fn void list_values_use_vec_minimum_and_power_two_capacity_but_exact_encoded_bytes(){
    let usize[7] lengths=[1,7,8,9,16,17,4096];
    let usize[7] value_bytes=[64,64,64,128,128,256,32768];
    var usize i=0;while(i<7){let ir::Program p=list(10,lengths[i]);
        let usize scratch=65536+value_bytes[i]+lengths[i];
        planned(ref p,false,false,0,scratch,0,scratch);i+=1;
    }
    let u8[3] tags=[10,1,9];let usize[3] totals=[65603,65612,65624];i=0;
    while(i<3){let ir::Program p=list(tags[i],3);
        planned(ref p,false,false,0,totals[i],0,totals[i]);i+=1;
    }
}

@test
fn void separate_list_maxima_cover_creation_replacement_and_aggregate_list_replacement(){
    var ir::Program p=list(10,3000);p.arrays.count=2;p.arrays.elements[1]=9;p.arrays.lengths[1]=1000;
    p.count=2;p.code[8]=81;p.code[9]=1;p.code[10]=184;p.code[11]=11;p.list_used=4000;
    // Longest list is u8[3000], widest encoding is i64[1000]. Both scratch
    // allocations exist together: 4096 i64 cells (32768) plus 8000 bytes.
    planned(ref p,false,false,0,106304,0,106304);
    // Aggregate REPLACE uses a different destination/start encoding, plus one
    // shared 16-wide place vector. It does not allocate a second list scratch.
    p.code[8]=87;p.code[9]=15;p.code[10]=1;p.code[11]=184;
    p.code[12]=3;p.code[13]=1;p.code[14]=11;
    planned(ref p,false,false,0,237376,0,237376);
}

@test
fn void all_place_formats_round_vector_capacity_at_minimum_boundaries_and_maximum(){
    let u8[5] ids=[0,1,6,7,15];
    let usize[5] array_bytes=[4096,8192,16384,32768,65536];
    let usize[5] mixed_bytes=[4096,8192,32768,32768,65536];
    let usize[5] aggregate_bytes=[8192,16384,32768,65536,131072];
    var u8 kind=0;while(kind<5){var usize i=0;while(i<5){
        var ir::Program p=ir::empty();p.count=1;p.code[0]=83;p.code[1]=ids[i];p.code[4]=kind;
        let usize expected=if(kind==0){array_bytes[i]}else if(kind<3){mixed_bytes[i]}else{aggregate_bytes[i]};
        planned(ref p,false,false,0,expected,0,expected);i+=1;
    }kind+=1;}
}

@test
fn void mixed_places_use_one_selected_format_and_all_maximum_components_overlap(){
    var ir::Program p=list(9,4096);p.count=3;
    // A low-ID aggregate selects the format for the high-ID legacy place too.
    p.code[8]=83;p.code[9]=0;p.code[12]=4;
    p.code[16]=83;p.code[17]=15;
    planned(ref p,false,false,0,262144,0,262144);
    planned(ref p,true,false,0,280576,0,280576);
    planned(ref p,false,true,1048576,262144,1049192,1311336);
    planned(ref p,true,true,1048576,280576,1049192,1329768);
    assert(p.count==3 && p.code[9]==0 && p.code[17]==15 && p.list_used==4096);
}

@test
fn void invalid_output_controls_and_all_size_header_overflows_fail_without_wrapping(){
    let usize maximum=18446744073709551615;var ir::Program p=ir::empty();
    rejected(ref p,false,false,1,0);rejected(ref p,true,false,maximum,0);
    rejected(ref p,false,true,1048577,0);rejected(ref p,true,true,maximum,0);
    p.count=257;rejected(ref p,false,false,0,0);
    p.count=maximum;rejected(ref p,false,false,0,0);p.count=0;
    p.arrays.count=17;rejected(ref p,false,false,0,0);
    p.arrays.count=maximum;rejected(ref p,false,false,0,0);p.arrays.count=0;
    p.records.count=17;rejected(ref p,false,false,0,0);
    p.records.count=maximum;rejected(ref p,false,false,0,0);p.records.count=0;
    p.list_used=4097;rejected(ref p,false,false,0,0);
    p.list_used=maximum;rejected(ref p,false,false,0,0);
    assert(p.count==0 && p.arrays.count==0 && p.records.count==0 && p.list_used==maximum);
}

@test
fn void original_list_and_place_errors_preserve_instruction_offsets_and_precedence(){
    var ir::Program p=array(10,1);p.count=3;p.list_used=1;p.code[16]=80;p.code[17]=16;
    p.offsets[2]=777;rejected(ref p,false,false,0,2);
    p.code[17]=0;p.arrays.elements[0]=0;rejected(ref p,false,false,0,2);
    p.arrays.elements[0]=10;p.arrays.lengths[0]=0;rejected(ref p,false,false,0,2);
    p.arrays.lengths[0]=4097;rejected(ref p,false,false,0,2);
    p.arrays.lengths[0]=18446744073709551615;rejected(ref p,false,false,0,2);
    p.code[8]=83;p.code[12]=5;
    rejected(ref p,false,false,0,2);
    p.arrays.lengths[0]=1;rejected(ref p,false,false,0,1);
    p=ir::empty();p.count=3;p.code[16]=83;p.code[17]=16;
    rejected(ref p,false,false,0,2);
    p.code[17]=0;p.code[20]=2;p.code[22]=1;rejected(ref p,false,false,0,2);
    p.code[16]=86;p.code[18]=1;p.code[20]=0;p.code[22]=0;
    rejected(ref p,false,false,0,2);
}
