module tests::m2::host_catalog;
import host_catalog as catalog;
import catalog_digest as sha;
import host_wire as wire;
import std::bytes as bytes;

fn catalog::Catalog parsed(ref u8[] source){
    return switch(catalog::parse(source)){case .ok(c):{c}case .err(_):{assert(false);return parsed(b"");}};
}
fn u8 code(catalog::Failure f){return switch(f){
    case .Json:{1}case .Limit:{2}case .Unknown:{3}case .Duplicate:{4}case .Missing:{5}
    case .Value:{6}case .Order:{7}case .Allocation:{8}case .Bounds:{9}
};}
fn void denied(ref u8[] source){assert(!catalog::parse(source).is_ok);}
fn void failure(ref u8[] source,catalog::Failure kind){
    switch(catalog::parse(source)){case .err(e):{assert(code(e.kind)==code(kind));assert(e.offset<=source.len);}
        case .ok(_):{assert(false);}};
}
fn void hash_matches(ref u32[] words,ref u8[] hex){
    assert(words.len==8 && hex.len==64);let ref u8[] digits=b"0123456789abcdef";var usize i=0;
    var u32 shift=28;
    while(i<64){assert(hex[i]==digits[((words[i/8]>>shift)&15) as usize]);i+=1;if(i%8==0){shift=28;}else{shift-=4;}}
}
fn void accepted(ref u8[] source,ref u8[] expected,ref u8[] digest){
    let catalog::Catalog c=parsed(source);
    let bytes::Buffer output=switch(catalog::canonical_bytes(ref c)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::equal(bytes::view(ref output),expected));
    let u32[8] hash=switch(catalog::digest(ref c)){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
    hash_matches(ref hash,digest);
}
fn void append(ref mut bytes::Buffer b,ref u8[] value){assert(bytes::append(b,value).is_ok);}
fn void number(ref mut bytes::Buffer b,usize n){assert(bytes::append_usize(b,n).is_ok);}
fn ref u8[] base(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"}]}";}
fn bytes::Buffer replace_base(usize begin,usize end,ref u8[] value){
    let ref u8[] original=base();var bytes::Buffer out=bytes::empty();
    append(ref mut out,original[..begin]);append(ref mut out,value);append(ref mut out,original[end..original.len]);return out;
}
fn void changed(usize begin,usize end,ref u8[] value){let bytes::Buffer source=replace_base(begin,end,value);denied(bytes::view(ref source));}
fn void changed_failure(usize begin,usize end,ref u8[] value,catalog::Failure kind){
    let bytes::Buffer source=replace_base(begin,end,value);failure(bytes::view(ref source),kind);
}
fn void accepted_change(usize begin,usize end,ref u8[] value,ref u8[] expected,ref u8[] hash){
    let bytes::Buffer source=replace_base(begin,end,value);accepted(bytes::view(ref source),expected,hash);
}
fn bytes::Buffer generated(usize imports,usize arguments){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"{\"schema\":\"brownie.catalog/1\",\"imports\":[");var usize i=0;
    while(i<imports){
        if(i>0){append(ref mut b,b",");}
        append(ref mut b,b"{\"id\":");number(ref mut b,i);append(ref mut b,b",\"module\":\"host::m\",\"symbol\":\"s");
        if(i<10){append(ref mut b,b"0");}number(ref mut b,i);
        append(ref mut b,b"\",\"parameters\":[");var usize j=0;
        while(j<arguments){if(j>0){append(ref mut b,b",");}append(ref mut b,b"\"ref u8[]\"");j+=1;}
        append(ref mut b,b"],\"result\":\"Result<brownie::bytes::Buffer,u32>\",\"effect\":\"write\",\"capability\":\"host.test\",\"adapter_revision\":\"v1.0_A\"}");i+=1;
    }append(ref mut b,b"]}");return b;
}

@test fn void zip_vector_and_empty_catalog_match_exact_bytes_and_sha256(){
    // accepted_zip
    accepted_change(225,225,b"",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"bfec9acc23d667b2fe2bd5a11e801c4e2c42ffad6b58a5632d39583098092f94");
    // empty
    accepted_change(41,223,b"",b"BRC-CATALOG-1\x0a\x00\x00\x00\x00",b"1f587a2b422cdf40fbb0712d70244d4a90c5be71ae7c31e6f8f5d97e0c156862");
}

