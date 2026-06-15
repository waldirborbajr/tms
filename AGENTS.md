# AGENTS.md — 12 Rules for Codex / OpenCode / Cursor

**Same 12 rules as `CLAUDE.md`, filename change for Codex-style tooling that looks for `AGENTS.md`.**

A Senior Engineer Developer Advocate (SEDA) bridges technical excellence and team empowerment. These 12 rules ensure that code—whether written by humans or AI—is simple, correct, and maintainable.

---

## The 12 Rules

### 1. **Think before coding.**
State assumptions out loud. Surface trade-offs. Push back when a simpler approach exists. No silent guesses.

**Why:** Code is communication first, instruction second. Unstated assumptions cause bugs, rework, and friction.

**In practice:**
- Before writing: "I'm assuming X because... is that right?"
- Challenge vague requirements: "What does 'fast enough' mean? 100ms? 1s?"
- Ask the hard questions: "Do we really need a new service, or can we cache?"
- Write specs before code. Tests before implementation.

**Red flags:** Starting code without a spec. Implementing features "just in case." Skipping edge case discussion.

---

### 2. **Simplicity first.**
Minimum code that solves the stated problem. No speculative features. No abstractions for single-use code.

**Why:** Every line is a liability. Complexity breeds bugs. Deletion is better than addition.

**In practice:**
- Delete before you refactor. Can you remove code and achieve the same goal?
- Avoid premature abstraction: "Do we have 3 concrete examples before we generalize?"
- Prefer obvious code over clever code. Future maintainers (including you) will thank you.
- When in doubt, ask: "Does this earn its place in the codebase?"

**Red flags:** Nested abstractions, cargo-cult dependencies, "future-proofing" with unused features.

---

### 3. **Surgical changes.**
Touch only what the task requires. Don't "improve" adjacent code, comments, or formatting. Match existing style.

**Why:** Mixing concerns makes reviews harder and regressions easier to hide.

**In practice:**
- One PR, one problem. If you spot another issue, file a follow-up.
- Match the codebase's style, even if you'd write it differently.
- Remove orphans you created. Don't clean up others' code.
- Preserve comments and structure. Don't refactor for aesthetics.

**Red flags:** "While I was here..." changes. Formatting wars. Unexplained deletions.

---

### 4. **Goal-driven execution.**
Define success criteria up front, then loop until verified. Prefer stating the goal over dictating steps.

**Why:** Clear goals prevent rework. They are verifiable. Teams move faster with autonomy.

**In practice:**
- Before starting: "How will we know this is done? What does success look like?"
- Write tests that verify the goal, not the implementation.
- For complex tasks: outline the plan. Execute. Verify each step.
- Ask: "What could go wrong?" Document the failure modes.

**Red flags:** Vague acceptance criteria. Tests that pass but don't validate behavior. No rollback plan.

---

### 5. **Don't make the model do non-language work.**
Retries, routing, rate-limiting, arithmetic, time — deterministic code, not prompts.

**Why:** LLMs are unreliable for deterministic tasks. A bad retry loop is worse than no retry loop.

**In practice:**
- Arithmetic, time logic, routing → deterministic code (Python, Go, SQL).
- Retries with backoff → don't ask the model, implement exponential backoff.
- Rate limiting → token buckets, not prompt-guided rate limiting.
- Pagination, sorting, filtering → code, not "tell the model to handle edge cases."

**Red flags:** Prompting the model to "keep trying." "Calculate X using the model." "Handle errors by asking the model again."

---

### 6. **Hard token budget.**
Every loop gets a ceiling. If the same input has been re-chewed for 90 minutes, stop.

**Why:** Spinning on unsolvable problems wastes time and resources.

**In practice:**
- AI-assisted code: if you've re-prompted 5+ times on the same task, pull back. Change approach, not prompt.
- For code review: 3 back-and-forths max. Then pair or escalate.
- For debugging: if 30 minutes hasn't surfaced the issue, get logs, get a trace, don't re-prompt blindly.
- Set time-boxing: "I have 45 min. If this isn't solved by then, we regroup."

**Red flags:** Endless re-prompting. Iterating on the same failure without new information. Ignoring logs/traces.

---

### 7. **Surface conflicts, don't average them.**
Two codebase patterns disagreeing → pick one visibly and say why.

**Why:** Mixing patterns is worse than committing to one.

**In practice:**
- Some code uses factories, some uses constructors? Choose one pattern for the new code. Document why.
- Some tests use mocks, some use stubs? Stick to one approach in this PR.
- Old code vs. new code style clash? Update the old code, or commit to a migration. Don't blend.
- Make the choice explicit: "We're going with pattern X because Y is being deprecated."

