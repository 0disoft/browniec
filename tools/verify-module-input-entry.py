"""Execute actual owning InputEntry and unchanged zero-argument native tests."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BASE = 'f78a734fd079324e0ba88bb8e40e4291acf55de8'
FILES = ['src/module_input_entry.fy', 'tests/m2/module_input_entry.fy',
         'tools/verify-module-input-entry.py', 'docs/engineering/module-input-entry.md']


def sha(b):
    return hashlib.sha256(b).hexdigest()


def write(p, b):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(b.encode() if isinstance(b, str) else b)


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--compiler', type=Path, default=ROOT/'build/toolchain/fairyc.exe')
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows native verification required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ), 'Compiler environment overrides prohibited')
    out = ROOT/'build/module-input-entry'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    receipt = dict(schema='browniec.module-input-entry/v1', baseCommit=BASE, status='incomplete',
                   commands=[], native=[], negatives=[], defaultStacks=True,
                   stackOverrides=False, environmentOverrides=False)
    compiler = args.compiler.resolve(strict=True)

    def run(argv, label, cwd, reject=False):
        argv = list(map(str, argv))
        need(not any('/STACK' in a.upper() for a in argv), 'Stack overrides prohibited')
        p = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=600)
        name = f'{len(receipt["commands"]):03}-{label}'
        write(out/(name+'.stdout'), p.stdout)
        write(out/(name+'.stderr'), p.stderr)
        receipt['commands'].append(dict(argv=argv, cwd=str(cwd), exit=p.returncode,
            stdout=name+'.stdout', stderr=name+'.stderr', stdoutSha256=sha(p.stdout), stderrSha256=sha(p.stderr)))
        need(p.returncode != 0 if reject else p.returncode == 0,
             f'{label}: {p.returncode}; {p.stderr[-2500:]!r}; {p.stdout[-1000:]!r}')
        if not reject:
            need(not p.stderr, label+': unexpected stderr')
        return p.stderr if reject else p.stdout

    try:
        tc = json.loads((ROOT/'toolchain.json').read_bytes())
        compiler_sha = sha(compiler.read_bytes())
        need(compiler_sha == tc['platforms']['windows/amd64']['sha256'], 'Pinned compiler hash')
        version = run([compiler, '--version'], 'version', out).decode()
        need(tc['compiler']['revision'] in version and tc['sdk']['version'] in version, 'Compiler/SDK identity')
        receipt['compiler'] = dict(sha256=compiler_sha, version=version)
        # Copy the real production import closure, plus unchanged zero-arg tests.
        inputs = {p: (ROOT/p).read_bytes() for p in FILES+['fairy.toml', 'toolchain.json', 'tests/m2/module_entry.fy']}
        pending = ['src/module_input_entry.fy', 'src/module_entry.fy']
        visited = set()
        while pending:
            path = pending.pop()
            if path in visited:
                continue
            visited.add(path)
            blob = (ROOT/path).read_bytes()
            inputs[path] = blob
            for module in re.findall(rb'import\s+([a-zA-Z_][a-zA-Z_0-9:]*)\s+as', blob):
                name = module.decode()
                if not name.startswith('std::'):
                    pending.append('src/'+name.replace('::', '/')+'.fy')
        need(all(b'\r' not in b for p, b in inputs.items() if p.endswith(('.fy', '.py', '.md'))), 'LF inputs')
        receipt['inputs'] = [dict(path=p, sha256=sha(b)) for p, b in sorted(inputs.items())]
        project = out/'project'
        for p, b in inputs.items():
            write(out/'inputs'/p, b)
            if p.endswith('.fy') or p == 'fairy.toml':
                write(project/p, b)
        write(project/'src/main.fy', 'module main;fn i32 main(){return 0;}\n')
        run([compiler, 'check'], 'lock', project)
        lock = (project/'fairy.lock').read_bytes()
        sdk = [p for p in json.loads(lock)['packages'] if p['role'] != 'root']
        need(len(sdk) == 1 and all(sdk[0][a] == tc['sdk'][b] for a, b in
             [('sdkIdentity', 'identity'), ('version', 'version')]), 'Pinned SDK lock')
        need(sdk[0]['runtimeAbi'] == tc['runtimeAbi'] and sdk[0]['sourceDigest'] ==
             'fysrc1-sha256-e256aabfe2a16a603f947d4ef5b55b5a4ae80915fdd855e18c6016910fbcc597',
             'Pinned bytes/text/vec SDK import-closure digest (not full-root SDK digest)')
        receipt['nativeLockSha256'] = sha(lock)
        receipt['sdk'] = sdk
        identities = []
        for module in ['module_input_entry', 'module_entry']:
            identities += ['tests::m2::'+module+'::'+n for n in
                re.findall(r'@test\s+fn void (\w+)\(', inputs['tests/m2/'+module+'.fy'].decode())]
        need(len(identities) == len(set(identities)) == 13, 'Seven input and six unchanged zero-arg groups')
        for profile in (['development', 'release'] if args.profile == 'all' else [args.profile]):
            cmd = [compiler, 'test', '--native', '--json', '--capture-output', '--locked']
            if profile == 'release':
                cmd.append('--release')
            for identity in identities:
                cmd += ['--exact', identity]
            raw = run(cmd, profile+'-native', project)
            report = json.loads(raw)
            need(report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native' and
                report['profile'] == profile and report['lock'] == 'verified' and report['status'] == 'ok' and
                report['count'] == report['passed'] == len(identities) and report['failed'] == 0 and
                {t['identity'] for t in report['tests']} == set(identities), 'Exact native results')
            need(all(t['outcome'] == 'passed' and t['trapCategory'] is None and
                not t['stdoutBase64'] and not t['stderrBase64'] for t in report['tests']), 'Native output/trap')
            receipt['native'].append(dict(profile=profile, groups=len(identities), reportSha256=sha(raw)))
            print(f'PASS {profile}: seven InputEntry and six unchanged Entry groups', flush=True)
        negatives = {
            'private-selected': 'fn void bad(ref mut e::InputEntry x){x.selected=0;}',
            'private-index': 'fn void bad(ref e::InputEntry x){discard x.index;}',
            'private-signature': 'fn void bad(ref mut e::InputEntry x){x.signature=e::signature_span(x);}',
            'private-parameter': 'fn void bad(ref mut e::InputEntry x){x.parameter=e::parameter_span(x);}',
            'private-name': 'fn void bad(ref mut e::InputEntry x){x.name=e::parameter_name_span(x);}',
            'private-forge': 'fn e::InputEntry bad(m::Index x){return e::InputEntry{.index=x,.selected=0,.signature=s::no_source(),.parameter=s::no_source(),.name=s::no_source()};}',
            'owner-lifetime': 'fn ref m::Index bad(e::InputEntry x){return e::index(ref x);}',
            'moved-owner': 'fn void bad(e::InputEntry x){let e::InputEntry y=x;discard e::selected(ref x);}',
        }
        for label, body in negatives.items():
            write(project/'src/negative.fy', 'module negative;import module_input_entry as e;import module_index as m;import source_snapshot as s;'+body+'\n')
            diagnostic = run([compiler, 'check'], label, project, reject=True)
            expected = ([b'E0103', b'E0101'] if label.startswith('private-') else
                        [b'E1101'] if label == 'moved-owner' else [b'E2102'])
            need(any(code in diagnostic for code in expected), 'Expected ownership/privacy diagnostic: '+label)
            receipt['negatives'].append(dict(name=label, diagnosticSha256=sha(diagnostic)))
            (project/'src/negative.fy').unlink()
        run([compiler, 'check'], 'restored-lock', project)
        need(all((ROOT/p).read_bytes() == b for p, b in inputs.items()), 'Inputs unchanged')
        need(sha(compiler.read_bytes()) == compiler_sha, 'Compiler unchanged')
        receipt.update(status='passed', executableInputPath=False, publicAvailabilityChanged=False,
            limitations=['Signature and owning Index only; module_program accepts only module_entry::Entry.',
                         'No guest input lowering, Engine/Instance/VM wiring, CLI, or body/type proof.',
                         'No new allocator seam: allocation belongs to existing Index construction.',
                         'No unsafe metadata/layout moves; no R03 or complete Engine accounting claim.'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        receipt['artifacts'] = [dict(path=p.relative_to(out).as_posix(), sha256=sha(p.read_bytes()))
            for p in sorted(out.rglob('*')) if p.is_file() and p.name != 'receipt.json']
        write(out/'receipt.json', json.dumps(receipt, indent=2)+'\n')
        write(ROOT/'build/module-input-entry/latest.json', json.dumps(dict(path=str(out/'receipt.json'),
              sha256=sha((out/'receipt.json').read_bytes())), indent=2)+'\n')
    print('Receipt: '+str(out/'receipt.json'), flush=True)


if __name__ == '__main__':
    main()
