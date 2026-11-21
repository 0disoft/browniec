"""Exercise Windows file publication with injected write and close statuses."""
import importlib.util
import os
from pathlib import Path
import subprocess
from tempfile import mkdtemp

ROOT = Path(__file__).resolve().parent.parent
HOST = ROOT / 'tests/native/cli_output_publication_host.c'
HELPER = ROOT / 'tools/verify-runtime-store-probe.py'
NATIVE = ('native/windows-project-cli.c', 'native/anchored_sources.c',
          'native/anchored_sources.h', 'native/anchored-source-loader/bridge.c',
          'native/anchored-source-loader/bridge.h', 'native/runtime_input_reader.c',
          'native/runtime_input_reader.h', 'native/host_adapter_process.c',
          'native/host_adapter_process.h')
EXPECTED = (b'PASS: short write, failed write and close status leave no output, '
            b'staging file or handle; retry publishes exact bytes')


def main():
    spec = importlib.util.spec_from_file_location('native_helper', HELPER)
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    native.need(os.name == 'nt', 'Windows x64 required')
    native.need(not {'CL', '_CL_', 'LINK'}.intersection(key.upper() for key in os.environ),
                'Compiler overrides must be absent')
    build = ROOT / 'build'
    build.mkdir(exist_ok=True)
    output = Path(mkdtemp(prefix='cli-output-publication-', dir=build))
    inputs = [HOST, HELPER, Path(__file__).resolve(), *(ROOT / name for name in NATIVE)]
    hashes = {path.relative_to(ROOT).as_posix(): native.sha(path.read_bytes()) for path in inputs}
    receipt = {'status': 'incomplete', 'inputs': hashes, 'commands': [], 'profiles': []}

    def run(argv, cwd=output, env=None):
        argv = list(map(str, argv))
        done = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=120)
        name = str(len(receipt['commands']))
        (output / (name + '.stdout')).write_bytes(done.stdout)
        (output / (name + '.stderr')).write_bytes(done.stderr)
        receipt['commands'].append(dict(argv=argv, cwd=str(cwd), exit=done.returncode,
                                        stderrBytes=len(done.stderr), stdoutSha256=native.sha(done.stdout)))
        native.need(done.returncode == 0 and not done.stderr,
                    f'{argv[0]} exited {done.returncode}; see {output / name}')
        return done.stdout

    try:
        cl, env, receipt['msvc'] = native.native_environment(run)
        for profile, optimization in [('development', '/Od'), ('optimized', '/O2')]:
            cwd = output / profile
            cwd.mkdir()
            exe = cwd / 'output-host.exe'
            run([cl, '/nologo', '/std:c11', '/MT', '/Gy', optimization, '/I' + str(ROOT),
                 HOST, ROOT / 'native/runtime_input_reader.c', ROOT / 'native/host_adapter_process.c',
                 '/Fe' + str(exe), '/link', '/OPT:REF', 'bcrypt.lib', 'ntdll.lib'], cwd, env)
            result = run([exe], cwd, env).strip()
            native.need(result == EXPECTED, f'Unexpected output host result: {result!r}')
            receipt['profiles'].append(dict(profile=profile, image=native.image(exe),
                                            result=result.decode('ascii')))
            print(f'{profile}: {result.decode("ascii")}', flush=True)
        native.need(all(native.sha((ROOT / name).read_bytes()) == digest
                        for name, digest in hashes.items()), 'Test input changed during verification')
        receipt['status'] = 'passed'
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        native.record(output / 'receipt.json', receipt)
        print(f'Receipt: {output / "receipt.json"}', flush=True)


if __name__ == '__main__':
    main()
