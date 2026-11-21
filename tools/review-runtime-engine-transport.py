"""Emit a pinned private transport candidate, including all declarations/layouts.

Review build/engine-input-transport-review/candidate-transport.json first; use
--write-contract to replace the local reviewed contract after inspecting changes.
"""
import argparse
from compiler_scratch_layouts import reviewed_scratch
from runtime_engine_transport import project_layouts
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
project_layouts(t, c)
c['transportSha256']=hashlib.sha256(generated).hexdigest()
c['compilerScratch']=reviewed_scratch(t)
c['sourceInputs']=[dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sources]
raw=json.dumps(c,indent=2)+'\n'
(folder/'candidate-transport.json').write_text(raw,encoding='utf-8',newline='\n')
if review_options.write_contract:(root/'native/runtime-engine/transport.json').write_text(raw,encoding='utf-8',newline='\n')
print(f"Candidate: {len(c['bindings'])} typed bindings, {len(c['reviewedLayouts'])} layouts; {folder/'candidate-transport.json'}")
