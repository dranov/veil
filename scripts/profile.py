#!/usr/bin/env python3
"""Portable single-file/folder profiling; shell entry points preserve the old CLI."""

import argparse
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import runpy
import signal
import subprocess
import sys
import time

SCRIPTS = Path(__file__).resolve().parent
ANALYSIS = runpy.run_path(str(SCRIPTS / 'parse-profile.py'))


def source_files(root):
    for directory, dirs, files in os.walk(root):
        dirs[:] = sorted(name for name in dirs if name not in {'.git', '.lake', '.veil.tmp', 'node_modules'})
        for name in sorted(files):
            if name.endswith('.lean'):
                yield Path(directory) / name


def stop_child(child):
    try:
        if os.name == 'posix':
            os.killpg(child.pid, signal.SIGTERM)
        else:
            child.terminate()
    except ProcessLookupError:
        child.wait()
        return
    try:
        child.wait(timeout=5)
    except subprocess.TimeoutExpired:
        if os.name == 'posix':
            os.killpg(child.pid, signal.SIGKILL)
        else:
            child.kill()
        child.wait()


def profile_file(source, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    # A failed run must never reuse a successful run's old profile.
    output.unlink(missing_ok=True)
    log = output.with_suffix('.log')
    command = ['lake', 'lean', str(source), '--', '-Dtrace.profiler=true',
               f'-Dtrace.profiler.output={output}', '-Dtrace.veil.perf=true', '-Dtrace.smt.perf=true']
    start = time.monotonic()
    record = {'file': str(source), 'status': 'failed', 'real_seconds': 0.0,
              'cpu_seconds': None, 'profile_file': str(output), 'log_file': str(log)}
    try:
        with log.open('w') as stream:
            child = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                     start_new_session=os.name == 'posix')
            try:
                record['exit_code'] = child.wait()
            except KeyboardInterrupt:
                stop_child(child)
                raise
        if record['exit_code'] == 0:
            profile = ANALYSIS['load_profile'](output)
            stats = ANALYSIS['analyze_single_profile'](profile)
            record['cpu_seconds'] = ANALYSIS['get_total_cpu_time'](stats) / 1000
            record['status'] = 'ok'
    except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
        record['error'] = str(error)
    finally:
        record['real_seconds'] = time.monotonic() - start
    return record


def write_summary(output, records, interrupted):
    failed = sum(record['status'] != 'ok' for record in records)
    summary = {'format': 'veil-profile-run-v1', 'interrupted': interrupted, 'files': records}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    columns = ['file', 'status', 'real_seconds', 'cpu_seconds', 'profile_file', 'log_file']
    with (output / 'summary.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(records)
    text = (f'Total files completed: {len(records)}\nSuccessful: {len(records) - failed}\n'
            f'Failed: {failed}\nInterrupted: {interrupted}\n'
            f'Wall seconds: {sum(record["real_seconds"] for record in records):.3f}\n')
    (output / 'summary.txt').write_text(text)
    print(text, end='')
    profiles = [record['profile_file'] for record in records if record['status'] == 'ok']
    (output / 'profiles.json').write_text(json.dumps(profiles, indent=2) + '\n')
    return profiles


def aggregate(profiles, output, options):
    if not profiles:
        return 0
    command = [sys.executable, str(SCRIPTS / 'parse-profile.py'), *profiles, *options]
    with (output / 'timing.txt').open('w') as stream:
        text_result = subprocess.run(command, stdout=stream).returncode
    with (output / 'timing.json').open('w') as stream:
        json_result = subprocess.run([*command, '--json'], stdout=stream).returncode
    print(f'Timings: {output / "timing.json"} (full identifiers; suitable for plotting)')
    return text_result or json_result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['file', 'folder'])
    parser.add_argument('arguments', nargs=argparse.REMAINDER, help='[--quiet] source [output] [parser options...]')
    args = parser.parse_args(argv)
    options = list(args.arguments)
    quiet = bool(options and options[0] in {'--quiet', '-q'})
    if quiet:
        options.pop(0)
    source = Path(options.pop(0) if options else '.')
    output_arg = options.pop(0) if options and not options[0].startswith('-') else None
    if args.mode == 'file':
        if not source.is_file():
            parser.error(f'{source}: expected a Lean source file')
        output = Path(output_arg) if output_arg else Path('profiles') / source.with_suffix('.json').name
        try:
            record = profile_file(source, output)
        except KeyboardInterrupt:
            return 130
        print(json.dumps(record, indent=2))
        if record['status'] != 'ok':
            return 1
        if not quiet:
            return subprocess.run([sys.executable, str(SCRIPTS / 'parse-profile.py'), str(output), *options]).returncode
        return 0

    if not source.is_dir():
        parser.error(f'{source}: expected a source directory')
    output = Path(output_arg) if output_arg else Path('profiles') / datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
    output.mkdir(parents=True, exist_ok=True)
    records = []
    interrupted = False
    try:
        for file in source_files(source):
            destination = output / file.relative_to(source).with_suffix('.json')
            record = profile_file(file, destination)
            records.append(record)
            print(f'{record["status"]}: {file} ({record["real_seconds"]:.3f}s)', flush=True)
    except KeyboardInterrupt:
        interrupted = True
    finally:
        profiles = write_summary(output, records, interrupted)
    aggregation_status = aggregate(profiles, output, options)
    if interrupted:
        return 130
    return 1 if not records or aggregation_status or any(record['status'] != 'ok' for record in records) else 0


if __name__ == '__main__':
    sys.exit(main())
