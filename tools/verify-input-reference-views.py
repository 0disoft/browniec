"""Verify invocation input span metadata with default-stack development/O2 native tests."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('input_views_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/input-reference-views'
bottom.MODULES = {'input_reference_views': None}
bottom.EXTRA_INPUTS = {'tools/verify-input-reference-views.py', 'docs/engineering/input-reference-views.md',
    'tools/verify-runtime-store-probe.py', 'probes/m2-buffer-failure/allocator_probe.h'}


def seams(profiles):
    """Reuse the existing explicit allocator seam, adapted only for cell size."""
    import json, os, re, shutil, subprocess
    from datetime import datetime, timezone
    assert os.name == 'nt'
    assert not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ)
    sha = bottom.runner.sha
    paths = ['src/input_reference_views.fy','tests/m2/input_reference_views.fy',
             'tools/verify-input-reference-views.py','docs/engineering/input-reference-views.md',
             'fairy.toml','fairy.lock','toolchain.json','tools/verify-runtime-store-probe.py',
             'probes/m2-buffer-failure/allocator_probe.h']
    inputs = {path: (ROOT/path).read_bytes() for path in paths}
    out = ROOT / 'build/input-reference-views/seams'
    out.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='incomplete', recordedAt=datetime.now(timezone.utc).isoformat(),
                   commands=[], profiles=[], defaultStacks=True, nativeOverrides=False,
                   inputs=[dict(path=p,sha256=sha(b)) for p,b in inputs.items()])
    def write(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data.encode() if isinstance(data, str) else data)
    def run(argv, cwd=out, env=None):
        argv = list(map(str, argv))
        assert not any('/STACK' in a.upper() for a in argv)
        done = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=300)
        n = len(receipt['commands'])
        write(out / f'{n}.stdout', done.stdout); write(out / f'{n}.stderr', done.stderr)
        receipt['commands'].append(dict(argv=argv, exit=done.returncode,
            stdout=f'{n}.stdout', stderr=f'{n}.stderr',
            stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr)))
        bottom.runner.write(out / 'receipt.json', receipt)
        assert done.returncode == 0 and not done.stderr, (argv, done.returncode, done.stderr[-3000:], done.stdout[-2000:])
        return done.stdout
    helper_spec = importlib.util.spec_from_file_location('input_native_helper', ROOT / 'tools/verify-runtime-store-probe.py')
    helper = importlib.util.module_from_spec(helper_spec); helper_spec.loader.exec_module(helper)
    helper.ROOT = ROOT
    cl, env, receipt['msvc'] = helper.native_environment(run)
    tc = json.loads((ROOT / 'toolchain.json').read_bytes())
    compiler = ROOT / 'build/toolchain/fairyc.exe'
    assert sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256']
    project = out / 'project'
    shutil.copytree(ROOT / 'src', project / 'src', dirs_exist_ok=True)
    shutil.copyfile(ROOT / 'fairy.toml', project / 'fairy.toml')
    source = (ROOT / 'tests/m2/input_reference_views.fy').read_text()
    names = re.findall(r'@test fn void (\w+)\(', source)
    assert len(names) == 6
    adapter = source.replace('module tests::m2::input_reference_views;', 'module input_views_probe;').replace('@test fn void ', 'pub fn void ')
    write(project / 'src/input_views_probe.fy', adapter)
    # Select the OOM test on explicit injection, otherwise all six groups. All
    # process-argument reads use stack buffers, so they cannot hide allocations.
    main = 'module main;import input_views_probe as p;import std::process as process;fn i32 main(){if(process::arg_count()>1){p::'+names[-1]+'();}else{'
    main += ''.join('p::'+name+'();' for name in names) + '}return 0;}\n'
    write(project / 'src/main.fy', main)
    run([compiler, 'check'], cwd=project)
    emitted = run([compiler, 'experimental', 'emit-workspace-c', '--target', 'x86_64-windows-msvc', '--locked'], cwd=project).decode()
    # Assert the exact generated nominal Cell and Vec descriptor, not a model.
    cell = re.findall(r'typedef struct \{\s*uintptr_t f_0;\s*uintptr_t f_1;\s*int32_t f_2;\s*\} (fy_struct_\d+);', emitted)
    assert len(cell)==1, 'Generated Cell shape missing or ambiguous'
    name = cell[0]
    guards = '\n_Static_assert(sizeof('+name+')==24,"Cell stride");\n'
    guards += ''.join('_Static_assert(offsetof('+name+',f_'+str(i)+')=='+str(off)+',"Cell field");\n' for i,off in enumerate([0,8,16]))
    write(out / 'probe.c', emitted + guards)
    fairy = (ROOT / tc['source']['localRepository']).resolve()
    if not (fairy / '.git').exists(): fairy = ROOT.parents[2] / 'fairyc'
    runtime = ['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)\n']
    receipt['runtimeInputs'] = []
    paths = ['internal/cstdlib/'+n for n in ['stage0_system_heap.c','stage0_buffer.c','stage0_vector_storage.c','stage0_windows_console.c','stage0_windows_process_args.c']]+['internal/cruntime/stage0_scalar.c']
    for path in paths:
        raw = run(['git', '-C', fairy, 'show', tc['compiler']['revision']+':'+path]).decode()
        receipt['runtimeInputs'].append(dict(path=path, sha256=sha(raw.encode()), revision=tc['compiler']['revision']))
        if path.endswith('stage0_scalar.c'):
            for token, value in [('@TRAP_RECEIPT_INCLUDE@',''),('@TRAP_RECEIPT_WRITE@',''),('@TRAP_EXIT_BASE@','128')]:
                assert raw.count(token)==1; raw=raw.replace(token,value)
        runtime.append(raw)
    write(out / 'runtime.c', '\n'.join(runtime))
    header = (ROOT / 'probes/m2-buffer-failure/allocator_probe.h').read_text()
    assert header.count('320')==2
    write(out / 'allocator.h', header.replace('320','24576'))
    receipt.update(adapterSha256=sha(adapter.encode()), generatedSha256=sha(emitted.encode()),
        cellStride=24, cellOffsets=[0,8,16], reserveCapacity=1024, initializedCells=768,
        allocatorSeam='Existing allocator_probe.h; target 320 replaced by 24576; explicit /FI')
    for profile in profiles:
        flag = '/O2' if profile=='release' else '/Od'
        for name in ['probe','runtime']:
            argv = [cl,'/nologo','/TC','/std:c11','/MT','/W4','/WX',flag]
            if name=='runtime': argv += ['/FI'+str(out/'allocator.h')]
            run(argv+['/c',out/(name+'.c'),'/Fo'+str(out/(name+'-'+profile+'.obj'))],env=env)
        exe=out/(profile+'.exe')
        run([cl,'/nologo','/MT',out/('probe-'+profile+'.obj'),out/('runtime-'+profile+'.obj'),'/Fe'+str(exe),'/link','/INCREMENTAL:NO','/Brepro'],env=env)
        # The existing helper asserts default 1MiB reserve / 4KiB commit.
        pe=helper.image(exe)
        normal=json.loads(run([exe]))
        assert normal['live']==0 and normal['attempts']==normal['frees']==8 and normal['failures']==0, normal
        oom=json.loads(run([exe,'inject'],env=dict(os.environ,BROWNIE_BUFFER_FAIL_BYTES='24576')))
        assert oom['live']==0 and oom['targetAttempts']==2 and oom['failures']==1 and oom['attempts']==2 and oom['frees']==1, oom
        receipt['profiles'].append(dict(profile=profile,image=pe,normal=normal,oom=oom))
        print('PASS '+profile+': generated Cell layout, exactly 8 opens / 8 allocations, OOM rollback, default stack',flush=True)
    assert all((ROOT/p).read_bytes()==b for p,b in inputs.items())
    assert sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256']
    receipt.update(status='passed', compilerSha256=sha(compiler.read_bytes()))
    receipt['artifacts']=[dict(path=p.relative_to(out).as_posix(),sha256=sha(p.read_bytes())) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='receipt.json']
    bottom.runner.write(out/'receipt.json',receipt)

if __name__ == '__main__':
    bottom.main()
    if '--discover' not in sys.argv:
        selected = sys.argv[sys.argv.index('--profile')+1] if '--profile' in sys.argv else 'all'
        seams(['development','release'] if selected=='all' else [selected])
