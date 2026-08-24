# MonMon Agent Workflow

## Physical iPhone validation

All agents and sub-agents working in this repository must follow this workflow.

- Do not use an iPhone Simulator for runtime or UI validation unless the user explicitly requests it.
- After a relevant app change, build, install, and launch MonMon on the physical iPhone named `Yushaku` with `scripts/run-iphone.sh Yushaku`.
- The iPhone must be connected, unlocked, and have Developer Mode enabled. If it is unavailable, locked, or busy preparing, report that blocker and wait; do not silently fall back to a Simulator.
- Report only whether build, install, and launch succeeded. The user performs and owns hands-on UI and acceptance testing on the physical device.
- Unit tests, format lint, and non-Simulator build checks remain quality gates before commit or merge unless the user explicitly waives them.

