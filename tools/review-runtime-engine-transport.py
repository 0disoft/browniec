"""Emit a pinned private transport candidate, including all declarations/layouts.

Review build/engine-input-transport-review/candidate-transport.json first; use
--write-contract to replace the local reviewed contract after inspecting changes.
"""
import argparse
args_parser=argparse.ArgumentParser(description=__doc__)
args_parser.add_argument('--write-contract',action='store_true')
review_options=args_parser.parse_args()
import importlib.util, json, re, subprocess, hashlib
from pathlib import Path
root=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('engine',root/'tools/verify-runtime-engine.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
folder=root/'build/engine-input-transport-review'
project=folder/'project';project.mkdir(parents=True,exist_ok=True)
(project/'src').mkdir(exist_ok=True)
if not (project/'src').resolve().is_relative_to((root/'build').resolve()):
 raise RuntimeError('Review source path escaped build directory')
for f in (project/'src').glob('*.fy'): f.unlink()
(project/'fairy.toml').write_bytes((root/'fairy.toml').read_bytes())
sources=m.closure()
for f in sources:
 name,raw=m.source_copy(f)
 (project/'src'/name).write_bytes(raw)
compiler=root/'build/toolchain/fairyc.exe'
contract=json.loads((root/'native/runtime-engine/transport.json').read_bytes())
m.need(hashlib.sha256(compiler.read_bytes()).hexdigest()==contract['compilerSha256'], 'Pinned compiler binary changed')
for args in [['check'],['experimental','emit-workspace-c','--target','x86_64-windows-msvc','--locked']]:
 r=subprocess.run([str(compiler),*args],cwd=project,capture_output=True)
 if r.returncode: print(r.stderr.decode());raise SystemExit(r.returncode)
 if args==['check']:print(r.stdout.decode())
 else:generated=r.stdout
(folder/'generated.c').write_bytes(generated)
t=generated.decode('utf-8')
c=json.loads((root/'native/runtime-engine/transport.json').read_bytes())
c['bindings']={}
for number,tail in re.findall(r'bc_runtime_engine_binding\(UINT32_C\((\d+)\)\);(.*?)(?=bc_runtime_engine_binding|\Z)',t,re.S):
 found=re.search(r'(fy_fn_\d+)\(',tail)
 if found:
  if number in c['bindings']:raise RuntimeError('Duplicate binding marker '+number)
  c['bindings'][number]=found.group(1)
definitions=list(re.finditer(r'^static [^\n]+\b(fy_fn_\d+)\([^\n]*\) \{',t,re.M))
marked=[]
for i,match in enumerate(definitions):
 block=t[match.end():definitions[i+1].start() if i+1<len(definitions) else len(t)]
 if 'bc_runtime_engine_binding(UINT32_C(29));' in block:marked.append(match.group(1))
assert len(marked)==1,marked
c['bindings']['29']=marked[0]
def decl(n):return re.search(r'^static [^\n]+\b'+c['bindings'][str(n)]+r'\([^\n]*\);$',t,re.M).group()
c['reviewedDeclarations']={n:decl(n) for n in c['bindings']}
def arg(n,i):
 a=decl(n).split('(',1)[1].split(',')[i];return re.search(r'\bfy_(?:struct|resource)_\d+\b',a).group()
for n,i,k in [(4,2,'incomingType'),(9,2,'inputEntryType'),(10,5,'snapshotType'),(11,4,'snapshotVectorType'),(16,2,'outputVectorType'),(21,1,'programVectorType'),(22,0,'instanceType'),(25,0,'programType'),(28,0,'machineType'),(30,0,'outputType'),(31,0,'pendingVectorType'),(31,1,'completionType'),(31,2,'publishedVectorType')]:c[k]=arg(n,i)
c['coreType']=arg(28,1)
c['entryTypes']={'ordinary':arg(19,0),'input':arg(20,0)}
output_layout=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(c['outputType'])+';$',t,re.M).group()
c['executionType']=re.search(r'\b(fy_resource_\d+) f_1;',output_layout).group(1)
def field_type(owner,index):
 layout=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(owner)+';$',t,re.M).group()
 return re.search(r'\b(fy_(?:struct|resource)_\d+) f_'+str(index)+r';',layout).group(1)
c['pendingMetaType']=arg(26,2)
c['cursorType']=field_type(c['pendingMetaType'],0)
c['outputCopyType']=field_type(c['cursorType'],2)
c['arrayFillType']=field_type(c['cursorType'],3)
c['callCopyType']=field_type(c['cursorType'],4)
c['returnWorkType']=field_type(c['cursorType'],5)
c['transactionType']=field_type(c['machineType'],6)
c['preparationType']=field_type(c['programVariants']['output']['stored'],4)
c['capturePlanType']=field_type(c['preparationType'],8)
types={k:c[k] for k in ['engineType','programType','instanceType','boundInputType','outputType','sourceIndexType','sourceIndexVectorType','programVectorType','snapshotType','snapshotVectorType','machineType','coreType','executionType','pendingVectorType','completionType','publishedVectorType','pendingMetaType','cursorType','outputCopyType','transactionType']}
for variant,rows in c['programVariants'].items():types.update({variant+'_'+k:v for k,v in rows.items()})
types.update({k+'_entry':v for k,v in c['entryTypes'].items()})
types['preparationType']=c['preparationType']
types['arrayFillType']=c['arrayFillType']
types['callCopyType']=c['callCopyType']
types['returnWorkType']=c['returnWorkType']
types['capturePlanType']=c['capturePlanType']
c['reviewedLayouts']={k:re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(v)+';$',t,re.M).group() for k,v in types.items()}
assert len(c['bindings'])==33 and len(c['reviewedLayouts'])==33
c['transportSha256']=hashlib.sha256(generated).hexdigest()
c['sourceInputs']=[dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sources]
raw=json.dumps(c,indent=2)+'\n'
(folder/'candidate-transport.json').write_text(raw,encoding='utf-8',newline='\n')
if review_options.write_contract:(root/'native/runtime-engine/transport.json').write_text(raw,encoding='utf-8',newline='\n')
print(f"Candidate: {len(c['bindings'])} typed bindings, {len(c['reviewedLayouts'])} layouts; {folder/'candidate-transport.json'}")
