# How We Update jd-insights

Rules for keeping this section useful and small. Follow them on every update.

---

## The flow

```text
New JDs applied to
        ↓
Does the theme fit an existing card?
   ├── Yes → merge into that card (add a bullet or source tag)
   └── No  → is it seen in 2+ real JDs?
          ├── Yes → new card in patterns/
          └── No  → wait, do not create a card yet
        ↓
Update INDEX.md (links + last updated date)
```

## Rules

1. **Merge patterns, do not multiply cards.** One card per theme. If two cards start overlapping, merge them.
2. **Never paste full JDs.** Never include vacancy IDs, application URLs, recruiter names, or personal contact details. Source tags stay short, like `EPAM Azure Lead` or `Sezzle SRE`.
3. **Keep cards short.** Aim for 100 to 120 lines maximum. If a card grows past that, move depth into a Day lesson and link to it.
4. **Map to real Day files.** Every card links to existing `Day-*.md` files with their real filenames. Check the link works before committing.
5. **Update INDEX.md** every time a card is added or changed. Set the last updated date.
6. **Simple language only.** Short sentences. Everyday words. A newer learner should understand every line.
7. **No em-dashes.** Use commas, periods, parentheses, or a spaced hyphen.
8. **Never invent.** No employers, skills, or claims beyond the real JD source material. Gaps are stated honestly in the card's gap note.
9. **Do not edit the Day lessons from here.** This section points at the curriculum, it does not rewrite it.
10. **Raw apply logs go in `log/`,** dated, and stay out of the learner path. Cards never link into `log/`.

## Card skeleton (copy this)

```markdown
# Title (plain words)

## In one sentence
## What employers ask for
## Mental model
## Remember
## Study these days first
## Common interview question
## Honest gap note (optional)
## Source tags
```

> **Remember:** Small and honest beats big and impressive. If in doubt, cut it.
