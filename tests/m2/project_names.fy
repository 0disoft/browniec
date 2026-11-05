module tests::m2::project_names;
import project_names as names;

@test fn void project_names_require_the_declared_lowercase_alphabet_and_domain(){
    assert(names::project_name(b"a"));
    assert(names::project_name(b"0"));
    assert(names::project_name(b"a-"));
    assert(names::project_name(b"0-fed--tool"));
    var u8[80] maximum=[97;80];
    var u8[81] too_long=[97;81];
    assert(names::project_name(ref maximum));
    assert(!names::project_name(ref too_long));
    assert(!names::project_name(b""));
    assert(!names::project_name(b"Upper"));
    assert(!names::project_name(b"-leading"));
    assert(!names::project_name(b"_leading"));
    assert(!names::project_name(b"a_b"));
    assert(!names::project_name(b"a.b"));
    assert(!names::project_name(b"a b"));
    assert(!names::project_name(b"a/slash"));
    assert(!names::project_name(b"a:b"));
    assert(!names::project_name(b"\xc3\xa9"));
}

@test fn void module_and_function_names_reuse_language_identifiers_and_reserved_words(){
    assert(names::module_name(b"main"));
    assert(names::module_name(b"util::math"));
    assert(names::module_name(b"Upper::_inner9"));
    assert(names::module_name(b"stdx::std"));
    assert(names::function_name(b"main"));
    assert(names::function_name(b"_worker9"));
    assert(names::function_name(b"Upper"));
    assert(names::function_name(b"Fn"));
    assert(names::function_name(b"ResultX"));
    assert(names::function_name(b"std"));

    assert(!names::module_name(b""));
    assert(!names::module_name(b"std"));
    assert(!names::module_name(b"std::guest"));
    assert(!names::module_name(b"brownie"));
    assert(!names::module_name(b"brownie::app"));
    assert(!names::module_name(b"fn::helper"));
    assert(!names::module_name(b"helper::Result"));
    assert(!names::module_name(b"1bad"));
    assert(!names::module_name(b"a.b"));
    assert(!names::module_name(b"a:b"));
    assert(!names::module_name(b"a:::b"));
    assert(!names::module_name(b"a::"));
    assert(!names::module_name(b"::a"));
    assert(!names::module_name(b"a::_"));

    assert(!names::function_name(b""));
    assert(!names::function_name(b"return"));
    assert(!names::function_name(b"fn"));
    assert(!names::function_name(b"i32"));
    assert(!names::function_name(b"Result"));
    assert(!names::function_name(b"_"));
    assert(!names::function_name(b"a::b"));
    assert(!names::function_name(b"9lives"));
}

@test fn void module_function_and_capability_limits_are_inclusive(){
    var u8[128] module_bound=[97;128];
    var u8[129] module_over=[97;129];
    var u8[64] function_bound=[102;64];
    var u8[65] function_over=[102;65];
    var u8[128] capability_bound=[97;128];capability_bound[64]=46;capability_bound[65]=98;
    var u8[129] capability_over=[97;129];capability_over[64]=46;capability_over[65]=98;
    assert(names::module_name(ref module_bound));
    assert(!names::module_name(ref module_over));
    assert(names::function_name(ref function_bound));
    assert(!names::function_name(ref function_over));
    assert(names::capability(ref capability_bound));
    assert(!names::capability(ref capability_over));
}

@test fn void capability_segments_are_dotted_and_start_with_lowercase_letters(){
    assert(names::capability(b"a.b"));
    assert(names::capability(b"fs.read"));
    assert(names::capability(b"net.http2.retry"));
    assert(!names::capability(b""));
    assert(!names::capability(b"leaf"));
    assert(!names::capability(b".a.b"));
    assert(!names::capability(b"a..b"));
    assert(!names::capability(b"a.b."));
    assert(!names::capability(b"A.b"));
    assert(!names::capability(b"a.B"));
    assert(!names::capability(b"a.1b"));
    assert(!names::capability(b"a.b-c"));
    assert(!names::capability(b"a.b_c"));
    assert(!names::capability(b"a.b c"));
    assert(!names::capability(b"a.\xc3\xa9"));
}

