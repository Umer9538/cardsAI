# Carbsai — Brand & Product Reference

**For the marketing team.** Everything here is taken from the shipping app, not
from a plan or a pitch. Where something is not built yet, it says so.

*Package `com.carbsai.app` · Category: Health & Fitness · Android first, iOS to follow*

---

## 1. What the app is, in one line

**Carbsai turns a photo of your plate into calories and macros.**

Point the camera at a meal. It reads what is on the plate and estimates
calories, protein, carbs and fat in about eight to twelve seconds. No weighing,
no scrolling a database, no typing.

**The one-sentence version for a store listing:**
> AI calorie counter and macro tracker. Photograph a meal, get the numbers.

---

## 2. Colour palette

Every value is an exact sRGB conversion of the design file's fill. **Do not
re-sample these from a screenshot** — use the hex below.

### Core

| Token | Hex | Where it is used |
|---|---|---|
| **Primary** | `#FF5A16` | The brand orange. Every primary button, the active tab, links, the "ai" in the wordmark. |
| **Background** | `#121212` | The app's ground. Near-black, not pure black. |
| **Ink** | `#121212` | Headline text on light surfaces. Same value as the background, kept separate because it means something different. |
| **Ink Muted** | `#232220` | Card surfaces on dark, and body copy on light. |
| **Outline** | `#2F2F2F` | Field borders, dividers, secondary buttons. |
| **White** | `#FFFFFF` | Primary text on dark. |

### Accents

| Token | Hex | Where it is used |
|---|---|---|
| **Accent Green** | `#45C588` | Protein. Success states. The streak counter. |
| **Accent Orange** | `#FF6F43` | The highlight pill behind "healthy" on the splash. Lighter than Primary — they are not interchangeable. |
| **Lilac** | `#DDC0FF` | The Calories card. Onboarding page one. |
| **Plan Yellow** | `#F5F378` | The Carbs card. |
| **Accent Blue** | `#1894E0` | Water. The only blue in the product. |
| **Ink on Accent** | `#2F2F2F` | Text sitting on any accent fill. |

### Supporting

| Token | Hex | Where it is used |
|---|---|---|
| **Placeholder** | `#C3C3C3` | Hint text, secondary captions. |
| **Muted** | `#474747` | Disabled and de-emphasised labels ("Skip"). |
| **Error** | `#C93838` | Validation borders and messages. |

### The quiz palette — a second, deliberate world

The onboarding quiz and the plan builder do **not** use the dark app palette.
They are cream, flat and hand-drawn:

| Token | Hex | Note |
|---|---|---|
| **Quiz Ground** | `#FFF4E4` | Cream. |
| **Quiz Card** | `#FFFFFF` | Flat white cards. |
| Outline weight | `2.5 pt` | A hard black outline, not a hairline. |
| Shadow | offset `(5, 5)`, **no blur** | A hard offset shadow. Choosing an option collapses it and moves the card by exactly that offset, so the card presses into the page. |

The accent **changes per question**, cycling Primary → Accent Green → Lilac →
Plan Yellow, so moving through the quiz is visibly moving rather than the same
screen with new words.

> **This is not a mistake and must not be "unified" into the dark palette.** The
> screen has been three things; a dark version was coherent and completely
> characterless. The cream world is where the brand's personality lives.

### Contrast — measured, for anyone building an asset

| Pair | Ratio | Verdict |
|---|---|---|
| White on `#121212` | **18.7 : 1** | The app's main pairing. Excellent. |
| Ink `#121212` on quiz cream | **17.2 : 1** | Excellent. |
| Placeholder `#C3C3C3` on `#121212` | **10.6 : 1** | Fine for captions. |
| **Ink `#121212` on Primary orange** | **6.0 : 1** | Passes AA. **This is the correct way to put type on the orange.** |
| White on Primary orange | **3.1 : 1** | Large text only (24 pt+). Fails for body copy. |
| Accent Green on Primary orange | **1.4 : 1** | **Never.** Illegible. |
| Muted `#474747` on `#121212` | **2.0 : 1** | Decorative only — never for anything that must be read. |

Two rules that follow from the table:

1. **Type on the orange is near-black, not white.** Small white text on
   `#FF5A16` fails AA, and it is the easiest mistake to make in a banner.
2. **Never pair two accents.** Each accent is designed against `#121212` or the
   cream, never against another accent.

---

## 3. Typography

