"""Build and run the Windows AppContainer and Job launcher fixture."""

import argparse
import base64
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HELLO_PROJECT = ROOT / 'examples/projects/hello'
POLICY_EXAMPLE = ROOT / 'examples/projects/configured-output/policy.json'


def verify_managed_project(run, need, image, folder, env):
    target = folder / 'hello'
    shutil.copytree(HELLO_PROJECT, target)
    project = target / 'project.json'
    project_arg = project.relative_to(folder)
    original = project.read_bytes()
    # Exercise multiple stream windows using an otherwise unchanged manifest.
    project.write_bytes(original + b' ' * 5200)
    for op, status, value in [('check', 'checked', None), ('run', 'completed', 42)]:
        result = json.loads(run([image, '--internal-project-broker', op, project_arg],
                                cwd=folder, env=env, no_stderr=True))
        need(result == dict(schema='browniec.result/v2', profile='brownie.m1-scalar/1',
                            command=op, status=status, return_i32=value, error=None),
             f'Unexpected isolated project outcome: {result}')

    math = target / 'src/math.brc'
    math.write_bytes(math.read_bytes().replace(b'return 42;', b'return missing;'))
    fixture = [image, 'check', '--project', project_arg, '--json-v2']
    expected = json.loads(run(fixture, cwd=folder, env=env, expected_exit=3, no_stderr=True))
    observed = json.loads(run([image, '--internal-project-broker', 'check', project_arg],
                              cwd=folder, env=env, expected_exit=3, no_stderr=True))
    location = observed['error']['location']
    need(observed == expected and location['source_index'] == 1 and location['path'] == 'src/math.brc',
         f'Isolated project diagnostic did not preserve the second source: {observed}')

    manifest = json.loads(original)
    manifest['requires'] = ['quote.lookup']
    project.write_text(json.dumps(manifest), encoding='utf-8')
    math.unlink()
    denied = json.loads(run([image, '--internal-project-broker', 'run', project_arg],
                            cwd=folder, env=env, expected_exit=4, no_stderr=True))
    need(denied['error']['kind'] == 'unavailable' and denied['return_i32'] is None,
         f'An ungranted requirement reached project source acquisition or execution: {denied}')
    run([image, '--internal-project-worker'], cwd=folder, env=env, expected_exit=4, silent=True)
    need(not list(Path(env['TEMP']).iterdir()), 'project runs left staged resources')
    return 5


