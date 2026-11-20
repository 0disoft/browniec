"""Render or check localized CLI output tables from one shared contract."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'docs-site/cli-output.json'
START = '<!-- cli-output:start -->'
END = '<!-- cli-output:end -->'
HEADERS = {
    'en': ('Command', 'Output option', 'Channel', 'Schema'),
    'ko': ('명령', '출력 옵션', '채널', '스키마'),
    'es': ('Comando', 'Opción de salida', 'Canal', 'Esquema'),
    'zh': ('命令', '输出选项', '通道', '模式'),
}


def table(rows, locale):
    lines = ['| ' + ' | '.join(HEADERS[locale]) + ' |', '| --- | --- | --- | --- |']
    for row in rows:
        command = ' '.join(part for part in ('browniec', row['command'], row['arguments']) if part)
        command = command.replace('|', r'\|')
        for mode in row['formats']:
            option = mode['option']
            schema = mode['schema']
            lines.append(
                f"| `{command}` | {quoted(option)} | `{mode['channel']}` | {quoted(schema)} |"
            )
    return '\n'.join(lines)


def quoted(value):
    return f'`{value}`' if value else '—'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    rows = json.loads(DATA.read_bytes())
    for locale in HEADERS:
        target = ROOT / f'docs-site/src/content/docs/{locale}/cli/commands-and-errors.md'
        original = target.read_text(encoding='utf-8')
        before, _, rest = original.partition(START)
        _, _, after = rest.partition(END)
        if original.count(START) != 1 or original.count(END) != 1 or not rest:
            raise SystemExit(f'Missing CLI output table markers: {target}')
        expected = f'{before}{START}\n{table(rows, locale)}\n{END}{after}'
        if args.check:
            if original != expected:
                raise SystemExit(f'Stale CLI output table: {target}')
        else:
            target.write_text(expected, encoding='utf-8', newline='\n')
    print('CLI output tables match the shared contract (en, ko, es, zh).')


if __name__ == '__main__':
    main()