**Space Grotesk**, exclusively. Bundled as static instances at weights
400 / 500 / 600 / 700.

> **Never substitute the variable font.** Its default instance is weight 300,
> which makes the engine synthesise a fake bold — about 20% too much ink against
> the reference. If you need the font for a deck or a banner, use the static
> cuts.

| Role | Size / line | Weight |
|---|---|---|
| Onboarding & auth headline | 28 / 42 | SemiBold 600 |
| Splash headline, dialog, screen title | 24 / 36 | SemiBold 600 |
| Plan price | 34 / 51 | SemiBold 600 |
| Section & card headings | 20 / 30 | SemiBold 600 |
| Card list titles, button labels | 18 / 27 | SemiBold 600 |
| Body, field labels, links | 17 / 25 | Regular 400 |
| Secondary labels | 15 / 22 | Regular 400 |
| Calendar, greeting | 15 / 22 | Medium 500 |
| Dense metadata | 13 / 19 | Regular 400 |

---

## 4. Brand assets

| Asset | What it is | File |
|---|---|---|
| **Mascot** | A gloved avocado, 1930s rubber-hose cartoon — heavy uniform black linework, pie-cut eyes, white gloves, a leaf and a stem. Thumbs up. | `assets/images/brand/mascot.png` |
| **Wordmark** | "Carbs" in white, "ai" in `#FF5A16`, set in Space Grotesk Bold. **Designed for a dark ground** — the orange disappears on orange. | `assets/images/splash/logo_carbsai.png` |
| **App icon** | The mascot composited on `#FF5A16`. | `assets/images/brand/app_icon_1024.png` |
| **Notification mark** | A monochrome avocado half with the pit knocked out — the one shape that survives 24 square pixels. Generated, not drawn by hand. | `tool/make_notification_icon.py` |
| **Feature graphic** | 1024 × 500, mascot on `#121212` with a warm orange glow. Generated from the masters. | `tool/make_feature_graphic.py` |

### The illustration style

1930s rubber-hose cartoon: heavy **uniform** linework (the line does not taper),
pie-cut eyes, white gloves, flat colour, sparkles. No gradients, no soft shadows,
no 3D.

**The mascot appears on the plan screen and nowhere else inside the app.** That
is deliberate — it is the only way a mascot stays likeable. Marketing is free to
use it more widely; the product is not.

---

## 5. Design principles you can quote

These are real constraints in the codebase, and they are good copy because they
are unusual.

**Corrections are the product.** Mining roughly 40,000 reviews in this category
produced one finding that outranks everything else: **correction friction, not
error rate, decides a one-star review.** The same inaccuracy earns four stars or
one depending only on whether fixing it is fast and free. So editing any food —
its name, its weight, all four macros — is never behind a paywall, works before
*and* after you log, and an edit becomes the new baseline so a later ½× halves
what *you* corrected rather than what the model guessed.

**The app never invents a number.** Every figure on screen is computed from the
diary. The diet plan catalogue ships owned by nobody — no pre-favourited plans,
no fake streak, no seeded notifications. An app that pretends you did something
is the clearest signal its numbers are decoration.

**It never scolds.** No guilt-worded reminders, no streak about to break, no
exclamation marks in notifications. Reviewers of this category name guilt
wording as the reason they turned notifications off for good — and a
notification nobody receives is worth less than none.

**Neither weight direction is coloured.** The app does not know whether someone
is cutting or gaining, and a red number for going up is how a tracker starts
scolding people.

---

## 6. Features — what actually ships

### Logging a meal: four ways

| Way | What it does | Uses AI? |
|---|---|---|
| **Photograph it** | Reads the whole plate at once. 8–12 s. | Yes |
| **Scan a barcode** | Exact figures from the product label, via Open Food Facts. | No |
| **Describe it** | "Two eggs and toast" — for restaurants, dim light, or something already eaten. About a tenth of the cost of a photo. | Yes |
| **Search the database** | USDA lab-analysed reference foods. Free and unlimited, always. | No |

Barcode and search deliberately do **not** go near the model: a barcode
identifies a product exactly, and a search is someone telling us what they ate.
Guessing at either would be worse *and* billable.

### The calorie target

Built from the person's own body — height, weight, age, activity level and goal
— using the **Mifflin-St Jeor** equation, the same one MyFitnessPal, Lose It and
Cal AI use. Protein and fat are set from bodyweight (1.8 g/kg and 0.9 g/kg) and
carbohydrate takes the remaining energy, because fixed macro percentages give a
very light person too little protein and a heavy one more than they can use.

