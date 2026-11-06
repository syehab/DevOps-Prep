# Hunt Filters: Shifts, Work Auth, Duplicate Listings

## In one sentence

Some remote Senior and Staff listings fail you on a form or a shift window before anyone reads the Terraform story.

## What employers (and their forms) ask for

- A fixed US-morning window from Turkey or India, for example 6:00 AM to 2:00 PM EST, not a rotating follow-the-sun pager
- A hard Greenhouse question: are you eligible to work in Turkey? An automated knock-out can discard a "no" before a human sees the CV
- The same Staff Platform role posted twice (a Turkey twin and an India twin). Jobgether is one board that does this. Apply to one
- Lever hCaptcha verify often fails. Retry. It is not a grade of your skills

## Mental model

```text
Form / shift / listing
        ↓
Automated filter
        ↓
Human reads the CV
        ↓
Interview (the other cards)
```

The [SRE card](sre-slos-observability.md) already has follow-the-sun on-call. A fixed US-morning shift is different: you overlap the US day, every workday, from Turkey or India. Some of those roles publish a high USD monthly band. That is a fit question. It is not a new SLO skill.

Work authorization is a legal fact. Answer the Turkey question honestly. A guessed "yes" that the form then checks is a knock-out later, and it is dishonest. Duplicate listings are one job. Two applications do not double the chance. They can look like noise. A captcha that fails on Lever is a site bug. Retry it. Do not treat it as a rejected application.

> **Remember:** Answer the form as the truth. Pick one twin. A captcha failure is a site bug.

**Understand:** The filter sits before the interview. A strong IaC story never reaches a human if the form already dropped you.

**Look-up:** none. This is not a tool to study.

**Exit check:** A Greenhouse form asks if you can work in Turkey, and the same Staff role appears for Turkey and for India. What do you answer, and how many times do you apply?

## Remember

> **Honest answers and one application beat a guessed work-auth and two twins of the same job.**

## Study these days first

1. [Day-21-Senior-Lead-DevOps-Capstone/01-concepts.md](../../Day-21-Senior-Lead-DevOps-Capstone/01-concepts.md) - do not inflate what you cannot defend
2. [Day-41-Production-Deployment-Incident/01-concepts.md](../../Day-41-Production-Deployment-Incident/01-concepts.md) - on-call is a named window, not a slogan
3. [Day-20-Observability-and-Production-Incident/01-concepts.md](../../Day-20-Observability-and-Production-Incident/01-concepts.md) - the pager and the SLO still apply if you take the US-morning SRE seat

## Common interview question

**Q: This role is 6:00 AM to 2:00 PM EST from Turkey. Can you do it, and are you authorized to work in Turkey?**

Outline:
1. Shift: yes or no as a real calendar fact. It is not follow-the-sun. You are on that window every workday.
2. Work auth: the legal answer. Greenhouse can drop a "no" before review. Do not guess.
3. If two twins exist, say you applied once.
4. Honest: the course does not change work authorization. The SRE card still teaches the pager.

## Honest gap note

This card is hunt process, not a lab. It exists because forms now fail people before the interview. No Day teaches Greenhouse or Lever. Do not invent a workaround for work authorization you do not have.

## Source tags

2026-11-06 market (US-morning SRE window from TR / IN, Greenhouse Turkey work-auth, Jobgether twins, Lever hCaptcha)
