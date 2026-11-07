"""Verify private guest-output completion plus focused input, ownership and depth regressions."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
SELECTED = {
    'output_source': None,
    'output_verifier': None,
    'module_output_execution': None,
    'module_input_completion': [
        'exact_and_one_less_return_keep_atomic_leave_and_prepaid_abort_prices',
        'nested_returned_input_calls_match_static_prices_at_exact_fuel',
        'nested_division_failure_preserves_all_call_and_prior_read_debits',
        'nested_range_failure_preserves_dispatch_without_committing_atomic_range'],
    'module_input_execution': [
        'input_lengths_and_last_bytes_cross_image_limit_through_one_program',
        'reused_program_observes_independent_snapshots_with_binary_nuls'],
    'module_program': [
        'selected_nonfirst_entry_and_private_helpers_execute_with_exact_scalar_fuel',
        'shared_byte_returns_literals_ranges_and_text_cross_real_module_calls'],
    'reference_return_execution': [
        'the_same_returned_signature_reads_distinct_image_and_runtime_values_at_exact_fuel',
        'caller_alias_and_range_survive_parent_and_original_loan_close_until_last_alias',
        'complete_return_fuel_is_checked_before_invalid_native_formal_authentication'],
    'captured_call_stack': ['retained_captured_calls_keep_the_32_deep_limit_and_reject_33'],
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain/fairyc.exe')
    parser.add_argument('--fairyc-repository', type=Path, default=ROOT.parent / 'fairyc')
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--suite', choices=['output', 'compile-memory'], default='output')
    args = parser.parse_args()
    assert os.name == 'nt' and __debug__
    assert not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ)
    compiler = args.compiler.resolve()
    tc = json.loads((ROOT / 'toolchain.json').read_bytes())
    assert sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256']
    selected = SELECTED if args.suite == 'output' else {
        'compile_memory': None,
        'module_compile_memory': None,
        'captured_call_stack': ['retained_captured_calls_keep_the_32_deep_limit_and_reject_33'],
    }
    out = ROOT / ('build/module-output-execution' if args.suite == 'output' else 'build/compile-memory')
    out.mkdir(parents=True, exist_ok=True)
    receipt = dict(schema=('browniec.module-output-execution/v1' if args.suite == 'output'
                          else 'browniec.compile-memory/v1'), status='incomplete',
        recordedAt=datetime.now(timezone.utc).isoformat(), commands=[], profiles=[], inputs=[],
        compilerSha256=sha(compiler.read_bytes()), compilerRevision=tc['compiler']['revision'],
        defaultStacks=True, nativeOverrides=False, vmReplay=False, groupIsolation=True)
    receipt['suite'] = args.suite
    def write(path, raw):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw.encode() if isinstance(raw, str) else raw)
    def record():
        write(out / 'receipt.json', json.dumps(receipt, indent=2) + '\n')
    def run(argv, cwd=out, env=None):
        argv = list(map(str, argv))
        assert not any('/STACK' in a.upper() for a in argv)
        done = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=600)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index:03}.stdout', f'logs/{index:03}.stderr'
        write(out / stdout, done.stdout); write(out / stderr, done.stderr)
        receipt['commands'].append(dict(argv=argv, cwd=str(cwd), exit=done.returncode,
            stdout=stdout, stderr=stderr, stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr)))
        record()
        assert done.returncode == 0 and not done.stderr, (argv, done.returncode, done.stderr[-2000:], done.stdout[-2000:])
        return done.stdout
    spec = importlib.util.spec_from_file_location('output_execution_native', ROOT / 'tools/verify-runtime-store-probe.py')
    helper = importlib.util.module_from_spec(spec); spec.loader.exec_module(helper); helper.ROOT = ROOT
    cl, env, receipt['msvc'] = helper.native_environment(run)
    sources = {p.stem: p for p in (ROOT / 'src').glob('*.fy')}
    original = {}; pending = []; groups = []; adapters = {}
    for module, selection in selected.items():
        path = ROOT / f'tests/m2/{module}.fy'; raw = path.read_bytes(); original[path] = raw
        text = raw.decode(); names = re.findall(r'@test\s+fn\s+void\s+(\w+)\(', text)
        chosen = names if selection is None else selection
        assert chosen and set(chosen) <= set(names)
        alias = 'output_execution_probe_' + module
        adapter = text.replace('module tests::m2::' + module + ';', 'module ' + alias + ';')
        adapter = re.sub(r'@test\s+fn\s+void\s+', 'pub fn void ', adapter)
        adapters[alias] = adapter
        pending += re.findall(r'^import (\w+) as \w+;', adapter, re.M)
        groups += [dict(module=module, function=name, alias=alias) for name in chosen]
    seen = set()
    while pending:
        name = pending.pop()
        if name in seen: continue
        seen.add(name); path = sources[name]; raw = path.read_bytes(); original[path] = raw
        pending += re.findall(r'^import (\w+) as \w+;', raw.decode(), re.M)
    for name in ['fairy.toml', 'toolchain.json', 'tools/verify-module-output-execution.py', 'tools/verify-runtime-store-probe.py']:
        path = ROOT / name; original[path] = path.read_bytes()
    if args.suite == 'compile-memory':
        path = ROOT / 'tools/runtime-engine/heap-observer.c'
        original[path] = path.read_bytes()
    assert all(b'\r' not in raw for p, raw in original.items() if p.suffix in ['.fy', '.py'])
    receipt['inputs'] = [dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(raw)) for p, raw in sorted(original.items())]
    receipt['groups'] = groups
    project = out / 'project'
    write(project / 'fairy.toml', (ROOT / 'fairy.toml').read_bytes())
    for name in seen: write(project / 'src' / sources[name].name, original[sources[name]])
    for name, text in adapters.items(): write(project / 'src' / (name + '.fy'), text)
    driver = 'module main;import std::process as process;'
    driver += ''.join('import '+g+' as p'+str(i)+';' for i, g in enumerate(adapters))
    driver += 'fn i32 main(){assert(process::arg_count()==2);var u8[8] raw=[0;8];let usize length=switch(process::arg(1,ref mut raw)){case .ok(v):{v}case .err(_):{assert(false);0}};var usize index=0;var usize i=0;while(i<length){assert(raw[i]>=48 && raw[i]<=57);index=index*10+(raw[i]-48) as usize;i+=1;}'
    aliases = {name: 'p'+str(i) for i, name in enumerate(adapters)}
    driver += ''.join('if(index=='+str(i)+'){'+aliases[g['alias']]+'::'+g['function']+'();return 0;}' for i, g in enumerate(groups))
    driver += 'return 2;}\n'
    write(project / 'src/main.fy', driver)
    run([compiler, 'check'], cwd=project)
    run([compiler, 'check', '--locked'], cwd=project)
    generated = run([compiler, 'experimental', 'emit-workspace-c', '--target', 'x86_64-windows-msvc', '--locked'], cwd=project)
    write(out / 'generated.c', generated)
    receipt.update(sourceClosure=len(seen), generatedSha256=sha(generated),
        isolatedLockSha256=sha((project / 'fairy.lock').read_bytes()),
        adapterChanges='Module name and test visibility only; complete original 32/33 fixture unchanged')
    runtime = ([original[ROOT / 'tools/runtime-engine/heap-observer.c'].decode()]
               if args.suite == 'compile-memory' else
               ['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)\n'])
    receipt['runtimeInputs'] = []
    paths = ['internal/cstdlib/' + n for n in ['stage0_system_heap.c', 'stage0_buffer.c', 'stage0_vector_storage.c',
        'stage0_text_view.c', 'stage0_windows_console.c', 'stage0_windows_process_args.c']] + ['internal/cruntime/stage0_scalar.c']
    for path in paths:
        raw = run(['git', '-C', args.fairyc_repository.resolve(), 'show', tc['compiler']['revision'] + ':' + path])
        receipt['runtimeInputs'].append(dict(path=path, revision=tc['compiler']['revision'], sha256=sha(raw)))
        text = raw.decode()
        if path.endswith('stage0_scalar.c'):
            for key, value in [('@TRAP_RECEIPT_INCLUDE@', ''), ('@TRAP_RECEIPT_WRITE@', ''), ('@TRAP_EXIT_BASE@', '192')]:
                assert text.count(key)==1; text=text.replace(key,value)
        runtime.append(text)
    write(out / 'runtime.c', '\n'.join(runtime))
    empty = out / 'empty-path'; empty.mkdir(exist_ok=True)
    runenv = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}; runenv['PATH'] = str(empty)
    profiles = ['development', 'release'] if args.profile=='all' else [args.profile]
    for profile in profiles:
        objects = []
        for name in ['generated', 'runtime']:
            obj = out / (name+'-'+profile+'.obj')
            run([cl, '/nologo', '/TC', '/std:c11', '/MT', '/W3', '/Od' if profile=='development' else '/O2',
                '/c', out / (name+'.c'), '/Fo'+str(obj)], env=env); objects.append(obj)
        exe = out / ('output-execution-'+profile+'.exe')
        run([cl, '/nologo', '/MT', *objects, '/Fe'+str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
        image = helper.image(exe)
        for i, group in enumerate(groups):
            run([exe, str(i)], cwd=empty, env=runenv)
            print('PASS '+profile+' '+group['module']+'::'+group['function'], flush=True)
        receipt['profiles'].append(dict(profile=profile, groupsPassed=len(groups), image=image)); record()
    assert all(p.read_bytes()==raw for p, raw in original.items())
    assert sha(compiler.read_bytes())==receipt['compilerSha256']
    receipt['status']='passed'; record()

if __name__ == '__main__':
    main()
