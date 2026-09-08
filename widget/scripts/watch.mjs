import { spawn } from 'node:child_process';
import { resolve } from 'node:path';

const children = new Set();
let stopping = false;

async function stop(code) {
  if (stopping) return;
  stopping = true;
  const waits = [...children].map(child => new Promise(resolve => {
    child.once('close', resolve);
    child.kill('SIGTERM');
    const force = setTimeout(() => child.kill('SIGKILL'), 5000);
    force.unref();
  }));
  await Promise.all(waits);
  process.exit(code);
}

function launch(relativeTool, args) {
  const child = spawn(process.execPath, [resolve('node_modules', relativeTool), ...args], {
    stdio: 'inherit',
    env: { ...process.env, NODE_ENV: process.argv.includes('--production') ? 'production' : 'development' },
  });
  children.add(child);
  child.once('close', () => children.delete(child));
  child.once('error', error => { console.error(error); void stop(1); });
  return child;
}

process.once('SIGINT', () => { void stop(130); });
process.once('SIGTERM', () => { void stop(143); });

// Rollup consumes dist, so complete an initial TypeScript build before it starts.
const initial = launch('typescript/bin/tsc', []);
initial.once('exit', code => {
  if (stopping) return;
  if (code !== 0) { void stop(code ?? 1); return; }
  for (const child of [
    launch('typescript/bin/tsc', ['--watch', '--preserveWatchOutput']),
    launch('rollup/dist/bin/rollup', ['--config', '--watch']),
  ]) {
    child.once('exit', code => { if (!stopping) void stop(code ?? 1); });
  }
});
