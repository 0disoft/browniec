module tests::m2::fuel_schedule;
import fuel as meter;
import array_meta as metadata;
import array_vm as arrays;
import struct_vm as records;
import errors as errors;

fn usize price(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void invalid(Result<usize,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==123}});}

@test fn void all_scalar_array_prices_preserve_independent_minimum_and_maximum_layout_oracles(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[6] strides=[4,1,8,1,4,8];
    var usize t=0;while(t<6){var usize n=1;while(n<=4096){
        var metadata::Catalog c=metadata::empty();c.count=1;c.elements[0]=tags[t];c.lengths[0]=n;
        let usize w=strides[t];let usize size=n*w;let usize bool_scan=if(tags[t]==2){n}else{0};
        assert(price(arrays::cost(ref c,33,0,123))==56+2*w+size);
        assert(price(arrays::cost(ref c,34,0,123))==56+size+bool_scan);
        assert(price(arrays::cost(ref c,35,0,123))==33+w);
        assert(price(arrays::cost(ref c,36,0,123))==33+2*w);
        assert(price(arrays::cost(ref c,37,0,123))==49);
        assert(price(arrays::cost(ref c,38,0,123))==81+size+bool_scan);
        assert(price(arrays::cost(ref c,40,0,123))==49+2*w+size);
        if(tags[t]==10){assert(price(arrays::cost(ref c,51,0,123))==33+4*n);}
        else{invalid(arrays::cost(ref c,51,0,123));}
        invalid(arrays::cost(ref c,39,0,123));invalid(arrays::cost(ref c,255,0,123));
        invalid(arrays::cost(ref c,33,16,123));n*=4096;
    }t+=1;}
    var metadata::Catalog malformed=metadata::empty();malformed.count=1;malformed.elements[0]=1;
    invalid(arrays::cost(ref malformed,33,0,123));malformed.lengths[0]=4097;
    invalid(arrays::cost(ref malformed,33,0,123));
}
@test fn void every_record_opcode_preserves_its_independent_fixed_envelope(){
    let usize[9] expected=[46145,42049,41281,41281,65,60545,131072,46145,87105];
    let u8[9] ops=[41,42,43,44,45,46,47,48,49];var usize i=0;
    while(i<9){assert(price(records::cost(ops[i],123))==expected[i]);i+=1;}
    invalid(records::cost(40,123));invalid(records::cost(50,123));invalid(records::cost(255,123));
}
@test fn void list_and_place_setup_maxima_stay_bounded_below_the_public_ceiling(){
    assert(meter::list_prepare(0,0)==0 && meter::list_prepare(1,1)==260);
    assert(meter::list_prepare(4096,32768)==41217);
    assert(meter::list_instruction(false,4096,32768)==102456);
    assert(meter::list_instruction(true,4096,32768)==102449);
    assert(meter::place_prepare(0)==0 && meter::place_prepare(16)==46657);
    assert(meter::slice_place_prepare(16)==72267 && meter::record_place_prepare(16)==72277);
    assert(meter::cli_default()==256 && meter::cli_limit()==16000000);
    assert(65537+41217+72277+102456<meter::cli_limit());
}