@test fn void decoded_duplicate_and_unknown_keys_reject_at_both_object_levels(){
    // duplicate_root_schema
    changed_failure(31,224,b"\\u0073chema\":\"brownie.catalog/1\"",.Duplicate);
    // duplicate_root_imports
    changed_failure(2,32,b"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"}],\"\\u0069",.Duplicate);
    // duplicate_import_id
    changed_failure(2,222,b"imports\":[{\"id\":0,\"\\u0069d\":0",.Duplicate);
    // duplicate_import_module
    changed_failure(2,221,b"imports\":[{\"module\":\"host::example\",\"\\u006dodule\":\"host::example",.Duplicate);
    // duplicate_import_symbol
    changed_failure(2,221,b"imports\":[{\"symbol\":\"check\",\"\\u0073ymbol\":\"check",.Duplicate);
    // duplicate_import_parameters
    changed_failure(2,222,b"imports\":[{\"parameters\":[\"i32\",\"ref u8[]\"],\"\\u0070arameters\":[\"i32\",\"ref u8[]\"]",.Duplicate);
    // duplicate_import_result
    changed_failure(2,221,b"imports\":[{\"result\":\"Result<i32,u32>\",\"\\u0072esult\":\"Result<i32,u32>",.Duplicate);
    // duplicate_import_effect
    changed_failure(2,221,b"imports\":[{\"effect\":\"read\",\"\\u0065ffect\":\"read",.Duplicate);
    // duplicate_import_capability
    changed_failure(2,221,b"imports\":[{\"capability\":\"host.example.check\",\"\\u0063apability\":\"host.example.check",.Duplicate);
    // duplicate_import_adapter_revision
    changed_failure(2,202,b"imports\":[{\"adapter_revision\":\"1\",\"\\u0061",.Duplicate);
    // unknown_12
    changed_failure(2,224,b"\\u0078\":{}",.Unknown);
    // unknown_13
    changed_failure(2,222,b"imports\":[{\"\\u0078\":[{}]",.Unknown);
}

@test fn void every_required_field_is_required(){
    // missing_root_schema
    changed_failure(2,31,b"",.Missing);
    // missing_root_imports
    changed_failure(29,224,b"",.Missing);
    // missing_import_id
    changed_failure(43,50,b"",.Missing);
    // missing_import_module
    changed_failure(50,75,b"",.Missing);
    // missing_import_symbol
    changed_failure(75,92,b"",.Missing);
    // missing_import_parameters
    changed_failure(92,124,b"",.Missing);
    // missing_import_result
    changed_failure(124,151,b"",.Missing);
    // missing_import_effect
    changed_failure(151,167,b"",.Missing);
    // missing_import_capability
    changed_failure(167,201,b"",.Missing);
    // missing_import_adapter_revision
    changed_failure(199,222,b"",.Missing);
}

@test fn void strict_grammar_utf8_escapes_and_one_root(){
    // empty_input
    changed(0,225,b"");
    // empty_object
    changed(1,224,b"");
    // root_array
    changed(0,225,b"[]");
    // root_null
    changed(0,225,b"null");
    // root_string
    changed(0,225,b"\"x\"");
    // wrong_schema
    changed(27,223,b"2\",\"imports\":[");
    // trailing_root
    changed(225,225,b"{}");
    // trailing_garbage
    changed(225,225,b"x");
    // trailing_root_comma
    changed(41,224,b"],");
    // trailing_import_comma
    changed(222,222,b",");
    // trailing_array_comma
    changed(223,223,b",");
    // trailing_arg_comma
    changed(121,121,b",");
    // missing_colon
    changed(9,10,b"");
    // missing_comma
    changed(29,30,b" ");
    // imports_object
    changed(2,224,b"imports\":{}");
    // entry_array
    changed(2,223,b"imports\":[[]");
    // arg_null
    changed(105,121,b"null");
    // arg_number
    changed(105,121,b"0");
    // parameters_string
    changed(104,122,b"\"i32\"");
    // effect_bool
    changed(159,165,b"true");
    // bad_escape
    changed(65,72,b"\\q");
    // unpaired_high
    changed(84,89,b"\\uD800");
    // unpaired_low
    changed(84,89,b"\\uDC00");
    // nul
    changed(84,89,b"x\\u0000");
    // unicode
    changed(84,89,b"\\u00e9");
    // unicode_surrogates
    changed(84,89,b"\\ud83d\\ude00");
    // raw_control
    changed(65,72,b"a\x01");
    // invalid_utf8
    changed(65,72,b"\xff");
}

