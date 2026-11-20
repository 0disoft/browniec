"""Verify the private one-shot adapter transport against real Windows children."""
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def main():
    spec = importlib.util.spec_from_file_location('probe', ROOT/'tools/verify-runtime-store-probe.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    need = helper.need
    need(os.name == 'nt' and not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ),
         'Windows required with no compiler or linker overrides')
    out = ROOT/'build/host-adapter-process'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    inputs = ['native/host_adapter_process.c', 'native/host_adapter_process.h',
              'tests/native/host_adapter_process_host.c', 'tools/verify-host-adapter-process.py',
              'tools/verify-runtime-store-probe.py']
    receipt = dict(status='incomplete', commands=[], profiles=[],
                   inputs=[dict(path=p, sha256=helper.sha((ROOT/p).read_bytes())) for p in inputs])

    def run(args, cwd=out, env=None):
        args = list(map(str, args))
        process = subprocess.run(args, cwd=cwd, env=env, capture_output=True, timeout=30)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index}.stdout', f'logs/{index}.stderr'
        helper.write(out/stdout, process.stdout)
        helper.write(out/stderr, process.stderr)
        receipt['commands'].append(dict(argv=args, exit=process.returncode, stdout=stdout, stderr=stderr))
        need(process.returncode == 0, f'{args}: {process.returncode}: {process.stdout!r} {process.stderr!r}')
        return process.stdout

    try:
        cl, env, receipt['msvc'] = helper.native_environment(run)
        for profile, option in [('development', '/Od'), ('release', '/O2')]:
            folder = out/profile
            folder.mkdir()
            exe = folder/'adapter fixture.exe'
            run([cl, '/nologo', '/std:c11', '/TC', '/MT', '/W4', '/WX', option,
                 ROOT/inputs[0], ROOT/inputs[2], '/Fe'+str(exe),
                 '/link', 'bcrypt.lib', '/INCREMENTAL:NO', '/Brepro'], cwd=folder, env=env)
            runtime_env = {k: v for k, v in os.environ.items()
                           if k.upper() in {'SYSTEMROOT', 'WINDIR', 'TEMP', 'TMP'}}
            result = json.loads(run([exe], cwd=folder, env=runtime_env))
            need(result == {'processCases': 8, 'launchRejections': 3, 'aggregateCases': 1, 'handleDelta': 0},
                 'Expected all real child-process cases and balanced handles')
            receipt['profiles'].append(dict(profile=profile, exe=helper.image(exe), result=result))
            print(f'PASS {profile}: {result}', flush=True)
        need(all(helper.sha((ROOT/i['path']).read_bytes()) == i['sha256'] for i in receipt['inputs']),
             'Inputs changed during verification')
        receipt['status'] = 'passed'
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        helper.record(out/'receipt.json', receipt)
        print(f'Receipt: {out/"receipt.json"}')


if __name__ == '__main__':
    main()
