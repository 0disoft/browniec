module cli_output_base64;

import std::bytes as bytes;

// The caller checks the runtime payload ceiling before sizing the JSON buffer.
pub fn usize encoded_bytes(usize length){return ((length+2)/3)*4;}

pub fn Result<usize,bytes::BufferError> append(ref mut bytes::Buffer output,ref u8[] data){
    let usize start=bytes::len(output);
    let usize encoded=encoded_bytes(data.len);
    discard bytes::resize_zeroed(output,start+encoded)?;
    let ref mut u8[] target=bytes::view_mut(output);
    write(target[start..start+encoded],data);
    return .ok(start+encoded);
}

fn void write(ref mut u8[] target,ref u8[] data){
    let ref u8[] alphabet=b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var usize src=0;var usize dst=0;
    while(data.len-src>=3){
        let usize a=data[src] as usize;
        let usize b=data[src+1] as usize;
        let usize c=data[src+2] as usize;
        target[dst]=alphabet[a>>2];
        target[dst+1]=alphabet[((a&3)<<4)|(b>>4)];
        target[dst+2]=alphabet[((b&15)<<2)|(c>>6)];
        target[dst+3]=alphabet[c&63];
        src+=3;dst+=4;
    }
    let usize left=data.len-src;
    if(left==0){return;}
    let usize a=data[src] as usize;
    let usize b=if(left==2){data[src+1] as usize}else{0};
    target[dst]=alphabet[a>>2];
    target[dst+1]=alphabet[((a&3)<<4)|(b>>4)];
    target[dst+2]=if(left==2){alphabet[(b&15)<<2]}else{61};
    target[dst+3]=61;
}
