"""Build and run the Windows AppContainer and Job launcher fixture."""

import argparse
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

    def check(expected_exit=0, kind=None):
        policy_file.write_text(json.dumps(policy), encoding='utf-8')
        run_file.write_text(json.dumps(config), encoding='utf-8')
        data = json.loads(run([image, '--internal-project-broker', 'run', project, policy_file, run_file],
                              cwd=folder, env=env, expected_exit=expected_exit, no_stderr=True))
        need(data['schema'] == 'browniec.result/v2' and data['command'] == 'run' and
             (data['error']['kind'] == kind and data['return_i32'] is None if kind else
              data['status'] == 'completed' and data['return_i32'] == 42),
             f'Unexpected configured project result: {data}')
        need(not list(Path(env['TEMP']).iterdir()), 'configured project left staged resources')

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

    runtime = config['limits'].copy()
    config['limits'].update(memory_bytes=1, object_bytes=1, input_bytes=0, output_bytes=0,
                            host_request_bytes=1, host_response_bytes=1)
    check(5, 'memory_limit')
    config['limits'] = runtime

    math_file = target / 'src/math.brc'
    original_source = math_file.read_bytes()
    math_file.write_text('module util::math;\npub fn i32 answer(){var i32 n=0;'
                         'while(n<2000000000){n+=1;}return n;}\n', encoding='utf-8')
    initial_source_limit = policy['compile']['source_bytes']
    policy['compile']['source_bytes'] = 4096
    config['limits']['deadline_ms'] = 1
    check(5, 'deadline')
    config['limits']['deadline_ms'] = policy['run']['deadline_ms']
    policy['compile']['source_bytes'] = initial_source_limit
    math_file.write_bytes(original_source)

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
    return 11


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