**Two guardrails, and they are worth saying out loud:**
- The deficit is capped at **25% of maintenance**, not a flat 500 kcal — 500 off
  a small person is a far harsher cut than off a large one.
- Floors of **1,200 kcal (female) / 1,500 kcal (male)**, whatever the arithmetic
  says.
- The goal-weight slider **starts at a BMI of 18.5** for the entered height and
  says so on screen. Nothing will put a date on an underweight target.

### The meal plan builder

**Fifty seconds of tapping pictures, not a text box.** In the one controlled
study of the idea, plans built from picture-tapping were accepted **72.5%** of
the time against **50.8%** for the same nutrition with no taste input.

Two 3×3 grids of dishes, then five this-or-that pairs, then what you avoid, then
how long you will cook. Every question is about the *food*, never the person —
calories and goal were answered at sign-up.

- **Six cuisines:** South Asian, Mediterranean, East Asian, Western, Mexican &
  Latin, Middle Eastern.
- **Seven avoidances:** beef, pork, dairy, gluten, nuts, eggs, seafood.
- **An avoidance is a rule, not a hint.** The plan is scanned against your list
  before you ever see it, and rebuilt if it fails.
- **"Something else"** rebuilds from the same answers — you never re-answer.

### The shipped plan catalogue — seven plans, each with a real day of food

Safe to name in screenshots and listing copy. Each carries what to eat, what to
limit, and a full day of meals you can log into the diary in one tap — not four
numbers on a card.

| Plan | What it is for |
|---|---|
| **Mediterranean Lifestyle** | Heart health, long-term maintenance |
| **Keto Kickstart** | Fat loss, appetite control |
| **Low-Carb Fat Burner** | Fat loss, steadier energy |
| **Vegan Vitality** | Plant-based eating, cholesterol |
| **Paleo Power Plan** | Whole foods, fewer processed carbs |
| **Indian Vegetarian Weight Loss** | Weight loss on a desi diet |
| **Detox Cleanse Plan** | A reset week, more vegetables |

Every plan is **rescaled to the user's own calorie target** — it keeps the
pattern's macro ratio (keto is a fat ratio, Mediterranean is a fat-to-carb ratio)
and puts your energy through it. So the app never computes a 2,413 kcal target
and then offers you a "2,000 kcal plan" beside it.

> **Note for copy:** "Detox Cleanse Plan" is the weakest name in the set from a
> claims point of view — the plan itself is just more vegetables for a week,
> which is what its goal line says. Do not write detox copy around it.

### Everything else

- **Diary with photos**, week navigation, and a streak that stays hidden below
  two days because "1 day streak" is a nag, not an achievement.
- **Weight**, led by a **seven-day trend** rather than the last reading — body
  weight swings a kilo on water alone, and the newest number is the worst
  estimate of where someone is.
- **Water**, logged in one tap from three quick-add amounts, against a target of
  35 ml per kg of the person's own bodyweight.
- **Activity**, with ten MET values from the *Compendium of Physical
  Activities*. Its energy is **not** added back to the day's budget, and the
  sheet says so — an app that hands back 500 kcal for a run it guessed at is
  inventing a number and then inviting you to eat it.
- **Analysis**: calorie trends, macro split, where the day's energy came from,
  and "Days With a Full Picture" — days with at least two eating occasions,
  which pooled RCTs found the best adherence predictor of six-month weight loss.
- **Metric or imperial**, defaulted from the device and switchable anywhere the
  app asks for a measurement.
- **Works offline.** Diary, plans and history all.

### Notifications — the part nobody else does

Meal reminders are timed to **your own diary**, not a fixed hour:

1. A time you set yourself, if you set one.
2. Otherwise the **median** hour you logged that meal over the last 28 days,
   plus 45 minutes — because reminding you at the median is reminding you of
   something already done.
3. Otherwise **what your country eats**.

That last one is a fifteen-pattern table. Dinner is 17:30 in Stockholm, 18:00 in
Chicago, 20:30 in Karachi, 21:30 in Madrid. One global default is one to four
hours wrong for most of the world — late enough to arrive after the meal in
Sweden, early enough to arrive before it in Spain.

The app reads the **time zone**, not the phone's language, because an `en-US`
handset standing in Karachi is the norm across much of the world.

