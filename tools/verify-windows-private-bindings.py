"""Verify the pinned compiler's same-build Windows C-to-Fairy bindings."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
from tempfile import mkdtemp

ROOT = Path(__file__).resolve().parent.parent
COMPILER = ROOT / 'build/toolchain/fairyc.exe'
SOURCE = """module main;
resource Number { i32 value; cleanup {} }
unsafe extern C fn i32 bridge(ptr void value);
fn i32 decode(ref Number n){return n.value;}
fn i32 main(){
    let Number n=Number{.value=41};
    return unsafe{bridge(ref n as ptr void)}-41;
}
"""


def alias(kind, name):
    return f'fy_private_{kind}_{name.encode("utf-8").hex()}'


def verify():
    assert __debug__ and os.name == 'nt'
    assert not {'CL', '_CL_', 'LINK'}.intersection(key.upper() for key in os.environ)
    pin = json.loads((ROOT / 'toolchain.json').read_bytes())['platforms']['windows/amd64']['sha256']
    assert hashlib.sha256(COMPILER.read_bytes()).hexdigest() == pin
    project = Path(mkdtemp(prefix='windows-private-bindings-', dir=ROOT / 'build'))
    (project / 'src').mkdir()

    def write(name, content):
        (project / name).write_text(content, encoding='utf-8', newline='\n')

    def configure(names):
        write('fairy.windows.json', json.dumps({
            'schema': 'fairyc.windows-build/v1', 'subsystem': 'console',
            'sources': ['bridge.c'], 'privateFunctions': names,
        }))

    def run(*args, code=0):
        result = subprocess.run(args, cwd=project, capture_output=True, timeout=180)
        assert result.returncode == code, (args, project, result)
        return result

    (project / 'fairy.toml').write_bytes((ROOT / 'fairy.toml').read_bytes())
    write('bridge.c', f"""#define FY_PROJECT_PRIVATE_BINDINGS
#include "fy_project.h"
int32_t bridge(const void *value) {{
    const {alias('type', 'main::Number')} *number=value;
    return {alias('fn', 'main::decode')}(number);
}}
""")
    configure(['main::decode'])
    write('src/main.fy', SOURCE)
    run(COMPILER, 'check')
    run(COMPILER, 'build', '--locked')
    exe = project / 'build/browniec.exe'
    assert not run(exe).stderr

    # A new earlier-sorting reachable function changes generated symbol numbers.
    write('src/earlier.fy', 'module earlier; pub fn i32 another(){return 1;}\n')
    write('src/main.fy', SOURCE.replace('module main;', 'module main; import earlier as earlier;')
          .replace('}-41;', '}-40-earlier::another();'))
    run(COMPILER, 'check')
    run(COMPILER, 'build', '--release', '--locked')
    assert not run(exe).stderr

    for names, error in (
        (['main::absent'], b'missing or unsupported private application function'),
        (['main::decode', 'main::decode'], b'invalid/duplicate private Windows function'),
    ):
        configure(names)
        result = run(COMPILER, 'build', '--locked', code=6)
        assert error in result.stderr, result
    print(f'PASS: development and release C-to-Fairy bindings, missing and duplicate rejection ({project})')


if __name__ == '__main__':
    verify()
