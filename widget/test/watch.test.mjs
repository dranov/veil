import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, writeFile, readFile, symlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { setTimeout } from 'node:timers/promises';
import test from 'node:test';

async function waitFor(predicate, description) {
  const deadline = Date.now() + 25000;
  while (Date.now() < deadline) {
    if (await predicate()) return;
    await setTimeout(100);
  }
  assert.fail(`Timed out waiting for ${description}`);
}

test('watch builds from TypeScript and follows newly imported helpers', { timeout: 35000 }, async () => {
  const directory = await mkdtemp(join(tmpdir(), 'veil-watch-'));
  let child;
  let closed;
  let output = '';
  try {
    await symlink(resolve('node_modules'), join(directory, 'node_modules'), 'dir');
    await mkdir(join(directory, 'src'));
    await writeFile(join(directory, 'tsconfig.json'), JSON.stringify({
      compilerOptions: { module: 'esnext', target: 'es2020', outDir: 'dist', rootDir: 'src', skipLibCheck: true },
      include: ['src/*.ts'],
    }));
    await writeFile(join(directory, 'rollup.config.mjs'), 'export default {input:"dist/index.js",output:{file:"bundle.js",format:"es"}};');
    await writeFile(join(directory, 'src/index.ts'), 'export const message = "before";');
    child = spawn(process.execPath, [resolve('scripts/watch.mjs')], { cwd: directory });
    closed = new Promise(resolve => child.once('close', resolve));
    child.stdout.on('data', data => { output += data; });
    child.stderr.on('data', data => { output += data; });
    const bundled = async value => {
      try { return (await readFile(join(directory, 'bundle.js'), 'utf8')).includes(value); }
      catch { return false; }
    };
    await waitFor(() => bundled('before'), `initial source build: ${output}`);
    await writeFile(join(directory, 'src/helper.ts'), 'export const value = "after";');
    await writeFile(join(directory, 'src/index.ts'), 'export { value as message } from "./helper.js";');
    await waitFor(() => bundled('after'), `new TypeScript helper: ${output}`);
  } finally {
    if (child) {
      child.kill('SIGTERM');
      await closed;
    }
    await rm(directory, { recursive: true, force: true });
  }
});
