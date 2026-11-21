"""Emit a pinned private transport candidate, including all declarations/layouts.

Review build/engine-input-transport-review/candidate-transport.json first; use
--write-contract to replace the local reviewed contract after inspecting changes.
"""
import argparse
from compiler_scratch_layouts import reviewed_scratch
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
toolchain=json.loads((root/'toolchain.json').read_bytes())
revision=toolchain['compiler']['revision']
compiler_sha=toolchain['platforms']['windows/amd64']['sha256']
m.need(hashlib.sha256(compiler.read_bytes()).hexdigest()==compiler_sha, 'Pinned compiler binary changed')
for args in [['check'],['experimental','emit-workspace-c','--target','x86_64-windows-msvc','--locked']]:
 r=subprocess.run([str(compiler),*args],cwd=project,capture_output=True)
 if r.returncode: print(r.stderr.decode());raise SystemExit(r.returncode)
 if args==['check']:print(r.stdout.decode())
 else:generated=r.stdout
(folder/'generated.c').write_bytes(generated)
t=generated.decode('utf-8')
c=json.loads((root/'native/runtime-engine/transport.json').read_bytes())
c['compilerRevision']=revision
c['compilerSha256']=compiler_sha
repository=(root/toolchain['source']['localRepository']).resolve()
for row in c['runtimeInputs']:
 raw=subprocess.check_output(['git','-C',str(repository),'show',revision+':'+row['path']])
 row.update(revision=revision,sha256=hashlib.sha256(raw).hexdigest())
c['bindings']={}
for number,tail in re.findall(r'bc_runtime_engine_binding\(UINT32_C\((\d+)\)\);(.*?)(?=bc_runtime_engine_binding|\Z)',t,re.S):
 found=re.search(r'(fy_fn_\d+)\(',tail)
 if found:
  if number in c['bindings']:raise RuntimeError('Duplicate binding marker '+number)
  c['bindings'][number]=found.group(1)
# MSVC transport orders the reply witness after a forward block jump. Resolve
# that jump within the witness definition before reading the typed callee.
reply_body=re.search(r'^static void fy_fn_\d+\([^\n]*\) \{\n(?:(?!^}).)*bc_runtime_engine_binding\(UINT32_C\(40\)\);(?:(?!^}).)*^}',t,re.M|re.S).group()
reply_target=re.search(r'bc_runtime_engine_binding\(UINT32_C\(40\)\);\s+goto (fy_b_\d+);',reply_body).group(1)
reply_block=re.search(r'^'+reply_target+r':\n((?:    [^\n]*\n)+)',reply_body,re.M).group(1)
c['bindings']['40']=re.search(r'\b(fy_fn_\d+)\(',reply_block).group(1)
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

# Resolve resource roles from typed projections, never previous numeric IDs.
def vector_element(vector):
 matches=set(re.findall(r'^static (?:const )?(fy_(?:struct|resource)_\d+) \* fy_fn_\d+\((?:const )?'+re.escape(vector)+r' \* [^,]+, uintptr_t [^;]+;',t,re.M))
 assert len(matches)==1,(vector,matches)
 return matches.pop()
c['sourceIndexType']=field_type(c['entryTypes']['ordinary'],0)
c['sourceIndexVectorType']=field_type(c['sourceIndexType'],0)
c['boundInputType']=vector_element(arg(10,3))
for variant,index in [('ordinary',3),('input',4),('output',5)]:
 program=vector_element(field_type(c['programType'],index))
 c['programVariants'][variant]={'program':program,'stored':vector_element(field_type(program,0))}
engine_candidates=[]
for layout,name in re.findall(r'^(typedef struct \{\n[^}]*\} (fy_resource_\d+);)$',t,re.M):
 if re.search(r'\b'+re.escape(arg(1,0))+r' f_0;',layout) and re.search(r'\b'+re.escape(c['programVectorType'])+r' f_1;',layout):engine_candidates.append(name)
