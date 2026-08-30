# Implementation Plan: ETF Catalogue Import

## Overview

Add a VNDIRECT-backed catalogue for HOSE-listed ETFs, let the owner choose
Fmarket or VNDIRECT from the Funds & ETFs instrument list, and fetch a valid
closing price before any ETF instrument is saved.

## Architecture Decisions

- Discover ETFs from VNDIRECT search results for the `FUE` and `E1` symbol
  families, then accept only HOSE ETF rows at the provider boundary.
- Import ETF quotes asynchronously with bounded concurrency. Save successful
  instruments and report failed symbols without ever persisting a zero price.
- Keep Fmarket and gold catalogue behavior unchanged.

## Task List

1. Add and test the VNDIRECT ETF catalogue contract.
2. Add and test quote-backed partial catalogue imports.
3. Add the import-source picker and ETF-specific catalogue presentation.
4. Run format, unit-test, iOS compile, review, and commit gates.

## Risks and Mitigations

- VNDIRECT is an undocumented best-effort source: validate every external field
  and map changed replies to the existing typed decoding failure.
- Batch quote requests can overload the source: cap concurrent requests at four.
- Suspended or unavailable symbols can fail individually: keep those selected
  for retry while committing valid symbols.

