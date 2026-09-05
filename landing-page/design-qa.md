# Design QA

final result: passed

## Comparison target and evidence

- Source: user attachment `/var/folders/78/1vjjzszd5kd99s2zj4s9d4kw0000gn/T/orca-paste-1788615310488-1edc88d2-5a3c-4ea1-aeaf-ae3ecf6ce339.png`.
- Source dimensions: 1920 × 1301 pixels.
- Implementation: `/tmp/monmon-landing-tools/reference-viewport.png`, rendered in
  isolated Chromium at 1920 × 1301 CSS pixels, device scale factor 1.
- State: page top, no dialog open. Source and implementation were opened together
  in the same comparison tool result. This is a style adaptation for MonMon, not a
  reproduction of Nexora's text, dashboard data or social-media overlay.
- Full-page evidence: `/tmp/monmon-landing-tools/desktop.png` (1440 px),
  `mobile.png` (390 px), `small.png` (320 px).
- Dialog evidence: `/tmp/monmon-landing-tools/dialog.png`.
- A separate crop was unnecessary: the 1920 px capture displays the complete hero
  with legible typography, feature cards, image frame and actions.

## Fidelity surfaces

- Typography: bold sans-serif, two-line hierarchy and violet/pink emphasis match
  the selected style; Vietnamese copy and system font are intentional adaptations.
- Layout: left-aligned copy, right-hand tilted dashboard, raised feature cards,
  paired rounded actions and lower feature row carry the reference's composition.
  A restrained maximum content width intentionally improves wide-screen reading.
- Color: white, lavender glow, violet buttons, soft translucent shadows. Original
  lower-page asset-map colors were identified as a mismatch and changed to lavender.
- Assets: generated dashboard has the requested financial subject, clear detail,
  natural 3:2 ratio and no stretching. Original MonMon brand icon is preserved.
- Content: fictional sample figures are labeled. Reference customers, testimonials,
  ratings, trial claims and social overlays are intentionally absent.

## Comparison history

1. Initial desktop/mobile captures: no overflow or broken assets. Found older
   green/yellow asset-map colors inconsistent with the new theme (P2).
2. Applied lavender map colors, recaptured all three widths and the reference
   viewport, then compared source and revised hero together. No remaining
   actionable P0/P1/P2 findings.

## Interaction checks

- No console errors or broken images at 1440, 390 or 320 px.
- No horizontal page overflow and no missing in-page link targets.
- Income Home/End keys select 5/50 million VND; allocations remain 55/10/10/10/10/5.
- Preview opens, closes by Escape or button, and returns focus to its trigger.
- Reduced-motion mode disables smooth scrolling.

## Follow-up polish

A genuine MonMon screenshot can replace the explicitly labeled concept image when
native capture becomes available. This does not block the requested style adaptation.


## Asset-first content revision

User priority: highlight asset management and add income/expense management,
daily/monthly reports and debt management. Preserve the chosen lavender style.
Latest desktop and mobile full-page captures at the paths above were inspected.

- Hero, top feature link, main CTA, first feature section and closing CTA all lead
  with asset management. Budget jars appear after the four requested core sections.
- New report and debt sections remain readable without horizontal overflow at
  1440, 390 and 320 px. No broken images, anchor targets or console errors.
- Day report: 485,000 VND expenses and −485,000 VND net. Month report: 8,500,000 VND
  expenses and 11,500,000 VND net. Chart rows and selected button update together.
- Verified month selection by keyboard Enter, day selection by click and DOM order
  `tai-san, cach-dung, bao-cao, khoan-no, chia-hu, rieng-tu, kham-pha`.
- Existing image-dialog controls, focus restoration and income slider still pass.
- All financial examples are labeled and consistent; no real-user records are used.
- No new actionable visual findings. The content hierarchy changes intentionally
  supersede the earlier jar-led story.


## Asset portfolio UI enhancement

The asset section was deliberately redesigned from the simple relationship map
into a usable portfolio demonstration while retaining the lavender visual direction.

- Evidence: `/tmp/monmon-landing-tools/assets-desktop.png` at 1440 px viewport,
  and `assets-mobile.png` at 390 px. Full-page checks also cover 320 px.
- Portfolio header emphasizes the 125 million VND total; the allocation ring maps
  exactly to 20/40/24/12/4 percent and the five visible values sum to that total.
- Each asset button updates its pressed state, ring-center percentage and detail
  panel. All five groups tested; only one is selected at a time.
- Funds and gold show positive illustrative PnL; coins show a negative amount with
  a minus sign as well as color. Cash and term deposits have distinct detail labels.
- Selection works by keyboard. Updated details use a polite live region.
- Initial mobile capture exposed the old offscreen skip-link clipping behavior;
  switched to an explicitly clipped, focus-revealed skip link and recaptured.
- Increased muted text contrast in the portfolio. Final mobile capture is clear,
  has no overflow, and preserves visible keyboard focus on the selected group.
- Report controls, income allocation, preview-dialog focus behavior and anchor
  navigation still pass. No console errors or broken images.

Final result remains passed.