@test fn void member_paths_accept_root_relative_source_spellings_and_maximum_length(){
    assert(names::member_path(b"main.fy"));
    assert(names::member_path(b"src/main.brc"));
    assert(names::member_path(b"A_b-9/N.x.fy"));
    assert(names::member_path(b"src/Upper-Case.File.fy"));
    var u8[240] maximum=[97;240];
    maximum[100]=47;maximum[237]=46;maximum[238]=102;maximum[239]=121;
    var u8[241] too_long=[97;241];
    too_long[100]=47;too_long[238]=46;too_long[239]=102;too_long[240]=121;
    assert(names::member_path(ref maximum));
    assert(!names::member_path(ref too_long));
    assert(!names::member_path(b"main.txt"));
    assert(!names::member_path(b"main.FY"));
    assert(!names::member_path(b"main.fy "));
    assert(names::member_path(b"src/main.fy"));
}

@test fn void member_paths_reject_traversal_alternate_streams_controls_and_wildcards(){
    assert(!names::member_path(b""));
    assert(!names::member_path(b"/main.fy"));
    assert(!names::member_path(b"//server/main.fy"));
    assert(!names::member_path(b"src//main.fy"));
    assert(!names::member_path(b"src/main.fy/"));
    assert(!names::member_path(b"./main.fy"));
    assert(!names::member_path(b"src/./main.fy"));
    assert(!names::member_path(b"../main.fy"));
    assert(!names::member_path(b"src/../main.fy"));
    assert(!names::member_path(b"src./main.fy"));
    assert(!names::member_path(b"dir../main.fy"));
    assert(!names::member_path(b"src/main.fy."));
    assert(!names::member_path(b"src\\main.fy"));
    assert(!names::member_path(b"C:/main.fy"));
    assert(!names::member_path(b"src:name/main.fy"));
    assert(!names::member_path(b"src/main.fy:stream"));
    assert(!names::member_path(b"src/main.fy::$DATA"));
    assert(!names::member_path(b"src/a b.fy"));
    assert(!names::member_path(b"src/a*.fy"));
    assert(!names::member_path(b"src/a?.fy"));
    assert(!names::member_path(b"src/a|b.fy"));
    assert(!names::member_path(b"src/a<b.fy"));
    assert(!names::member_path(b"src/a>b.fy"));
    assert(!names::member_path(b"src/a\x00.fy"));
    assert(!names::member_path(b"src/a\x01.fy"));
    assert(!names::member_path(b"src/a\x1f.fy"));
    assert(!names::member_path(b"src/a\x7f.fy"));
    assert(!names::member_path(b"src/a\x80.fy"));
    assert(!names::member_path(b"src/main.fyx"));
    assert(!names::member_path(b"src/main.brcx"));
}

@test fn void every_component_rejects_windows_devices_with_or_without_extensions(){
    assert(!names::member_path(b"CON.fy"));
    assert(!names::member_path(b"con.brc"));
    assert(!names::member_path(b"nUl.fy"));
    assert(!names::member_path(b"PRN.brc"));
    assert(!names::member_path(b"AUX.fy"));
    assert(!names::member_path(b"src/AUX.fy"));
    assert(!names::member_path(b"CON.tools/main.fy"));
    assert(!names::member_path(b"src/PRN.brc"));
    assert(!names::member_path(b"src/COM1.fy"));
    assert(!names::member_path(b"LPT9.fy"));
    assert(!names::member_path(b"COM9.tar.fy"));
    assert(!names::member_path(b"lpt1.copy.brc"));
    assert(names::member_path(b"COM0.fy"));
    assert(names::member_path(b"COM10.fy"));
    assert(names::member_path(b"LPT0.fy"));
    assert(names::member_path(b"LPT10.fy"));
    assert(names::member_path(b"console.fy"));
    assert(names::member_path(b"NULish.fy"));
    assert(names::member_path(b"AUXILIARY.brc"));
}

@test fn void same_path_folds_ascii_case_only_for_two_valid_member_paths(){
    assert(names::same_path(b"src/Main.fy",b"SRC/main.fy"));
    assert(names::same_path(b"Vendor/Lib.brc",b"vendor/lib.brc"));
    assert(!names::same_path(b"src/main.fy",b"src/main.brc"));
    assert(!names::same_path(b"src/A.fy",b"src/aa.fy"));
    assert(!names::same_path(b"src/main.fy",b"src/maim.fy"));
    assert(!names::same_path(b"src/main.fy",b"src/main.FY"));
    assert(!names::same_path(b"",b""));
    assert(!names::same_path(b"../main.fy",b"../MAIN.fy"));
}
