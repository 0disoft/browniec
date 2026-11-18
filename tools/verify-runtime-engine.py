"""Execute the private owning Engine/Program/Instance lifecycle on native Windows."""
import argparse
from compiler_scratch_layouts import reviewed_scratch
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'native/runtime-engine'
spec = importlib.util.spec_from_file_location('store_probe', ROOT / 'tools/verify-runtime-store-probe.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
need, sha, write, record = probe.need, probe.sha, probe.write, probe.record


def closure():
    files = {p.stem: p for p in (ROOT / 'src').glob('*.fy')}
    files.update({p.stem: p for p in (ROOT / 'tools/runtime-engine').glob('*.fy')})
    files['runtime_engine'] = NATIVE / 'runtime_engine.fy'
    files['runtime_pending_output'] = NATIVE / 'runtime_pending_output.fy'
    files['retention_plan_contracts'] = ROOT / 'tests/m2/retention_plan.fy'
    files['program_compile_contracts'] = ROOT / 'tests/m2/runtime_program_compile_memory.fy'
    files['control_budget_contracts'] = ROOT / 'tests/m2/runtime_control_budget.fy'
    files['live_memory_contracts'] = ROOT / 'tests/m2/runtime_live_memory.fy'
    files['output_memory_contracts'] = ROOT / 'tests/m2/module_output_memory.fy'
    files['execution_memory_contracts'] = ROOT / 'tests/m2/runtime_execution_memory.fy'
    files['pending_memory_contracts'] = ROOT / 'tests/m2/runtime_pending_memory.fy'
    files['output_chunk_contracts'] = ROOT / 'tests/m2/runtime_output_chunks.fy'
    files['dispatch_cursor_contracts'] = ROOT / 'tests/m2/slice_result_cursor.fy'
    files['dispatch_quantum_contracts'] = ROOT / 'tests/m2/module_dispatch_quantum.fy'
    files['runtime_input_adoption'] = ROOT / 'native/runtime-input-adoption/adoption.fy'
    seen, todo = {}, ['main']
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        need(name in files, f'Missing source module: {name}')
        path = files[name]
        seen[name] = path
        todo.extend(re.findall(r'^import ([A-Za-z_][A-Za-z0-9_]*)(?: as [A-Za-z_][A-Za-z0-9_]*)?;',
                               path.read_text(encoding='utf-8'), re.M))
    return sorted(seen.values())


def source_copy(path):
    if path == ROOT / 'src/slice_result_call_ir.fy':
        source = path.read_text(encoding='utf-8')
        signatures = ['pub fn Result<usize,errors::Error> binding(ref ir::Program p,usize pc){',
                      'pub fn usize creator(ref ir::Program p,usize site){',
                      'pub fn Result<Chain,errors::Error> chain(ref ir::Program p,usize pc,usize argument){']
        for signature in signatures:
            need(source.count(signature) == 1, 'CALL recipe visit anchor changed')
            source = source.replace(signature, signature + '\n    unsafe{bc_runtime_engine_test_recipe_visit();}', 1)
        source = source.replace(signatures[0], 'unsafe extern C fn void bc_runtime_engine_test_recipe_visit();\n' + signatures[0], 1)
        return path.name, source.encode('utf-8')
    if path == ROOT / 'src/verifier.fy':
        text = path.read_text(encoding='utf-8')
        signature = 'pub fn Result<ReferenceReturnProof,errors::Error> inspect_output_returns(ref image_calls::Program unit,ref images::Image image,bool input){'
        need(text.count(signature) == 1, 'Full output proof counter anchor changed')
        text = text.replace(signature, 'unsafe extern C fn void bc_runtime_engine_test_proof_visit();\n' +
                            signature + '\n    unsafe{bc_runtime_engine_test_proof_visit();}', 1)
        return path.name, text.encode('utf-8')
    if path == ROOT / 'src/output_canonical_proof_work.fy':
        text = path.read_text(encoding='utf-8')
        anchor = 'if(w.phase==0){let bool input=w.input;'
        need(text.count(anchor) == 1, 'Staged output proof counter anchor changed')
        text = text.replace('// Private complete canonical proof.',
                            'unsafe extern C fn void bc_runtime_engine_test_proof_visit();\n// Private complete canonical proof.', 1)
        text = text.replace(anchor, 'if(w.phase==0){if(w.output){unsafe{bc_runtime_engine_test_proof_visit();}}let bool input=w.input;', 1)
        return path.name, text.encode('utf-8')
    if path == ROOT / 'src/compiler.fy':
        text=path.read_text(encoding='utf-8')
        marker='fn Result<scratch_vec::Vec<expression_work::Bank>,errors::Error> expression_scratch'
        probe_source='unsafe extern C fn void bc_runtime_engine_test_compiler_work_begin();\nunsafe extern C fn void bc_runtime_engine_test_compiler_work_end();\nresource AllocationProbe { bool active; cleanup {unsafe{bc_runtime_engine_test_compiler_work_end()};} }\nfn AllocationProbe allocation_probe(){unsafe{bc_runtime_engine_test_compiler_work_begin()};return AllocationProbe{.active=true};}\n'
        need(text.count(marker)==1,'Compiler allocation probe anchor changed')
        text=text.replace(marker,probe_source+marker,1)
        for name in ['expression_scratch','expression_state','conditional_scratch']:
            pattern=r'(fn Result<scratch_vec::Vec<[^\n]+> '+name+r'\([^\n]+\)\{)'
            text,count=re.subn(pattern,r'\1\n    let AllocationProbe probe=allocation_probe();',text)
            need(count==1,'Compiler allocation scope changed: '+name)
        return path.name,text.encode('utf-8')
    if path == ROOT / 'src/retention_plan.fy':
        text=path.read_text(encoding='utf-8');anchor='    plan.admitted=true;'
        need(text.count(anchor)==1,'Retention admission probe anchor changed')
        text=text.replace('module retention_plan;','module retention_plan;\nunsafe extern C fn void bc_runtime_engine_test_retention_admitted();',1)
        text=text.replace(anchor,anchor+'\n    unsafe{bc_runtime_engine_test_retention_admitted()};',1)
        return path.name,text.encode('utf-8')
    adapters = {'runtime_control_budget': 'control_budget_contracts', 'retention_plan': 'retention_plan_contracts',
                'runtime_program_compile_memory': 'program_compile_contracts',
                'runtime_live_memory': 'live_memory_contracts',
                'module_output_memory': 'output_memory_contracts',
                'runtime_execution_memory': 'execution_memory_contracts',
                'runtime_pending_memory': 'pending_memory_contracts',
                'runtime_output_chunks': 'output_chunk_contracts',
                'slice_result_cursor': 'dispatch_cursor_contracts',
                'module_dispatch_quantum': 'dispatch_quantum_contracts'}
    for original, alias in adapters.items():
        if path == ROOT / f'tests/m2/{original}.fy':
            text = path.read_text(encoding='utf-8').replace(f'module tests::m2::{original};', f'module {alias};')
            text = re.sub(r'@test\s+fn void', 'pub fn void', text)
            return alias + '.fy', text.encode('utf-8')
    return ('runtime_input_adoption.fy' if path == ROOT / 'native/runtime-input-adoption/adoption.fy' else path.name,
            path.read_bytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--fairyc-repository', type=Path)
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows native execution required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ),
         'CL/_CL_/LINK overrides must be absent, including empty values')
    output = ROOT / 'build/runtime-engine' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output.mkdir(parents=True, exist_ok=False)
    receipt_path = output / 'receipt.json'
    receipt = dict(schema='browniec.private-runtime-engine-verification/v1', status='incomplete',
                   recordedAt=datetime.now(timezone.utc).isoformat(), commands=[], profiles=[], runtimeInputs=[])
    root_lock = (ROOT / 'fairy.lock').read_bytes()

    def run(command, cwd=output, env=None):
        command = list(map(str, command))
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=180)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index:02d}.stdout', f'logs/{index:02d}.stderr'
        write(output / stdout, result.stdout)
        write(output / stderr, result.stderr)
        receipt['commands'].append(dict(argv=command, cwd=str(cwd), exit=result.returncode,
                                       stdout=stdout, stderr=stderr,
                                       stdoutSha256=sha(result.stdout), stderrSha256=sha(result.stderr)))
        record(receipt_path, receipt)
        trap=output / 'trap-receipt.bin'
        if result.returncode != 0 and trap.exists():
            raw=trap.read_bytes()
            if len(raw)>=20 and raw[1]==1 and len(raw)==20+int.from_bytes(raw[2:4],'little'):
                source=raw[20:].decode('utf-8',errors='replace')
                start=int.from_bytes(raw[4:12],'little');end=int.from_bytes(raw[12:20],'little')
                raise RuntimeError(f'Native trap {raw[0]} in {source} bytes {start}..{end}; see {trap}')
        need(result.returncode == 0, f'Command failed: {command}; see {output / stderr}')
        return result.stdout

    try:
        contract = json.loads((NATIVE / 'transport.json').read_bytes())
        toolchain = json.loads((ROOT / 'toolchain.json').read_bytes())
        revision = contract['compilerRevision']
        need(toolchain['compiler']['revision'] == revision and
             toolchain['platforms']['windows/amd64']['sha256'] == contract['compilerSha256'],
             'Reviewed compiler identity changed')
        compiler = ROOT / 'build/toolchain/fairyc.exe'
        need(sha(compiler.read_bytes()) == contract['compilerSha256'], 'Compiler binary changed')
        receipt['compiler'] = dict(revision=revision, sha256=contract['compilerSha256'],
                                   version=run([compiler, '--version']).decode().strip())
        sources = closure()
        expected = {row['path']: row['sha256'] for row in contract['sourceInputs']}
        need({p.relative_to(ROOT).as_posix() for p in sources} == set(expected), 'Reviewed closure changed')
        for path in sources:
            need(sha(path.read_bytes()) == expected[path.relative_to(ROOT).as_posix()], f'Source changed: {path}')
        extras = ['fairy.toml', 'toolchain.json', 'tools/verify-runtime-engine.py',
                  'tools/verify-runtime-store-probe.py', 'tools/compiler_scratch_layouts.py', 'tools/runtime-engine/test-host.inc',
                  'native/runtime-engine/bridge.inc', 'native/runtime-engine/transport.json',
                  'native/abi_thread_identity.c', 'native/abi_thread_identity.h',
                  'native/runtime_input_reader.c', 'native/runtime_input_reader.h',
                  'native/runtime-input-adoption/bridge.c',
                  'tools/runtime-engine/heap-observer.c', 'tools/runtime-engine/compile-test-host.inc']
        inputs = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in sources}
        inputs.update({name: (ROOT / name).read_bytes() for name in extras})
        need(all(b'\r' not in raw for name, raw in inputs.items()
                 if name.endswith(('.fy', '.c', '.h', '.inc', '.py'))), 'Source must retain LF')
        receipt['inputs'] = [dict(path=name, sha256=sha(raw), bytes=len(raw)) for name, raw in sorted(inputs.items())]
        project = output / 'project'
        write(project / 'fairy.toml', inputs['fairy.toml'])
        for path in sources:
            name, raw = source_copy(path)
            write(project / 'src' / name, raw)
        run([compiler, 'check'], cwd=project)
        lock = (project / 'fairy.lock').read_bytes()
        run([compiler, 'check', '--locked'], cwd=project)
        generated = run([compiler, 'experimental', 'emit-workspace-c', '--target',
                         'x86_64-windows-msvc', '--locked'], cwd=project)
        need(sha(generated) == contract['transportSha256'], 'Emitted transport changed; review every private binding')
        need(reviewed_scratch(generated.decode('utf-8')) == contract['compilerScratch'], 'Compiler scratch width proof changed')
        write(output / 'generated.c', generated)
        for key, function in contract['bindings'].items():
            declaration = re.search(r'^static [^\n]+\b' + re.escape(function) + r'\([^\n]*\);$',
                                    generated.decode('utf-8'), re.M)
            need(declaration is not None and declaration.group() == contract['reviewedDeclarations'][key],
                 f'Reviewed typed declaration changed: binding {key}')
        projections = [('4', 2, 'incomingType'), ('9', 2, 'inputEntryType'),
                       ('10', 5, 'snapshotType'), ('11', 4, 'snapshotVectorType'),
                       ('13', 2, 'incomingType'), ('14', 2, 'inputEntryType'),
                       ('15', 4, 'snapshotVectorType'), ('16', 2, 'outputVectorType'),
                       ('16', 3, 'outputVectorType'), ('16', 5, 'outputVectorType'),
                       ('21', 1, 'programVectorType'), ('22', 0, 'instanceType'),
                       ('23', 1, 'programVectorType'), ('23', 5, 'snapshotType'),
                       ('24', 2, 'outputVectorType'), ('25', 0, 'programType'),
                       ('28',0,'machineType'),('28',1,'coreType'),
                       ('29',0,'machineType'),('29',1,'coreType'),('26',10,'callMetadataType')]
        projections.extend([('30',0,'outputType'),('38',2,'hostProgramVectorType'),('39',3,'outputVectorType'),('39',4,'policyVectorType'),('39',5,'hostRunConfigType'),('40',2,'outputVectorType'),('41',0,'hostExchangeVectorType'),('41',7,'hostTransitionType')])
        projections.extend([('31',0,'pendingVectorType'),('31',1,'completionType'),('31',2,'publishedVectorType'),
                            ('31',3,'outputProgramType'),('31',4,'snapshotType'),('33',0,'pendingVectorType')])
        for binding, index, key in projections:
            argument = contract['reviewedDeclarations'][binding].split('(', 1)[1].split(',')[index]
            actual = re.search(r'\bfy_(?:resource|struct)_\d+\b', argument)
            expected_type=contract['programVariants']['output']['program'] if key=='outputProgramType' else contract[key]
            need(actual is not None and actual.group() == expected_type,
                 f'Typed projection differs from actual declaration: {binding}/{index}/{key}')
        for binding, key in [('19', 'ordinary'), ('20', 'input')]:
            argument = contract['reviewedDeclarations'][binding].split('(', 1)[1].split(',')[0]
            actual = re.search(r'\bfy_resource_\d+\b', argument)
            need(actual is not None and actual.group() == contract['entryTypes'][key],
                 f'Typed Entry projection differs from declaration: {binding}/{key}')
        layout_types = {key: contract[key] for key in ['engineType', 'programType', 'instanceType',
                        'boundInputType', 'outputType', 'sourceIndexType', 'sourceIndexVectorType',
                        'programVectorType', 'snapshotType', 'snapshotVectorType', 'machineType', 'coreType',
                        'executionType','pendingVectorType','completionType','publishedVectorType',
                        'pendingMetaType','cursorType','outputCopyType','transactionType','preparationType','arrayFillType','callCopyType','returnWorkType','capturePlanType',
                        'callMetadataType','metadataBudgetType','returnMetadataType','callCopyPlanType','callContextWorkType','callArgumentWorkType','callOwnedWorkType','returnPreparationType','returnRecordPlanType','returnCatalogWorkType','lifecycleType','setupWorkType','preparationWorkType','cleanupWorkType','runtimeMetadataType','cleanupRuntimeType','inputWindowsType','storageBufferType']}
        for variant, types in contract['programVariants'].items():
            layout_types.update({variant + '_' + role: name for role, name in types.items()})
        layout_types.update({key + '_entry': name for key, name in contract['entryTypes'].items()})
        for key in ['policyType','policyVectorType','hostProgramVectorType','hostProgramType','hostIRType','hostExchangeVectorType','hostExchangeType','hostRunConfigType','hostTransitionType']:
            layout_types[key]=contract[key]
        need(set(layout_types) == set(contract['reviewedLayouts']), 'Reviewed layout set changed')
        cached_field=re.search(r'\b(fy_struct_\d+) f_4;',contract['reviewedLayouts']['output_stored'])
        need(cached_field is not None and cached_field.group(1)==contract['preparationType'],
             'Output Program preparation projection differs')
        for owner,field,key in [('programType',9,'hostProgramVectorType'),('outputType',3,'hostExchangeVectorType'),('outputType',1,'executionType'),('outputType',2,'pendingVectorType'),
                                ('preparationType',8,'capturePlanType'),
                                ('executionType',0,'completionType'),('executionType',1,'publishedVectorType'),
                                ('machineType',0,'storageBufferType'),('machineType',5,'inputWindowsType'),('inputWindowsType',0,'storageBufferType'),('machineType',6,'transactionType'),('machineType',7,'pendingMetaType'),
                                ('pendingMetaType',6,'lifecycleType'),('lifecycleType',0,'setupWorkType'),('lifecycleType',1,'preparationWorkType'),('lifecycleType',2,'cleanupWorkType'),('callMetadataType',1,'runtimeMetadataType'),('runtimeMetadataType',0,'cleanupRuntimeType'),('pendingMetaType',0,'cursorType'),('cursorType',2,'outputCopyType'),('cursorType',3,'arrayFillType'),('cursorType',4,'callCopyType'),('cursorType',5,'returnWorkType'),
                                ('cursorType',6,'metadataBudgetType'),('coreType',7,'callMetadataType'),('coreType',8,'callCopyPlanType'),('callMetadataType',8,'callContextWorkType'),('callContextWorkType',0,'callArgumentWorkType'),('callContextWorkType',1,'callOwnedWorkType'),('callMetadataType',9,'returnPreparationType'),('returnPreparationType',0,'returnRecordPlanType'),('returnRecordPlanType',0,'returnCatalogWorkType'),('cursorType',8,'returnMetadataType')]:
            member=re.search(r'\b(fy_(?:struct|resource)_\d+) f_'+str(field)+r';',contract['reviewedLayouts'][owner])
            need(member is not None and member.group(1)==contract[key],f'Output field projection differs: {owner}/{field}')
        advance_args=contract['reviewedDeclarations']['26'].split('(',1)[1].split(',')
        need(re.fullmatch(r'\s*'+re.escape(contract['callMetadataType'])+r'\s*\*\s*fy_l_\d+\s*',advance_args[10]) is not None,
             'Pending CALL metadata argument must be a mutable pointer')
        need(re.fullmatch(r'\s*'+re.escape(contract['callCopyPlanType'])+r'\s*\*\s*fy_l_\d+\s*',advance_args[11]) is not None,
             'Pending CALL copy plan argument must be a mutable pointer')
        for binding,argument,key in [('27',7,'runtimeMetadataType'),('34',2,'pendingMetaType'),('35',2,'coreType')]:
            declaration=contract['reviewedDeclarations'][binding].split('(',1)[1].split(')',1)[0].split(',')[argument]
            need(re.fullmatch(r'\s*'+re.escape(contract[key])+r'\s*\*\s*fy_l_\d+\s*',declaration) is not None,
                 f'Lifecycle mutable projection differs: {binding}/{argument}')
        need(re.search(r'uintptr_t f_3;',contract['reviewedLayouts']['lifecycleType']) is not None,
             'Lifecycle dispatcher phase field differs')
        machine_meta=re.search(r'\b(fy_struct_\d+) f_7;',contract['reviewedLayouts']['machineType'])
        need(machine_meta is not None and machine_meta.group(1) in advance_args[2],
             'Pending Machine control metadata differs')
        core_layout=contract['reviewedLayouts']['coreType']
        advance_args=contract['reviewedDeclarations']['26'].split('(',1)[1].split(',')
        for field,argument in [(0,3),(1,4),(2,5)]:
            member=re.search(r'\b(fy_(?:struct|resource)_\d+) f_'+str(field)+r';',core_layout)
            need(member is not None and member.group(1) in advance_args[argument],
                 f'Pending Core field/argument differs: {field}/{argument}')
        for field,ctype,length in [(3,'uint8_t',16),(4,'uintptr_t',32),(5,'uint32_t',512),(6,'int64_t',4096)]:
            member=re.search(r'\b(fy_array_\w+) f_'+str(field)+r';',core_layout)
            need(member is not None,'Pending bank missing')
            array=re.search(r'typedef struct \{[^}]*\} '+re.escape(member.group(1))+r';',generated.decode('utf-8'))
            need(array is not None and re.search(re.escape(ctype)+r' data\[UINT64_C\('+str(length)+r'\)\]',array.group()),
                 f'Pending bank element/count differs: {field}')
        for field in range(12,18):
            member=re.search(r'\b(fy_array_\w+) f_'+str(field)+r';',contract['reviewedLayouts']['callCopyType'])
            need(member is not None,'CALL comparison bank missing')
            array=re.search(r'typedef struct \{[^}]*\} '+re.escape(member.group(1))+r';',generated.decode('utf-8'))
            need(array is not None and re.search(r'uintptr_t data\[UINT64_C\(8\)\]',array.group()),
                 'CALL comparison bank element/count differs')
        policy_vector=contract['policyVectorType']
        need(re.search(r'\b'+re.escape(policy_vector)+r' f_8;',contract['reviewedLayouts']['engineType']),
             'Engine policy storage projection differs')
        need(re.search(r'\b'+re.escape(policy_vector)+r' \w+\('+re.escape(policy_vector)+r' ',contract['reviewedDeclarations']['37']),
             'Engine policy teardown signature differs')
        for key, name in layout_types.items():
            actual = re.search(r'^typedef struct \{\n[^}]*\} ' + re.escape(name) + r';$',
                               generated.decode('utf-8'), re.M)
            need(actual is not None and actual.group() == contract['reviewedLayouts'][key],
                 f'Reviewed emitted layout differs: {key}')
        bindings = f'typedef {contract["engineType"]} bc_engine;\ntypedef {contract["incomingType"]} bc_engine_input;\n'
        bindings += f'typedef {contract["inputEntryType"]} bc_engine_input_entry;\ntypedef {contract["snapshotType"]} bc_engine_snapshot;\n'
        bindings += f'typedef {contract["snapshotVectorType"]} bc_engine_snapshots;\n'
        bindings += f'typedef {contract["outputVectorType"]} bc_engine_outputs;\n'
        bindings+=f'typedef {contract["machineType"]} bc_pending_machine;\ntypedef {contract["coreType"]} bc_pending_core;\n'
        bindings+=f'typedef {contract["preparationType"]} bc_output_preparation;\n'
        bindings+=f'typedef {contract["arrayFillType"]} bc_array_fill_work;\ntypedef {contract["cursorType"]} bc_dispatch_cursor;\n'
        bindings += f'typedef {contract["callCopyType"]} bc_call_copy_work;\n'
        bindings += f'typedef {contract["returnWorkType"]} bc_return_work;\n'
        bindings += f'typedef {contract["callMetadataType"]} bc_call_metadata_work;\ntypedef {contract["metadataBudgetType"]} bc_metadata_budget;\n'
        bindings += f'typedef {contract["capturePlanType"]} bc_call_capture_plan;\n'
        for key, alias in [('programType', 'bc_engine_program'), ('instanceType', 'bc_engine_instance'),
                           ('boundInputType', 'bc_engine_bound_input'), ('outputType', 'bc_engine_output')]:
            bindings += f'typedef {contract[key]} {alias};\n'
        for variant, types in contract['programVariants'].items():
            for role, name in types.items():
                bindings += f'typedef {name} bc_{variant}_{role};\n'
        for key, name in contract['entryTypes'].items():
            bindings += f'typedef {name} bc_{key}_entry;\n'
        bindings += f'typedef {contract["policyType"]} bc_engine_policy;\n'
        bindings += f'typedef {contract["hostProgramType"]} bc_host_program;\ntypedef {contract["hostIRType"]} bc_host_ir;\n'
        bindings += f'typedef {contract["hostExchangeType"]} bc_host_exchange;\n'
        bindings += '\n'.join(f'#define B{key} {value}' for key, value in contract['bindings'].items()) + '\n'
        write(output / 'bindings.h', bindings)
        for name in ['abi_thread_identity.c', 'abi_thread_identity.h']:
            write(output / name, inputs['native/' + name])
        for name in ['native/runtime_input_reader.c', 'native/runtime_input_reader.h',
                     'native/runtime-input-adoption/bridge.c']:
            write(output / name, inputs[name])
        write(output / 'bridge.inc', inputs['native/runtime-engine/bridge.inc'])
        write(output / 'test-host.inc', inputs['tools/runtime-engine/test-host.inc'])
        write(output / 'compile-test-host.inc', inputs['tools/runtime-engine/compile-test-host.inc'])
        write(output / 'transport.c', '#define main generated_main\n#include "generated.c"\n#undef main\n' +
              ''.join('_Static_assert(sizeof('+r['type']+') <= UINT64_C('+str(r['slotBound'])+'), "compiler scratch width bound");\n' for r in contract['compilerScratch'].values()) +
              '#include "abi_thread_identity.h"\n#include "bindings.h"\n'
              '#include "bridge.inc"\n#include "test-host.inc"\n#include "compile-test-host.inc"\n')
        repository = (args.fairyc_repository or ROOT / toolchain['source']['localRepository']).resolve()
        runtime = [inputs['tools/runtime-engine/heap-observer.c'].decode('utf-8')]
        for row in contract['runtimeInputs']:
            need(row['revision'] == revision, 'Runtime revision mismatch')
            raw = run(['git', 'show', revision + ':' + row['path']], cwd=repository)
            need(sha(raw) == row['sha256'], f'Pinned runtime Git object changed: {row["path"]}')
            write(output / 'runtime-inputs' / Path(row['path']).name, raw)
            receipt['runtimeInputs'].append(row)
            text = raw.decode('utf-8')
            if row['path'].endswith('stage0_scalar.c'):
                for key, value in [('@TRAP_EXIT_BASE@', '192'), ('@TRAP_RECEIPT_INCLUDE@', '#include <stdio.h>'),
                                   ('@TRAP_RECEIPT_WRITE@', 'FILE *trace=fopen("trap-receipt.bin","wb"); if(trace){fwrite(fy_trap_receipt,1,fy_trap_receipt_length,trace);fclose(trace);}')]:
                    need(text.count(key) == 1, f'Unexpected runtime placeholder: {key}')
                    text = text.replace(key, value)
            runtime.append(text)
        composed = '\n'.join(runtime)
        write(output / 'runtime.c', composed)
        receipt.update(transportSha256=sha(generated), runtimeSha256=sha(composed.encode()),
                       isolatedLockSha256=sha(lock), sourceClosure=len(sources))
        cl, env, receipt['msvc'] = probe.native_environment(run)
        empty = output / 'empty-tools'
        empty.mkdir()
        runtime_env = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR', 'TEMP', 'TMP'] if k in os.environ}
        runtime_env['PATH'] = str(empty)
        for profile in (['development', 'release'] if args.profile == 'all' else [args.profile]):
            folder = output / profile
            folder.mkdir()
            objects = []
            native_sources = {name: output / (name + '.c') for name in ['transport', 'runtime', 'abi_thread_identity']}
            native_sources.update(input_reader=output / 'native/runtime_input_reader.c',
                                  input_adoption=output / 'native/runtime-input-adoption/bridge.c')
            for name, source in native_sources.items():
                obj = folder / (name + '.obj')
                run([cl, '/nologo', '/TC', '/std:c11', '/MT', '/W3',
                     '/Od' if profile == 'development' else '/O2', '/c', source,
                     '/Fo' + str(obj)], env=env)
                objects.append(obj)
            exe = folder / 'runtime-engine.exe'
            run([cl, '/nologo', *objects, 'ntdll.lib', '/Fe' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            need(run([exe], env=runtime_env) == b'' and
                 receipt['commands'][-1]['stderrSha256'] == sha(b''), 'Expected silent native success')
            metrics_raw = (output / 'control-metrics.json').read_bytes()
            metrics = json.loads(metrics_raw)
            need(metrics['cases'] == 6 and metrics['smallHeapBytes'] * 8 == metrics['maximumHeapBytes'],
                 'Expected eightfold reduction in one-slot control backing')
            write(folder / 'control-metrics.json', metrics_raw)
            preparation_raw=(output / 'preparation-metrics.json').read_bytes()
            preparation=json.loads(preparation_raw)
            need(preparation['cacheBytes']>0 and preparation['storedBytes']-preparation['previousStoredBytes']==preparation['cacheBytes'] and
                 preparation['retainedVecExtraBytes']==8*preparation['cacheBytes'], 'Unexpected preparation cache layout')
            need(preparation['capturePlanBytes']>0 and preparation['cacheBytes']>=preparation['previousCacheBytes']+preparation['capturePlanBytes'] and
                 preparation['capturePlanVecExtraBytes']==8*(preparation['cacheBytes']-preparation['previousCacheBytes']),
                 'Unexpected immutable CALL capture cache storage')
            write(folder / 'preparation-metrics.json',preparation_raw)
            fill_raw=(output / 'array-fill-metrics.json').read_bytes()
            fill_metrics=json.loads(fill_raw)
            need(fill_metrics['arrayWorkBytes']>0 and fill_metrics['pendingVecExtraBytes']==8*fill_metrics['arrayWorkBytes'],
                 'Unexpected array work cursor storage')
            need(fill_metrics['callPendingVecExtraBytes']==8*fill_metrics['callWorkBytes'] and
                 fill_metrics['returnPendingVecExtraBytes']==8*fill_metrics['returnWorkBytes'] and
                 fill_metrics['combinedPendingVecExtraBytes']==8*(fill_metrics['arrayWorkBytes']+fill_metrics['callWorkBytes']+fill_metrics['returnWorkBytes']),
                 'Unexpected CALL/RET work cursor accounting')
            write(folder / 'array-fill-metrics.json',fill_raw)
            receipt['profiles'].append(dict(profile=profile, artifact=probe.image(exe), exit=0,
                controlMetrics=metrics, preparationMetrics=preparation, arrayFillMetrics=fill_metrics,
                liveHeapAllocationsAtExit=0, assertions='native Fairy and C, no parsed trace',
                objects=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p.read_bytes())) for p in objects]))
            print(f'PASS {profile}: control {metrics}; real compile/reuse, pins, fresh VM, terminal/cancel, OS guards, exhaustion; heap 0', flush=True)
        need(all((ROOT / name).read_bytes() == raw for name, raw in inputs.items()), 'Input changed during verification')
        need((ROOT / 'fairy.lock').read_bytes() == root_lock and (project / 'fairy.lock').read_bytes() == lock,
             'Root or isolated lock changed')
        need(sha(compiler.read_bytes()) == contract['compilerSha256'], 'Compiler changed during verification')
        receipt.update(status='passed', rootLockUnchanged=True, compilerOverrides=False,
                       runtimeEnvironment='cleared; empty tool PATH', limitations=[
                           'Private synchronous typed transport, not public C handles or CLI lifecycle APIs',
                           'Complete Engine accounting/preallocation, OOM injection and poison containment remain',
                           'Ordinary zero-argument terminal Fuel is still marked unknown',
                           'Private setup/cache checks/seal/cleanup and CALL/RET stages share the allowance; whole Runtime projection/copy accounting is conservative, not an instrumented field or CPU bound',
                           'Private input/output compiler proof uses resumable logical stages; synchronous compile still drains them, source lowering and admission allocations remain atomic; no public stopping/poison, host dispatch or OS deadline'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        record(receipt_path, receipt)
        print('Receipt: ' + str(receipt_path), flush=True)


if __name__ == '__main__':
    main()
