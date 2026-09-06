# Compiled model-checker execution

Each compiled request reserves its own directory under `.lake/model_checker_builds`.
Exclusive creation prevents different files with the same basename, different checks
in one file, and concurrent Lean processes from overwriting each other's sources.
The directory is removed after the request completes, fails, or is cancelled.
These directories are not a persistent native build cache.

Generated source replays the command prefix, including definitions, local instances,
namespace openings, and options after `#gen_spec`. Lean's module-header parser finds
the insertion point for internal options. Earlier model-check commands are disabled
while replaying the prefix; only the selected command defines the native entry point.

Compilation and native execution use the same streaming process runner. It checks
request cancellation before spawning, during execution, and before publishing output.
On POSIX, children start in a new process group; cancellation terminates the group
and waits for the process and both output readers. On other platforms, Lean's process
API terminates the immediate child, without its POSIX process-group guarantee.

An explicit compiled request reports compiler, missing-binary, execution, and output
parsing failures as Lean errors, even with `veil.violationIsError false`. Default mode
retains interpreted execution if acceleration fails; a failure after handoff is a
terminal error. A finished interpreted result cancels an unnecessary background build.

Progress, terminal results, and handoff state share one lock. Completion and
cancellation publish a consistent terminal snapshot, and late worker updates cannot
reopen it. Stop requests survive handoff's replacement of the worker cancellation
token. A violation discovered while the interpreted worker drains prevents restart.

Memory retention is bounded independently:

- The global index retains 64 completed results, plus active runs. Panels and workers
  own their run handles, so evicting an index entry does not invalidate a displayed
  result. An expired ID is terminal rather than something to poll indefinitely.
- A run keeps the latest 512 progress samples.
- Live compilation logs retain 256 lines, each truncated to 2,048 characters.
- Captured compiler stdout and stderr retain their last 65,536 characters, with a
  truncation marker. Native result stdout remains complete so large traces are not
  silently corrupted; native stderr has the same diagnostic retention budget.

Run `lake build VeilTest` for the Lean regressions. After building Veil, run
`python3 scripts/test-compiled-model-checker.py` for the command-level integration
checks. These inject the child compiler and elaborate a generated model using Lean;
they do not validate the platform's native solver/linker installation.
