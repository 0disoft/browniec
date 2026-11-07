"""Focused native exchange, real allocator rollback and generated-C layout checks.

Writes only build/host-exchange, using byte-identical source dependency mirrors.
Normal native tests use default stacks and no compiler overrides. The two explicit
allocator scenarios reuse the existing MSVC forced-include heap seam with explicit cl /FI arguments, separately.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BASE = '845a05623d28e9eea348500debedbe264905c5f9'
FEATURES = ['src/host_exchange.fy', 'tests/m2/host_exchange.fy',
            'tools/verify-host-exchange.py', 'docs/engineering/host-exchange.md']
LAYOUT_MAIN = r'''module main;
import host_exchange as x;import host_catalog as c;
@link_name("brownie_exchange_seed") unsafe extern C fn void seed(ptr mut void e);
fn i32 main(){
 let ref u8[] json=b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"example.check\",\"adapter_revision\":\"v1\"}]}";
 let c::Catalog catalog=switch(c::parse(json)){case .ok(v):{v}case .err(_):{assert(false);return 1;}};
 let bool[1] grants=[true];
 let x::Limits l=x::Limits{.request_bytes=1048576,.reply_bytes=1048576,.requests_total=18446744073709551615,
  .replies_total=18446744073709551615,.calls=18446744073709551615,.adapter_per_call=0,.adapter_total=0};
 var x::Exchange e=switch(x::create(catalog,ref grants,l,7,18446744073709551615,0)){
  case .ok(v):{v}case .err(_):{assert(false);return 1;}};
 unsafe {seed(ref mut e as ptr mut void);}
 assert(x::begin(ref mut e,0,b"\x00\x00",0,0,1,false).is_ok);
 assert(x::observe(ref e).request==18446744073709551615 && x::observe(ref e).fuel==18446744073709551615);
 assert(x::reply(ref mut e,7,18446744073709551615,0,b"\x03\x00\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00",0,2,false).is_ok);
 let x::Output output=switch(x::take_reply(ref mut e,3,false)){case .ok(v):{v}case .err(_):{assert(false);return 1;}};
 assert(!x::begin(ref mut e,0,b"\x00\x00",0,0,4,false).is_ok);
 let x::Observation t=x::observe(ref e);
 assert(t.request==18446744073709551615 && t.cause==6 && t.phase==3);
 assert(x::output_field(ref output).scalar==42);return 0;
}
'''


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def write(path, blob):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob.encode() if isinstance(blob, str) else blob)


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def closure():
    pending, names = ['host_exchange'], set()
    while pending:
        name = pending.pop()
        if name in names:
            continue
        names.add(name)
        pending.extend(re.findall(r'^import ([a-z_]+) as ', (ROOT / f'src/{name}.fy').read_text(), re.M))
    return sorted(f'src/{name}.fy' for name in names)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--native-from', type=Path, help='Reuse only hash-matching normal native reports from this work session; rerun all seams.')
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain/fairyc.exe')
    args = parser.parse_args()
    need(__debug__ and os.name == 'nt', 'Windows x64 and enabled Python assertions required')
    need(not any(k.upper() in {'CL','_CL_','LINK'} for k in os.environ), 'Ambient compiler overrides prohibited')
    out = ROOT / 'build/host-exchange' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    receipt = dict(schema='browniec.host-exchange/v1', status='incomplete', baseCommit=BASE,
                   recordedAt=datetime.now(timezone.utc).isoformat(), commands=[], profiles=[],
                   normalNativeOverrides=False, defaultStacks=True, historicalResultReuse=False)
    compiler = args.compiler.resolve(strict=True)

    def run(argv, label, cwd=out, env=None, expected=0, timeout=600):
        argv = list(map(str, argv))
        p = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=timeout)
        name = f'{len(receipt["commands"]):03}-{label}'
        write(out / (name + '.stdout'), p.stdout)
        write(out / (name + '.stderr'), p.stderr)
        receipt['commands'].append(dict(argv=argv, cwd=str(cwd), exit=p.returncode,
            stdout=name+'.stdout', stderr=name+'.stderr', stdoutSha256=sha(p.stdout), stderrSha256=sha(p.stderr)))
        need((p.returncode == expected if expected is not None else p.returncode != 0),
             f'{label} exit {p.returncode}: {p.stderr[-2500:]!r} {p.stdout[-1000:]!r}')
        if expected == 0:
            need(not p.stderr, f'{label}: unexpected stderr {p.stderr[-2500:]!r}')
        return p.stdout

    def native_report(raw, profile, selected):
        data=json.loads(raw)
        need(data['schemaVersion']=='fairyc.test-report/v4' and data['engine']=='native' and
             data['profile']==profile and data['status']=='ok' and data['lock']=='verified' and
             data['count']==data['passed']==len(selected) and data['failed']==0 and
             {t['identity'] for t in data['tests']}==set(selected), 'Exact native pass report required')
        need(all(t['outcome']=='passed' and t['trapCategory'] is None and not t['stderrBase64'] and
                 not t['stdoutBase64'] for t in data['tests']), 'Native failure/output')
        return dict(groups=len(selected),sha256=sha(raw))

    try:
        tc = json.loads((ROOT / 'toolchain.json').read_bytes())
        compiler_hash = sha(compiler.read_bytes())
        need(compiler_hash == tc['platforms']['windows/amd64']['sha256'], 'Pinned compiler hash mismatch')
        version = run([compiler, '--version'], 'compiler-version').decode()
        need(tc['compiler']['revision'] in version and tc['sdk']['version'] in version, 'Compiler/SDK identity')
        receipt['compiler'] = dict(sha256=compiler_hash, version=version)
        paths = sorted(set(closure() + FEATURES + ['fairy.toml', 'fairy.lock', 'toolchain.json',
            'probes/m2-buffer-failure/allocator_probe.h']))
        inputs = {p: (ROOT / p).read_bytes() for p in paths}
        need(all(b'\r' not in b for p, b in inputs.items() if p.endswith(('.fy', '.py', '.md'))), 'LF feature inputs required')
        receipt['inputs'] = [dict(path=p, sha256=sha(b)) for p,b in inputs.items()]
        for p,b in inputs.items():
            write(out/'inputs'/p,b)
        project = out / 'project'
        for p in closure() + ['tests/m2/host_exchange.fy', 'fairy.toml']:
            write(project/p, inputs[p])
        write(project/'src/main.fy', 'module main;fn i32 main(){return 0;}\n')
        run([compiler, 'check'], 'mirror-lock', project)
        lock = (project/'fairy.lock').read_bytes()
        sdk_packages=[p for p in json.loads(lock)['packages'] if p['role']!='root']
        need(len(sdk_packages)==1 and all(sdk_packages[0][key]==tc['sdk'][other] for key,other in
             [('sdkIdentity','identity'),('version','version'),('sourceDigest','sourceDigest')]), 'Pinned base SDK identity')
        receipt['nativeSdkPackages']=sdk_packages
        receipt['rootSdkPackages']=[p for p in json.loads(inputs['fairy.lock'])['packages'] if p['role']!='root']
        receipt['nativeLockSha256'] = sha(lock)
        source = inputs['tests/m2/host_exchange.fy'].decode()
        selected = ['tests::m2::host_exchange::'+n for n in re.findall(r'@test\s+fn void (\w+)\(',source)]
        need(10 <= len(selected) <= 20 and len(selected)==len(set(selected)), 'Focused unique test inventory')
        profiles = ['development','release'] if args.profile=='all' else [args.profile]
        reused=None
        if args.native_from:
            previous=args.native_from.resolve(strict=True)
            reused=json.loads(previous.read_bytes())
            need(reused['compiler']['sha256']==compiler_hash and reused['normalNativeOverrides'] is False and
                 reused['defaultStacks'] is True,'Reusable normal compiler/stack identity')
            old_inputs={i['path']:i['sha256'] for i in reused['inputs']}
            need(all(old_inputs.get(p)==sha(inputs[p]) for p in closure()+['tests/m2/host_exchange.fy','fairy.toml','toolchain.json']),
                 'Normal native dependency/test inputs differ')
            receipt['normalNativeReuse']=dict(receipt=str(previous),sha256=sha(previous.read_bytes()),
                scope='Only current-session byte-identical normal native reports; every seam rerun')
        for profile in profiles:
            if reused:
                candidates=[c for c in reused['commands'] if c['stdout'].endswith(profile+'-native.stdout')]
                need(len(candidates)==1,'Exactly one previous native command/profile required')
                c=candidates[0];raw=(previous.parent/c['stdout']).read_bytes()
                need(c['exit']==0 and sha(raw)==c['stdoutSha256'] and not (previous.parent/c['stderr']).read_bytes(),
                     'Previous native command/report hash')
                write(out/(profile+'-native-reused.json'),raw)
                report=native_report(raw,profile,selected)
            else:
                command=[compiler,'test','--native','--capture-output','--json','--locked']
                if profile=='release':command.append('--release')
                for identity in selected:command+=['--exact',identity]
                report=native_report(run(command,profile+'-native',project),profile,selected)
            receipt['profiles'].append(dict(profile=profile,native=report))
            print(f'PASS {profile}: {len(selected)} native groups; default environment/stacks'+(' (hash-matched session evidence)' if reused else ''),flush=True)

        # Regression negative control: remove only the three nonallocating SDK
        # validation calls. The same release test must reproduce the old heap fault.
        control=out/'raw-loop-negative-control'
        for p in closure()+['tests/m2/host_exchange.fy','fairy.toml']:write(control/p,inputs[p])
        write(control/'src/main.fy','module main;fn i32 main(){return 0;}\n')
        raw_loop=inputs['src/host_exchange.fy'].decode()
        removed=['    assert(unsafe {validate_buffer_raw(e as ptr mut void,0)}==0);\n',
                 '    assert(bytes::reserve(ref mut incoming,0).is_ok);\n',
                 '    assert(bytes::reserve(ref mut old,0).is_ok);\n']
        for line in removed:
            need(raw_loop.count(line)==1,'Negative control anchor changed');raw_loop=raw_loop.replace(line,'')
        write(control/'src/host_exchange.fy',raw_loop)
        run([compiler,'check'],'negative-control-lock',control)
        identity='tests::m2::host_exchange::fake_adapter_decodes_actual_request_and_encodes_reply_42'
        run([compiler,'test','--native','--release','--json','--capture-output','--locked','--exact',identity],
            'negative-control-release',control,expected=6)
        fault=(out/receipt['commands'][-1]['stderr']).read_bytes()
        need(any(str(code).encode() in fault for code in [-1073740940,-1073741819]) and
             b'without valid trap control' in fault,'Expected isolated raw-loop ownership fault')
        receipt['rawLoopNegativeControl']=dict(reproduced=True,identity=identity,profile='release',
            sourceSha256=sha(raw_loop.encode()),removedSdkValidations=3,defaultStack=True,environmentOverrides=False)

        # Compile negative callers without changing any production module.
        negative = {
            'private-state': 'fn void forge(ref mut x::Exchange e){e.deadline=0;}',
            'private-save': 'fn void forge(ref mut x::Exchange e,x::Observation s){x::save(e,s);}',
            'live-request-view': '''fn void bad(ref mut x::Exchange e){
                let ref u8[] request=switch(x::request_bytes(e)){case .ok(v):{v}case .err(_):{return;}};
                discard x::reply(e,7,1,2,b"",0,1,false);assert(request.len==0);}''',
        }
        for label,body in negative.items():
            write(project/'src/forgery.fy','module forgery;import host_exchange as x;'+body+'\n')
            raw = run([compiler,'check'],label,project,expected=None)
            diagnostic = (out/receipt['commands'][-1]['stderr']).read_bytes()
            need(b'E2101' in diagnostic if label=='live-request-view' else
                 (b'E0103' in diagnostic or b'E0101' in diagnostic), f'{label}: expected specific rejection')
            (project/'src/forgery.fy').unlink()
        run([compiler,'check'],'restored-mirror-lock',project)

        # Emit actual production C plus a test-only native identity-boundary hook.
        write(project/'src/main.fy',LAYOUT_MAIN)
        run([compiler,'check'],'layout-lock',project)
        emitted = run([compiler,'experimental','emit-workspace-c','--target','x86_64-windows-msvc','--locked'],
                      'generated-c',project).decode()
        write(out/'generated.c',emitted)
        resources=re.findall(r'typedef struct\s*\{([^{}]*)\}\s*(fy_resource_\d+);',emitted,re.S)
        # Actual generated resource definitions use ordinal field names. Match
        # the complete Buffer shape and Exchange prefix; do not copy a C layout.
        buffer=[n for b,n in resources if re.sub(r'\s+','',b)=='void*f_0;uintptr_tf_1;uintptr_tf_2;uintptr_tf_3;']
        need(len(buffer)==1,'Unambiguous generated Buffer definition required');bn=buffer[0]
        exchange=[n for b,n in resources if re.sub(r'\s+','',b).startswith(bn+'f_0;'+bn+'f_1;uint8_t*f_2;')]
        need(len(exchange)==1,'Unambiguous generated Exchange definition required');en=exchange[0]
        harness = f'''
#include <stddef.h>
#include <assert.h>
_Static_assert(sizeof({bn}) == 32, "Buffer size");
_Static_assert(offsetof({bn}, f_0)==0, "Buffer data");
_Static_assert(offsetof({bn}, f_1)==8, "Buffer capacity");
_Static_assert(offsetof({bn}, f_2)==16, "Buffer alignment");
_Static_assert(offsetof({bn}, f_3)==24, "Buffer length");
_Static_assert(sizeof({en})==7632, "Exchange size");
_Static_assert(offsetof({en}, f_0)==0, "Exchange backing");
_Static_assert(offsetof({en}, f_1)==32, "Exchange header");
_Static_assert(offsetof({en}, f_2)==64, "Exchange header data");
_Static_assert(offsetof({en}, f_3)==72, "Exchange catalog");
void brownie_exchange_seed(void *raw) {{
    {en} *e = ({en} *)raw;
    assert(sizeof({bn})==32 && sizeof({en})==7632);
    assert(offsetof({en},f_0)==0 && offsetof({en},f_1)==32 && offsetof({en},f_2)==64 && offsetof({en},f_3)==72);
    assert(e->f_0.f_0==NULL && e->f_0.f_1==0 && e->f_0.f_2==0 && e->f_0.f_3==0);
    assert(e->f_1.f_3==80 && e->f_2==e->f_1.f_0);
    /* Private C test hook only: execute final actual request ID and stop guard. */
    memset(e->f_2+16, 255, 8);e->f_2[16]=254;
    memset(e->f_2+32, 255, 8);e->f_2[32]=254;
}}
'''
        write(out/'layout-product.c',emitted+harness)
        # Exact pinned runtime Git objects, never current Fairy working-tree bytes.
        fairy = (ROOT/tc['source']['localRepository']).resolve()
        if not (fairy/'.git').exists():
            fairy = ROOT.parents[2]/'fairyc'  # ignored build/<mirror> layout
        runtime = ['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)\n']
        runtime_inputs = []
        for path in ['internal/cstdlib/'+n for n in ['stage0_system_heap.c','stage0_buffer.c',
                     'stage0_windows_console.c','stage0_windows_process_args.c','stage0_text_view.c']] + ['internal/cruntime/stage0_scalar.c']:
            blob=run(['git','-C',fairy,'show',tc['compiler']['revision']+':'+path],Path(path).stem).decode()
            runtime_inputs.append(dict(path=path,revision=tc['compiler']['revision'],sha256=sha(blob.encode())))
            if path.endswith('stage0_scalar.c'):
                for token,value in [('@TRAP_RECEIPT_INCLUDE@',''),('@TRAP_RECEIPT_WRITE@',''),('@TRAP_EXIT_BASE@','128')]:
                    need(blob.count(token)==1,'Scalar template changed');blob=blob.replace(token,value)
            runtime.append(blob)
        write(out/'runtime.c','\n'.join(runtime))
        receipt['runtimeInputs']=runtime_inputs
        pf=Path(os.environ['ProgramFiles(x86)'])
        vs=Path(run([pf/'Microsoft Visual Studio/Installer/vswhere.exe','-latest','-products','*','-requires',
                     'Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-property','installationPath'],'vswhere').decode().strip())
        mv=(vs/'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt').read_text().strip()
        msvc=vs/'VC/Tools/MSVC'/mv;cl=msvc/'bin/Hostx64/x64/cl.exe';kits=pf/'Windows Kits/10'
        sdks=sorted(p.name for p in (kits/'Include').iterdir() if p.name.startswith('10.') and all(
            (kits/q/p.name/sub).is_dir() for q,sub in [('Include','ucrt'),('Include','shared'),('Include','um'),('Lib','ucrt/x64'),('Lib','um/x64')]))
        need(bool(sdks),'Complete Windows SDK required');sdk=sdks[-1]
        env=dict(os.environ,PATH=str(cl.parent)+os.pathsep+os.environ['PATH'],
                 INCLUDE=os.pathsep.join(map(str,[msvc/'include']+[kits/'Include'/sdk/s for s in ['ucrt','shared','um']])),
                 LIB=os.pathsep.join(map(str,[msvc/'lib/x64']+[kits/'Lib'/sdk/s/'x64' for s in ['ucrt','um']])))
        receipt['nativeToolchain']=dict(msvc=mv,sdk=sdk,clSha256=sha(cl.read_bytes()))
        header=out/'inputs/probes/m2-buffer-failure/allocator_probe.h'
        for profile in profiles:
            objects=[]
            for label in ['layout-product','runtime']:
                obj=out/f'{label}-{profile}.obj'
                run([cl,'/nologo','/std:c11','/TC','/MT','/W4','/WX','/Od' if profile=='development' else '/O2',
                     *(['/FI'+str(header)] if label=='runtime' else []),
                     '/c',out/(label+'.c'),'/Fo:'+str(obj)],profile+'-'+label,env=env)
                objects.append(obj)
            exe=out/f'layout-{profile}.exe'
            run([cl,'/nologo','/MT',*objects,'/Fe:'+str(exe),'/link','/INCREMENTAL:NO','/Brepro'],profile+'-layout-link',env=env)
            counters=json.loads(run([exe],profile+'-layout-execute'))
            need(counters['live']==0 and counters['failures']==0 and counters['attempts']==counters['frees'], 'Layout ownership cleanup')
            receipt.setdefault('layout',[]).append(dict(profile=profile,executed=True,bufferBytes=32,
                exchangeBytes=7632,backingOffset=0,headerOffset=32,headerDataOffset=64,catalogOffset=72,identityMaximumExecuted=True,
                generatedSha256=sha(emitted.encode()),harnessSha256=sha(harness.encode()),exeSha256=sha(exe.read_bytes()),allocator=counters))
            print(f'PASS {profile}: generated-C layout assertions and actual identity exhaustion',flush=True)
        # Separate allocator seam. Production source remains byte-identical;
        # the generated test adapter only removes @test and exports test entrypoints.
        probe=source.replace('module tests::m2::host_exchange;', 'module host_exchange_probe;').replace('@test fn void ', 'pub fn void ')
        need(probe.count('pub fn void ')==len(selected), 'Exact mechanical test adapter')
        write(project/'src/host_exchange_probe.fy',probe)
        receipt['allocatorSeam']=dict(explicitCompilerArguments=True,environmentOverrides=False,
            stackOverrides=False,fixtureAdapter='module rename; @test fn -> pub fn only',
            fixtureSha256=sha(source.encode()),adapterSha256=sha(probe.encode()))
        for suffix,target in [('allocator_request_preparation_retains_state_and_explicit_resubmission_uses_id_one',320),
                              ('allocator_reply_preparation_retains_backing_fuel_counters_and_never_replays_adapter',384)]:
            main_source='module main;import host_exchange_probe as probe;fn i32 main(){probe::'+suffix+'();return 0;}\n'
            write(project/'src/main.fy',main_source)
            run([compiler,'check'],f'oom-{target}-lock',project)
            emitted_probe=run([compiler,'experimental','emit-workspace-c','--target','x86_64-windows-msvc','--locked'],
                f'oom-{target}-emit',project)
            probe_file=out/f'oom-{target}.c';write(probe_file,emitted_probe)
            for profile in profiles:
                obj=out/f'oom-{target}-{profile}.obj'
                run([cl,'/nologo','/std:c11','/TC','/MT','/W4','/WX','/Od' if profile=='development' else '/O2',
                     '/c',probe_file,'/Fo:'+str(obj)],f'{profile}-oom-{target}-compile',env=env)
                exe=out/f'oom-{target}-{profile}.exe'
                run([cl,'/nologo','/MT',obj,out/f'runtime-{profile}.obj','/Fe:'+str(exe),'/link','/INCREMENTAL:NO','/Brepro'],
                    f'{profile}-oom-{target}-link',env=env)
                runtime_env={k:v for k,v in os.environ.items() if k.upper() not in {'CL','_CL_','LINK'}}
                runtime_env['BROWNIE_BUFFER_FAIL_BYTES']=str(target)
                counters=json.loads(run([exe,'inject'],f'{profile}-oom-{target}-execute',env=runtime_env))
                need(counters['live']==0 and counters['target']==target and counters['targetAttempts']==2 and
                     counters['failures']==1 and counters['attempts']==counters['frees']+1, 'Explicit allocator seam rollback/leak proof')
                receipt.setdefault('allocator',[]).append(dict(profile=profile,target=target,counters=counters,
                    sourceSha256=sha(emitted_probe),exeSha256=sha(exe.read_bytes()),explicitClFI=True))
                print(f'PASS {profile}: explicit cl /FI allocator seam {target}; rollback and empty-source cleanup',flush=True)
        need(all((ROOT/p).read_bytes()==b for p,b in inputs.items()),'Inputs changed during verification')
        need(sha(compiler.read_bytes())==compiler_hash,'Compiler changed')
        receipt.update(status='passed',sourceDependencyClosure=closure(),
                       publicAvailabilityChanged=False,vmDispatchImplemented=False,r03ChunkBounds=False,
                       limitations=['Native coordinator only; no VM/Instance/HOST_REQUEST opcode, public ABI, broker, policy loader or thread registry.',
                         'Synchronous bounded copy with owner-supplied timestamps/charges; no mid-copy deadline checkpoint or R03 quantum evidence.',
                         'All nonfatal TLV envelopes (including scalar/empty byte reply headers) allocate; compact inline reply optimization remains.',
                         'Per-message/cumulative bytes and adapter budgets are logical limits, not complete Engine memory accounting.'])
    except Exception as error:
        receipt.update(status='failed',error=str(error))
        raise
    finally:
        # Every file retained under the run is independently hash-addressed.
        receipt['artifacts']=[dict(path=p.relative_to(out).as_posix(),sha256=sha(p.read_bytes()))
                              for p in sorted(out.rglob('*')) if p.is_file() and p.name!='receipt.json']
        write(out/'receipt.json',json.dumps(receipt,indent=2)+'\n')
        write(ROOT/'build/host-exchange/latest.json',json.dumps(dict(path=str(out/'receipt.json'),sha256=sha((out/'receipt.json').read_bytes())),indent=2)+'\n')
    print('Receipt: '+str(out/'receipt.json'),flush=True)


if __name__ == '__main__':
    main()
