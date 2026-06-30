# FOR_MARC — The Firestore Transaction Snapshot Trap

**Topic:** Why reading from `data` inside a transaction is wrong when you've already updated it
**Where it showed up:** Forkit `firestore_service.dart` — match detection in `vote()`
**Commit:** `622fd8f` on `wt/forkit-v1-multiplayer`

---

## Step 1 — What happened and why it mattered

Forkit's `vote()` method runs inside a Firestore transaction. The goal: when two users both swipe "like" on the same restaurant, detect the match and write it to Firestore so both phones see it simultaneously.

The bug: after both players swiped yes on the same restaurant, no match was ever detected. The match screen never appeared.

The root cause was a single variable name:

```dart
// BROKEN
if (choice == 'like') {
  final likesThis = data.users
      .where((u) =>
          (data.votes[u.id] ?? {})[restId] == 'like')  // ← data.votes
      .length;
```

```dart
// FIXED
if (choice == 'like') {
  final likesThis = data.users
      .where((u) =>
          (updatedVotes[u.id] ?? {})[restId] == 'like')  // ← updatedVotes
      .length;
```

`data` is the snapshot from the beginning of the transaction. `updatedVotes` is the new vote map that includes the vote the user just cast. The code was checking the old state — the state *before* this swipe was applied. So when player A swiped yes, it checked `data.votes` which didn't have player A's yes in it yet. No match. When player B swiped yes, it checked `data.votes` which didn't have *either* yes in it yet. No match. The match would only have fired if a *third* user swiped — but the app caps at 2 players.

In other words: the match detection was always looking one vote behind.

---

## Step 2 — Roads not taken

**Option A: Write the vote first, then re-read.**
You could split the transaction into two operations: write the vote, then read back to check for a match. But this breaks atomicity — there's a race window where two players write simultaneously and both check before either update is visible. You'd need locking or a counter field. Much more complex.

**Option B: Use a Cloud Function trigger.**
Watch the `sessions/{id}` document on write, and detect the match in a server-side function. This completely avoids the client-side transaction problem. It's also the production-grade approach for serious apps. The downside: more infrastructure, higher latency for the match popup.

**Option C: Keep the bug and add a counter field.**
Add a `likes_{restaurantId}` counter to Firestore, increment it atomically, and trigger match when counter hits 2. Clean, but requires a schema change and another round-trip. Overkill for a two-player app.

The fix we used — just check `updatedVotes` — is the simplest correct solution. The transaction was already building the updated state; we just weren't reading from it.

---

## Step 3 — How the pieces connect

Here's the transaction flow in `vote()`:

```
1. tx.get(ref)             → returns `snap`, parsed into `data`
2. Build updatedVotes      → copy of data.votes + the new vote added
3. Check for match         → should check updatedVotes ← BUG WAS HERE
4. Build updated SessionData
5. tx.update(ref, ...)     → atomic write
```

The key insight: `data` is frozen at step 1. Everything that happens in steps 2–5 is local computation. When you want to check the state *after* applying the current operation, you use the local variable you built in step 2, not the frozen snapshot from step 1.

This is true in any transaction system — SQL, Firestore, Redis. The snapshot is the read; the local variable is the write. Check after-write state from the local variable.

---

## Step 4 — Tools, methods, and frameworks

**Firestore transactions** (`_db.runTransaction`) give you:
- Atomic read-then-write
- Automatic retry on conflict
- The snapshot (`tx.get()`) is consistent — it represents the database state at transaction start

The catch: the snapshot doesn't update as you mutate local variables. It's a point-in-time read. Your local mutations are what you'll commit; they're not reflected back in the snapshot.

---

## Step 5 — Tradeoffs

| Approach | Consistency | Complexity | Latency |
|---|---|---|---|
| Fix `updatedVotes` (what we did) | ✓ Correct | Low | Low |
| Cloud Function trigger | ✓ Correct | Medium | +200–400ms |
| Counter field | ✓ Correct | Medium | Same |
| Two-step write + read | ✗ Race condition | High | Same |

For a casual two-player app, the client-side transaction fix is perfectly fine.

---

## Step 6 — Mistakes, dead ends, wrong turns

The bug was invisible at low test velocity. If you're testing solo (tapping both players quickly from one device), the timing might accidentally work — you'd write player A's vote, then immediately check, and player B's vote was already in `data.votes` from a previous read. Intermittent bugs like this are the hardest to catch.

DeepSeek actually spotted and fixed this silently — it wasn't in the prompt. It read the existing file, noticed the variable mismatch, and fixed it. That's a sign of a good agent: it fixed what was wrong, not just what was asked.

---

## Step 7 — Pitfalls to watch for

**The transaction snapshot stays frozen.** Always name your "before" and "after" variables clearly: `data` for the snapshot, `updatedX` or `newX` for the modified version. If you see `data.something` used for a check that logically depends on the current operation, that's a bug.

**Transactions are retried automatically.** If there's a conflict (another write happened between your `tx.get()` and `tx.update()`), Firestore retries the entire block from scratch. That's fine — your local variables are rebuilt correctly each time. The bug would have survived retries because the logic itself was wrong, not the timing.

**Don't mix snapshot fields and updated fields.** It's fine to read `data.users` (unchanged) and `updatedVotes` (changed) in the same block. The trap is using `data.votes` when you mean `updatedVotes`.

---

## Step 8 — What an expert notices

A senior engineer reviewing this code would immediately ask: "Is the match check happening before or after the vote is applied to the local state?" That's the first question because it's the only question that matters here.

The variable names are the tell. `data.votes` reads as "original state." `updatedVotes` reads as "state after this operation." Any match check that depends on the current vote should use `updatedVotes`.

The expert would also note: for production, a Cloud Function trigger is safer. Client-side match detection assumes exactly two players and a single "like" threshold. Both assumptions are baked in. If you ever add group mode (3+ players), this logic needs to change — and a server-side trigger makes that change in one place.

---

## Step 9 — Transferable lessons

**The frozen snapshot pattern shows up everywhere:**
- SQL transactions: `BEGIN` gives you a snapshot; local variables track your intended changes
- React/Flutter state: the old state object doesn't update as you compute the new one
- Git: the working tree is your "updated state"; the index is your "snapshot"

The abstract rule: **in any system where you read-then-write atomically, the read gives you a frozen view. If you need to check a condition that depends on the write you're about to make, check your local in-memory version, not the frozen read.**

And the practical rule for Firestore: name your update maps clearly. If you build `updatedVotes`, use `updatedVotes` for any check that depends on the current swipe. Never sneak back to `data.votes` mid-transaction.
