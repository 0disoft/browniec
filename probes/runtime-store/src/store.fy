module store;
import std::vec as vec;
import std::bytes as bytes;
unsafe extern C fn void record_drop(usize value);
unsafe extern C fn usize push_raw(ptr mut void owner,usize value);
unsafe extern C fn usize mutate_raw(ptr mut void owner,usize index,u8 value);
unsafe extern C fn usize pop_raw(ptr mut void owner);
resource Entry {bytes::Buffer buffer;usize value;cleanup{unsafe{record_drop(this.value)};}}
pub resource Store {vec::Vec<Entry> items;cleanup{}}
pub fn Store open(){return Store{.items=vec::empty<Entry>()};}
pub fn usize size(ref Store s){return vec::len<Entry>(ref s.items);}
pub fn usize push(ref mut Store s,usize value){return unsafe{push_raw(s as ptr mut void,value)};}
pub fn usize mutate(ref mut Store s,usize index,u8 value){return unsafe{mutate_raw(s as ptr mut void,index,value)};}
pub fn usize pop(ref mut Store s){return unsafe{pop_raw(s as ptr mut void)};}
// Normal typed Fairy ownership operations. C only projects actual emitted fields.
pub fn usize push_inner(ref mut vec::Vec<Entry> items,usize value){
    var bytes::Buffer b=bytes::empty();assert(bytes::append_byte(ref mut b,7).is_ok);
    assert(vec::push<Entry>(items,Entry{.buffer=b,.value=value}).is_ok);return vec::len<Entry>(items);
}
pub fn usize mutate_buffer(ref mut bytes::Buffer b,u8 value){assert(bytes::append_byte(b,value).is_ok);return bytes::len(b);}
pub fn usize pop_inner(ref mut vec::Vec<Entry> items){
    return switch(vec::pop<Entry>(items)){case .some(e):{assert(bytes::len(ref e.buffer)>=1);e.value}case .none:{0}};
}
pub fn ptr mut void entry_address(ref mut vec::Vec<Entry> v,usize index){let ref mut Entry e=vec::at_mut<Entry>(v,index);return unsafe{e as ptr mut void};}
pub fn void retain_helpers(){
    var vec::Vec<Entry> v=vec::empty<Entry>();assert(push_inner(ref mut v,90)==1);
    let ptr mut void address=entry_address(ref mut v,0);assert(address!=null);
    var bytes::Buffer b=bytes::empty();assert(mutate_buffer(ref mut b,1)==1);assert(pop_inner(ref mut v)==90);
}