assert len(engine_candidates)==1,engine_candidates
c['engineType']=engine_candidates[0]
c['compileWorkVectorType']=field_type(c['engineType'],9)
c['compileWorkType']=vector_element(c['compileWorkVectorType'])
assert arg(42,2)==arg(44,1)==arg(45,1)==arg(46,0)==c['compileWorkVectorType']
c['compileCandidateVectorType']=field_type(c['engineType'],11)
c['compileCandidateType']=vector_element(c['compileCandidateVectorType'])
assert arg(42,4)==arg(45,3)==arg(47,0)==c['compileCandidateVectorType']
assert arg(42,3)==arg(43,0)==arg(44,2)==arg(44,3)==arg(45,2)==field_type(c['engineType'],10)==c['incomingType']
c['hostProgramVectorType']=field_type(c['programType'],9)
assert arg(38,2)==c['hostProgramVectorType']
c['hostProgramType']=vector_element(c['hostProgramVectorType'])
host_ir_vector=field_type(c['hostProgramType'],0)
host_ir=set(re.findall(r'^static fy_tagged_\d+ fy_fn_\d+\('+re.escape(host_ir_vector)+r' \* [^,]+, (fy_struct_\d+) [^;]+;',t,re.M))
assert len(host_ir)==1,host_ir
c['hostIRType']=host_ir.pop()
c['hostExchangeVectorType']=field_type(c['outputType'],3)
c['hostExchangeType']=vector_element(c['hostExchangeVectorType'])
c['hostRunConfigType']=arg(39,5)
c['hostTransitionType']=arg(41,7)
assert arg(41,0)==c['hostExchangeVectorType']
assert arg(40,1)==c['programVectorType'] and arg(40,3)==arg(40,4)==c['outputVectorType']
c['policyVectorType']=field_type(c['engineType'],8)
c['policyType']=vector_element(c['policyVectorType'])
assert arg(37,0)==c['policyVectorType']
c['pendingMetaType']=arg(26,2)
c['cursorType']=field_type(c['pendingMetaType'],0)
c['outputCopyType']=field_type(c['cursorType'],2)
c['arrayFillType']=field_type(c['cursorType'],3)
c['callCopyType']=field_type(c['cursorType'],4)
c['returnWorkType']=field_type(c['cursorType'],5)
c['metadataBudgetType']=field_type(c['cursorType'],6)
c['callMetadataType']=field_type(c['coreType'],7)
c['callContextWorkType']=field_type(c['callMetadataType'],8)
c['callArgumentWorkType']=field_type(c['callContextWorkType'],0)
c['callOwnedWorkType']=field_type(c['callContextWorkType'],1)
c['returnPreparationType']=field_type(c['callMetadataType'],9)
c['returnRecordPlanType']=field_type(c['returnPreparationType'],0)
c['returnCatalogWorkType']=field_type(c['returnRecordPlanType'],0)
c['callCopyPlanType']=field_type(c['coreType'],8)
assert arg(26,11)==c['callCopyPlanType']
c['returnMetadataType']=field_type(c['cursorType'],8)
c['lifecycleType']=field_type(c['pendingMetaType'],6)
c['setupWorkType']=field_type(c['lifecycleType'],0)
c['preparationWorkType']=field_type(c['lifecycleType'],1)
c['cleanupWorkType']=field_type(c['lifecycleType'],2)
c['inputWindowsType']=field_type(c['machineType'],5)
c['storageBufferType']=field_type(c['machineType'],0)
assert field_type(c['inputWindowsType'],0)==c['storageBufferType']
c['runtimeMetadataType']=field_type(c['callMetadataType'],1)
c['cleanupRuntimeType']=field_type(c['runtimeMetadataType'],0)
assert arg(27,7)==c['runtimeMetadataType'] and arg(34,2)==c['pendingMetaType'] and arg(35,2)==c['coreType']

assert arg(26,10)==c['callMetadataType']
assert re.fullmatch(r'\s*'+re.escape(c['callMetadataType'])+r'\s*\*\s*fy_l_\d+\s*',decl(26).split('(',1)[1].split(',')[10])
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
types['metadataBudgetType']=c['metadataBudgetType']
types['callMetadataType']=c['callMetadataType']
for key in ['callContextWorkType','callArgumentWorkType','callOwnedWorkType','returnPreparationType','returnRecordPlanType','returnCatalogWorkType']:types[key]=c[key]
types['callCopyPlanType']=c['callCopyPlanType']
types['returnMetadataType']=c['returnMetadataType']
types['policyVectorType']=c['policyVectorType']
types['policyType']=c['policyType']
types['capturePlanType']=c['capturePlanType']
for key in ['hostProgramVectorType','hostProgramType','hostIRType','hostExchangeVectorType','hostExchangeType','hostRunConfigType','hostTransitionType']:types[key]=c[key]
c['reviewedLayouts']={k:re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(v)+';$',t,re.M).group() for k,v in types.items()}
assert len(c['bindings'])==47 and len(c['reviewedLayouts'])==52
for key in ['lifecycleType','setupWorkType','preparationWorkType','cleanupWorkType','runtimeMetadataType','cleanupRuntimeType','inputWindowsType','storageBufferType']:
 c['reviewedLayouts'][key]=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(c[key])+';$',t,re.M).group()
for key in ['compileWorkType','compileWorkVectorType','compileCandidateType','compileCandidateVectorType']:
 c['reviewedLayouts'][key]=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(c[key])+';$',t,re.M).group()
assert len(c['reviewedLayouts'])==64
c['transportSha256']=hashlib.sha256(generated).hexdigest()
c['compilerScratch']=reviewed_scratch(t)
c['sourceInputs']=[dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sources]
raw=json.dumps(c,indent=2)+'\n'
(folder/'candidate-transport.json').write_text(raw,encoding='utf-8',newline='\n')
if review_options.write_contract:(root/'native/runtime-engine/transport.json').write_text(raw,encoding='utf-8',newline='\n')
print(f"Candidate: {len(c['bindings'])} typed bindings, {len(c['reviewedLayouts'])} layouts; {folder/'candidate-transport.json'}")
