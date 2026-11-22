"""Build and run the Windows AppContainer and Job launcher fixture."""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HELLO_PROJECT = ROOT / 'examples/projects/hello'
POLICY_EXAMPLE = ROOT / 'examples/projects/configured-output/policy.json'


def write_compile_fixture(path, target, manifest, policy=None, config=None, imports=b''):
    files = [(target / entry['path']).read_bytes() for entry in manifest['sources']]
    documents = (manifest,) if config is None else (manifest, policy, config)
    sections = [json.dumps(value).encode('utf-8') for value in documents]
    mode = 3 if config is None else 8 if imports else 5
    fuel = 256 if config is None else config['limits']['fuel']
    prefix = bytes([mode]) + fuel.to_bytes(4, 'little')
    prefix += b''.join(len(section).to_bytes(4, 'little') for section in sections)
    if imports:
        prefix += bytes(4) + len(imports).to_bytes(4, 'little')
    path.write_bytes(prefix + b''.join(sections) + imports +
                     b''.join(len(file).to_bytes(2, 'little') for file in files) + b''.join(files))


def verify_managed_project(run, need, image, folder, env):
    target = folder / 'hello'
    shutil.copytree(HELLO_PROJECT, target)
    project = target / 'project.json'
    project_arg = project.relative_to(folder)
    original = project.read_bytes()
    write_compile_fixture(folder / 'managed-compile.start', target, json.loads(original))
    # Exercise multiple stream windows using an otherwise unchanged manifest.
    project.write_bytes(original + b' ' * 5200)
    for op, status, value in [('check', 'checked', None), ('run', 'completed', 42)]:
        result = json.loads(run([image, '--internal-project-broker', op, project_arg],
                                cwd=folder, env=env, no_stderr=True))
        need(result == dict(schema='browniec.result/v2', profile='brownie.m1-scalar/1',
                            command=op, status=status, return_i32=value, error=None),
             f'Unexpected isolated project outcome: {result}')

    math = target / 'src/math.brc'
    math.write_bytes(math.read_bytes().replace(b'return 42;', b'return missing;'))
    fixture = [image, 'check', '--project', project_arg, '--json-v2']
    expected = json.loads(run(fixture, cwd=folder, env=env, expected_exit=3, no_stderr=True))
    observed = json.loads(run([image, '--internal-project-broker', 'check', project_arg],
                              cwd=folder, env=env, expected_exit=3, no_stderr=True))
    location = observed['error']['location']
    need(observed == expected and location['source_index'] == 1 and location['path'] == 'src/math.brc',
         f'Isolated project diagnostic did not preserve the second source: {observed}')

    manifest = json.loads(original)
    manifest['requires'] = ['quote.lookup']
    project.write_text(json.dumps(manifest), encoding='utf-8')
    math.unlink()
    denied = json.loads(run([image, '--internal-project-broker', 'run', project_arg],
                            cwd=folder, env=env, expected_exit=4, no_stderr=True))
    need(denied['error']['kind'] == 'unavailable' and denied['return_i32'] is None,
         f'An ungranted requirement reached project source acquisition or execution: {denied}')
    run([image, '--internal-project-worker'], cwd=folder, env=env, expected_exit=4, silent=True)
    need(not list(Path(env['TEMP']).iterdir()), 'project runs left staged resources')
    return 5