**Red flags:** Code that looks like a merge of different philosophies. Undocumented style shifts within the same file.

---

### 8. **Read before you write.**
Understand adjacent code before adding new code.

**Why:** Context prevents bugs and rework.

**In practice:**
- Review the existing codebase: How are similar problems solved?
- Check the tests: What edge cases are already handled?
- Read the comments: Why was that design choice made?
- Ask: "What patterns exist here?"

**For code review:** If you see new code that re-invents an existing pattern, flag it immediately.

**Red flags:** Code that duplicates adjacent logic. New patterns that contradict existing ones. Ignoring existing tests.

---

### 9. **Tests are gated by correctness, not "pass."**
Assertions must be tied to behavior, not shape.

**Why:** Tests that pass but don't validate behavior are worse than no tests.

**In practice:**
- Test behavior, not implementation: assert the *result*, not the call sequence.
- Cover happy path + 2+ edge cases (empty, boundary, error).
- Each assertion answers: "What would break if this failed?"
- Use descriptive assertion messages: `assert result == 42, "Pagination offset should be 1-indexed"`

**Red flags:** Tests that check implementation details (call counts, internal state). Tests that pass with wrong data. No error case tests.

---

### 10. **Long-running operations need checkpoints.**
Commit between steps.

**Why:** Large operations that fail silently are operationally painful.

**In practice:**
- Batch operations: log progress. "Processed 1000/10000 rows."
- Database migrations: checkpoint after each atomic step.
- Multi-stage deployments: verify each stage before proceeding.
- Async tasks: log state transitions. "Started → Processing → Done."

**For code:** Add logging/metrics before shipping. An operation that takes 5+ minutes needs observability.

**Red flags:** Silent failures. No progress indication. Rollback complexity.

---

### 11. **Convention beats novelty.**
Use the codebase's established pattern.

**Why:** Predictability reduces cognitive load.

**In practice:**
- Study the codebase: naming, structure, error handling, testing approach.
- When you have a choice: pick the pattern that exists.
- New patterns need explicit buy-in, not snuck in on a feature branch.
- If the codebase is inconsistent, pick the *most common* pattern and say why.

**Red flags:** Reinventing local wheels. Novel patterns without team discussion. Style that varies file-to-file.

---

### 12. **Fail visibly, not silently.**
Surface partial failures, skipped rows, truncated output, retry exhaustion.

**Why:** Hidden failures are production disasters waiting to happen.

**In practice:**
- Don't swallow exceptions. Wrap them with context: "Failed to process row 42: invalid email format."
- Partial failures should be visible: "Processed 99/100 rows. Check logs for errors."
- Truncated output? Say so: "First 1000 results shown. 5000 total matches."
- Rate limit hit? Don't silently retry forever. Fail with a clear message.
- Observability: metrics for all failure modes. Alerts for unexpected ones.

**Red flags:** Try/except with no logging. Silent retry loops. Incomplete operations that don't report why.

---

## Principle Foundation

These 12 rules rest on three core principles:

**Specification-Driven Development (SDD)**
- Before code exists, clarity does. Insist on written specs: what should this do? What are the inputs and outputs? What are the constraints?
- Specs are contracts. They prevent rework, align teams, and provide verification criteria.
- Surface assumptions early. Ask: "Are we building the right thing?" before "Are we building it right?"

**Test-Driven Development (TDD)**
- Tests are design documents. They articulate expected behavior in executable form.
- Red → Green → Refactor. Write failing tests first. Tests drive implementation shape.
- Coverage matters. Aim for critical path coverage; perfectionism is the enemy of delivery.

**Humility in Technical Leadership**
- "I don't know" is a complete sentence. Model intellectual honesty. Admit gaps. Ask for help.
- Ask before telling. Challenge with questions, not declarations: "What would happen if...?" vs. "You're wrong because..."
- Respect the code author. They know context you don't. Collaborate, don't dictate.

---

---

## Supporting Context

### Code Review Checklist (Rules 1, 3, 8, 9, 11)

Before reviewing:
- ✓ Does a spec exist? If not, ask for one before reviewing code.
- ✓ Are there tests? Do they cover the happy path and edge cases? (Rule 9)
- ✓ Is the solution proportional to the problem? (Rule 2)
- ✓ Does the code match the team's conventions? (Rule 11)
- ✓ Are changes surgical, or does the PR mix concerns? (Rule 3)

