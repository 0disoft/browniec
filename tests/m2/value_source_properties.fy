module tests::m2::value_source_properties;
import value_source_properties as source;
import value_properties as raw;
fn u8 tag(raw::Error e){return switch(e){case .Metadata:{0}case .Type:{1}case .Depth:{2}case .Size:{3}};}
fn Result<raw::Plan,raw::Error> run(ref raw::Catalog c){return source::inspect(c);}

fn void same(ref raw::Catalog c){
    switch(raw::inspect(c)){
        case .err(a):{switch(run(c)){case .ok(_):{assert(false);}case .err(b):{assert(tag(a)==tag(b));}};}
        case .ok(a):{
            switch(run(c)){
                case .err(_):{assert(false);}
                case .ok(b):{
                    assert(a.count==b.count);var usize i=0;
                    while(i<64){let raw::Property x=a.properties[i];let raw::Property y=b.properties[i];
                        assert(x.bytes==y.bytes && x.alignment==y.alignment && x.payload_offset==y.payload_offset &&
                            x.wrapper_depth==y.wrapper_depth && x.copyable==y.copyable && x.contains_buffer==y.contains_buffer);i+=1;}
                }
            };
        }
    };
}
@test fn void private_property_adapter_matches_raw_plans_and_error_precedence(){
    var raw::Catalog c=raw::empty();same(ref c);c.count=4;c.nodes[0]=raw::Node{.kind=4,.first=0,.second=0,.extent=0};
    c.nodes[1]=raw::Node{.kind=2,.first=9,.second=0,.extent=4096};c.nodes[2]=raw::Node{.kind=5,.first=1,.second=0,.extent=0};
    c.nodes[3]=raw::Node{.kind=6,.first=0,.second=2,.extent=0};same(ref c);
    c.nodes[3].first=3;same(ref c);c.nodes[3].first=0;c.nodes[63].first=1;same(ref c);
    c.records.count=1;same(ref c);c.count=65;same(ref c);c=raw::empty();c.records.count=1;c.records.fields[0]=1;c.records.types[0]=1;
    c.count=1;c.nodes[0]=raw::Node{.kind=3,.first=0,.second=0,.extent=0};same(ref c);c.records.kinds[0]=1;same(ref c);
    c=raw::empty();c.count=6;c.nodes[0]=raw::Node{.kind=1,.first=1,.second=0,.extent=0};var usize i=1;var u8 prior=0;
    while(i<6){c.nodes[i]=raw::Node{.kind=5,.first=prior,.second=0,.extent=0};prior+=1;i+=1;}same(ref c);
    c=raw::empty();c.count=1;c.nodes[0]=raw::Node{.kind=2,.first=9,.second=0,.extent=4097};same(ref c);
    c=raw::empty();c.count=64;i=0;while(i<64){c.nodes[i]=raw::Node{.kind=1,.first=1,.second=0,.extent=0};i+=1;}same(ref c);
}