@test fn void schema_names_effects_and_unsupported_types_reject(){
    // module_52
    changed(59,72,b"");
    // module_53
    changed(63,72,b"");
    // module_54
    changed(65,72,b"");
    // module_55
    changed(59,72,b"HOST::a");
    // module_56
    changed(59,72,b"xhost::a");
    // module_57
    changed(65,72,b"a:");
    // module_58
    changed(65,72,b"a::");
    // module_59
    changed(65,72,b"a:::b");
    // module_60
    changed(65,72,b"1a");
    // module_61
    changed(65,72,b"a-b");
    // module_62
    changed(65,72,b"a b");
    // module_63
    changed(65,72,b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    // symbol_64
    changed(84,89,b"");
    // symbol_65
    changed(84,89,b"1a");
    // symbol_66
    changed(84,89,b"a::b");
    // symbol_67
    changed(84,89,b"a.b");
    // symbol_68
    changed(84,89,b"a-b");
    // symbol_69
    changed(84,89,b"a b");
    // symbol_70
    changed(84,89,b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    // capability_71
    changed(180,198,b"");
    // capability_72
    changed(180,198,b"ab");
    // capability_73
    changed(180,198,b"a");
    // capability_74
    changed(180,198,b"a.");
    // capability_75
    changed(180,198,b".a");
    // capability_76
    changed(180,198,b"a..b");
    // capability_77
    changed(180,198,b"A.b");
    // capability_78
    changed(180,198,b"a.B");
    // capability_79
    changed(180,198,b"a._b");
    // capability_80
    changed(180,198,b"a.b-c");
    // capability_81
    changed(180,198,b"a.bcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc");
    // capability_82
    changed(180,198,b"a\\\\b");
    // adapter_revision_83
    changed(220,221,b"");
    // adapter_revision_84
    changed(220,221,b"a-b");
    // adapter_revision_85
    changed(220,221,b"a b");
    // adapter_revision_86
    changed(220,221,b"a/b");
    // adapter_revision_87
    changed(220,221,b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    // effect_88
    changed(160,164,b"");
    // effect_89
    changed(160,164,b"pure");
    // effect_90
    changed(160,161,b"R");
    // effect_91
    changed(164,164,b" ");
    // parameters_92
    changed(106,120,b"ref str");
    // parameters_93
    changed(106,115,b"ref mut");
    // parameters_94
    changed(107,120,b"8");
    // parameters_95
    changed(106,120,b"Buffer");
    // parameters_96
    changed(106,120,b"Result<i32,u32>");
    // result_97
    changed(133,148,b"i32");
    // result_98
    changed(144,144,b" ");
    // result_99
    changed(144,145,b"i");
    // result_100
    changed(140,143,b"Buffer");
    // result_101
    changed(140,143,b"ref u8[]");
}

@test fn void contiguous_ids_and_full_qualified_ascii_order_are_required(){
    // bad_id_102
    changed(47,48,b"-1");
    // bad_id_103
    changed(47,48,b"64");
    // bad_id_104
    changed(47,48,b"999999999999999999999999999999");
    // bad_id_105
    changed(47,48,b"true");
    // bad_id_106
    changed(47,48,b"null");
    // bad_id_107
    changed(47,48,b"\"0\"");
    // bad_id_108
    changed(47,48,b"[]");
    // bad_id_109
    changed(47,48,b"{}");
    // id_spelling_-0
    changed(47,47,b"-");
    // id_spelling_0.0
    changed(48,48,b".0");
    // id_spelling_0e0
    changed(48,48,b"e0");
    // id_spelling_0E+0
    changed(48,48,b"E+0");
    // id_spelling_00
    changed(48,48,b"0");
    // id_spelling_+0
    changed(47,47,b"+");
    // first_id_1
    changed_failure(47,48,b"1",.Order);
    // id_gap
    changed(65,89,b"a\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":2,\"module\":\"host::b\",\"symbol\":\"x");
    // repeated_id
    changed(65,89,b"a\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":0,\"module\":\"host::b\",\"symbol\":\"x");
    // unsorted_ids
    changed(47,89,b"1,\"module\":\"host::a\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":0,\"module\":\"host::b\",\"symbol\":\"x");
    // unsorted_symbols
    changed(65,89,b"a\",\"symbol\":\"z\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::a\",\"symbol\":\"a");
    // duplicate_symbol
    changed(65,89,b"a\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::a\",\"symbol\":\"x");
    // decoded_duplicate_symbol
    changed(65,89,b"a\",\"symbol\":\"\\u0078\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::a\",\"symbol\":\"x");
    // nonadjacent_duplicate
    changed(65,89,b"a\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::b\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":2,\"module\":\"host::a\",\"symbol\":\"x");
    // qualified_prefix_valid
    accepted_change(65,89,b"a0\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::a\",\"symbol\":\"x",b"BRC-CATALOG-1\x0a\x02\x00\x00\x00\x00\x00\x00\x00\x08\x00\x00\x00host::a0\x01\x00\x00\x00x\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]\x01\x00\x00\x00\x07\x00\x00\x00host::a\x01\x00\x00\x00x\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"41a316f4404ce57f11c7f02bea9b84cdd52a5d7b8fb8a39c9afaa2bd45178f28");
    // qualified_prefix_invalid
    changed(65,89,b"a\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::a0\",\"symbol\":\"x");
    // qualified_nested_valid
    accepted_change(65,89,b"a::b\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::a\",\"symbol\":\"z",b"BRC-CATALOG-1\x0a\x02\x00\x00\x00\x00\x00\x00\x00\x0a\x00\x00\x00host::a::b\x01\x00\x00\x00x\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]\x01\x00\x00\x00\x07\x00\x00\x00host::a\x01\x00\x00\x00z\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"626bb069f246c8c4cb19ce184b5aeba2236e387facf2bc888bd9b20c4339c5a4");
    // case_order_valid
    accepted_change(65,89,b"A\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::a\",\"symbol\":\"x",b"BRC-CATALOG-1\x0a\x02\x00\x00\x00\x00\x00\x00\x00\x07\x00\x00\x00host::A\x01\x00\x00\x00x\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]\x01\x00\x00\x00\x07\x00\x00\x00host::a\x01\x00\x00\x00x\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"ad04ecb4be7c07f965f665c35e20ccae9aa94b523a34924d5141a71d7016c735");
    // case_order_invalid
    changed(65,89,b"a\",\"symbol\":\"x\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"},{\"id\":1,\"module\":\"host::A\",\"symbol\":\"x");
}

@test fn void all_scalar_and_bytes_argument_and_result_types_match_canonical_vectors(){
    // type_1
    accepted_change(106,143,b"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize\",\"ref u8[]\"],\"result\":\"Result<bool",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x10\x00\x00\x00Result<bool,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"c079e964d87b6bbb34a9025360de4ba60a3ee87ae59027203d2d3fcab62f79e0");
    // type_2
    accepted_change(106,143,b"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize\",\"ref u8[]\"],\"result\":\"Result<u8",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0e\x00\x00\x00Result<u8,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"2e839641bd2dc1b55999088f18868f85ef7acfd22c4253ebf6a32d70b2b84bb3");
    // type_3
    accepted_change(106,109,b"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"f90171ef54a04801e47b7f5fb92270d99b9051ceecdbeaeafcd53667ec10bb55");
    // type_4
    accepted_change(106,143,b"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize\",\"ref u8[]\"],\"result\":\"Result<i64",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i64,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"e1387f993914d432cc8f8c323004cc311d30648718b67fc50987b0cc402cae56");
    // type_5
    accepted_change(106,141,b"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize\",\"ref u8[]\"],\"result\":\"Result<u",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<u32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"19c571875684da4928b060c88c5b3f04b05e6f88626a9fda77e363243ebc45d9");
    // type_6
    accepted_change(106,143,b"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize\",\"ref u8[]\"],\"result\":\"Result<usize",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x11\x00\x00\x00Result<usize,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"fab61112ed5508f43ebceae7a8c9ccc12896b2177586c5c51d57fd7c5bbb621d");
    // type_7
    accepted_change(106,143,b"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize\",\"ref u8[]\"],\"result\":\"Result<brownie::bytes::Buffer",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\"\x00\x00\x00Result<brownie::bytes::Buffer,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"931611bb467b9b631dcc876abdbf9d708300c35ccad336d25d241f8e389e766f");
}

@test fn void every_binding_field_is_hashed_and_equivalent_json_preserves_identity(){
    // module
    accepted_change(65,72,b"other",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0b\x00\x00\x00host::other\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"ba576d71a5e593977139d8817e385b73071a9fb0373934dd87fea07a6d5113a0");
    // symbol
    accepted_change(84,89,b"other",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00other\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"43e8b29313f1046c21c487b9faf3fbf7aa761f92660e283073fdffbffa729dbf");
    // effect
    accepted_change(160,164,b"write",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x05\x00\x00\x00write\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"0b5915fbe65132f26388a3b1f2bfa78f6e37eff0dd7c573d00cd2f83e6c80cda");
    // capability
    accepted_change(193,198,b"other",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.other\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"cb88dd45cee5866c8ba8feeaeb3f89bf5913bd008be9e54c4597f9d8a533918c");
    // adapter_revision
    accepted_change(220,221,b"2",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x002\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"db9a27e43dae36f34847f1cd8cce942c332175cace1956c6186c1cd5ba25618f");
    // parameters
    accepted_change(107,109,b"64",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i64\x08\x00\x00\x00ref u8[]",b"b981844dbd6ec83d49e91b788ed770d82e9189f0560a409234b2aedba2174d4e");
    // result
    accepted_change(141,143,b"64",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i64,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"3ca1135ad7be5499ae20c9afe4dbdf9e654428f5dc1225c14de94f6cfc06d22f");
    // equivalent_json
    accepted_change(1,224,b"\x0a \"imports\": [\x0a  {\x0a   \"adapter_revision\": \"1\",\x0a   \"capability\": \"host.example.check\",\x0a   \"effect\": \"read\",\x0a   \"result\": \"Result<i32,u32>\",\x0a   \"parameters\": [\x0a    \"i32\",\x0a    \"ref u8\\u005b\\u005d\"\x0a   ],\x0a   \"symbol\": \"check\",\x0a   \"\\u006dodule\": \"ho\\u0073t::example\",\x0a   \"id\": 0\x0a  }\x0a ],\x0a \"\\u0073chema\": \"brownie.catalog/1\"\x0a",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x0d\x00\x00\x00host::example\x05\x00\x00\x00check\x0f\x00\x00\x00Result<i32,u32>\x04\x00\x00\x00read\x12\x00\x00\x00host.example.check\x01\x00\x00\x001\x02\x00\x00\x00\x03\x00\x00\x00i32\x08\x00\x00\x00ref u8[]",b"bfec9acc23d667b2fe2bd5a11e801c4e2c42ffad6b58a5632d39583098092f94");
}

@test fn void exact_byte_import_and_argument_limits_and_maximum_spellings(){
    assert(catalog::byte_limit()==16384 && catalog::import_limit()==64 && catalog::argument_limit()==32);
    var bytes::Buffer b=generated(64,0);assert(bytes::len(ref b)<16384);
    while(bytes::len(ref b)<16384){append(ref mut b,b" ");}
    let catalog::Catalog c=parsed(bytes::view(ref b));assert(catalog::count(ref c)==64);
    assert(switch(catalog::symbol(ref c,63)){case .ok(s):{bytes::equal(s,b"s63")}case .err(_):{false}});
    let bytes::Buffer canonical=switch(catalog::canonical_bytes(ref c)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::len(ref canonical)<catalog::canonical_limit());assert(catalog::digest(ref c).is_ok);
    append(ref mut b,b" ");failure(bytes::view(ref b),.Limit);
    let bytes::Buffer excessive=generated(65,0);assert(bytes::len(ref excessive)<16384);failure(bytes::view(ref excessive),.Limit);
    let bytes::Buffer args=generated(1,32);let catalog::Catalog a=parsed(bytes::view(ref args));
    assert(switch(catalog::parameter_count(ref a,0)){case .ok(n):{n==32}case .err(_):{false}});
    assert(switch(catalog::parameter_tag(ref a,0,31)){case .ok(n):{n==7}case .err(_):{false}});
    assert(switch(catalog::result_tag(ref a,0)){case .ok(n):{n==7}case .err(_):{false}});
    let bytes::Buffer too_many=generated(1,33);failure(bytes::view(ref too_many),.Limit);
    accepted_change(65,221,b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"symbol\":\"_zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\",\"parameters\":[\"bool\",\"u8\",\"i32\",\"i64\",\"u32\",\"usize\",\"ref u8[]\"],\"result\":\"Result<brownie::bytes::Buffer,u32>\",\"effect\":\"read\",\"capability\":\"a.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"adapter_revision\":\"................................................................",b"BRC-CATALOG-1\x0a\x01\x00\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00host::aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa@\x00\x00\x00_zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\"\x00\x00\x00Result<brownie::bytes::Buffer,u32>\x04\x00\x00\x00read\x80\x00\x00\x00a.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb@\x00\x00\x00................................................................\x07\x00\x00\x00\x04\x00\x00\x00bool\x02\x00\x00\x00u8\x03\x00\x00\x00i32\x03\x00\x00\x00i64\x03\x00\x00\x00u32\x05\x00\x00\x00usize\x08\x00\x00\x00ref u8[]",b"67d40857956ce67f1b4dc3b62b3f31d364ee1fc427250386aa164318b533e1fa");
}

@test fn void admitted_catalog_owns_decoded_bytes_and_accessors_are_bounded(){
    var bytes::Buffer source=switch(bytes::copy(b"{\x22schema\x22:\x22brownie.catalog/1\x22,\x22imports\x22:[{\x22id\x22:0,\x22module\x22:\x22host::example\x22,\x22symbol\x22:\x22check\x22,\x22parameters\x22:[\x22i32\x22,\x22ref u8[]\x22],\x22result\x22:\x22Result<i32,u32>\x22,\x22effect\x22:\x22read\x22,\x22capability\x22:\x22host.example.check\x22,\x22adapter_revision\x22:\x221\x22}]}")){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    let catalog::Catalog c=parsed(bytes::view(ref source));
    let ref mut u8[] original=bytes::view_mut(ref mut source);var usize i=0;while(i<original.len){original[i]=0;i+=1;}
    assert(catalog::count(ref c)==1);
    assert(switch(catalog::module_name(ref c,0)){case .ok(v):{bytes::equal(v,b"host::example")}case .err(_):{false}});
    assert(switch(catalog::symbol(ref c,0)){case .ok(v):{bytes::equal(v,b"check")}case .err(_):{false}});
    assert(switch(catalog::capability(ref c,0)){case .ok(v):{bytes::equal(v,b"host.example.check")}case .err(_):{false}});
    assert(switch(catalog::adapter_revision(ref c,0)){case .ok(v):{bytes::equal(v,b"1")}case .err(_):{false}});
    assert(switch(catalog::effect(ref c,0)){case .ok(v):{bytes::equal(v,b"read")}case .err(_):{false}});
    assert(switch(catalog::result_type(ref c,0)){case .ok(v):{bytes::equal(v,b"Result<i32,u32>")}case .err(_):{false}});
    assert(switch(catalog::parameter_type(ref c,0,0)){case .ok(v):{bytes::equal(v,b"i32")}case .err(_):{false}});
    assert(switch(catalog::parameter_type(ref c,0,1)){case .ok(v):{bytes::equal(v,b"ref u8[]")}case .err(_):{false}});
    assert(!catalog::module_name(ref c,1).is_ok && !catalog::symbol(ref c,64).is_ok);
    assert(!catalog::capability(ref c,1).is_ok && !catalog::adapter_revision(ref c,1).is_ok);
    assert(!catalog::effect(ref c,1).is_ok && !catalog::result_type(ref c,1).is_ok);
    assert(!catalog::result_tag(ref c,1).is_ok && !catalog::parameter_count(ref c,1).is_ok);
    assert(!catalog::parameter_tag(ref c,1,0).is_ok && !catalog::parameter_type(ref c,0,2).is_ok);
    assert(!catalog::parameter_tag(ref c,0,32).is_ok);
    assert(catalog::canonical_bytes(ref c).is_ok && catalog::digest(ref c).is_ok);
}
@test fn void sha256_known_answers_padding_boundaries_and_hard_bound(){
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<0){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<1){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<55){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<56){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<63){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<64){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<65){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<119){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"31eba51c313a5c08226adf18d4a359cfdfd8d2e816b13f4af952f7ea6584dcfb");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<120){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"2f3d335432c70b580af0e8e1b3674a7c020d683aa5f73aaaedfdc55af904c21c");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<127){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"c57e9278af78fa3cab38667bef4ce29d783787a2f731d4e12200270f0c32320a");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<128){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"6836cf13bac400e9105071cd6af47084dfacad4e5e302c94bfed24e013afb73e");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<16384){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"f3336bea752b5a28743033dd2c844a4a63fba08871aaee2586a2bf2d69be83a2");
    }
    {
        var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<65536){append(ref mut b,b"a");}
        let u32[8] words=switch(sha::digest(bytes::view(ref b))){case .ok(v):{v}case .err(_):{assert(false);[0;8]}};
        hash_matches(ref words,b"bf718b6f653bebc184e1479f1935b8da974d701b893afcf49e701f3e2f9f9c5a");
    }
    var bytes::Buffer b=bytes::empty();while(bytes::len(ref b)<65537){append(ref mut b,b"a");}
    assert(!sha::digest(bytes::view(ref b)).is_ok);
}

@test fn void admitted_catalog_tags_compose_with_real_wire_decoders(){
    // Preserve i32/ref-u8[] arguments and select the accepted Buffer result.
    let catalog::Catalog c=parsed(b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\",\"ref u8[]\"],\"result\":\"Result<brownie::bytes::Buffer,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"}]}");
    let usize argc=switch(catalog::parameter_count(ref c,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    var u8[32] tags=[0;32];var usize i=0;
    while(i<argc){tags[i]=switch(catalog::parameter_tag(ref c,0,i)){case .ok(v):{v}case .err(_):{assert(false);0}};i+=1;}
    let u8 result=switch(catalog::result_tag(ref c,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    assert(argc==2 && tags[0]==3 && tags[1]==7 && result==7);
    assert(wire::scalar_tag(tags[0])==1);
    let ref u8[] request=b"\x02\x00\x03\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x80\x07\x00\x00\x00\x02\x00\x00\x00ab";
    let wire::Request decoded=switch(wire::decode_request(request,ref tags[..argc],wire::payload_limit())){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };
    assert(decoded.count==2 && decoded.fields[0].tag==3 && decoded.fields[0].scalar==-2147483648);
    assert(decoded.fields[1].tag==7 && decoded.fields[1].length==2);
    let usize begin=decoded.fields[1].start;assert(bytes::equal(request[begin..begin+2],b"ab"));
    let ref u8[] reply=b"\x07\x00\x00\x00\x02\x00\x00\x00ab";
    let wire::Field ok=switch(wire::decode_reply(0,result,reply,wire::payload_limit())){
        case .ok(v):{v}case .err(_):{assert(false);wire::empty_field()}
    };
    assert(ok.tag==7 && bytes::equal(reply[ok.start..ok.start+ok.length],b"ab"));
    let ref u8[] scalar_reply=b"\x03\x00\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00";
    assert(!wire::decode_reply(0,result,scalar_reply,wire::payload_limit()).is_ok);
    let wire::Field err=switch(wire::decode_reply(1,result,b"\x05\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff",wire::payload_limit())){
        case .ok(v):{v}case .err(_):{assert(false);wire::empty_field()}
    };
    assert(err.tag==5 && err.scalar==4294967295);
    let catalog::Catalog mismatch=parsed(b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"u32\",\"ref u8[]\"],\"result\":\"Result<brownie::bytes::Buffer,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"1\"}]}");
    tags[0]=switch(catalog::parameter_tag(ref mismatch,0,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    assert(tags[0]==5 && !wire::decode_request(request,ref tags[..argc],wire::payload_limit()).is_ok);
}