Also: water nudges spread across your own eating window, a weekly weigh-in, and
a nightly "how did today go". **Already logged lunch? That reminder waits until
tomorrow.**

---

## 7. Unique selling points

Ranked by how defensible they are. The first three are the ones to lead with.

### 1. Correcting an estimate is free, fast, and always will be

Competitors paywall editing or make it slow. This is the single thing that
decides whether an AI estimate earns four stars or one, and it is a promise the
product can keep forever because it costs nothing to honour.

> **"An estimate you cannot fix is worse than no estimate."**

### 2. Reminders that know when *you* eat — and where you are

Nobody else in this category ships a fifteen-pattern meal-time table keyed off
the time zone. It is immediately legible to anyone outside the US, and it is the
one feature that demos in a sentence to a Pakistani, Spanish or Swedish user.

> **"Dinner is not at the same hour in Stockholm, Karachi and Madrid."**

### 3. Food the rest of the category gets wrong

Biryani, karahi, shawarma, roti, falafel, tacos. The dish taxonomy and the plan
builder were built around six cuisines including South Asian and Middle Eastern
— markets where the incumbent food databases are weakest. **This is the wedge.**

### 4. A plan built from pictures you tapped, not a form you filled

Fifty seconds, and a published result behind it (72.5% vs 50.8% acceptance).

### 5. Four ways to log, because photos fail

Restaurants, dim light, something already eaten, a packet. Three of the four
need no AI at all — so the app keeps working when the scans run out.

### 6. It is honest about being an estimate

Low-confidence items carry a "Check this" chip. The model's own clarifying
question is shown. A barcode result says "from the product label", not "AI
estimate". This is unusual, and it is the thing that makes the confident numbers
believable.

### 7. Privacy that is actually unusual

Meal photographs **stay on the phone**. No analytics SDK, no location, no
contacts, no tracking of what you do inside the app. You are told, in the app
and before it happens, that the photo goes to an AI provider — and nothing is
used to train AI models.

---

## 8. Honest limits — read before writing a claim

Marketing copy that trips any of these is a Play policy problem, not just an
accuracy problem.

- **It is not a medical device, not medical advice, and not a substitute for a
  doctor or a registered dietitian.** The Terms say so; the listing must agree.
- **No outcome claims.** No "lose 10 kg", no "clinically proven", no before and
  after. Play requires health claims to be substantiated.
- **Accuracy is an estimate.** Best-in-class vision models on food photos, as of
  2026, run about **36% error on energy** and worse on protein. Calories — the
  number the UI leads with — are among the more reliable. Do not imply exactness.
- **Free scans are limited.** Barcode, search and manual logging are unlimited
  and always free; AI scans are not.
- **Not yet live:** in-app purchases (store products not created), real ad units,
  meal-photo cloud backup, email verification, Google/Apple sign-in, iOS.

---

## 9. Tone of voice

**Plain, specific, and never breathless.**

| Do | Don't |
|---|---|
| "Snap it before the plate is empty." | "Crush your goals! 🔥" |
| "A photo takes less time than remembering at noon." | "Don't forget to log!" |
| "Weight must be between 25 and 350 kg." | "Oops! Something went wrong." |
| Name the meal, then stop. | Exclamation marks in notifications. |

Write from the user's side of the screen. A control says exactly what happens.
Errors explain what went wrong and how to fix it — no apologies, no vagueness.
Specific beats clever.

**British spelling** throughout: the Play listing's default language is `en-GB`.

---

## 10. Ready-to-use copy

### App name — 27 / 30 characters
```
Carbsai: AI Calorie Counter
```

### Short description — 69 / 80
```
AI food scanner: track calories, macros and weight loss from a photo.
```

### Taglines
- Count calories by taking a photo.
- Snap your food. Get the calories.
- Eating healthy made easy! *(the splash headline, verbatim — "healthy" sits in an Accent Orange pill)*

### Store tags
Dieting · Weight loss · Food & drink · Barcode scanner — plus a nutrition or
calorie tag if one exists.

### The three sentences to open any pitch
> Carbsai turns a photo of your plate into calories and macros.
>
> You can correct anything it gets wrong, in one tap, free, forever.
>
> And it reminds you at the time *you* eat — which is not the same hour in
> Karachi as it is in Chicago.

---

*Keep this file in step with the app. If a feature here stops being true, it is
a store-listing problem before it is a documentation problem.*