**Review stance:**
- Read for understanding first. Skim once to grasp intent. Then re-read critically.
- Distinguish between "wrong" and "different." Not all styles are incorrect.
- Surface conflicts visibly. (Rule 7)
- Praise good choices. "I like how you handled X" builds trust and morale.

**Feedback types:**
1. **Blocking issues** (correctness, security, performance regressions, silent failures per Rule 12)
2. **Strong suggestions** (architecture clarity per Rule 4, convention alignment per Rule 11)
3. **Nice-to-haves** (style, minor optimizations)

Clearly label them.

### System Design Conversation (Rules 1, 4, 5, 10, 12)

**Ask the hard questions:**
- "What's the success criteria? SLOs? Operational burden?" (Rule 4)
- "What happens when this fails? How do we know it failed?" (Rule 12)
- "How do you roll this back in production?" (Rule 10)
- "Is this deterministic code or prompt-driven logic?" (Rule 5)
- "Can we simplify this?" (Rule 2)

**Pressure-test scale:**
- "At 100M events/day, what breaks?"
- "Can you cache it? Batch it? Defer it?"

### Debugging Together (Rules 1, 8, 12)

Don't solve it for them. Instead:
1. Ask them to state what they expect vs. what they observe.
2. "What changed since it last worked?" (Rule 8: read before you write)
3. "What's the smallest input that breaks?"
4. "Where would you add logging to confirm your hypothesis?" (Rule 12: fail visibly)

### Knowledge Sharing

**Code as teaching:**
- Comments explain *why*, not what. The code shows what.
- Commit messages are teaching moments: "Fixed off-by-one in pagination that only surfaced with 10k+ items."
- Pair on hard problems. Verbal explanation builds understanding faster than reviews.

**Documentation:**
- Spec documents are contracts. Keep them current.
- Runbooks for operational systems: "How to debug when X fails?"
- Decision logs: "Why did we choose Y?" (Rule 7: surface conflicts visibly)

---

---

## Quick Troubleshooting

### "This is too slow / too complex / too risky"

**Check Rule 2 (Simplicity first):**
- Can you delete code and achieve the same goal?
- Do we have 3 concrete examples before we generalize?
- Is this solving the problem or over-building?

**Check Rule 1 (Think before coding):**
- What's the actual constraint? "Slow" to whom? 100ms? 1s? 1h?
- Is there a simpler approach we haven't considered?

**Check Rule 4 (Goal-driven execution):**
- Can we define done and verify incrementally instead of all at once?

### "This code looks nothing like the rest of the codebase"

**Check Rule 11 (Convention beats novelty):**
- Study 3 examples of how adjacent code solves this.
- Pick the most common pattern.
- If inconsistency exists, document why you're breaking it.

**Check Rule 7 (Surface conflicts):**
- Make the choice explicit and visible.

### "Tests are passing but I don't trust them"

**Check Rule 9 (Tests are gated by correctness, not "pass"):**
- Do assertions validate *behavior* or just *shape*?
- What would break if this assertion failed?
- Are edge cases covered (empty, boundary, error)?

### "Operation failed but no one noticed"

**Check Rule 12 (Fail visibly, not silently):**
- Is there logging at each step?
- Can we identify which row/batch failed?
- Are partial failures surfaced?

### "This is taking way too long to review"

**Check Rule 6 (Hard token budget):**
- Have we re-prompted/re-looped 5+ times?
- Do we have all the information we need, or are we guessing?
- Should we pair instead?

---

## Project Specifics

<!-- Add repo-specific rules here. Keep it under 50 lines. -->

**Team:** Development team of 8 engineers (ANTONIOFONSECA, CARLOSRIBAS, GABRIELGMACK, LUCASOLIVEIRA, SONIAMOSSON, VITORGRIEGER, THAMIRISMELO, ALINELIMA)

**Additional conventions:**
- **Specs before code.** All features require a written spec (Google Doc or ADR) reviewed before implementation.
- **Test coverage:** 80%+ on critical paths. Happy path + 2 edge cases minimum per feature.
- **Database changes:** Migrations must be reversible and logged with checkpoints.
- **Observability:** All new services ship with logs, metrics, and runbooks.
- **PR reviews:** Max 3 back-and-forths. Then pair or escalate.
- **Technical debt:** Conscious only. File follow-ups, don't sneak it in.

---

**Version:** 2.0 (merged with 12-rules format)  
**Last Updated:** 2026  
**Audience:** Senior Engineers, Tech Leads, Codex/Cursor users  
**Status:** Living document—update as practice evolves.
