# STE House Style (80% Simplified Technical English)

How we write the Day lessons. Based on ASD-STE100 Simplified Technical English, applied about 80% of the way. The goal is faster learning, not certification. When an STE rule fights clarity or the Day voice, clarity and voice win.

---

## The rules we apply (the 80%)

1. **Short sentences.** Procedural sentences (steps, instructions) stay at about 20 words or fewer. Descriptive sentences stay at about 25 words or fewer. Split longer ones at the natural seam (usually "because", "so", "which", or "and").
2. **Active voice.** Name the actor: "Terraform stores the state file", not "the state file is stored". Use the imperative for steps: "Run the command."
3. **One word, one meaning.** Inside one Day, use one term for one act or thing. Do not alternate synonyms (deploy / ship / push, container / workload, secret / credential) for the same referent. Pick the term the tools use and keep it.
4. **Simple verbs.** Prefer use, start, stop, make, run, find, send, keep, show. Avoid utilize, initiate, commence, facilitate, leverage, accomplish.
5. **One instruction per sentence** in steps. One topic per paragraph.
6. **No long noun clusters.** Break stacks of 3+ nouns ("deployment pipeline approval gate" becomes "the approval gate in the deployment pipeline"). Use articles (the, a) so the reader can parse the sentence once.
7. **Avoid -ing noun phrases** where a plain verb works: "to configure the backend", not "for configuring of the backend".
8. **Warnings and notes carry the reason.** "Do not commit the state file, because it contains secrets in plain text." A rule without a reason does not stick.

## The deliberate deviation (the 20%)

- **Technical names stay.** Terraform, AKS, kubectl, VNet, OIDC, blue-green, canary, and every real tool or service name are technical names under STE and are never simplified or replaced.
- **Paragraphs stay paragraphs.** Strict STE produces one-line fragments. We combine short STE sentences into flowing prose paragraphs of at least 3 to 4 lines. Short sentences inside a real paragraph, not a wall of bullets.
- **Teaching prose stays.** Explanatory "why" prose, analogies that build a mental model, Remember / Understand / Look-up callouts, exit checks, and ASCII diagrams are the point of the course. Simplify their sentences, never remove them.
- **Code is untouchable.** Never change code blocks, commands, file names, or technical truth. Never invent tools. Simplify wording, do not lengthen it.

## Verb list

| Prefer | Avoid |
|:--|:--|
| use | utilize, leverage |
| start, run | initiate, commence, kick off |
| stop, end | terminate (except technical names like "TLS termination", "instance termination") |
| make, create | construct, facilitate |
| find, check | locate, verify (keep "verify" where the act is a formal check) |
| need | require (keep "required" for hard constraints) |
| about | approximately |
| before / after | prior to / subsequent to |
| to | in order to |
| also | additionally, furthermore |

> **Remember:** STE is for the learner's first read. If a rule makes the sentence harder to read once, break the rule.
