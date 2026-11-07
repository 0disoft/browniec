"""Verify private Windows reader -> actual Fairy Snapshot copy ownership."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'native/runtime-input-adoption'
SPEC = importlib.util.spec_from_file_location('native_helper', ROOT / 'tools/verify-runtime-store-probe.py')
helper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helper)
need, sha, write, record = helper.need, helper.sha, helper.write, helper.record
SOURCES = ['native/runtime-input-adoption/adoption.fy', 'src/runtime_input.fy',
           'tools/runtime-input-adoption/main.fy']
SIGNATURES = [
    'extern const uint8_t * bc_ria_bytes(void * fy_a_0);',
    'extern void bc_ria_close(void * fy_a_0);',
    'extern uintptr_t bc_ria_length(void * fy_a_0);',
    'extern void * bc_ria_read_handle(uintptr_t fy_a_0, uintptr_t fy_a_1, uint32_t * fy_a_2, uint32_t * fy_a_3);',
    'extern void * bc_ria_read_path(const uint8_t * fy_a_0, uintptr_t fy_a_1, uintptr_t fy_a_2, uint32_t * fy_a_3, uint32_t * fy_a_4);',
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fairyc-repository', type=Path)
    parser.add_argument('--emit-only', action='store_true', help='Emit a candidate contract for explicit boundary review, without native builds')
    args = parser.parse_args()
    need(os.name == 'nt' and __debug__, 'Windows and enabled Python assertions required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ), 'CL/_CL_/LINK must be absent, even empty')
    out = ROOT / 'build/runtime-input-adoption' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    receipt = dict(schema='browniec.runtime-input-adoption/v1', status='incomplete', commands=[], profiles=[],
                   recordedAt=datetime.now(timezone.utc).isoformat(), defaultStacks=True,
                   compilerEnvironmentOverrides=False, stackOverrides=False, runtimeInputs=[])

    def run(argv, cwd=out, env=None):
        argv = list(map(str, argv))
        need(not any('/STACK' in a.upper() for a in argv), 'No stack override')
        need(env is None or not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in env), 'No child overrides')
        p = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=180)
        i = len(receipt['commands'])
        stdout, stderr = f'logs/{i:03d}.stdout', f'logs/{i:03d}.stderr'
        write(out / stdout, p.stdout); write(out / stderr, p.stderr)
        receipt['commands'].append(dict(argv=argv, cwd=str(cwd), exit=p.returncode, stdout=stdout, stderr=stderr,
            stdoutSha256=sha(p.stdout), stderrSha256=sha(p.stderr)))
        record(out / 'receipt.json', receipt)
        need(p.returncode == 0, f'Command failed ({p.returncode}): {argv}; {p.stderr[-2000:]!r}; {p.stdout[-2000:]!r}; {out / stderr}')
        return p.stdout

    try:
        tc = json.loads((ROOT / 'toolchain.json').read_bytes())
        compiler = ROOT / 'build/toolchain/fairyc.exe'
        revision = tc['compiler']['revision']
        need(sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256'], 'Pinned compiler required')
        receipt['compiler'] = dict(revision=revision, sha256=sha(compiler.read_bytes()), version=run([compiler, '--version']).decode().strip())
        names = SOURCES + ['native/runtime_input_reader.c', 'native/runtime_input_reader.h',
            'native/runtime-input-adoption/bridge.c', 'tools/runtime-input-adoption/host.c',
            'tools/runtime-input-adoption/heap.c', 'tools/verify-runtime-input-adoption.py',
            'tools/verify-runtime-store-probe.py', 'toolchain.json', 'fairy.toml', 'fairy.lock']
        inputs = {name: (ROOT / name).read_bytes() for name in names}
        need(all(b'\r' not in raw for name, raw in inputs.items() if name.endswith(('.fy', '.py', '.c', '.h'))), 'LF sources required')
        receipt['inputs'] = [dict(path=n, sha256=sha(b)) for n, b in inputs.items()]
        for n, b in inputs.items(): write(out / 'inputs' / n, b)
        project = out / 'project'
        write(project / 'fairy.toml', inputs['fairy.toml'])
        for name in SOURCES:
            write(project / 'src' / ('runtime_input_adoption.fy' if name.endswith('/adoption.fy') else Path(name).name), inputs[name])
        run([compiler, 'check'], project)
        lock = (project / 'fairy.lock').read_bytes()
        sdk = [p for p in json.loads(lock)['packages'] if p['role'] != 'root']
        need(len(sdk) == 1 and all(sdk[0][a] == tc['sdk'][b] for a,b in
            [('sdkIdentity','identity'), ('version','version'), ('sourceDigest','sourceDigest')]), 'Pinned SDK required')
        generated = run([compiler, 'experimental', 'emit-workspace-c', '--target', 'x86_64-windows-msvc', '--locked'], project)
        write(out / 'generated.c', generated)
        text = generated.decode()
        declarations = [line for line in text.splitlines() if line.startswith('extern ') and ' bc_ria_' in line]
        # Freeze the emitted primitive signatures, never reconstruct resource layout.
        receipt['declarations'] = declarations
        candidate = dict(schema='browniec.runtime-input-adoption-transport/v1', compilerRevision=revision,
            compilerSha256=sha(compiler.read_bytes()), transportSha256=sha(generated), declarations=declarations,
            sourceInputs=[dict(path=n, sha256=sha(inputs[n])) for n in SOURCES])
        runtime = [(ROOT / 'tools/runtime-input-adoption/heap.c').read_text()]
        repository = (args.fairyc_repository or ROOT / tc['source']['localRepository']).resolve()
        for name in ['internal/cstdlib/stage0_system_heap.c', 'internal/cstdlib/stage0_buffer.c',
                     'internal/cstdlib/stage0_windows_console.c', 'internal/cstdlib/stage0_windows_process_args.c',
                     'internal/cruntime/stage0_scalar.c']:
            raw = run(['git', '-C', repository, 'show', revision + ':' + name])
            row = dict(path=name, revision=revision, sha256=sha(raw));receipt['runtimeInputs'].append(row)
            write(out / 'runtime-inputs' / Path(name).name, raw)
            source = raw.decode()
            if name.endswith('stage0_scalar.c'):
                for key, value in [('@TRAP_EXIT_BASE@', '192'), ('@TRAP_RECEIPT_INCLUDE@', ''), ('@TRAP_RECEIPT_WRITE@', '')]:
                    need(source.count(key) == 1, 'Runtime template changed');source = source.replace(key, value)
            runtime.append(source)
        candidate['runtimeInputs'] = receipt['runtimeInputs']
        record(out / 'candidate-transport.json', candidate)
        if args.emit_only:
            receipt.update(status='emitted-for-review', transportSha256=sha(generated));return
        contract = json.loads((NATIVE / 'transport.json').read_bytes())
        need(candidate == contract, 'Reviewed transport changed; review candidate-transport.json before updating contract')
        # Reviewed generated declarations have the expected primitive-only types.
        need([re.sub(r'\s+', '', d) for d in declarations] == [re.sub(r'\s+', '', d) for d in SIGNATURES], 'Primitive extern signatures changed')
        write(out / 'runtime.c', '\n'.join(runtime))
        cl, env, receipt['msvc'] = helper.native_environment(run)
        empty = out / 'empty-tools';empty.mkdir()
        runtime_env = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR', 'TEMP', 'TMP'] if k in os.environ}
        runtime_env['PATH'] = str(empty)
        for profile in ['development', 'release']:
            folder = out / profile;folder.mkdir()
            flags = ['/nologo', '/TC', '/std:c11', '/MT', '/W3', '/Od' if profile == 'development' else '/O2']
            objects = {}
            for name, source in [('fairy',out/'generated.c'), ('runtime',out/'runtime.c'), ('bridge',NATIVE/'bridge.c')]:
                obj = folder / (name + '.obj');run([cl,*flags,'/c',source,'/Fo'+str(obj)],env=env);objects[name]=obj
            results = []
            for seam in [False, True]:
                tag = 'seam' if seam else 'normal';parts=[]
                for name, source in [('reader', ROOT/'native/runtime_input_reader.c'), ('host',ROOT/'tools/runtime-input-adoption/host.c')]:
                    obj=folder/(name+'-'+tag+'.obj')
                    run([cl,*flags,*(['/DBC_RIR_TEST'] if seam else []),'/c',source,'/Fo'+str(obj)],env=env);parts.append(obj)
                exe=folder/(tag+'.exe')
                run([cl,'/nologo',*objects.values(),*parts,'ntdll.lib','/Fe'+str(exe),'/link','/INCREMENTAL:NO','/Brepro'],env=env)
                data=exe.read_bytes();image=helper.image(exe)
                result=json.loads(run([exe],env=runtime_env))
                need(receipt['commands'][-1]['stderrSha256']==sha(b'') and result['liveHeap']==0 and result['nativeLive']==0 and
                    result['handlesStable'] and result['fairyOomCases']==(48 if seam else 0) and
                    result['nativeOomCases']==(24 if seam else 0), 'Actual ownership/cleanup assertions')
                symbols=run([cl.parent/'dumpbin.exe','/symbols',parts[0]],env=env)
                need((b'bc_rir_test_' in symbols)==seam,'Reader production hook separation')
                results.append(dict(seam=seam,result=result,image=image,objects=[dict(path=str(p),sha256=sha(p.read_bytes())) for p in [*objects.values(),*parts]]))
            receipt['profiles'].append(dict(profile=profile,results=results))
            print(f'PASS {profile}: disk/path/pipe exact binary copies, 1MiB, no partial publish, 48 Fairy/24 native OOM cases; heap/handles clean',flush=True)
        need(all((ROOT/n).read_bytes()==b for n,b in inputs.items()), 'Inputs changed during verification')
        need((project/'fairy.lock').read_bytes()==lock, 'Isolated lock changed')
        receipt.update(status='passed',transportSha256=sha(generated),isolatedLockSha256=sha(lock),
            sourceLockUnchanged=True,publicAvailabilityChanged=False,limitations=[
                'Private synchronous explicit host I/O; no Engine/Instance/public CLI association.',
                'Copies exact payload into real Fairy Snapshot; native capacity plus SDK payload coexist transiently.',
                'Trusted caller charge; not a complete Fuel schedule or Engine memory accounting.',
                'OOM is explicit allocator-return injection, not whole-process exhaustion.',
                'Consumed cursor/pipe input is not rolled back or replayed; EOF probes may block indefinitely.',
                'No deadlines, cancellation, hostile pointer validation or filesystem containment.'])
    except Exception as error:
        receipt.update(status='failed',error=str(error));raise
    finally:
        record(out/'receipt.json',receipt)
        record(ROOT/'build/runtime-input-adoption/latest.json',dict(path=str(out/'receipt.json'),sha256=sha((out/'receipt.json').read_bytes())))
        print('Receipt: '+str(out/'receipt.json'),flush=True)


if __name__ == '__main__': main()