def verify_configured_project(run, need, image, folder, env):
    target = folder / 'configured'
    shutil.copytree(HELLO_PROJECT, target)
    project = target / 'project.json'
    policy_file = target / 'policy.json'
    run_file = target / 'run.json'
    manifest = json.loads(project.read_bytes())
    policy = json.loads(POLICY_EXAMPLE.read_bytes())
    policy['compile']['source_bytes'] = sum((target / s['path']).stat().st_size for s in manifest['sources'])
    policy['compile']['modules'] = len(manifest['sources'])
    config = dict(schema='brownie.run/0.3', entry=manifest['entry'].copy(),
                  requires=[], grants=[], limits=policy['run'].copy())

    def check(expected_exit=0, kind=None, operation='run', payload=None, value=42, output=None):
        policy_file.write_text(json.dumps(policy), encoding='utf-8')
        run_file.write_text(json.dumps(config), encoding='utf-8')
        args = [image, '--internal-project-broker', operation, project, policy_file, run_file]
        if payload is not None:
            args.append(payload)
        data = json.loads(run(args, cwd=folder, env=env, expected_exit=expected_exit, no_stderr=True))
        status = 'checked' if operation == 'check' else 'completed'
        expected = value if operation == 'run' else None
        need(data['schema'] == 'browniec.result/v2' and data['command'] == operation and
             (data['error']['kind'] == kind and data['return_i32'] is None if kind else
              data['status'] == status and data['return_i32'] == expected and data['error'] is None),
             f'Unexpected configured project result: {data}')
        if output is None:
            need('output_b64' not in data, f'Unexpected guest output: {data}')
        else:
            need(base64.b64decode(data['output_b64'], validate=True) == output,
                 'Guest output differs from the sealed payload')
        need(not list(Path(env['TEMP']).iterdir()), 'configured project left staged resources')
        return data

    check()
    policy['compile']['source_bytes'] -= 1
    check(3, 'compile_limit')
    policy['compile']['source_bytes'] += 1
    config['limits']['fuel'] = 1
    check(5, 'fuel')
    config['limits']['fuel'] = policy['run']['fuel'] + 1
    check(4, 'unavailable')
    config['limits']['fuel'] = policy['run']['fuel']

    working = policy['compile']['working_bytes']
    policy['compile']['working_bytes'] = policy['compile']['source_bytes']
    check(3, 'compile_limit')
    policy['compile']['working_bytes'] = working

    compile_defaults = policy['compile'].copy()
    # The two original hello files have 27 and 17 lexer tokens, excluding EOF.
    policy['compile'].update(tokens=44, functions=2)
    check()
    policy['compile']['tokens'] = 43
    check(3, 'compile_limit')
    policy['compile']['tokens'] = 44
    policy['compile']['functions'] = 1
    check(3, 'compile_limit')
    policy['compile'] = compile_defaults.copy()
    policy['compile']['instructions'] = 1
    check(3, 'compile_limit', 'check')
    policy['compile'] = compile_defaults.copy()

    math_file = target / 'src/math.brc'
    original_source = math_file.read_bytes()
    math_file.write_text(
        'module util::math;\nstruct One { i32 value; }\nstruct Two { i32 value; }\n'
        'pub fn i32 answer(){var i32 n=40; n+=2; return n;}\n', encoding='utf-8')
    policy['compile'].update(source_bytes=4096, types=2)
    check()
    policy['compile']['types'] = 1
    check(3, 'compile_limit')
    policy['compile']['types'] = 2
    policy['compile']['registers_per_function'] = 1
    check(3, 'compile_limit')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    nested_source = (b'module util::math;\npub fn i32 answer(){var i32 n=40;'
                     b' /* [{( */ { n += (2); } { n += 0; } return n;}\n')
    math_file.write_bytes(nested_source)
    policy['compile'] = dict(compile_defaults, source_bytes=4096, depth=2)
    check()
    policy['compile']['depth'] = 1
    location = check(3, 'compile_limit', 'check')['error']['location']
    offset = nested_source.index(b'(2)')
    need(location['source_index'] == 1 and location['path'] == 'src/math.brc' and
         location['offset'] == offset and location['end_offset'] == offset + 1,
         f'Unexpected nesting limit location: {location}')
    policy['compile'] = compile_defaults
    math_file.write_bytes(original_source)

    runtime = config['limits'].copy()
    config['limits'].update(memory_bytes=1, object_bytes=1, input_bytes=0, output_bytes=0,
                            host_request_bytes=1, host_response_bytes=1)
    check(5, 'memory_limit')
    config['limits'] = runtime

    math_file.write_text('module util::math;\npub fn i32 answer(){var i32 n=0;'
                         'while(n<2000000000){n+=1;}return n;}\n', encoding='utf-8')
    initial_source_limit = policy['compile']['source_bytes']
    policy['compile']['source_bytes'] = 4096
    config['limits']['deadline_ms'] = 1
    check(5, 'deadline')
    config['limits']['deadline_ms'] = policy['run']['deadline_ms']
    policy['compile']['source_bytes'] = initial_source_limit
    math_file.write_bytes(original_source)

    entry = target / 'src/main.brc'
    original_entry = entry.read_bytes()
    payload = target / 'guest.bin'
    payload.write_bytes(bytes(8192) + bytes([255]))
    check(4, 'unavailable', payload=payload)
    entry.write_bytes(b'module app; pub fn i32 start(ref u8[] data){'
                      b'if(data.len==0){return 0;}return data[data.len-1] as i32;}')
    source_limit = policy['compile']['source_bytes']
    input_limit = config['limits']['input_bytes']
    policy['compile']['source_bytes'] = 4096
    config['limits']['input_bytes'] = 8193
    check(payload=payload, value=255)
    config['limits']['input_bytes'] = 8192
    check(5, 'input_limit', payload=payload)
    config['limits']['input_bytes'] = input_limit
    check(operation='check')
    check(4, 'unavailable')
    check(2, 'usage', operation='check', payload=payload)
    instruction_limit = policy['compile']['instructions']
    policy['compile']['instructions'] = 1
    check(3, 'compile_limit', operation='check')
    policy['compile']['instructions'] = instruction_limit
    payload.write_bytes(bytes(1048575) + bytes([77]))
    check(payload=payload, value=77)
    payload.write_bytes(b'')
    check(payload=payload, value=0)
    entry.write_bytes(original_entry)
    policy['compile']['source_bytes'] = source_limit

    output_cap = ['brownie.output.emit']
    binary = bytes(8192) + bytes([255])
    payload.write_bytes(binary)
    policy['compile']['source_bytes'] = 4096
    entry.write_bytes(b'module app; pub fn i32 start(ref u8[] data){output::emit(ref data);return 77;}')
    check(4, 'unavailable', payload=payload)
    manifest['requires'] = output_cap
    project.write_text(json.dumps(manifest), encoding='utf-8')
    config['requires'] = output_cap
    check(4, 'unavailable', payload=payload)
    config['grants'] = output_cap
    check(operation='check')
    config['limits']['output_bytes'] = len(binary)
    check(payload=payload, value=77, output=binary)
    config['limits']['output_bytes'] -= 1
    check(5, 'output_limit', payload=payload)
    config['limits']['output_bytes'] = policy['run']['output_bytes']
    entry.write_bytes(b'module app; pub fn i32 start(ref u8[] data){output::emit(ref data);'
                      b'var i32 zero=0; return 1/zero;}')
    check(5, 'zero_divisor', payload=payload)
    entry.write_bytes(b'module app; pub fn i32 start(){output::emit(ref b"Hi");return 77;}')
    check(value=77, output=b'Hi')
    entry.write_bytes(original_entry)
    policy['compile']['source_bytes'] = source_limit
    manifest['requires'] = config['requires'] = config['grants'] = []
    project.write_text(json.dumps(manifest), encoding='utf-8')

    baseline = policy['worker'].copy()
    policy['worker'].update(startup_ms=1, session_ms=1)
    policy['compile']['deadline_ms'] = policy['run']['deadline_ms'] = config['limits']['deadline_ms'] = 1
    check(5, 'deadline')
    policy['worker'] = baseline

    (target / 'src/math.brc').unlink()
    policy['compile']['modules'] -= 1
    check(3, 'compile_limit')
    policy['compile']['modules'] += 1
    config['entry']['function'] = 'other'
    check(4, 'unavailable')
    config['entry']['function'] = manifest['entry']['function']
    config['grants'] = ['brownie.output.emit']
    check(4, 'unavailable')
    return 36


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scalar-images', type=Path,
                        help='directory containing locked development/browniec.exe and release/browniec.exe')
    args = parser.parse_args()
    scalar_images = args.scalar_images.resolve() if args.scalar_images else None
    spec = importlib.util.spec_from_file_location('probe', ROOT / 'tools/verify-runtime-store-probe.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper.need(os.name == 'nt' and not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ),
                'Windows required with no compiler or linker overrides')
    out = ROOT / 'build/restricted-worker' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    paths = ['native/restricted_worker.c', 'native/restricted_worker.h',
             'native/restricted_worker_pipes.c', 'native/restricted_worker_pipes.h',
             'native/restricted_worker_frame.c', 'native/restricted_worker_frame.h',
             'native/restricted_worker_stream.c', 'native/restricted_worker_stream.h',
             'native/restricted_worker_gate.c', 'native/restricted_worker_gate.h',
             'native/restricted_worker_io.c', 'native/restricted_worker_io.h',
             'native/restricted_worker_broker.c', 'native/restricted_worker_broker.h',
             'native/restricted_worker_stage.c', 'native/restricted_worker_stage.h',
             'tests/native/restricted_worker_host.c', 'tools/verify-restricted-worker.py',
             'tools/verify-runtime-store-probe.py']
    c_sources = [path for path in paths if path.endswith('.c')]
    if scalar_images:
        paths.extend(['fairy.windows.json', 'fairy.toml', 'fairy.lock', 'examples/answer.brc',
                      POLICY_EXAMPLE.relative_to(ROOT).as_posix()])
        paths.extend(path.relative_to(ROOT).as_posix() for path in sorted(HELLO_PROJECT.rglob('*'))
                     if path.is_file())
        paths.extend(path.relative_to(ROOT).as_posix()
                     for folder in ('src', 'native') for path in sorted((ROOT / folder).rglob('*'))
                     if path.is_file())
        paths = list(dict.fromkeys(paths))
    receipt = dict(schema='browniec.restricted-worker-verification/v1', status='incomplete',
                   inputs=[dict(path=p, sha256=helper.sha((ROOT / p).read_bytes())) for p in paths],
                   profiles=[], commands=[])

    def run(args, cwd=out, env=None, timeout=30, expected_exit=0, silent=False, no_stderr=False):
        command = list(map(str, args))
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=timeout)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index}.stdout', f'logs/{index}.stderr'
        helper.write(out / stdout, result.stdout)
        helper.write(out / stderr, result.stderr)
        receipt['commands'].append(dict(argv=command, exit=result.returncode, stdout=stdout, stderr=stderr))
        helper.need(result.returncode == expected_exit and (not no_stderr or not result.stderr)
                    and (not silent or not (result.stdout or result.stderr)),
                    f'{command}: {result.returncode}: {result.stdout!r} {result.stderr!r}')
        return result.stdout

    try:
        cl, env, receipt['msvc'] = helper.native_environment(run)
        for profile, option in [('development', '/Od'), ('release', '/O2')]:
            folder = out / profile
            folder.mkdir()
            exe = folder / 'worker-host.exe'
            child = folder / 'worker fixture.exe'
            run([cl, '/nologo', '/std:c11', '/TC', '/MT', '/W4', '/WX', option,
                 *(ROOT / path for path in c_sources), '/Fe' + str(exe),
                 '/link', 'advapi32.lib', 'bcrypt.lib', 'mincore.lib', 'userenv.lib', '/INCREMENTAL:NO', '/Brepro'],
                cwd=folder, env=env)
            shutil.copyfile(exe, child)
            (folder / 'parent-data.txt').write_bytes(b'fixture data\n')
            (folder / 'empty-image.exe').touch()
            runtime_env = {k: v for k, v in os.environ.items()
                           if k.upper() in {'SYSTEMROOT', 'WINDIR', 'LOCALAPPDATA', 'USERPROFILE', 'TEMP', 'TMP'}}
            command = [exe, child]
            scalar = None
            if scalar_images:
                scalar = folder / 'browniec.exe'
                shutil.copyfile(scalar_images / profile / scalar.name, scalar)
                shutil.copyfile(ROOT / 'examples/answer.brc', folder / 'answer.brc')
                (folder / 'bad-source.brc').write_bytes(b'\xff')
                run([scalar, '--internal-scalar-worker'], cwd=folder, env=runtime_env,
                    expected_exit=4, silent=True)
                stage_temp = folder / 'stage temp'
                stage_temp.mkdir()
                stage_env = dict(runtime_env, TEMP=str(stage_temp), TMP=str(stage_temp))
                data = run([scalar, '--internal-scalar-broker', 'run', 'answer.brc'],
                           cwd=folder, env=stage_env, no_stderr=True)
                helper.need(json.loads(data) == dict(schema='browniec.result/v1', profile='brownie.m1-scalar/1',
                            command='run', status='completed', return_i32=77, error=None),
                            f'Unexpected managed broker result: {data!r}')
                helper.need(not list(stage_temp.iterdir()), 'managed launch left a staged file or directory')
                invalid_temp = stage_temp / 'missing'
                failure_env = dict(runtime_env, TEMP=str(invalid_temp), TMP=str(invalid_temp))
                data = run([scalar, '--internal-scalar-broker', 'run', 'answer.brc'],
                           cwd=folder, env=failure_env, expected_exit=4, no_stderr=True)
                helper.need(json.loads(data).get('error', {}).get('kind') == 'unavailable'
                            and not list(stage_temp.iterdir()), 'staging failure fell back or left files')
                managed_project_cases = verify_managed_project(run, helper.need, scalar, folder, stage_env)
                configured_project_cases = verify_configured_project(run, helper.need, scalar, folder, stage_env)
                command.append(scalar)
            evidence = json.loads(run(command, cwd=folder, env=runtime_env))
            helper.need({key: value for key, value in evidence.items()
                         if key not in {'coldHandleDelta', 'parentColdHandleDelta'}} ==
                        dict(appContainer=True, capabilities=0, inheritedPipes=3,
                             commitDenied=True, cpuTermination=True, privatePipeAcl=True,
                             framedExchange=True, headerMutationsRejected=48,
                             boundedStream=True, pipeEof=True, publicationGate=True,
                             ioLease=True, brokerSessions=6, sharedBudget=True,
                             phaseDeadlines=True, gracefulCancelCases=2, handleDelta=0, staging=True,
                             scalarSessions=5 if scalar else 0, parentBrokerCases=4 if scalar else 0,
                             projectWireRejections=2 if scalar else 0)
                        and type(evidence.get('coldHandleDelta')) is int
                        and evidence.get('parentColdHandleDelta') in ((0, 1) if scalar else (0,)),
                        f'Unexpected worker result: {evidence}')
            receipt['profiles'].append(dict(profile=profile, exe=helper.image(exe), result=evidence))
            if scalar:
                receipt['profiles'][-1]['scalarWorker'] = helper.image(scalar)
                receipt['profiles'][-1]['managedProjectCases'] = managed_project_cases
                receipt['profiles'][-1]['configuredProjectCases'] = configured_project_cases
            print(f'PASS {profile}: {evidence}', flush=True)
        helper.need(all(helper.sha((ROOT / i['path']).read_bytes()) == i['sha256'] for i in receipt['inputs']),
                    'Inputs changed during verification')
        receipt['status'] = 'passed'
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        helper.record(out / 'receipt.json', receipt)
        print(f'Receipt: {out / "receipt.json"}')


if __name__ == '__main__':
    main()
