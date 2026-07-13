# Cognitive Engagement Features — Research Summary (2026-07-13)

Evidence-based interventions for maintaining/improving cognition in dementia that could become interactive daily tasks in Lumina. Ranked by evidence strength × fit with the existing task/reminder system.

## Tier 1 — Strong evidence, natural fit

### 1. Cognitive Stimulation Therapy (CST) sessions
The best-evidenced non-drug intervention for cognition + quality of life in mild–moderate dementia. Group CST is the gold standard, but an individual app version (iCST / "Thinkability") passed a [feasibility RCT](https://pubmed.ncbi.nlm.nih.gov/35221680/) — usable, enjoyable, computerized delivery beneficial. A [2025 pilot](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2025.1561157/full) found online delivery comparable to face-to-face. The 12-week multidomain [MEMODIO app RCT](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12726563/) showed preliminary cognitive benefit in MCI/mild dementia.
**Lumina fit:** daily 15–20 min "brain session" task — themed activities (word association, categorization, current events, "which is more expensive?", odd-one-out). CST protocols are published; content can rotate on a 14-theme cycle. Caregiver sees completion + engagement.

### 2. Personalized reminiscence (digital life story book)
[Pilot RCT](https://link.springer.com/article/10.1186/s12877-020-01563-2) of digital reminiscence therapy showed benefit; the [Online Life Story Book RCT](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8443059/) supports guided digital life-story creation. A [2026 USC/Cornell trial](https://gero.usc.edu/2026/04/22/digital-reminiscence-dementia-caregivers/) found reminiscence web tools improve patient–caregiver connection. A [2026 meta-analysis](https://link.springer.com/article/10.1186/s12883-026-04759-y) is more cautious: benefits strongest when personalized and socially engaging.
**Lumina fit:** caregiver uploads photos/audio with captions ("Where was this taken?", "Who is this?"); patient gets a daily "memory lane" task — view, listen, answer a gentle prompt, optionally record a voice response the caregiver can hear. Reuses existing Storage + photo-verified-task infrastructure.

### 3. Face–name recognition practice (errorless learning)
Forgetting family names is among the most distressing symptoms. The [Gotcha! app](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11712778/) applies errorless-learning principles to relearning names of key people, with evidence it improves name recall and relationships. Errorless learning + spaced retrieval has [RCT support for relearning daily tasks](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5364615/) and an [algorithmic spaced-retrieval app pilot](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11297374/) enhanced long-term retention in AD.
**Key design rule — errorless:** show name WITH face first, fade cues gradually, never force a guess that could be wrong. Multiple-choice with the right answer visually prominent; expand review intervals on success, shrink on failure (simple SM-2-style scheduler).
**Lumina fit:** caregiver tags family photos with name + relationship; patient gets a short daily "who's who" task. High emotional value, low content burden.

## Tier 2 — Good evidence, moderate build effort

### 4. Personalized music sessions
Strong evidence for reducing agitation/anxiety and improving mood ([feasibility trial](https://pmc.ncbi.nlm.nih.gov/articles/PMC10442569/), [systematic review](https://www.tandfonline.com/doi/full/10.1080/18387357.2025.2605992)); cognitive effects [inconsistent](https://pmc.ncbi.nlm.nih.gov/articles/PMC10041788/). Works best personalized (music from ages ~15–25). Caution: can increase sadness in patients with high depression — caregiver should curate.
**Lumina fit:** caregiver builds a playlist (links or uploaded clips); scheduled "music time" task, optionally paired with a reminiscence prompt. Could double as a de-escalation tool caregivers trigger remotely when agitation is reported.

### 5. Movement / dual-task exercise prompts
Dual-task training (physical + cognitive simultaneously) shows [small-to-medium cognitive and medium-to-large gait/balance effects](https://pubmed.ncbi.nlm.nih.gov/35543010/) in cognitively impaired older adults ([network meta-analysis](https://pmc.ncbi.nlm.nih.gov/articles/PMC12043736/)). Falls prevention is a bonus that fits Lumina's safety mission.
**Lumina fit:** daily "move + think" task — TTS-guided seated/standing routine ("march in place and name animals A-to-Z"). Video/animation + voice prompts; self-report or photo-verified completion. Keep it simple: 5–10 min.

### 6. Montessori-style purposeful daily activities
Montessori-based activities [increase engagement and positive affect, reduce agitation](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7791677/) ([evidence review](https://www.ncbi.nlm.nih.gov/books/NBK72281/)). These are real-world tasks with purpose: fold laundry, set the table, water plants, sort objects.
**Lumina fit:** cheapest win — a curated library of purposeful-activity task templates caregivers add to the daily schedule, using the existing photo-verified task system (photo of the set table = done). No new screens beyond a template picker.

## Tier 3 — Worth knowing, weaker/narrower evidence

- **Generic computerized cognitive training (brain games):** [moderate effects in MCI](https://pubmed.ncbi.nlm.nih.gov/27838936/) (g≈0.35) but weak in established dementia — effects there were driven by VR/Wii trials. Don't build a Lumberjack-style game suite and expect cognitive gains in moderate dementia; CST-style content (Tier 1) beats abstract drills.
- **Orientation support:** daily "today board" (date, weather, today's schedule, one news item) reflects reality-orientation principles; low evidence as standalone but near-zero cost and reduces anxiety.
- **Quiz/conversation prompts** (AmuseIT-style simple picture quizzes) work best as social activities with the caregiver, not solo.

## Cross-cutting design principles (from the literature)
- **Errorless by default** — no "Wrong!" feedback anywhere; celebrate attempts, reveal answers gently.
- **Personalized content beats generic** — every Tier 1/2 feature leans on caregiver-supplied photos/music/facts. That's Lumina's structural advantage over consumer brain-game apps.
- **Short, daily, routine-anchored** — 10–20 min sessions at consistent times; slot into the existing reminders/tasks engine rather than a separate "games" silo.
- **Caregiver in the loop** — engagement metrics (completion, time, accuracy trend) surface on the caregiver dashboard; declining accuracy trends are clinically meaningful signals.
- **Adaptive difficulty, never frustrating** — scale down on struggle; the goal is engagement + mood + retained function, not score-chasing.

## Regulatory & business guardrails (STANDING RULE — applies to all cognition features)

**Claims language (FTC):** Market and describe these features as **engagement, routine, and structure support** only. Never claim the app "slows decline," "improves memory/cognition," "prevents dementia progression," or similar efficacy claims — in App Store copy, website, in-app text, or notifications. The FTC fined Lumosity $2M (2016) for exactly these unsubstantiated brain-training claims. Safe words: engage, routine, purposeful, familiar, calming, enjoyable, connection, structure. Banned words: improve/boost memory, slow decline, treat, therapy (as a product claim), cognitive training benefits.

**FDA line (wellness vs. medical device):** Stay on the general-wellness side — the features promote healthy activities and routine for wellbeing. Do NOT position any feature as diagnosing, treating, or mitigating dementia (that's Software-as-a-Medical-Device territory requiring FDA clearance). This also means: no in-app "cognitive assessment scores," no decline-detection alerts framed clinically. Engagement/completion trends shown to caregivers are fine as activity data, not as clinical measures.

**The research citations in this doc are for internal design rationale and the NIA STTR narrative — not for marketing copy.**

**STTR upside:** a real cognition-engagement module with measurable outcomes (completion rates, engagement trends, caregiver-reported measures) considerably strengthens an NIA STTR application — under a research protocol with IRB oversight, efficacy questions become fundable research rather than marketing claims. Keep the data model clean (task_completions history already provides this) so outcome analysis is possible later.

## Suggested MVP order
1. Montessori task templates (reuses photo-verified tasks — days, not weeks)
2. Face–name "who's who" (caregiver photo tagging + errorless quiz + spaced scheduler)
3. Reminiscence "memory lane" (same photo infrastructure + audio)
4. CST daily session (content-heavy; could seed with Claude-generated themed activity packs)
5. Music time / move-and-think (later)
