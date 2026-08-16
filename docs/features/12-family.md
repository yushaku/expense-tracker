# Feature: Family Sharing (Phase 3)

> Multi-user, shared budgets, per-person tracking

---

## Overview

Allow multiple users (family members) to share budgets and track expenses together.

## User Entity

```
User
├── id: uuid
├── email: string
├── name: string
├── avatar: string (url/path)
├── role: enum [admin, member]
├── createdAt, updatedAt: ISO datetime
```

## Family/Group Entity

```
Family
├── id: uuid
├── name: string
├── createdBy: string (FK → User)
├── inviteCode: string
├── createdAt, updatedAt: ISO datetime
```

## Membership

```
FamilyMember
├── familyId: string (FK → Family)
├── userId: string (FK → User)
├── role: enum [admin, member]
├── joinedAt: ISO datetime
```

## Shared vs Private

- **Shared expenses:** visible to all family members
- **Private expenses:** visible only to creator
- **Shared budgets:** family-wide spending limits
- **Per-person tracking:** attribute expenses to members

## Invite Flow

1. Admin generates invite code
2. New user enters code
3. Family appears in their app
4. All shared data syncs

## UI Changes

- Family switcher (top nav)
- Shared expenses tab
- Per-person breakdown
- Invite member screen

## MCP Implications

- MCP needs auth to determine which family
- Read-only mode per agent
- Audit log for agent actions

## Edge Cases

- Member leaves → private expenses stay, shared expenses remain
- Delete family → cascade delete shared data
- Conflict: two members edit same expense → last-writer-wins
- No internet → queue invite acceptance
