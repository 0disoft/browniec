"""Verify private owning I/O using native tests and explicit default-stack C seams."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BASE = 'f78a734fd079324e0ba88bb8e40e4291acf55de8'
FILES = ['src/runtime_input.fy', 'src/runtime_output.fy', 'tests/m2/runtime_io.fy',
         'tools/verify-runtime-io.py', 'docs/engineering/runtime-io.md', 'src/fuel.fy']
LAYOUT_MAIN = r'''module main;
import runtime_input as input;import runtime_output as output;
@link_name("brownie_runtime_io_layout") unsafe extern C fn void layout(ptr void t,ptr void i,ptr void p);
fn i32 main(){
 var usize fuel=10;
 let input::Snapshot i=switch(input::snapshot(b"\x00a\xff\x00",4,1,ref mut fuel)){
  case .ok(v):{v}case .err(_):{assert(false);return 1;}};
 var output::Transaction t=switch(output::open(4,true,fuel)){
  case .ok(v):{v}case .err(_):{assert(false);return 1;}};
 assert(output::emit(ref mut t,input::view(ref i),1).is_ok);
 let output::Published p=switch(output::seal(ref mut t,1)){
  case .ok(v):{v}case .err(_):{assert(false);return 1;}};
 unsafe {layout(ref t as ptr void,ref i as ptr void,ref p as ptr void);}
 assert(output::observe(ref t).phase==1 && output::published_observation(ref p).fuel==7);
 return 0;
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--native-from',type=Path,help='Reuse matching current-session normal reports; rerun every ownership/layout/OOM seam.')
    parser.add_argument('--compiler', type=Path, default=ROOT/'build/toolchain/fairyc.exe')
    args = parser.parse_args()
    need(__debug__ and os.name=='nt', 'Windows x64; Python assertions required')
    need(not any(k.upper() in {'CL','_CL_','LINK'} for k in os.environ), 'Compiler environment overrides prohibited')
    out=ROOT/'build/runtime-io'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    receipt=dict(schema='browniec.runtime-io/v1',status='incomplete',baseCommit=BASE,
        recordedAt=datetime.now(timezone.utc).isoformat(),commands=[],native=[],layout=[],allocator=[],
        environmentOverrides=False,stackOverrides=False,defaultStacks=True,historicalResultReuse=False)
    compiler=args.compiler.resolve(strict=True)

    def run(argv,label,cwd=out,env=None,expected=0):
        argv=list(map(str,argv))
        need(not any('/STACK' in a.upper() for a in argv), 'Stack override prohibited')
        need(env is None or not any(k.upper() in {'CL','_CL_','LINK'} for k in env), 'Child compiler overrides prohibited')
        p=subprocess.run(argv,cwd=cwd,env=env,capture_output=True,timeout=600)
        name=f'{len(receipt["commands"]):03}-{label}'
        write(out/(name+'.stdout'),p.stdout);write(out/(name+'.stderr'),p.stderr)
        receipt['commands'].append(dict(argv=argv,cwd=str(cwd),exit=p.returncode,
            stdout=name+'.stdout',stderr=name+'.stderr',stdoutSha256=sha(p.stdout),stderrSha256=sha(p.stderr)))
        need((p.returncode==expected if expected is not None else p.returncode!=0),f'{label}: {p.returncode}; {p.stderr[-2500:]!r}; {p.stdout[-1500:]!r}')
        if expected==0:need(not p.stderr,f'{label}: unexpected stderr')
        return p.stdout

    try:
        tc=json.loads((ROOT/'toolchain.json').read_bytes());compiler_sha=sha(compiler.read_bytes())
        need(compiler_sha==tc['platforms']['windows/amd64']['sha256'],'Pinned compiler SHA-256')
        version=run([compiler,'--version'],'compiler-version').decode()
        need(tc['compiler']['revision'] in version and tc['sdk']['version'] in version,'Compiler/SDK identity')
        receipt['compiler']=dict(sha256=compiler_sha,version=version)
        paths=sorted(set(FILES+['fairy.toml','fairy.lock','toolchain.json','probes/m2-buffer-failure/allocator_probe.h']))
        inputs={p:(ROOT/p).read_bytes() for p in paths}
        need(all(b'\r' not in b for p,b in inputs.items() if p.endswith(('.fy','.py','.md'))),'LF inputs required')
        receipt['inputs']=[dict(path=p,sha256=sha(b)) for p,b in inputs.items()]
        for p,b in inputs.items():write(out/'inputs'/p,b)
        project=out/'project'
        for p in FILES[:3]+['src/fuel.fy','fairy.toml']:write(project/p,inputs[p])
        write(project/'src/main.fy','module main;fn i32 main(){return 0;}\n')
        run([compiler,'check'],'mirror-lock',project)
        lock=(project/'fairy.lock').read_bytes();sdk=[p for p in json.loads(lock)['packages'] if p['role']!='root']
        need(len(sdk)==1 and all(sdk[0][a]==tc['sdk'][b] for a,b in
            [('sdkIdentity','identity'),('version','version'),('sourceDigest','sourceDigest')]),'Pinned base SDK lock')
        receipt['nativeLockSha256']=sha(lock);receipt['nativeSdk']=sdk
        source=inputs['tests/m2/runtime_io.fy'].decode()
        selected=['tests::m2::runtime_io::'+n for n in re.findall(r'@test\s+fn void (\w+)\(',source)]
        need(len(selected)==len(set(selected))==10,'Focused native group inventory')
        profiles=['development','release'] if args.profile=='all' else [args.profile]
        reused=None
        if args.native_from:
            previous=args.native_from.resolve(strict=True);reused=json.loads(previous.read_bytes())
            need(reused['compiler']['sha256']==compiler_sha and reused['environmentOverrides'] is False and
                reused['stackOverrides'] is False and reused['defaultStacks'] is True,'Reusable native compiler/stack identity')
            old={i['path']:i['sha256'] for i in reused['inputs']}
            need(all(old.get(p)==sha(inputs[p]) for p in FILES[:3]+['fairy.toml','toolchain.json']),'Reusable source/test hashes')
            receipt['normalNativeReuse']=dict(receipt=str(previous),sha256=sha(previous.read_bytes()),
                scope='Only current-session matching normal reports; all seams rerun')
        for profile in profiles:
            if reused:
                candidates=[c for c in reused['commands'] if c['stdout'].endswith(profile+'-native.stdout')]
                need(len(candidates)==1,'Exactly one normal command per profile required');c=candidates[0]
                raw=(previous.parent/c['stdout']).read_bytes()
                need(c['exit']==0 and sha(raw)==c['stdoutSha256'] and not (previous.parent/c['stderr']).read_bytes(),'Native report integrity')
                write(out/(profile+'-native-reused.json'),raw)
            else:
                cmd=[compiler,'test','--native','--json','--capture-output','--locked']
                if profile=='release':cmd.append('--release')
                for identity in selected:cmd+=['--exact',identity]
                raw=run(cmd,profile+'-native',project)
            report=json.loads(raw)
            need(report['schemaVersion']=='fairyc.test-report/v4' and report['engine']=='native' and
                report['profile']==profile and report['lock']=='verified' and report['status']=='ok' and
                report['count']==report['passed']==len(selected) and report['failed']==0 and
                {t['identity'] for t in report['tests']}==set(selected),'Exact native passes required')
            need(all(t['outcome']=='passed' and t['trapCategory'] is None and not t['stdoutBase64'] and not t['stderrBase64']
                for t in report['tests']),'Native failure/output')
            receipt['native'].append(dict(profile=profile,groups=len(selected),reportSha256=sha(raw)))
            print(f'PASS {profile}: {len(selected)} actual native I/O groups',flush=True)

        negatives={
            'private-stage': 'fn void bad(ref mut o::Transaction t){t.limit=0;}',
            'private-forged-published': 'fn o::Published bad(){return o::Published{.backing=bytes::empty(),.final=o::Observation{.phase=1,.length=0,.emits=0,.fuel=0,.charged=0}};}',
            'private-staging-view': 'fn void bad(ref o::Transaction t){discard o::staged(t);}',
            'private-input': 'fn void bad(ref mut i::Snapshot s){s.charged=0;}',
            'private-published': 'fn void bad(ref mut o::Published p){p.final=o::published_observation(p);}',
            'immutable-published-view': 'fn void bad(ref o::Published p){let ref mut u8[] v=ref mut o::view(p);v[0]=0;}',
            'input-lifetime': 'fn ref u8[] bad(){var usize fuel=0;let i::Snapshot s=switch(i::snapshot(b"x",1,0,ref mut fuel)){case .ok(v):{v}case .err(_):{return b"";}};return i::view(ref s);}',
        }
        for label,body in negatives.items():
            write(project/'src/negative.fy','module negative;import runtime_input as i;import runtime_output as o;import std::bytes as bytes;'+body+'\n')
            run([compiler,'check'],label,project,expected=None)
            diagnostic=(out/receipt['commands'][-1]['stderr']).read_bytes()
            need((b'E0103' in diagnostic or b'E0101' in diagnostic) if label.startswith('private-') else
                 any(code in diagnostic for code in [b'E1008',b'E2101',b'E2102']), 'Expected ownership/visibility diagnostic: '+label)
            (project/'src/negative.fy').unlink()
        run([compiler,'check'],'restored-lock',project)

        # Actual generated types, not hand-written C copies. Test-only hook just
        # asserts layout/empty-source invariants after actual Fairy seal.
        write(project/'src/main.fy',LAYOUT_MAIN);run([compiler,'check'],'layout-lock',project)
        emitted=run([compiler,'experimental','emit-workspace-c','--target','x86_64-windows-msvc','--locked'],'layout-emit',project).decode()
        write(out/'generated.c',emitted)
        resources=re.findall(r'typedef struct\s*\{([^{}]*)\}\s*(fy_resource_\d+);',emitted,re.S)
        normalized={n:re.sub(r'\s+','',b) for b,n in resources}
        matches=[n for n,b in normalized.items() if b=='void*f_0;uintptr_tf_1;uintptr_tf_2;uintptr_tf_3;']
        need(len(matches)==1,'Generated Buffer type');bn=matches[0]
        matches=[n for n,b in normalized.items() if b==bn+'f_0;uintptr_tf_1;']
        need(len(matches)==1,'Generated Snapshot type');sn=matches[0]
        matches=[n for n,b in normalized.items() if b==bn+'f_0;'+bn+'f_1;uint8_t*f_2;uintptr_tf_3;int32_tf_4;int32_tf_5;']
        need(len(matches)==1,'Generated Transaction type');tn=matches[0]
        matches=[n for n,b in normalized.items() if b.startswith(bn+'f_0;fy_struct_')]
        need(len(matches)==1,'Generated Published type');pn=matches[0]
        harness=f'''
#include <assert.h>
_Static_assert(sizeof({bn})==32, "Buffer size");
_Static_assert(offsetof({bn},f_0)==0 && offsetof({bn},f_1)==8 && offsetof({bn},f_2)==16 && offsetof({bn},f_3)==24, "Buffer cells");
_Static_assert(sizeof({sn})==40 && offsetof({sn},f_0)==0 && offsetof({sn},f_1)==32, "Snapshot layout");
_Static_assert(sizeof({tn})==88, "Transaction size");
_Static_assert(offsetof({tn},f_0)==0 && offsetof({tn},f_1)==32 && offsetof({tn},f_2)==64 && offsetof({tn},f_3)==72 && offsetof({tn},f_4)==80 && offsetof({tn},f_5)==84, "Transaction fields");
_Static_assert(sizeof({pn})==72 && offsetof({pn},f_0)==0 && offsetof({pn},f_1)==32, "Published layout");
void brownie_runtime_io_layout(const void *tx,const void *in,const void *pub) {{
 const {tn} *t=(const {tn}*)tx;const {sn} *i=(const {sn}*)in;const {pn} *p=(const {pn}*)pub;
 assert(sizeof({bn})==32 && sizeof({sn})==40 && sizeof({tn})==88 && sizeof({pn})==72);
 assert(offsetof({tn},f_0)==0 && offsetof({tn},f_1)==32 && offsetof({tn},f_2)==64 && offsetof({tn},f_3)==72 && offsetof({tn},f_4)==80);
 assert(t->f_0.f_0==NULL && t->f_0.f_1==0 && t->f_0.f_2==0 && t->f_0.f_3==0);
 assert(t->f_1.f_3==40 && t->f_2==t->f_1.f_0 && t->f_2[0]==1);
 assert(i->f_0.f_3==4 && i->f_1==1 && p->f_0.f_3==4);
 assert(memcmp(i->f_0.f_0,p->f_0.f_0,4)==0);
 assert(((const unsigned char*)p->f_0.f_0)[0]==0 && ((const unsigned char*)p->f_0.f_0)[2]==255);
}}
'''
        write(out/'layout.c',emitted+harness)
        fairy=(ROOT/tc['source']['localRepository']).resolve()
        if not (fairy/'.git').exists():fairy=ROOT.parents[2]/'fairyc'
        runtime=['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)\n'];receipt['runtimeInputs']=[]
        for path in ['internal/cstdlib/'+n for n in ['stage0_system_heap.c','stage0_buffer.c','stage0_windows_console.c',
                      'stage0_windows_process_args.c']] + ['internal/cruntime/stage0_scalar.c']:
            blob=run(['git','-C',fairy,'show',tc['compiler']['revision']+':'+path],Path(path).stem).decode()
            receipt['runtimeInputs'].append(dict(path=path,revision=tc['compiler']['revision'],sha256=sha(blob.encode())))
            if path.endswith('stage0_scalar.c'):
                for token,value in [('@TRAP_RECEIPT_INCLUDE@',''),('@TRAP_RECEIPT_WRITE@',''),('@TRAP_EXIT_BASE@','128')]:
                    need(blob.count(token)==1,'Scalar template changed');blob=blob.replace(token,value)
            runtime.append(blob)
        write(out/'runtime.c','\n'.join(runtime))
        pf=Path(os.environ['ProgramFiles(x86)'])
        vs=Path(run([pf/'Microsoft Visual Studio/Installer/vswhere.exe','-latest','-products','*','-requires',
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-property','installationPath'],'vswhere').decode().strip())
        mv=(vs/'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt').read_text().strip();msvc=vs/'VC/Tools/MSVC'/mv
        cl=msvc/'bin/Hostx64/x64/cl.exe';kits=pf/'Windows Kits/10'
        sdks=sorted(p.name for p in (kits/'Include').iterdir() if p.name.startswith('10.') and all((kits/q/p.name/sub).is_dir()
            for q,sub in [('Include','ucrt'),('Include','shared'),('Include','um'),('Lib','ucrt/x64'),('Lib','um/x64')]))
        need(bool(sdks),'Complete Windows SDK');sdk=sdks[-1]
        env=dict(os.environ,PATH=str(cl.parent)+os.pathsep+os.environ['PATH'],
            INCLUDE=os.pathsep.join(map(str,[msvc/'include']+[kits/'Include'/sdk/s for s in ['ucrt','shared','um']])),
            LIB=os.pathsep.join(map(str,[msvc/'lib/x64']+[kits/'Lib'/sdk/s/'x64' for s in ['ucrt','um']])))
        receipt['nativeToolchain']=dict(msvc=mv,sdk=sdk,clSha256=sha(cl.read_bytes()))
        header=out/'inputs/probes/m2-buffer-failure/allocator_probe.h'

        def compile_product(source_file,name,profile):
            obj=out/f'{name}-{profile}.obj'
            run([cl,'/nologo','/std:c11','/TC','/MT','/W4','/WX','/Od' if profile=='development' else '/O2',
                '/c',source_file,'/Fo:'+str(obj)],name+'-'+profile+'-compile',env=env)
            exe=out/f'{name}-{profile}.exe'
            run([cl,'/nologo','/MT',obj,out/f'runtime-{profile}.obj','/Fe:'+str(exe),'/link','/INCREMENTAL:NO','/Brepro'],
                name+'-'+profile+'-link',env=env)
            return exe

        for profile in profiles:
            run([cl,'/nologo','/std:c11','/TC','/MT','/W4','/WX','/Od' if profile=='development' else '/O2',
                '/FI'+str(header),'/c',out/'runtime.c','/Fo:'+str(out/f'runtime-{profile}.obj')],profile+'-runtime-explicit-FI',env=env)
            exe=compile_product(out/'layout.c','layout',profile)
            counters=json.loads(run([exe],profile+'-layout-execute'))
            need(counters['live']==0 and counters['failures']==0 and counters['attempts']==counters['frees'],'Layout/source-zero cleanup')
            receipt['layout'].append(dict(profile=profile,executed=True,bufferBytes=32,snapshotBytes=40,transactionBytes=88,
                publishedBytes=72,backingOffset=0,headerOffset=32,headerDataOffset=64,
                emptyMovedSourceVerified=True,allocator=counters,exeSha256=sha(exe.read_bytes())))
            print(f'PASS {profile}: actual generated layout and moved-source cleanup',flush=True)

        probe=source.replace('module tests::m2::runtime_io;','module runtime_io_probe;').replace('@test fn void ','pub fn void ')
        need(probe.count('pub fn void ')==len(selected),'Mechanical test adapter only')
        write(project/'src/runtime_io_probe.fy',probe)
        receipt['allocatorSeam']=dict(explicitClFI=True,environmentOverrides=False,stackOverrides=False,
            adapter='Test module rename and @test fn -> pub fn only',adapterSha256=sha(probe.encode()))
        for suffix,target in [('allocator_input_snapshot_failure_preserves_existing_owner_bytes_and_fuel',320),
            ('allocator_append_failure_preserves_prefix_observations_and_explicit_resubmission',384)]:
            write(project/'src/main.fy','module main;import runtime_io_probe as p;fn i32 main(){p::'+suffix+'();return 0;}\n')
            run([compiler,'check'],f'oom-{target}-lock',project)
            emitted_probe=run([compiler,'experimental','emit-workspace-c','--target','x86_64-windows-msvc','--locked'],f'oom-{target}-emit',project)
            path=out/f'oom-{target}.c';write(path,emitted_probe)
            for profile in profiles:
                exe=compile_product(path,f'oom-{target}',profile)
                runtime_env=dict(os.environ,BROWNIE_BUFFER_FAIL_BYTES=str(target))
                counters=json.loads(run([exe,'inject'],f'oom-{target}-{profile}-execute',env=runtime_env))
                need(counters['live']==0 and counters['target']==target and counters['targetAttempts']==2 and counters['failures']==1 and
                    counters['attempts']==counters['frees']+1,'Actual OOM rollback/no hidden retry/cleanup')
                receipt['allocator'].append(dict(profile=profile,target=target,counters=counters,exeSha256=sha(exe.read_bytes())))
                print(f'PASS {profile}: explicit /FI OOM seam {target}, rollback and zero live allocations',flush=True)
        need(all((ROOT/p).read_bytes()==b for p,b in inputs.items()),'Inputs changed during verification')
        need(sha(compiler.read_bytes())==compiler_sha,'Compiler changed')
        receipt.update(status='passed',publicAvailabilityChanged=False,vmSuccessImplemented=False,
            limitations=['Private native snapshots/staging/seal only; no Instance, guest opcode/emit, CLI, file/stdin or sinks.',
                'Caller supplies trusted Fuel charges and seal decision; no connected guest schedule or full Engine accounting.',
                'Synchronous bounded copies; no R03 per-step/chunk or allocator latency guarantee.',
                'Append copies the whole existing prefix plus suffix; zero-copy append optimization is not claimed.'])
    except Exception as error:
        receipt.update(status='failed',error=str(error));raise
    finally:
        receipt['artifacts']=[dict(path=p.relative_to(out).as_posix(),sha256=sha(p.read_bytes())) for p in sorted(out.rglob('*'))
            if p.is_file() and p.name!='receipt.json']
        write(out/'receipt.json',json.dumps(receipt,indent=2)+'\n')
        write(ROOT/'build/runtime-io/latest.json',json.dumps(dict(path=str(out/'receipt.json'),sha256=sha((out/'receipt.json').read_bytes())),indent=2)+'\n')
    print('Receipt: '+str(out/'receipt.json'),flush=True)


if __name__=='__main__':
    main()