def verify_configured_project(run, need, image, folder, env):
    target = folder / 'configured'
    shutil.copytree(HELLO_PROJECT, target)
    project = target / 'project.json'
    policy_file = target / 'policy.json'
    run_file = target / 'run.json'
    manifest = json.loads(project.read_bytes())
    policy = json.loads(POLICY_EXAMPLE.read_bytes())
    policy['compile']['source_bytes'] = sum((target / s['path']).stat().st_size for s in manifest['sources'])
    policy['compile']['modules'] = len(manifest['sources'])
    config = dict(schema='brownie.run/0.3', entry=manifest['entry'].copy(),
                  requires=[], grants=[], limits=policy['run'].copy())
    write_compile_fixture(folder / 'configured-compile.start', target, manifest, policy, config)

    cases = 0

    def check(expected_exit=0, kind=None, operation='run', payload=None, value=42, output=None):
        nonlocal cases
        policy_file.write_text(json.dumps(policy), encoding='utf-8')
        run_file.write_text(json.dumps(config), encoding='utf-8')
        args = [image, '--internal-project-broker', operation, project, policy_file, run_file]
        if payload is not None:
            args.append(payload)
        data = json.loads(run(args, cwd=folder, env=env, expected_exit=expected_exit, no_stderr=True))
        status = 'checked' if operation == 'check' else 'completed'
        expected = value if operation == 'run' else None
        need(data['schema'] == 'browniec.result/v2' and data['command'] == operation and
             (data['error']['kind'] == kind and data['return_i32'] is None if kind else
              data['status'] == status and data['return_i32'] == expected and data['error'] is None),
             f'Unexpected configured project result: {data}')
        if output is None:
            need('output_b64' not in data, f'Unexpected guest output: {data}')
        else:
            need(base64.b64decode(data['output_b64'], validate=True) == output,
                 'Guest output differs from the sealed payload')
        need(not list(Path(env['TEMP']).iterdir()), 'configured project left staged resources')
        cases += 1
        return data

    check()
    policy['compile']['source_bytes'] -= 1
    check(3, 'compile_limit')
    policy['compile']['source_bytes'] += 1
    config['limits']['fuel'] = 1
    check(5, 'fuel')
    config['limits']['fuel'] = policy['run']['fuel'] + 1
    check(4, 'unavailable')
    config['limits']['fuel'] = policy['run']['fuel']

    working = policy['compile']['working_bytes']
    policy['compile']['working_bytes'] = policy['compile']['source_bytes']
    check(3, 'compile_limit')
    policy['compile']['working_bytes'] = working

    compile_defaults = policy['compile'].copy()
    # Indexing prepays each source byte and one unit per scanner advance,
    # including each file's EOF. There are 44 non-EOF tokens in two files.
    index_fuel = policy['compile']['source_bytes'] + 44 + len(manifest['sources'])
    policy['compile']['fuel'] = index_fuel
    before_lowering = check(3, 'compile_limit', 'check')['error']
    need(before_lowering['location']['kind'] == 'none',
         f'Exact index Fuel should reach the lowering gate: {before_lowering}')
    policy['compile']['fuel'] = index_fuel - 1
    fuel_error = check(3, 'compile_limit', 'check')['error']
    need(fuel_error['location']['source_index'] == 1,
         f'Index Fuel reset between source members: {fuel_error}')
    # 863 prepaid batches after the 179-unit index, including independent proof,
    # plus 151 semantic transitions and two 16-row literal catalog passes.
    proof_fuel = index_fuel + 863 * 4096 + 151 + 32
    policy['compile']['fuel'] = proof_fuel
    preparation_error = check(3, 'compile_limit', 'check')['error']
    need(preparation_error['location']['kind'] == 'none',
         f'Exact proof Fuel should reach execution preparation: {preparation_error}')
    # Four instructions, visited by two place scans, the capture plan scan,
    # and the output-authority walk from the selected entry.
    scratch_fuel = proof_fuel + 2 * 4
    policy['compile']['fuel'] = scratch_fuel
    check(3, 'compile_limit', 'check')
    capture_fuel = scratch_fuel + 4
    policy['compile']['fuel'] = capture_fuel
    check(3, 'compile_limit', 'check')
    full_fuel = capture_fuel + 4
    policy['compile']['fuel'] = full_fuel - 1
    check(3, 'compile_limit')
    policy['compile']['fuel'] = full_fuel
    check()
    policy['compile']['types'] = 1
    policy['compile']['fuel'] = full_fuel + 4095
    check(3, 'compile_limit')
    policy['compile']['fuel'] = full_fuel + 4096
    check()
    policy['compile']['types'] = compile_defaults['types']
    policy['compile']['fuel'] = compile_defaults['fuel']

    # The two original hello files have 27 and 17 lexer tokens, excluding EOF.
    policy['compile'].update(tokens=44, functions=2)
    check()
    policy['compile']['tokens'] = 43
    check(3, 'compile_limit')
    policy['compile']['tokens'] = 44
    policy['compile']['functions'] = 1
    check(3, 'compile_limit')
    policy['compile'] = compile_defaults.copy()
    policy['compile']['instructions'] = 1
    check(3, 'compile_limit', 'check')
    policy['compile'] = compile_defaults.copy()

    math_file = target / 'src/math.brc'
    original_source = math_file.read_bytes()
    math_file.write_bytes(b'module util::math;pub fn i32 answer(){let i32 price=20+22;return price;}')
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=3944712 + 208 - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] += 1
    check()
    policy['compile'] = compile_defaults.copy()
    math_file.write_text(
        'module util::math;\nstruct One { i32 value; }\nstruct Two { i32 value; }\n'
        'pub fn i32 answer(){var i32 n=40; n+=2; return n;}\n', encoding='utf-8')
    policy['compile'].update(source_bytes=4096, types=3)
    check()
    policy['compile']['types'] = 2
    check(3, 'compile_limit')
    policy['compile']['types'] = 1
    check(3, 'compile_limit')
    policy['compile']['types'] = 3
    policy['compile']['registers_per_function'] = 1
    check(3, 'compile_limit')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    policy['compile'] = dict(compile_defaults, types=1)
    check()
    math_file.write_bytes(b'module util::math;pub fn i32 answer(){'
                          b'let Result<i32,bool> r=.ok(42);return 42;}')
    policy['compile'] = dict(compile_defaults, source_bytes=4096, types=3)
    check()
    policy['compile']['types'] = 2
    check(3, 'compile_limit', 'check')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    repeated_array = (b'module util::math;pub fn i32 answer(){'
                      b'let a=[42];var i32[1] b=[2];')
    arrays = ((repeated_array, 2),
              (repeated_array + b'let i32[2] c=[1,2];let bool[1] d=[false];', 5))
    for declarations, required in arrays:
        math_file.write_bytes(declarations + b'return 42;}')
        policy['compile'] = dict(compile_defaults, source_bytes=4096, types=required)
        check()
        policy['compile']['types'] = required - 1
        check(3, 'compile_limit', 'check')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    nested_source = (b'module util::math;\npub fn i32 answer(){var i32 n=40;'
                     b' /* [{( */ { n += (2); } { n += 0; } return n;}\n')
    math_file.write_bytes(nested_source)
    policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=2)
    check()
    policy['compile']['depth'] = 1
    location = check(3, 'compile_limit', 'check')['error']['location']
    offset = nested_source.index(b'(2)')
    need(location['source_index'] == 1 and location['path'] == 'src/math.brc' and
         location['offset'] == offset and location['end_offset'] == offset + 1,
         f'Unexpected nesting limit location: {location}')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    unary_source = b'module util::math;pub fn i32 answer(){return ~ ~ 42;}'
    math_file.write_bytes(unary_source)
    policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=2)
    check()
    policy['compile']['depth'] = 1
    location = check(3, 'compile_limit', 'check')['error']['location']
    offset = unary_source.index(b'42')
    need(location['source_index'] == 1 and location['offset'] == offset and
         location['end_offset'] == offset + 1,
         f'Unexpected semantic expression depth location: {location}')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    branch_chain = (b'module util::math;pub fn i32 answer(){if(false){return 0;}'
                    b'else if(false){return 1;}else if(true){return 42;}return 3;}')
    math_file.write_bytes(branch_chain)
    policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=3)
    check()
    policy['compile']['depth'] = 2
    location = check(3, 'compile_limit', 'check')['error']['location']
    offset = branch_chain.index(b'{return 42;}')
    need(location['source_index'] == 1 and location['path'] == 'src/math.brc' and
         location['offset'] == offset and location['end_offset'] == offset + 1,
         f'Unexpected control depth location: {location}')
    math_file.write_bytes(b'module util::math;pub fn i32 answer(){var i32 n=0;'
                         b'while(n<2){n+=1;}for(;n<4;n+=1){}'
                         b'if(n==4 && (n+1)==5){let Option<i32> pick=.some(42);'
                         b'switch(pick){case .some(v):{return v;}case .none:{return 0;}}}return 0;}')
    # 242 control Pratt advances and 42 assignment Pratt advances, plus two
    # post passes and a rewind of three registers and four 8-byte instructions.
    control_fuel = 9069509 + 242 + 42 + 2 + 3 + 4 * 8
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=control_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = control_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    math_file.write_bytes(b'module util::math;pub fn i32 answer(){'
                          b'let i32 n=(if(true){var i32 a=30;a+=5;a+7}else{0});'
                          b'let Option<i32> pick=.some(n);'
                          b'return switch(pick){case .some(v):{v}case .none:{0}};}')
    # The shared balance now covers the nested value and statement continuations.
    value_arm_fuel = 6968500 + 477
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=value_arm_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = value_arm_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    math_file.write_bytes(b'module util::math;struct Pair{i32 value;}pub fn i32 answer(){'
                          b'var a=[10,20];a[0+1]+=1+1;((a)[1])+=1+1;'
                          b'{let ref mut i32[] view=ref mut a;view[0+1]+=2+2;}'
                          b'var Pair p=Pair{.value=10};p.value+=1+1;((p).value)+=1+1;'
                          b'return a[1]+p.value;}')
    # Eight operands and both record targets add Pratt and path advances.
    place_fuel = 10232871 + 245 + 167
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=place_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = place_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    math_file.write_bytes(b'module util::math;pub fn i32 answer(){var a=[0,0];'
                          b'a=[5+5,2+4];((a))=([a[0]+6,a[1]+4]);'
                          b'var b=[0,0];b=([a[0]+a[1]-5;2]);'
                          b'return b[0]+b[1];}')
    # Literal classification, five operands and two list-pool passes add 494 units.
    array_assignment_fuel = 8459031 + 494
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=array_assignment_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = array_assignment_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    math_file.write_bytes(b'module util::math;struct Inner{i32 value;}'
                          b'struct Outer{Inner child;i32 extra;}pub fn i32 answer(){'
                          b'var Outer p=Outer{.child=Inner{.value=0},.extra=0};'
                          b'p=Outer{.child=(Inner{.value=12+5}),.extra=4+3};'
                          b'((p).child)=Inner{.value=p.child.value+18};'
                          b'let Outer q=p;p.child=(q).child;'
                          b'return p.child.value+p.extra;}')
    # Grouped destination, plain destination and aggregate source paths.
    record_assignment_fuel = 9688554 + 274 + 10
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=record_assignment_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = record_assignment_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    math_file.write_bytes(b'module util::math;struct Pair{i32 value;}'
                          b'fn i32[1] spread(i32 x,i32 y){return [x+y];}'
                          b'fn Pair pair(i32[1] a,i32 extra){return Pair{.value=a[0]+extra};}'
                          b'pub fn i32 answer(){var a=[0];'
                          b'a=spread(2*3,3+3);a=(spread(a[0],2*3));'
                          b'var Pair p=Pair{.value=0};p=pair(a,4+2);'
                          b'return a[0]+p.value;}')
    # Captured CALL and scalar argument advances share the compile balance.
    aggregate_call_fuel = 12055640 + 224 + 13
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=aggregate_call_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = aggregate_call_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    math_file.write_bytes(b'module util::math;struct Box{i32 value;}'
                          b'fn i32[1] gather(Box box,i32[1] a,i32[2] b,ref i32[] view){'
                          b'return [box.value+a[0]+b[1]+view[0]];}'
                          b'pub fn i32 answer(){var out=[0];let input=[13,0];'
                          b'out=gather(Box{.value=4+6},[3+5],[7+4;2],ref input[0+0..1+0]);'
                          b'return out[0];}')
    # Constructor, array literal and slice endpoint preparation use the caller's balance.
    aggregate_actual_fuel = 11138028 + 344 + 8
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=aggregate_actual_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = aggregate_actual_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    math_file.write_bytes(b'module util::math;struct Box{i32 value;}'
                          b'fn i32[1] sum(i32[1] base,i32[1] a,Box box){'
                          b'return [base[0]+a[0]+box.value];}'
                          b'pub fn i32 answer(){let base=[10];var a=[12];'
                          b'var Box box=Box{.value=20};var out=[0];'
                          b'out=sum(((base)),a,(box));return out[0];}')
    # Grouped immutable lookup and mutable array and record snapshots.
    owner_capture_fuel = 9819007 + 40
    policy['compile'] = dict(compile_defaults, source_bytes=4096, fuel=owner_capture_fuel - 1)
    check(3, 'compile_limit')
    policy['compile']['fuel'] = owner_capture_fuel
    check()
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    aggregate_projections = (
        (b'module util::math;pub fn i32 answer(){let i32[1] a=[42];'
         b'let usize n= ~ ~ (a).len;if(n==1){return 42;}return 0;}', b'(a).len'),
        (b'module util::math;struct Box{i32 value;}pub fn i32 answer(){'
         b'let Box r=Box{.value=42};return ~ ~ (r).value;}', b'(r).value'),
    )
    for aggregate_source, grouped in aggregate_projections:
        math_file.write_bytes(aggregate_source)
        policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=3)
        check()
        policy['compile']['depth'] = 2
        location = check(3, 'compile_limit', 'check')['error']['location']
        offset = aggregate_source.index(grouped)
        need(location['source_index'] == 1 and location['offset'] == offset and
             location['end_offset'] == offset + 1,
             f'Unexpected grouped aggregate depth location: {location}')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    nested_records = (b'module util::math;struct Outer{Inner item;}'
                      b'struct Inner{i32 value;}pub fn i32 answer(){return 42;}')
    math_file.write_bytes(nested_records)
    policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=2)
    check()
    policy['compile']['depth'] = 1
    location = check(3, 'compile_limit', 'check')['error']['location']
    offset = nested_records.index(b'Outer')
    need(location['source_index'] == 1 and location['path'] == 'src/math.brc' and
         location['offset'] == offset and location['end_offset'] == offset + 1,
         f'Unexpected record depth location: {location}')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    compound_signatures = (
        (b'fn Option<i32> helper(){return .none;}', b'Option'),
        (b'fn Result<i32,bool> helper(){return .ok(42);}', b'Result'),
        (b'fn i32 helper(i32[1] items){return items[0];}', b'i32[1]'),
    )
    for signature, start in compound_signatures:
        typed_source = original_source + signature
        math_file.write_bytes(typed_source)
        policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=2)
        check()
        policy['compile']['depth'] = 1
        location = check(3, 'compile_limit', 'check')['error']['location']
        offset = typed_source.index(start)
        need(location['source_index'] == 1 and location['offset'] == offset and
             location['end_offset'] == offset + 1,
             f'Unexpected signature depth location: {location}')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    compound_locals = (
        (b'let Option<i32> choice=.none;return 42;', b'Option'),
        (b'let Result<i32,bool> result=.ok(42);return 42;', b'Result'),
        (b'let i32[1] items=[42];return items[0];', b'i32[1]'),
        (b'let ref u8[] marker=b"42";return 42;', b'ref u8[]'),
    )
    for body, start in compound_locals:
        typed_source = b'module util::math;pub fn i32 answer(){' + body + b'}'
        math_file.write_bytes(typed_source)
        policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=2)
        check()
        policy['compile']['depth'] = 1
        location = check(3, 'compile_limit', 'check')['error']['location']
        offset = typed_source.index(start)
        need(location['source_index'] == 1 and location['offset'] == offset and
             location['end_offset'] == offset + 1,
             f'Unexpected local annotation depth location: {location}')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    view_types = (
        (b'let ref u8[] a=b"42";let ref u8[] b=b"0";', 3),
        (b'let ref u8[] a=b"42";let ref str b="0";', 4),
        # The slice bounds also materialize usize registers.
        (b'var i32[1] a=[42];{let ref i32[] s=ref a;}let ref mut i32[] m=ref mut a;', 5),
    )
    for declarations, required in view_types:
        math_file.write_bytes(b'module util::math;pub fn i32 answer(){' + declarations + b'return 42;}')
        policy['compile'] = dict(compile_defaults, source_bytes=4096, types=required)
        check()
        policy['compile']['types'] = required - 1
        check(3, 'compile_limit', 'check')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    runtime = config['limits'].copy()
    config['limits'].update(memory_bytes=1, object_bytes=1, input_bytes=0, output_bytes=0,
                            host_request_bytes=1, host_response_bytes=1)
    check(5, 'memory_limit')
    config['limits'] = runtime

    math_file.write_text('module util::math;\npub fn i32 answer(){var i32 n=0;'
                         'while(n<2000000000){n+=1;}return n;}\n', encoding='utf-8')
    initial_source_limit = policy['compile']['source_bytes']
    policy['compile']['source_bytes'] = 4096
    config['limits']['deadline_ms'] = 1
    check(5, 'deadline')
    config['limits']['deadline_ms'] = policy['run']['deadline_ms']
    policy['compile']['source_bytes'] = initial_source_limit
    math_file.write_bytes(original_source)

    entry = target / 'src/main.brc'
    original_entry = entry.read_bytes()
    payload = target / 'guest.bin'
    payload.write_bytes(bytes(8192) + bytes([255]))
    check(4, 'unavailable', payload=payload)
    entry.write_bytes(b'module app; pub fn i32 start(ref u8[] data){'
                      b'if(data.len==0){return 0;}return data[data.len-1] as i32;}')
    source_limit = policy['compile']['source_bytes']
    input_limit = config['limits']['input_bytes']
    policy['compile']['source_bytes'] = 4096
    config['limits']['input_bytes'] = 8193
    depth = policy['compile']['depth']
    policy['compile']['depth'] = 2
    check(payload=payload, value=255)
    policy['compile']['depth'] = 1
    location = check(3, 'compile_limit', 'check')['error']['location']
    offset = entry.read_bytes().index(b'ref u8[]')
    need(location['source_index'] == 0 and location['offset'] == offset and
         location['end_offset'] == offset + 1,
         f'Unexpected shared slice signature depth location: {location}')
    policy['compile']['depth'] = depth
    config['limits']['input_bytes'] = 8192
    check(5, 'input_limit', payload=payload)
    config['limits']['input_bytes'] = input_limit
    check(operation='check')
    check(4, 'unavailable')
    check(2, 'usage', operation='check', payload=payload)
    instruction_limit = policy['compile']['instructions']
    policy['compile']['instructions'] = 1
    check(3, 'compile_limit', operation='check')
    policy['compile']['instructions'] = instruction_limit
    payload.write_bytes(bytes(1048575) + bytes([77]))
    check(payload=payload, value=77)
    payload.write_bytes(b'')
    check(payload=payload, value=0)
    entry.write_bytes(b'module app;pub fn i32 start(ref u8[] data){'
                      b'let ref u8[] marker=b"42";return 42;}')
    type_limit = policy['compile']['types']
    policy['compile']['types'] = 3
    check(payload=payload)
    policy['compile']['types'] = 2
    check(3, 'compile_limit', 'check')
    policy['compile']['types'] = type_limit
    entry.write_bytes(original_entry)
    policy['compile']['source_bytes'] = source_limit

    output_cap = ['brownie.output.emit']
    binary = bytes(8192) + bytes([255])
    payload.write_bytes(binary)
    policy['compile']['source_bytes'] = 4096
    entry.write_bytes(b'module app; pub fn i32 start(ref u8[] data){output::emit(ref data);return 77;}')
    check(4, 'unavailable', payload=payload)
    manifest['requires'] = output_cap
    project.write_text(json.dumps(manifest), encoding='utf-8')
    config['requires'] = output_cap
    check(4, 'unavailable', payload=payload)
    config['grants'] = output_cap
    check(operation='check')
    config['limits']['output_bytes'] = len(binary)
    check(payload=payload, value=77, output=binary)
    config['limits']['output_bytes'] -= 1
    check(5, 'output_limit', payload=payload)
    config['limits']['output_bytes'] = policy['run']['output_bytes']
    entry.write_bytes(b'module app; pub fn i32 start(ref u8[] data){output::emit(ref data);'
                      b'var i32 zero=0; return 1/zero;}')
    check(5, 'zero_divisor', payload=payload)
    entry.write_bytes(b'module app; pub fn i32 start(){output::emit(ref b"Hi");return 77;}')
    check(value=77, output=b'Hi')
    entry.write_bytes(b'module app;pub fn i32 start(){let u8[5] data=[65,66,67,68,69];'
                      b'output::emit(ref data[1+1..4-1]);return 77;}')
    # The statement adds 14 token/emission units and 97 slice and operand advances.
    range_fuel = 5005760 + 14 + 97
    policy['compile']['fuel'] = range_fuel - 1
    check(3, 'compile_limit')
    policy['compile']['fuel'] = range_fuel
    check(value=77, output=b'C')
    text = b'A' * 255 + bytes.fromhex('f0908080') + b'Z'
    entry.write_bytes(b'module app;pub fn i32 start(){let ref str msg="' + text +
                      b'";let ref u8[] body=text::bytes(msg);output::emit(ref body);return 77;}')
    # The prior compiler needed 4,780,555 units. Admission now charges two
    # 16-row catalog scans, one literal row and two visits to each text byte.
    # The emit statement spends 13 token stages and one unit before IR emission.
    # The named static view adds two three-stage lookups and two token stages.
    text_fuel = 4780555 + 95 + 32 + 1 + 2 * len(text) + 14 + 8
    policy['compile']['fuel'] = text_fuel - 1
    check(3, 'compile_limit')
    policy['compile']['fuel'] = text_fuel
    check(value=77, output=text)
    entry.write_bytes(b'module app;pub fn i32 start(){'
                      b'output::emit(ref (text::bytes("ABCDE"))[1+1..4-1]);return 77;}')
    static_range_fuel = 4571541 + 128
    policy['compile']['fuel'] = static_range_fuel - 1
    check(3, 'compile_limit')
    policy['compile']['fuel'] = static_range_fuel
    check(value=77, output=b'C')
    policy['compile']['fuel'] = compile_defaults['fuel']
    entry.write_bytes(original_entry)
    policy['compile']['source_bytes'] = source_limit
    manifest['requires'] = config['requires'] = config['grants'] = []
    project.write_text(json.dumps(manifest), encoding='utf-8')

    baseline = policy['worker'].copy()
    policy['worker'].update(startup_ms=1, session_ms=1)
    policy['compile']['deadline_ms'] = policy['run']['deadline_ms'] = config['limits']['deadline_ms'] = 1
    check(5, 'deadline')
    policy['worker'] = baseline

    (target / 'src/math.brc').unlink()
    policy['compile']['modules'] -= 1
    check(3, 'compile_limit')
    policy['compile']['modules'] += 1
    config['entry']['function'] = 'other'
    check(4, 'unavailable')
    config['entry']['function'] = manifest['entry']['function']
    config['grants'] = ['brownie.output.emit']
    check(4, 'unavailable')
    return cases


