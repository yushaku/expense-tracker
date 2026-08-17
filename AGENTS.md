# Agent Instructions

Hard rules for every agent session. Skills live under `.agents/skills/`. Invoke the matching skill and follow it — do not improvise a parallel process.

## Documentation

All docs (specs, designs, plans, notes, READMEs) go in `docs/` only.

## Superpowers — mandatory order

Do **not** jump to implementation. Run the pipeline in order. Announce `Using [skill] to [purpose]` before acting. User instructions here override skills; skills override default behavior.

### 1. Spec & brainstorm

- Skill: `brainstorming` → then `writing-plans` when a multi-step design is approved
- Clarify intent, edge cases, design; get partner approval before code
- No implementation skill until brainstorming/plan gate passes

### 2. TDD (tests first)

- Skill: `test-driven-development`
- Write failing tests from the spec (**Red**) before production code
- Skipping TDD is forbidden (throwaway prototypes only with explicit partner OK)

### 3. Incremental implementation

- Skills: `executing-plans` and/or `subagent-driven-development` (independent tasks); `using-git-worktrees` when isolating feature work
- Small modules only; each change turns tests **Green**
- Parallel independent work → `dispatching-parallel-agents`

### 4. Review & refactor

- Skills: `verification-before-completion` before claiming done; `requesting-code-review` before merge/PR; `receiving-code-review` when handling feedback
- Refactor only with tests still green
- Bugs / failing tests → `systematic-debugging` (not guess-and-patch)

### 5. Finish & document

- Skill: `finishing-a-development-branch`
- Commit / PR / docs updates only after verification; follow partner rules for when to commit

## Skill lookup

| Skill                                              | Use for                | When                                     |
| -------------------------------------------------- | ---------------------- | ---------------------------------------- |
| `using-superpowers`                                | Find/invoke skills     | Start of work; any doubt a skill applies |
| `brainstorming`                                    | Requirements & design  | Before creative/feature work             |
| `writing-plans`                                    | Implementation plan    | After design approved, multi-step work   |
| `test-driven-development`                          | Red → Green → Refactor | Before any production code               |
| `executing-plans` / `subagent-driven-development`  | Build from plan        | After failing tests exist                |
| `systematic-debugging`                             | Root-cause fix         | Failures, bugs, flaky behavior           |
| `requesting-code-review` / `receiving-code-review` | Quality gate           | Before PR; when review arrives           |
| `verification-before-completion`                   | Prove it works         | Before "done" / "fixed" / "passing"      |
| `finishing-a-development-branch`                   | Merge/PR/cleanup       | Implementation complete + tests pass     |
| `writing-skills`                                   | Author/edit skills     | Changing `.agents/skills/`               |

## Best practices

- Small context: state the task; do not dump the whole repo unless needed
- Atomic tasks (~15–30 min slices), not whole systems in one shot
- Review each skill's output before the next step
- If a skill might apply (~1%), invoke it — no rationalizing around the pipeline
