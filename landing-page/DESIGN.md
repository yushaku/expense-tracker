# MonMon — Tiền gọn. Đời nhẹ.

## Creative direction

A Vietnamese, image-led landing page for the personal-finance app in this repository.
Treat money as a small collection of things with a purpose: capture a transaction,
divide income between jars, then see the whole picture. Editorial and tactile,
not a banking dashboard. Short copy, oversized headings, asymmetric compositions,
pastel diagrams and a still life of savings jars.

- Background: warm paper `#f5f2e9`; ink: deep olive `#263b31`.
- Accents: sage `#c9d9b5`, lilac `#d8cfee`, peach `#edb798`, yellow `#edcf7c`.
- Typography: system sans for readable Vietnamese, Georgia italic for emphasis.
- Layout: split hero → capture flow → interactive jar allocation → asset map → privacy.
- Interaction: change illustrative monthly income to see the six seeded allocations.
- Product claims: grounded in the repository README and BudgetJarSeed.swift.
- No invented App Store link, user counts, performance claims or testimonials.

## Images

- Use MonMon's existing production icon.
- Generated still life: original at
  `/Users/sonlv/.codex/generated_images/01a07112-ef84-7883-8eed-29eafae0fbbd/exec-0562152a-e770-4fce-b164-8a1cb79c36d5.png`.
- CUA can enumerate MonMon Dev, but opening its window still reports
  `Computer Use permissions are not granted`, including after the user's restart
  and a fresh attempt. Actual app screenshots could not be captured.
- Do not substitute fabricated screens for actual product screenshots. Any demo
  figures are explicitly marked as illustrative.

## Working state

Branch: `feat/monmon-landing-page`, based on fetched dev (32 commits ahead, none behind).
Work continued in an isolated worktree because the shared checkout switched to
another task's branch. Existing deletions in docs and scripts are untouched.

Browser checks passed at 1440, 390 and 320 px: no horizontal overflow, no broken
images, no missing anchor targets and no JavaScript console errors. Keyboard Home
and End adjust income to 5 and 50 million VND with correct allocations. Reduced
motion disables smooth scrolling. Desktop and mobile screenshots were inspected;
the hero image's aspect ratio and percentage-label contrast were corrected.
Swift format lint and all macOS unit tests passed in the landing-page worktree.
The iOS SDK compile check also passed after retrying a shared build database lock.
Do not merge, push or deploy without a user request.