def verify_project_host(run, need, image, folder, env):
    target = folder / 'catalog-project'
    shutil.copytree(HELLO_PROJECT, target)
    project = target / 'project.json'
    policy_file = target / 'policy.json'
    config_file = target / 'run.json'
    catalog_file = target / 'catalog.json'
    replies_file = target / 'replies.json'
    source = target / 'src/main.brc'
    manifest = json.loads(project.read_bytes())
    cap = 'host.example.check'
    manifest['requires'] = ['brownie.output.emit', cap]
    policy = json.loads(POLICY_EXAMPLE.read_bytes())
    policy['capabilities'] = manifest['requires']
    config = dict(schema='brownie.run/0.3', entry=manifest['entry'],
                  requires=manifest['requires'], grants=manifest['requires'],
                  limits=policy['run'] | dict(host_calls=2, host_request_bytes=14, host_response_bytes=12))
    entry = dict(id=0, module='host::example', symbol='check', parameters=['i32'],
                 result='Result<i32,u32>', effect='read', capability=cap, adapter_revision='v1')

    def u32(value):
        return value.to_bytes(4, 'little')

    def field(value):
        return u32(len(value)) + value.encode('ascii')

    canonical = (b'BRC-CATALOG-1\n' + u32(1) + u32(0) +
                 b''.join(field(entry[key]) for key in
                          ('module', 'symbol', 'result', 'effect', 'capability', 'adapter_revision')) +
                 u32(1) + field('i32'))
    imports = [entry]
    catalog_file.write_text(json.dumps(dict(schema='brownie.catalog/1', imports=imports)), encoding='utf-8')
    rows = [dict(import_id=0, kind=0,
                 request_hex=(bytes.fromhex('01000300000004000000') + u32(arg)).hex(),
                 reply_hex=(bytes.fromhex('0300000004000000') + u32(value)).hex())
            for arg, value in [(41, 42), (42, 35)]]
    replies = dict(schema='brownie.host-replies/1',
                   catalog_sha256=hashlib.sha256(canonical).hexdigest(), replies=rows)
    source.write_bytes(b'module app; import host::example as api; pub fn i32 start(){'
                       b'output::emit(b"before"); let i32 a=api::check(41);'
                       b'return a+api::check(42);}')
    write_compile_fixture(folder / 'catalog-compile.start', target, manifest, policy, config,
                          catalog_file.read_bytes())

    def check(operation='run', expected_exit=0, kind=None, payload=None, expected_value=77):
        for path, value in ((project, manifest), (policy_file, policy), (config_file, config),
                            (replies_file, replies)):
            path.write_text(json.dumps(value), encoding='utf-8')
        args = [image, '--internal-project-host-broker', operation, project, policy_file,
                config_file, catalog_file]
        if operation == 'run':
            args.append(replies_file)
        if payload is not None:
            args.append(payload)
        data = json.loads(run(args, cwd=folder, env=env, expected_exit=expected_exit, no_stderr=True))
        need(data['schema'] == 'browniec.result/v2' and data['command'] == operation,
             f'Unexpected catalog project response: {data}')
        if kind:
            need(data['error']['kind'] == kind and data['return_i32'] is None and 'output_b64' not in data,
                 f'Catalog project published a failed result: {data}')
        elif operation == 'run':
            need(data['status'] == 'completed' and data['return_i32'] == expected_value and data['error'] is None
                 and base64.b64decode(data['output_b64'], validate=True) == b'before',
                 f'Catalog project failed to resume and seal its output: {data}')
        else:
            need(data['status'] == 'checked' and data['error'] is None and 'output_b64' not in data,
                 f'Catalog project check executed or failed: {data}')
        need(not list(Path(env['TEMP']).iterdir()), 'catalog project left staged resources')

    check('check')
    policy['compile']['types'] = 3
    check()
    policy['compile']['types'] = 2
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['types'] = 3
    unused = entry | dict(id=1, symbol='unused', parameters=['bool'], result='Result<i64,u32>')
    imports.append(unused)
    catalog_file.write_text(json.dumps(dict(schema='brownie.catalog/1', imports=imports)), encoding='utf-8')
    check('check')
    imports.pop()
    catalog_file.write_text(json.dumps(dict(schema='brownie.catalog/1', imports=imports)), encoding='utf-8')
    policy['compile']['types'] = 4096
    original_source = source.read_bytes()
    source.write_bytes(original_source.replace(b'return a+', b'return - - a+'))
    original_depth = policy['compile']['depth']
    policy['compile']['depth'] = 2
    check()
    policy['compile']['depth'] = 1
    check(expected_exit=3, kind='compile_limit')
    branch_chain = (b'if(false){return 0;}else if(false){return 1;}'
                    b'else if(false){return 2;}')
    source.write_bytes(original_source.replace(b'return a+', branch_chain + b'return a+'))
    policy['compile']['depth'] = 3
    check()
    policy['compile']['depth'] = 2
    check(expected_exit=3, kind='compile_limit')
    math = target / 'src/math.brc'
    original_math = math.read_bytes()
    math.write_bytes(original_math + b'struct Inner{i32 value;}struct Outer{Inner item;}')
    source.write_bytes(original_source)
    policy['compile']['depth'] = 2
    check()
    policy['compile']['depth'] = 1
    check(expected_exit=3, kind='compile_limit')
    math.write_bytes(original_math)
    source.write_bytes(original_source.replace(
        b'let i32 a=api::check(41);',
        b'let Result<i32,u32> reply=api::check(41);'
        b'let i32 a=switch(reply){case .ok(value):{value}case .err(_):{0}};'))
    policy['compile']['depth'] = 2
    # The saved Result's branch test also materializes a bool register.
    policy['compile']['types'] = 4
    check()
    policy['compile']['types'] = 3
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['types'] = 4096
    policy['compile']['depth'] = 1
    check(expected_exit=3, kind='compile_limit')
    source.write_bytes(original_source)
    policy['compile']['depth'] = original_depth
    replies['replies'] = rows[:1]
    check(expected_exit=4, kind='unavailable')
    replies['replies'] = rows
    config['grants'] = ['brownie.output.emit']
    check(expected_exit=4, kind='unavailable')
    config['grants'] = [cap]
    check('check', expected_exit=4, kind='unavailable')
    config['grants'] = manifest['requires']
    config['limits']['host_calls'] = 1
    check(expected_exit=5, kind='allocation')
    config['limits']['host_calls'] = 2
    config['limits']['host_request_bytes'] = 13
    check(expected_exit=5, kind='allocation')
    config['limits']['host_request_bytes'] = 14
    config['limits']['host_response_bytes'] = 11
    check(expected_exit=4, kind='unavailable')
    config['limits']['host_response_bytes'] = 12
    original_digest = replies['catalog_sha256']
    replies['catalog_sha256'] = '00' * 32
    check(expected_exit=2, kind='usage')
    replies['catalog_sha256'] = original_digest
    policy['compile']['instructions'] = 1
    check('check', expected_exit=3, kind='compile_limit')
    policy['compile']['instructions'] = 262144
    original_compile_fuel = policy['compile']['fuel']
    policy['compile']['fuel'] = 1
    check('check', expected_exit=3, kind='compile_limit')
    # The 401 lowering batches leave no Fuel for the independent proof.
    # The literal emit spends 15 token stages and two IR emission units.
    # The raw declaration and return expressions spend another 12 units.
    # Host names, scalar argument lowering and argument packing add 54 units.
    # Host index token advances add 152 units.
    # Import rows, aliases and name comparisons add 36 units.
    lowering_fuel = 255 + 401 * 4096 + 17 + 12 + 54 + 152 + 36
    policy['compile']['fuel'] = lowering_fuel
    check('check', expected_exit=3, kind='compile_limit')
    # Verification itself needs 28 more batches from the same balance.
    full_fuel = lowering_fuel + 28 * 4096
    policy['compile']['fuel'] = full_fuel - 1
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['fuel'] = full_fuel
    check('check')
    check()
    policy['compile']['types'] = 3
    policy['compile']['fuel'] = full_fuel + 4095
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['fuel'] = full_fuel + 4096
    check()
    policy['compile']['types'] = 4096
    policy['compile']['fuel'] = original_compile_fuel
    payload = target / 'input.bin'
    payload.write_bytes(b'before')
    source.write_bytes(b'module app; import host::example as api; pub fn i32 start(ref u8[] data){'
                       b'output::emit(ref data); let i32 a=api::check(41); return a+api::check(42);}')
    policy['compile']['depth'] = 2
    policy['compile']['types'] = 5
    check(payload=payload)
    policy['compile']['types'] = 4
    check(expected_exit=3, kind='compile_limit', payload=payload)
    policy['compile']['types'] = 4096
    policy['compile']['depth'] = 1
    check(expected_exit=3, kind='compile_limit', payload=payload)
    policy['compile']['depth'] = original_depth
    check(expected_exit=4, kind='unavailable')
    source.write_bytes(b'module app; import host::example as api; pub fn i32 start(ref u8[] data){'
                       b'{output::emit(ref data);} let i32 a=api::check(41); return a+api::check(42);}')
    # The nested emit spends 14 token stages, two lookup stages and one IR unit.
    nested_fuel = 1892630 + 17 + 12 + 55 + 10 + 164 + 43
    policy['compile']['fuel'] = nested_fuel - 1
    check(expected_exit=3, kind='compile_limit', payload=payload)
    policy['compile']['fuel'] = nested_fuel
    check(payload=payload)
    source.write_bytes(b'module app; import host::example as api; pub fn i32 start(){'
                       b'output::emit(b"before");let Result<i32,u32> reply=api::check(41);'
                       b'let i32 a=(if(true){switch(reply){case .ok(v):{v}case .err(_):{0}}}else{0});'
                       b'return a+switch(api::check(42)){case .ok(v):{v}case .err(_):{0}};}')
    arm_fuel = 3232221 + 487 + 55 + 4 + 298 + 66
    policy['compile']['fuel'] = arm_fuel - 1
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['fuel'] = arm_fuel
    check()
    source.write_bytes(b'module app; import host::example as api; pub fn i32 start(){'
                       b'output::emit(b"before");let Result<i32,u32> reply=api::check(41);'
                       b'var i32 a=0;switch(reply){case .ok(v):{a=v;}case .err(_):{return 0;}}'
                       b'switch(api::check(42)){case .ok(v):{return a+v;}case .err(e):{return 0;}}}')
    statement_fuel = 3_121_699 + 141 + 290 + 66
    policy['compile']['fuel'] = statement_fuel - 1
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['fuel'] = statement_fuel
    check()
    replies['replies'] = [rows[0], rows[1] | dict(kind=1, reply_hex='050000000400000001000000')]
    check(expected_value=0)
    replies['replies'] = rows
    source.write_bytes(original_source.replace(
        b'api::check(41)', b'api /*' + b'x' * 192 + b'*/ ::check(41)'))
    index_fuel = 1_819_172 + 164 + 36
    policy['compile']['fuel'] = index_fuel - 1
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['fuel'] = index_fuel
    check()
    alias = b'catalog_' + b'a' * 56
    source.write_bytes(original_source.replace(b' as api;', b' as ' + alias + b';')
                       .replace(b'api::check(41)', alias + b'::check(41)')
                       .replace(b'api::check(42)', b'host /* scope */ :: example::check(42)'))
    binding_fuel = 1_794_714 + 44
    policy['compile']['fuel'] = binding_fuel - 1
    check(expected_exit=3, kind='compile_limit')
    policy['compile']['fuel'] = binding_fuel
    check()
    return 43


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scalar-images', type=Path,
                        help='directory containing locked development/browniec.exe and release/browniec.exe')
    args = parser.parse_args()
    scalar_images = args.scalar_images.resolve() if args.scalar_images else None
    spec = importlib.util.spec_from_file_location('probe', ROOT / 'tools/verify-runtime-store-probe.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper.need(os.name == 'nt' and not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ),
                'Windows required with no compiler or linker overrides')
    out = ROOT / 'build/restricted-worker' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    paths = ['native/restricted_worker.c', 'native/restricted_worker.h',
             'native/restricted_worker_pipes.c', 'native/restricted_worker_pipes.h',
             'native/restricted_worker_frame.c', 'native/restricted_worker_frame.h',
             'native/restricted_worker_stream.c', 'native/restricted_worker_stream.h',
             'native/restricted_worker_gate.c', 'native/restricted_worker_gate.h',
             'native/restricted_worker_io.c', 'native/restricted_worker_io.h',
             'native/restricted_worker_broker.c', 'native/restricted_worker_broker.h',
             'native/restricted_worker_stage.c', 'native/restricted_worker_stage.h',
             'native/restricted_worker_process_adapter.c', 'native/restricted_worker_process_adapter.h',
             'native/host_adapter_process.c', 'native/host_adapter_process.h',
             'native/windows-scalar-worker.c', 'native/windows-scalar-worker.h',
             'native/runtime-engine/clock.inc',
             'native/restricted_worker_payload.h',
             'tests/native/restricted_worker_host.c', 'tools/verify-restricted-worker.py',
             'tools/verify-runtime-store-probe.py']
    c_sources = [path for path in paths if path.endswith('.c')]
    if scalar_images:
        paths.extend(['fairy.windows.json', 'fairy.toml', 'fairy.lock', 'examples/answer.brc',
                      POLICY_EXAMPLE.relative_to(ROOT).as_posix()])
        paths.extend(path.relative_to(ROOT).as_posix() for path in sorted(HELLO_PROJECT.rglob('*'))
                     if path.is_file())
        paths.extend(path.relative_to(ROOT).as_posix()
                     for folder in ('src', 'native') for path in sorted((ROOT / folder).rglob('*'))
                     if path.is_file())
        paths = list(dict.fromkeys(paths))
    receipt = dict(schema='browniec.restricted-worker-verification/v1', status='incomplete',
                   inputs=[dict(path=p, sha256=helper.sha((ROOT / p).read_bytes())) for p in paths],
                   profiles=[], commands=[])

    def run(args, cwd=out, env=None, timeout=30, expected_exit=0, silent=False, no_stderr=False):
        command = list(map(str, args))
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=timeout)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index}.stdout', f'logs/{index}.stderr'
        helper.write(out / stdout, result.stdout)
        helper.write(out / stderr, result.stderr)
        receipt['commands'].append(dict(argv=command, exit=result.returncode, stdout=stdout, stderr=stderr))
        helper.need(result.returncode == expected_exit and (not no_stderr or not result.stderr)
                    and (not silent or not (result.stdout or result.stderr)),
                    f'{command}: {result.returncode}: {result.stdout!r} {result.stderr!r}')
        return result.stdout

    try:
        cl, env, receipt['msvc'] = helper.native_environment(run)
        for profile, option in [('development', '/Od'), ('release', '/O2')]:
            folder = out / profile
            folder.mkdir()
            exe = folder / 'worker-host.exe'
            child = folder / 'worker fixture.exe'
            run([cl, '/nologo', '/std:c11', '/TC', '/MT', '/W4', '/WX', option, '/I'+str(ROOT),
                 *(ROOT / path for path in c_sources), '/Fe' + str(exe),
                 '/link', 'advapi32.lib', 'bcrypt.lib', 'mincore.lib', 'userenv.lib', '/INCREMENTAL:NO', '/Brepro'],
                cwd=folder, env=env)
            shutil.copyfile(exe, child)
            (folder / 'parent-data.txt').write_bytes(b'fixture data\n')
            (folder / 'empty-image.exe').touch()
            runtime_env = {k: v for k, v in os.environ.items()
                           if k.upper() in {'SYSTEMROOT', 'WINDIR', 'LOCALAPPDATA', 'USERPROFILE', 'TEMP', 'TMP'}}
            command = [exe, child]
            scalar = None
            if scalar_images:
                scalar = folder / 'browniec.exe'
                shutil.copyfile(scalar_images / profile / scalar.name, scalar)
                shutil.copyfile(ROOT / 'examples/answer.brc', folder / 'answer.brc')
                (folder / 'bad-source.brc').write_bytes(b'\xff')
                run([scalar, '--internal-scalar-worker'], cwd=folder, env=runtime_env,
                    expected_exit=4, silent=True)
                stage_temp = folder / 'stage temp'
                stage_temp.mkdir()
                stage_env = dict(runtime_env, TEMP=str(stage_temp), TMP=str(stage_temp))
                data = run([scalar, '--internal-scalar-broker', 'run', 'answer.brc'],
                           cwd=folder, env=stage_env, no_stderr=True)
                helper.need(json.loads(data) == dict(schema='browniec.result/v1', profile='brownie.m1-scalar/1',
                            command='run', status='completed', return_i32=77, error=None),
                            f'Unexpected managed broker result: {data!r}')
                helper.need(not list(stage_temp.iterdir()), 'managed launch left a staged file or directory')
                invalid_temp = stage_temp / 'missing'
                failure_env = dict(runtime_env, TEMP=str(invalid_temp), TMP=str(invalid_temp))
                data = run([scalar, '--internal-scalar-broker', 'run', 'answer.brc'],
                           cwd=folder, env=failure_env, expected_exit=4, no_stderr=True)
                helper.need(json.loads(data).get('error', {}).get('kind') == 'unavailable'
                            and not list(stage_temp.iterdir()), 'staging failure fell back or left files')
                managed_project_cases = verify_managed_project(run, helper.need, scalar, folder, stage_env)
                configured_project_cases = verify_configured_project(run, helper.need, scalar, folder, stage_env)
                project_host_cases = verify_project_host(run, helper.need, scalar, folder, stage_env)
                command.append(scalar)
            evidence = json.loads(run(command, cwd=folder, env=runtime_env))
            helper.need({key: value for key, value in evidence.items()
                         if key not in {'coldHandleDelta', 'parentColdHandleDelta'}} ==
                        dict(appContainer=True, capabilities=0, inheritedPipes=3,
                             commitDenied=True, cpuTermination=True, privatePipeAcl=True,
                             framedExchange=True, headerMutationsRejected=48,
                             boundedStream=True, pipeEof=True, publicationGate=True,
                             ioLease=True, brokerSessions=6, hostBrokerCases=11, deferredAdapterCases=3, sharedBudget=True,
                             phaseDeadlines=True, gracefulCancelCases=2, handleDelta=0, staging=True,
                             scalarSessions=5 if scalar else 0, parentBrokerCases=4 if scalar else 0,
                             projectWireRejections=2 if scalar else 0,
                             projectCompileStopCases=4 if scalar else 0,
                             catalogHostStopCases=4 if scalar else 0, catalogProcessCases=4 if scalar else 0)
                        and type(evidence.get('coldHandleDelta')) is int
                        and evidence.get('parentColdHandleDelta') in ((0, 1) if scalar else (0,)),
                        f'Unexpected worker result: {evidence}')
            receipt['profiles'].append(dict(profile=profile, exe=helper.image(exe), result=evidence))
            if scalar:
                receipt['profiles'][-1]['scalarWorker'] = helper.image(scalar)
                receipt['profiles'][-1]['managedProjectCases'] = managed_project_cases
                receipt['profiles'][-1]['configuredProjectCases'] = configured_project_cases
                receipt['profiles'][-1]['projectHostCases'] = project_host_cases
            print(f'PASS {profile}: {evidence}', flush=True)
        helper.need(all(helper.sha((ROOT / i['path']).read_bytes()) == i['sha256'] for i in receipt['inputs']),
                    'Inputs changed during verification')
        receipt['status'] = 'passed'
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        helper.record(out / 'receipt.json', receipt)
        print(f'Receipt: {out / "receipt.json"}')


if __name__ == '__main__':
    main()
