"""Native reserved output tests plus explicit default-stack allocation/layout seams."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
ROOT=Path(__file__).resolve().parent.parent
FILES=['src/runtime_output.fy','src/fuel.fy','src/runtime_input.fy','tests/m2/runtime_io.fy','tests/m2/runtime_output_metered.fy','fairy.toml','toolchain.json','tools/verify-runtime-output-metered.py']
def sha(b):return hashlib.sha256(b).hexdigest()
def write(p,b):
 p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b.encode() if isinstance(b,str) else b)
def need(ok,msg):
 if not ok:raise RuntimeError(msg)
PERF=r'''module main;
import runtime_output as o;import std::bytes as bytes;
@link_name("output_probe") unsafe extern C fn void probe(i32 stage,ptr void t,ptr void p);
@link_name("output_seed") unsafe extern C fn void seed(ptr mut void t,i32 kind);
fn o::Transaction opened(usize limit,ref mut usize f){return switch(o::open_metered(limit,true,f)){
 case .ok(v):{v}case .err(_):{assert(false);opened(0,f)}};}
fn o::Published sealed(ref mut o::Transaction t,ref mut usize f){return switch(o::seal_metered(t,f)){
 case .ok(v):{v}case .err(_):{assert(false);sealed(t,f)}};}
fn void run(){
 var o::Transaction inactive=o::disabled();unsafe {probe(0,ref inactive as ptr void,null);}
 var usize f=16000000;var o::Transaction t=opened(1048576,ref mut f);
 unsafe {probe(1,ref t as ptr void,null);}
 let u8[256] chunk=[255;256];var usize i=0;
 while(i<4096){assert(o::emit_metered(ref mut t,ref chunk,ref mut f).is_ok);i+=1;}
 unsafe {probe(2,ref t as ptr void,null);}
 let o::Published p=sealed(ref mut t,ref mut f);
 unsafe {probe(3,ref t as ptr void,ref p as ptr void);}
 assert(f==9707520 && o::view(ref p).len==1048576);
 var o::Transaction cancelled=opened(16,ref mut f);assert(o::emit_metered(ref mut cancelled,b"secret",ref mut f).is_ok);
 discard o::cancel(ref mut cancelled);unsafe {probe(4,ref cancelled as ptr void,null);}
 var o::Transaction failed=opened(16,ref mut f);assert(o::emit_metered(ref mut failed,b"secret",ref mut f).is_ok);
 discard o::fail(ref mut failed);unsafe {probe(4,ref failed as ptr void,null);}
 var o::Transaction overflow=opened(4,ref mut f);unsafe {seed(ref mut overflow as ptr mut void,0);}
 let usize before=f;assert(!o::emit_metered(ref mut overflow,b"",ref mut f).is_ok && f==before);
 assert(!o::seal_metered(ref mut overflow,ref mut f).is_ok && f==before);
 assert(o::observe(ref overflow).charged==18446744073709551104 && o::observe(ref overflow).length==0);
 discard o::cancel(ref mut overflow);
 var o::Transaction count=opened(4,ref mut f);unsafe {seed(ref mut count as ptr mut void,1);}
 let usize count_before=f;assert(!o::emit_metered(ref mut count,b"",ref mut f).is_ok && f==count_before);
 assert(o::observe(ref count).emits==18446744073709551615);discard o::fail(ref mut count);
}
fn i32 main(){run();return 0;}
'''
HEADER_OOM=r'''module main;import runtime_output as o;
fn i32 main(){var usize f=10000;
 switch(o::open_metered(384,true,ref mut f)){case .ok(_):{assert(false);}case .err(e):{
 switch(e){case .Allocation:{}case .State:{assert(false);}case .Denied:{assert(false);}case .Limit:{assert(false);}case .Fuel:{assert(false);}};}};
 assert(f==10000);var o::Transaction t=switch(o::open_metered(384,true,ref mut f)){
 case .ok(v):{v}case .err(_):{assert(false);o::disabled()}};
 assert(f==8720 && o::observe(ref t).charged==1280);discard o::cancel(ref mut t);return 0;}
'''
PROBE=r'''#pragma once
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#pragma warning(push)
#pragma warning(disable:4505 4996)
static size_t probe_live,probe_attempts,probe_frees,probe_target,probe_hits,probe_copied;
static int probe_failed,probe_started;
static void probe_done(void){
 if(probe_live || (probe_target && !probe_failed))abort();
 printf("{\"live\":%zu,\"attempts\":%zu,\"frees\":%zu,\"target\":%zu,\"targetAttempts\":%zu,\"failures\":%d,\"copied\":%zu}\n",probe_live,probe_attempts,probe_frees,probe_target,probe_hits,probe_failed,probe_copied);
}
static void *probe_malloc(size_t n){
 if(!probe_started){const char *s=getenv("BROWNIE_OUTPUT_FAIL_BYTES");probe_target=s?(size_t)strtoull(s,NULL,10):0;
 if(atexit(probe_done))abort();probe_started=1;}
 probe_attempts++;
 if(probe_target==n){probe_hits++;if(!probe_failed){probe_failed=1;return NULL;}}
 void *p=malloc(n);if(p)probe_live++;return p;
}
static void probe_free(void *p){if(p){if(!probe_live)abort();probe_live--;probe_frees++;}free(p);}
static void *probe_move(void *d,const void *s,size_t n){probe_copied+=n;return memmove(d,s,n);}
#define FY_STD_SYSTEM_HEAP_MALLOC_V0(n) probe_malloc(n)
#define FY_STD_SYSTEM_HEAP_FREE_V0(p) probe_free(p)
#pragma warning(pop)
'''
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--compiler',type=Path,default=ROOT/'build/toolchain/fairyc.exe')
 ap.add_argument('--fairyc-repo',type=Path,default=ROOT/'../fairyc');args=ap.parse_args()
 need(os.name=='nt' and __debug__,'Windows and enabled Python assertions required')
 need(not any(k.upper() in {'CL','_CL_','LINK'} for k in os.environ),'No compiler overrides')
 compiler=args.compiler.resolve(strict=True);tc=json.loads((ROOT/'toolchain.json').read_bytes())
 need(sha(compiler.read_bytes())==tc['platforms']['windows/amd64']['sha256'],'Pinned compiler hash')
 out=ROOT/'build/runtime-output-metered'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out.mkdir(parents=True)
 receipt=dict(schema='browniec.runtime-output-metered/v1',status='incomplete',commands=[],native=[],seams=[],defaultStacks=True,stackOverrides=False,environmentOverrides=False,compilerSha256=sha(compiler.read_bytes()))
 inputs={p:(ROOT/p).read_bytes() for p in FILES};receipt['inputs']=[dict(path=p,sha256=sha(b)) for p,b in inputs.items()]
 def run(cmd,label,cwd=out,env=None,expected=0):
  cmd=list(map(str,cmd));need(not any('/STACK' in a.upper() for a in cmd),'Default stacks only')
  p=subprocess.run(cmd,cwd=cwd,env=env,capture_output=True,timeout=600)
  prefix=f'{len(receipt["commands"]):03}-{label}';write(out/(prefix+'.stdout'),p.stdout);write(out/(prefix+'.stderr'),p.stderr)
  receipt['commands'].append(dict(argv=cmd,cwd=str(cwd),exit=p.returncode,stdout=prefix+'.stdout',stderr=prefix+'.stderr',stdoutSha256=sha(p.stdout),stderrSha256=sha(p.stderr)))
  need(p.returncode==expected if expected is not None else p.returncode!=0,f'{label}: {p.returncode}: {p.stderr[-1800:]!r} {p.stdout[-1800:]!r}')
  if expected==0:need(not p.stderr,label+': unexpected stderr')
  return p.stdout
 try:
  version=run([compiler,'--version'],'version').decode();need(tc['compiler']['revision'] in version,'Compiler revision');receipt['compilerVersion']=version
  project=out/'project'
  for p,b in inputs.items():write(out/'inputs'/p,b)
  for p,b in inputs.items():
   if p.endswith('.fy') or p=='fairy.toml':write(project/p,b)
  write(project/'src/main.fy','module main;fn i32 main(){return 0;}\n');run([compiler,'check'],'lock',project)
  sdk=[p for p in json.loads((project/'fairy.lock').read_bytes())['packages'] if p['role']!='root']
  need(len(sdk)==1 and sdk[0]['sourceDigest']==tc['sdk']['sourceDigest'],'SDK hash');receipt['sdk']=sdk
  selected=[]
  for path in ['tests/m2/runtime_io.fy','tests/m2/runtime_output_metered.fy']:
   names=re.findall(r'@test\s+fn void (\w+)\(',inputs[path].decode());need(len(names)==(10 if path.endswith('runtime_io.fy') else 8),'Group inventory')
   selected += ['tests::m2::'+Path(path).stem+'::'+n for n in names]
  for profile in ['development','release']:
   cmd=[compiler,'test','--native','--json','--capture-output','--locked']
   if profile=='release':cmd+=['--release']
   for n in selected:cmd+=['--exact',n]
   report=json.loads(run(cmd,profile+'-native',project))
   need(report['status']=='ok' and report['passed']==report['count']==18 and report['failed']==0 and report['lock']=='verified' and {t['identity'] for t in report['tests']}==set(selected),'Native report')
   need(all(t['trapCategory'] is None and not t['stdoutBase64'] and not t['stderrBase64'] for t in report['tests']),'Clean tests')
   receipt['native'].append(dict(profile=profile,groups=18));print('PASS '+profile+': unchanged 10 + metered 8 groups',flush=True)
  for label,body in {'private-reserved':'fn void bad(ref mut o::Transaction t){t.reserved=false;}','private-staged':'fn void bad(ref o::Transaction t){discard o::staged(t);}'}.items():
   write(project/'src/negative.fy','module negative;import runtime_output as o;'+body+'\n');run([compiler,'check'],label,project,expected=None)
   diag=(out/receipt['commands'][-1]['stderr']).read_bytes();need(b'E0103' in diag or b'E0101' in diag,'Visibility diagnostic');(project/'src/negative.fy').unlink()
  runtime=['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)\n'];receipt['runtimeInputs']=[]
  for path in ['internal/cstdlib/'+n for n in ['stage0_system_heap.c','stage0_buffer.c','stage0_windows_console.c','stage0_windows_process_args.c']]+['internal/cruntime/stage0_scalar.c']:
   blob=run(['git','-C',args.fairyc_repo.resolve(),'show',tc['compiler']['revision']+':'+path],Path(path).stem).decode();receipt['runtimeInputs'].append(dict(path=path,sha256=sha(blob.encode())))
   if path.endswith('stage0_scalar.c'):
    for token,value in [('@TRAP_RECEIPT_INCLUDE@',''),('@TRAP_RECEIPT_WRITE@',''),('@TRAP_EXIT_BASE@','128')]:blob=blob.replace(token,value)
   if path.endswith('stage0_buffer.c'):blob=blob.replace('memmove(','probe_move(')
   runtime.append(blob)
  write(out/'probe.h',PROBE);pf=Path(os.environ['ProgramFiles(x86)'])
  vs=Path(run([pf/'Microsoft Visual Studio/Installer/vswhere.exe','-latest','-products','*','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-property','installationPath'],'vswhere').decode().strip())
  mv=(vs/'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt').read_text().strip();msvc=vs/'VC/Tools/MSVC'/mv;cl=msvc/'bin/Hostx64/x64/cl.exe';kits=pf/'Windows Kits/10'
  sdk=sorted(p.name for p in (kits/'Include').iterdir() if p.name.startswith('10.') and all((kits/q/p.name/s).is_dir() for q,s in [('Include','ucrt'),('Include','shared'),('Include','um'),('Lib','ucrt/x64'),('Lib','um/x64')]))[-1]
  env=dict(os.environ,PATH=str(cl.parent)+os.pathsep+os.environ['PATH'],INCLUDE=os.pathsep.join(map(str,[msvc/'include']+[kits/'Include'/sdk/s for s in ['ucrt','shared','um']])),LIB=os.pathsep.join(map(str,[msvc/'lib/x64']+[kits/'Lib'/sdk/s/'x64' for s in ['ucrt','um']])))
  receipt['nativeToolchain']=dict(msvc=mv,sdk=sdk,clSha256=sha(cl.read_bytes()))
  def emit(main_source,label):
   write(project/'src/main.fy',main_source);run([compiler,'check'],label+'-lock',project)
   return run([compiler,'experimental','emit-workspace-c','--target','x86_64-windows-msvc','--locked'],label+'-emit',project).decode()
  emitted=emit(PERF,'performance');resources=re.findall(r'typedef struct\s*\{([^{}]*)\}\s*(fy_resource_\d+);',emitted,re.S);types={n:re.sub(r'\s+','',b) for b,n in resources}
  def one(c):need(len(c)==1,'Unique generated type');return c[0]
  bn=one([n for n,b in types.items() if b=='void*f_0;uintptr_tf_1;uintptr_tf_2;uintptr_tf_3;'])
  tn=one([n for n,b in types.items() if b==bn+'f_0;'+bn+'f_1;uint8_t*f_2;uintptr_tf_3;int32_tf_4;int32_tf_5;uintptr_tf_6;uintptr_tf_7;int32_tf_8;'])
  pn=one([n for n,b in types.items() if b.startswith(bn+'f_0;fy_struct_')])
  harness=f'''
#include <assert.h>
_Static_assert(sizeof({bn})==32 && offsetof({bn},f_3)==24,"Buffer seam");
_Static_assert(sizeof({tn})==112 && offsetof({tn},f_0)==0 && offsetof({tn},f_1)==32 && offsetof({tn},f_2)==64 && offsetof({tn},f_3)==72 && offsetof({tn},f_4)==80 && offsetof({tn},f_5)==84 && offsetof({tn},f_6)==88 && offsetof({tn},f_7)==96 && offsetof({tn},f_8)==104,"Transaction actual layout");
_Static_assert(sizeof({pn})==72 && offsetof({pn},f_0)==0 && offsetof({pn},f_1)==32,"Published actual layout");
size_t output_probe_attempts(void);size_t output_probe_copied(void);
void output_probe(int32_t stage,const void *tx,const void *pub){{
 const {tn} *t=(const {tn}*)tx;
 if(stage==0){{assert(output_probe_attempts()==0 && t->f_2==NULL && t->f_0.f_0==NULL && t->f_1.f_0==NULL);return;}}
 assert(t->f_1.f_3==40 && t->f_2==t->f_1.f_0);
 if(stage==1 || stage==2){{assert(output_probe_attempts()==2 && t->f_0.f_1==1048576 && t->f_5==1);
 assert(t->f_0.f_3==(stage==1?0:1048576));assert(output_probe_copied()==(stage==1?0:1048576));}}
 if(stage==3 || stage==4){{assert(t->f_0.f_0==NULL && t->f_0.f_1==0 && t->f_0.f_2==0 && t->f_0.f_3==0);}}
 if(stage==3){{const {pn} *p=(const {pn}*)pub;assert(p->f_0.f_3==1048576 && p->f_0.f_1==1048576 && t->f_2[0]==1);assert(output_probe_attempts()==2 && output_probe_copied()==1048576);}}
 if(stage==4){{assert(t->f_2[0]==2 || t->f_2[0]==3);}}
}}
void output_seed(void *tx,int32_t kind){{{tn} *t=({tn}*)tx;uint64_t n=kind?UINT64_MAX:UINT64_MAX-511;memcpy(t->f_2+(kind?16:32),&n,8);}}
'''
  write(out/'performance.c',emitted+harness)
  for stem in ['runtime_io','runtime_output_metered']:
   source=inputs['tests/m2/'+stem+'.fy'].decode().replace('module tests::m2::'+stem+';','module '+stem+'_probe;').replace('@test fn void ','pub fn void ');write(project/'src'/(stem+'_probe.fy'),source)
  cases=[('header-oom',40,HEADER_OOM),('reserve-oom',384,'runtime_output_metered_probe','allocator_open_failure_preserves_fuel_and_existing_transaction'),('legacy-input-oom',320,'runtime_io_probe','allocator_input_snapshot_failure_preserves_existing_owner_bytes_and_fuel'),('legacy-output-oom',384,'runtime_io_probe','allocator_append_failure_preserves_prefix_observations_and_explicit_resubmission')]
  for case in cases:
   name,target=case[:2];main_source=case[2] if len(case)==3 else 'module main;import '+case[2]+' as p;fn i32 main(){p::'+case[3]+'();return 0;}\n';write(out/(name+'.c'),emit(main_source,name))
  for profile in ['development','release']:
   opt='/Od' if profile=='development' else '/O2';runtime_path=out/(profile+'-runtime.c')
   write(runtime_path,'\n'.join(runtime)+'\nsize_t output_probe_attempts(void){return probe_attempts;}\nsize_t output_probe_copied(void){return probe_copied;}\n');obj=out/(profile+'-runtime.obj')
   run([cl,'/nologo','/std:c11','/TC','/MT','/W4','/WX',opt,'/FI'+str(out/'probe.h'),'/c',runtime_path,'/Fo:'+str(obj)],profile+'-runtime',env=env)
   for name,target in [('performance',0)]+[(c[0],c[1]) for c in cases]:
    product_obj=out/(name+'-'+profile+'.obj');exe=out/(name+'-'+profile+'.exe')
    run([cl,'/nologo','/std:c11','/TC','/MT','/W4','/WX',opt,'/c',out/(name+'.c'),'/Fo:'+str(product_obj)],name+'-'+profile+'-compile',env=env)
    run([cl,'/nologo','/MT',product_obj,obj,'/Fe:'+str(exe),'/link','/INCREMENTAL:NO','/Brepro'],name+'-'+profile+'-link',env=env)
    child=dict(os.environ);child.pop('BROWNIE_OUTPUT_FAIL_BYTES',None)
    if target:child['BROWNIE_OUTPUT_FAIL_BYTES']=str(target)
    counters=json.loads(run([exe]+(['inject'] if target else []),name+'-'+profile+'-run',env=child))
    need(counters['live']==0 and counters['failures']==(1 if target else 0) and counters['attempts']==counters['frees']+counters['failures'],'Allocator balance')
    if target:need(counters['target']==target and counters['targetAttempts']==2,'One failure and explicit resubmission')
    receipt['seams'].append(dict(name=name,profile=profile,counters=counters,exeSha256=sha(exe.read_bytes())));print('PASS '+profile+': '+name,flush=True)
  need(all((ROOT/p).read_bytes()==b for p,b in inputs.items()),'Inputs changed during run')
  receipt.update(status='passed',performance=dict(emits=4096,payloadBytes=1048576,allocationsAtOpen=2,allocationsDuringEmitAndSeal=0,copiedBytes=1048576,bufferBytes=32,transactionBytes=112,publishedBytes=72),limitations=['Private native output; VM/Engine integration belongs to owner tests.','Trusted-owner publication; no external sink atomicity or latency guarantee.','Overflow seeded through test-only generated header; no production mutation API.'])
 except Exception as error:receipt.update(status='failed',error=str(error));raise
 finally:
  receipt['artifacts']=[dict(path=p.relative_to(out).as_posix(),sha256=sha(p.read_bytes())) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='receipt.json'];write(out/'receipt.json',json.dumps(receipt,indent=2)+'\n');print('Receipt: '+str(out/'receipt.json'),flush=True)
if __name__=='__main__':main()
