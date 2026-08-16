# Feature: OCR Receipt (Phase 1.5)

> Receipt scanning to auto-fill expense data

---

## Overview

Use camera to capture receipt, OCR extracts amount, date, merchant. User confirms and saves.

## Pipeline

```
Capture Image → OCR Extract → Parse Fields → User Confirm → Save Expense
```

## Implementation

### Capture
- Camera: `react-native-vision-camera`
- Guide frame: align receipt within border
- Auto-capture on detection (optional)

### OCR Engine
- **Phase 1.5:** Tesseract.js on-device
- Vietnamese language support
- Output: raw text from receipt

### Parse Fields

| Field | Parse Strategy |
|-------|----------------|
| amount | Find "Tổng", "Total", "Thành tiền" + number |
| date | Find date pattern (dd/mm/yyyy, dd-mm-yyyy) |
| merchant | First line or store name pattern |
| category | Map merchant → category (user-defined rules) |

### User Confidence

- High confidence (>80%): auto-fill, user taps save
- Medium (50-80%): pre-fill, user confirms/edits
- Low (<50%): empty form, show OCR text for reference

## Data Flow

```
1. User taps "Scan receipt"
2. Camera opens
3. Capture image
4. OCR processes (1-3 seconds)
5. Parse fields
6. Show confirmation screen with:
   - Thumbnail of receipt
   - Pre-filled form (amount, date, merchant, category)
   - Edit button for each field
7. User taps "Save"
8. Create expense + attach receipt image
```

## Receipt Storage

- Save image to app document directory
- Path stored in `expense.receiptImage`
- Compress before store (max 1MB)
- Cleanup: delete images when expense is voided

## UI Screens

- `/add/scan` → camera capture
- `/add/scan/confirm` → OCR result + edit form
- Expense detail → show receipt thumbnail

## Edge Cases

- OCR fails → fallback to manual entry
- Receipt in foreign language → try generic number parsing
- Multiple receipts → queue processing
- Poor lighting → prompt retake
- No camera permission → prompt settings
- Offline → works fully on-device
