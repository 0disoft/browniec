"""Verify the private Windows binary input primitive with real disk and pipes."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
FILES = ['native/runtime_input_reader.c', 'native/runtime_input_reader.h',
         'tests/native/runtime_input_reader_host.c', 'tools/verify-runtime-input-reader.py',
         'docs/engineering/runtime-input-reader.md']


def sha(b):
    return hashlib.sha256(b).hexdigest()


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def write(p, b):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(b.encode() if isinstance(b, str) else b)


def main():
    need(os.name == 'nt', 'Windows required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ), 'Compiler environment overrides prohibited')
    out = ROOT/'build/runtime-input-reader'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    receipt = dict(schema='browniec.runtime-input-reader/v1', status='incomplete', commands=[], profiles=[],
                   defaultStacks=True, stackOverrides=False, compilerEnvironmentOverrides=False,
                   allocatorSeam='Explicit BC_RIR_TEST test objects; no environment injection or production hooks')

    def run(argv, cwd=out, env=None, reject=False):
        argv = list(map(str, argv))
        need(not any('/STACK' in a.upper() for a in argv), 'Stack override prohibited')
        need(env is None or not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in env), 'Environment override prohibited')
        p = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=120)
        name = str(len(receipt['commands']))
        write(out/('logs/'+name+'.stdout'), p.stdout)
        write(out/('logs/'+name+'.stderr'), p.stderr)
        receipt['commands'].append(dict(argv=argv, cwd=str(cwd), exit=p.returncode,
            stdout='logs/'+name+'.stdout', stderr='logs/'+name+'.stderr',
            stdoutSha256=sha(p.stdout), stderrSha256=sha(p.stderr)))
        need(p.returncode != 0 if reject else p.returncode == 0,
             f'{argv}: {p.returncode}; {p.stdout[-2000:]!r}; {p.stderr[-2000:]!r}')
        return p.stderr if reject else p.stdout

    try:
        inputs = {p: (ROOT/p).read_bytes() for p in FILES+['tools/verify-runtime-store-probe.py']}
        need(all(b'\r' not in b for b in inputs.values()), 'LF inputs required')
        receipt['inputs'] = [dict(path=p, sha256=sha(b), bytes=len(b)) for p, b in inputs.items()]
        for p, b in inputs.items():
            write(out/'inputs'/p, b)
        spec = importlib.util.spec_from_file_location('native_helper', ROOT/'tools/verify-runtime-store-probe.py')
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        cl, env, receipt['msvc'] = helper.native_environment(run)
        # Use only the helper's compiler environment discovery; inspect our own images.
        for profile in ['development', 'release']:
            folder = out/profile
            folder.mkdir()
            flags = ['/nologo', '/TC', '/std:c11', '/MT', '/W4', '/WX', '/Od' if profile == 'development' else '/O2']
            prod = folder/'production.obj'
            run([cl, *flags, '/c', ROOT/FILES[0], '/Fo'+str(prod)], env=env)
            normal_host = folder/'normal-host.obj'
            run([cl, *flags, '/c', ROOT/FILES[2], '/Fo'+str(normal_host)], env=env)
            normal_exe = folder/'production.exe'
            run([cl, '/nologo', prod, normal_host, 'ntdll.lib', '/Fe'+str(normal_exe),
                 '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            normal_fixture = folder/'production-binary.bin'
            normal = json.loads(run([normal_exe, normal_fixture], env=env))
            need(normal['groups'] == 3 and normal['zeroBytePipeOsAttempts'] == 4 and normal['handlesStable'] and not normal_fixture.exists(),
                 'Hook-free production OS ownership checks')
            normal_data = normal_exe.read_bytes()
            normal_pe = struct.unpack_from('<I', normal_data, 0x3c)[0]
            need(struct.unpack_from('<QQ', normal_data, normal_pe+24+72) == (1048576, 4096), 'Production default stack')
            symbols = run([cl.parent/'dumpbin.exe', '/symbols', prod], env=env)
            need(b'bc_rir_test_' not in symbols, 'Test hook leaked into production')
            objects = []
            for name, source in [('reader', FILES[0]), ('host', FILES[2])]:
                obj = folder/(name+'.obj')
                run([cl, *flags, '/DBC_RIR_TEST', '/c', ROOT/source, '/Fo'+str(obj)], env=env)
                objects.append(obj)
            exe = folder/'reader.exe'
            run([cl, '/nologo', *objects, 'ntdll.lib', '/Fe'+str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            data = exe.read_bytes()
            pe = struct.unpack_from('<I', data, 0x3c)[0]
            need(data[:2] == b'MZ' and data[pe:pe+4] == b'PE\0\0' and
                 struct.unpack_from('<H', data, pe+4)[0] == 0x8664, 'AMD64 PE required')
            optional = pe+24
            stack = struct.unpack_from('<QQ', data, optional+72)
            need(stack == (1048576, 4096), 'Default stack required')
            fixture = folder/'binary-\uD55C\uAE00.bin'
            result = json.loads(run([exe, fixture], env=env))
            need(result['groups'] == 6 and result['zeroBytePipeOsAttempts'] == 4 and result['injectedZeroCases'] == 0 and result['live'] == 0 and result['partialReads'] > 0,
                 'Real disk/pipe/ownership/OOM checks required')
            need(not fixture.exists(), 'Host fixture cleanup required')
            need(receipt['commands'][-1]['stderrSha256'] == sha(b''), 'Silent native test assertions')
            receipt['profiles'].append(dict(profile=profile, result=result, exeSha256=sha(data),
                stackReserve=stack[0], stackCommit=stack[1], productionTestHooksAbsent=True,
                zeroBytePipeEvidence=dict(kind='actual OS anonymous byte-pipe WriteFile(0)', attempts=4,
                    observed=normal['zeroBytePipeOsObserved'], testObserved=result['zeroBytePipeOsObserved'],
                    syscallReturnInjection=False),
                normalProduction=dict(result=normal, exeSha256=sha(normal_data), defaultStacks=True),
                productionSha256=sha(prod.read_bytes()), objects=[dict(path=str(p),sha256=sha(p.read_bytes())) for p in objects]))
            # Explicit /FI syscall-return seam, separate from all normal OS runs.
            seam_header = out/'zero-read-seam.h'
            write(seam_header, '#define WIN32_LEAN_AND_MEAN\n#include <windows.h>\n'
                'BOOL bc_rir_zero_read(HANDLE,LPVOID,DWORD,LPDWORD,LPOVERLAPPED);\n#define ReadFile bc_rir_zero_read\n')
            seam_reader = folder/'zero-seam-reader.obj'
            seam_host = folder/'zero-seam-host.obj'
            run([cl, *flags, '/DBC_RIR_TEST', '/FI'+str(seam_header), '/c', ROOT/FILES[0], '/Fo'+str(seam_reader)], env=env)
            run([cl, *flags, '/DBC_RIR_TEST', '/DBC_RIR_ZERO_READ_SEAM', '/c', ROOT/FILES[2], '/Fo'+str(seam_host)], env=env)
            seam_exe = folder/'zero-seam.exe'
            run([cl, '/nologo', seam_reader, seam_host, 'ntdll.lib', '/Fe'+str(seam_exe),
                 '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            seam_data = seam_exe.read_bytes()
            seam_pe = struct.unpack_from('<I', seam_data, 0x3c)[0]
            need(struct.unpack_from('<QQ', seam_data, seam_pe+24+72) == (1048576, 4096), 'Seam default stack')
            seam_fixture = folder/'zero-seam-binary.bin'
            injected = json.loads(run([seam_exe, seam_fixture], env=env))
            need(injected['injectedZeroCases'] == 4 and injected['live'] == 0 and not seam_fixture.exists(),
                 'Four explicit zero-return failures, no partial publication/retry/leak')
            receipt['profiles'][-1]['syscallReturnSeam'] = dict(explicitClFI=True, cases=4, result=injected,
                exeSha256=sha(seam_data), headerSha256=sha(seam_header.read_bytes()), defaultStacks=True,
                noPartialPublication=True, originalHandleValid=True)
            # Negative control: only restore the old successful-zero-as-EOF branch
            # in a build artifact; use the same exact /FI seam and host object.
            current = inputs[FILES[0]].decode()
            branch = """        if(got==0){
            /* A successful zero-byte pipe read is a zero-byte writer operation,
               not EOF. Reject no progress without publishing or retrying. */
            if(type==FILE_TYPE_PIPE){status=fail(error,BC_RIR_OS,ERROR_NO_DATA);goto done;}
            break;
        }"""
            need(current.count(branch) == 1, 'Exact negative-control branch')
            old_source = out/'old-zero-as-eof.c'
            write(old_source, current.replace(branch, '        if(got==0){break;}'))
            old_object = folder/'old-zero-as-eof.obj'
            run([cl, *flags, '/DBC_RIR_TEST', '/FI'+str(seam_header), '/I'+str(ROOT/'native'),
                 '/c', old_source, '/Fo'+str(old_object)], env=env)
            old_exe = folder/'old-zero-as-eof.exe'
            run([cl, '/nologo', old_object, seam_host, 'ntdll.lib', '/Fe'+str(old_exe),
                 '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            old_fixture = folder/'old-zero-as-eof.bin'
            failure = run([old_exe, old_fixture], env=env, reject=True)
            need(b'bc_rir_handle(r,cap,&s,&e)==BC_RIR_OS&&e==ERROR_NO_DATA&&s==NULL' in failure,
                 'Old branch must fail specifically at no-progress/no-publication assertion')
            # Expected assertion abort precedes the host's final fixture delete.
            need(old_fixture.parent == folder and old_fixture.is_file(), 'Exact negative-control fixture')
            old_fixture.unlink()
            need(not old_fixture.exists(), 'Negative-control fixture cleanup')
            receipt['profiles'][-1]['oldBranchRegression'] = dict(expectedFailure=True,
                sourceSha256=sha(old_source.read_bytes()), exeSha256=sha(old_exe.read_bytes()),
                explicitSyscallReturnInjection=True, failure='No-progress/no-publication assertion')
            print('PASS '+profile+': fresh production/test OS groups; zero reads observed '+
                  str(normal['zeroBytePipeOsObserved'])+'/4 normal; four separate /FI return injections', flush=True)
        need(all((ROOT/p).read_bytes() == b for p, b in inputs.items()), 'Inputs changed during verification')
        receipt.update(status='passed', limitations=[
            'Private synchronous Windows OS primitive only; no Fairy/Engine/VM/CLI/stdin adapter.',
            'Trusted absolute drive path or explicit sync disk/byte-pipe handle; no guest FS authority.',
            'Duplicate handles share cursor/consumption; failure cannot restore already consumed bytes.',
            'EOF/limit probe can block indefinitely; no R03, deadline or atomic filesystem snapshot claim.',
            'Allocator failure is a separate explicit test-object seam, not whole-process heap exhaustion.',
            'Real zero-byte pipe writes are attempted and observations recorded; forced zero-return coverage is separate /FI evidence.'])
    except Exception as e:
        receipt.update(status='failed', error=str(e))
        raise
    finally:
        write(out/'receipt.json', json.dumps(receipt, indent=2)+'\n')
        write(ROOT/'build/runtime-input-reader/latest.json', json.dumps(dict(path=str(out/'receipt.json'),
            sha256=sha((out/'receipt.json').read_bytes())), indent=2)+'\n')
    print('Receipt: '+str(out/'receipt.json'), flush=True)


if __name__ == '__main__':
    main()
