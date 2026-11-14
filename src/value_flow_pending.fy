module value_flow_pending;

// Private 256-PC scheduler. The caller retains the ascending sweep cursor;
// work queued behind it is taken only after wrapping to the function start.
pub struct State { usize[4] words; }
pub fn State empty(){return State{.words=[0;4]};}
pub fn void add(ref mut State w,usize pc){
    assert(pc<256);let usize one=1;w.words[pc/64]|=one<<(pc%64);
}
// A nonzero word needs six binary tests to locate its least set bit.
fn usize first(usize word){
    var usize bits=word;var usize offset=0;
    if((bits&4294967295)==0){bits>>=32;offset+=32;}
    if((bits&65535)==0){bits>>=16;offset+=16;}
    if((bits&255)==0){bits>>=8;offset+=8;}
    if((bits&15)==0){bits>>=4;offset+=4;}
    if((bits&3)==0){bits>>=2;offset+=2;}
    if((bits&1)==0){offset+=1;}return offset;
}
// 256 is the empty sentinel. Excluded PCs remain queued for the next sweep.
pub fn usize take(ref mut State w,usize after,usize end){
    assert(after<=256 && end<=256);
    if(after>=end){return 256;}
    let usize one=1;var usize row=after/64;let usize current=one<<(after%64);
    // Dense straight-line code takes its immediate successor without a search.
    if((w.words[row]&current)!=0){w.words[row]^=current;return after;}
    var usize bits=w.words[row]&(~(current-1));
    while(row*64<end){
        if(bits!=0){let usize pc=row*64+first(bits);
            if(pc>=end){return 256;}
            w.words[row]^=one<<(pc%64);return pc;
        }
        row+=1;if(row*64<end){bits=w.words[row];}
    }return 256;
}
