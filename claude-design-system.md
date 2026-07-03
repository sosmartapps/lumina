# Lumina — Design System (for Claude Design)

Paste this into Claude Design (claude.ai/design) as the project's design system, or attach
this file plus the Lumina logo, so every page, prototype, or asset it generates stays on-brand.

> Part of the **So Smart Apps** portfolio (**Health & Wellness**). Inherits the parent brand
> (`sosmartapps-brand/claude-design-system.md`); this file is Lumina's own product identity.
> Lumina serves people with Alzheimer's and their caregivers — **accessibility and calm come
> before style** in every decision.

## Brand in one line
Care, kept close. Gentle location safety, easy communication, and shared peace of mind for
families living with Alzheimer's. Warm, calm, dignified.

## Logo
- Primary mark concept: a **soft lantern / lit circle** (a guiding light) in Lumina Blue with a
  warm glow center — light that keeps a loved one in view.
- Lockups: horizontal (lantern + "Lumina" wordmark) for nav/headers; the lantern for icon.
- Clear space ≥ half the lantern height. Never recolor harshly, stretch, or add aggressive
  gradients. Keep it soft and warm.

## Color tokens
| Token | Hex | Use |
|---|---|---|
| `--lumina-blue` | #1565C0 | Primary brand color, buttons, trust |
| `--lumina-blue-dark` | #0D47A1 | Headings, hovers, depth |
| `--lumina-teal` | #00838F | Secondary — calm surfaces, info |
| `--warm-glow` | #F2B137 | Gentle highlight — safe-zone "home", reassurance |
| `--safe-green` | #2E7D32 | Inside safe zone / all well |
| `--attention-amber` | #EF6C00 | Left safe zone / check-in (clear, not alarming) |
| `--urgent-red` | #D32F2F | Emergency / SOS only |
| `--bg` | #F6F8FB | Page background (soft light) |
| white | #FFFFFF | Cards, surfaces |
| `--ink` | #1E2A38 | Body text (high contrast) |
| `--muted` | #5A6B7B | Secondary text (still ≥ 4.5:1 on white) |

Rules: calm blue/teal lead; status colors are clear and meaningful; red is reserved strictly for
emergencies. Maintain WCAG AA+ contrast everywhere — many users are seniors.

## Typography
- Font: Inter (web), SF Pro (iOS native).
- Headings: 700/600. Body: 400 at a **larger base size (17–18px)** and line-height ~1.6 for
  readability. Generous tap targets (≥48px).
- Sentence case. Short sentences, plain words, no jargon.

## Voice
Warm, calm, and respectful — to both the person with Alzheimer's and the caregiver. Reassure
without patronizing. Be clear and steady in alerts (never frightening). Dignity first, always.

## Components feel
Soft, light, spacious, high-contrast. Large cards: white, 1px #E1E8F0 border, 18px radius, gentle
shadow. Big buttons with clear labels and icons. The map view uses calm tones with a clearly
marked safe zone (warm-glow) and a large status banner (green/amber/red). Big "Call" and "I'm OK"
actions. Rounded corners 14–22px. No clutter — one clear focus per screen.

## Suggested prompt to start in Claude Design
"Build a caregiver home screen for Lumina using the attached design system. Audience: a family
caregiver for someone with Alzheimer's. Show a large status banner (inside/outside safe zone), a
calm map with the safe zone marked, big 'Call' and 'Send check-in' buttons, and recent activity.
Calm Lumina blue/teal, large readable Inter type, soft light background, warm dignified tone.
High contrast, big tap targets; red reserved for emergencies only."
