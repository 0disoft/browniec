module tests::m2::aggregate_copy;
import aggregate_copy as copies;

fn usize relation(Result<copies::Relation,copies::Error> value){return switch(value){
    case .ok(r):{switch(r){case .Disjoint:{0}case .Identical:{1}case .Overlap:{2}}}
    case .err(_):{3}
};}
fn usize mode(Result<copies::Mode,copies::Error> value){return switch(value){
    case .ok(m):{switch(m){case .Direct:{0}case .NoOp:{1}case .Snapshot:{2}}}
    case .err(e):{switch(e){case .Bounds:{3}case .Scratch:{4}case .Alias:{5}}}
};}

@test fn void every_small_window_matches_an_independent_byte_membership_oracle(){
    var usize dst=0;while(dst<=16){var usize src=0;while(src<=16){var usize size=0;
        while(size<=16){
            let bool fits=dst+size<=16 && src+size<=16;
            var bool overlaps=false;var usize byte=0;
            while(byte<16){if(byte>=dst && byte<dst+size && byte>=src && byte<src+size){overlaps=true;}byte+=1;}
            let usize expected=if(!fits){3}else if(dst==src){1}else if(overlaps){2}else{0};
            assert(relation(copies::relation(dst,src,size,16))==expected);
            let usize direct=if(!fits){3}else if(size==0){0}else if(dst==src){1}else if(overlaps){5}else{0};
            assert(mode(copies::prove(dst,src,size,16,false,0,true))==direct);
            assert(mode(copies::prove(dst,src,size,16,true,size,false))==if(fits){2}else{3});
            size+=1;
        }src+=1;
    }dst+=1;}
}
@test fn void adjacency_empty_windows_and_usize_maximum_never_overflow_an_end(){
    let usize top=18446744073709551615;
    assert(relation(copies::relation(top,top,0,top))==1);
    assert(mode(copies::prove(top,top,0,top,false,0,false))==0);
    assert(relation(copies::relation(top-4,top-8,4,top))==0);
    assert(relation(copies::relation(top-4,top-5,4,top))==2);
    assert(mode(copies::prove(top,top,1,top,false,0,true))==3);
    assert(mode(copies::prove(0,top,top,top,true,top,true))==3);
    assert(mode(copies::prove(0,0,top,top,false,0,true))==1);
    assert(mode(copies::prove(0,0,top,top,true,top-1,true))==4);
}
@test fn void identical_and_partial_aliases_require_the_explicit_safe_strategy(){
    assert(mode(copies::prove(0,0,8,16,false,0,false))==5);
    assert(mode(copies::prove(0,0,8,16,false,0,true))==1);
    assert(mode(copies::prove(0,4,8,16,false,0,true))==5);
    assert(mode(copies::prove(4,0,8,16,false,0,true))==5);
    assert(mode(copies::prove(0,4,8,16,true,7,true))==4);
    assert(mode(copies::prove(0,4,8,16,true,8,false))==2);
    assert(mode(copies::prove(4,0,8,16,true,8,false))==2);
    // Even self-record assignment retains snapshot padding/bool normalization.
    assert(mode(copies::prove(0,0,8,16,true,8,true))==2);
    assert(mode(copies::prove(0,8,8,16,false,0,false))==0);
    assert(mode(copies::prove(17,17,0,16,false,0,true))==3);
}
