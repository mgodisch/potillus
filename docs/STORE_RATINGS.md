<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
=============================================================================

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>.

In addition, as permitted by section 7 of the GNU General Public License,
this program may carry additional permissions; any such permissions that
apply to it are stated in the accompanying COPYING.md file.

=============================================================================
`STORE_RATINGS.md` -- what each store asked, how it was answered, and why
=============================================================================

WHAT THIS IS
    The age-rating and audience answers given in App Store Connect and the
    Google Play Console, with the exact question wording and the reasoning.

WHY IT EXISTS
    Every other part of both store listings lives in this repository and has a
    gate: the texts, the screenshots, the categories, the copyright line. The
    rating questionnaires do not. They are filled in by hand, in two consoles,
    and the answers are recorded nowhere -- which is how, two years on, someone
    (quite possibly their author) looks at 18+ on one store beside 3+ on the
    other, assumes one of them is a mistake, and "fixes" it.

    This file exists so that they cannot. It is the reasoning, not the numbers,
    that is worth keeping: the numbers are visible in both consoles already.

WHEN TO REVISE IT
    Whenever an answer changes, or when a console asks something new. Apple
    added social-media questions on 2026-07-09 and makes them mandatory in
    September 2026; that is the normal rate of change here.
=============================================================================
-->

# Store age ratings and audience

- **Last reviewed:** 2026-07-18 (v0.84.0)
- **Application:** Libellus Potionis (`de.godisch.potillus`)

## The one thing to understand about the two ratings

**The two stores ask different questions, and the answers are not
transferable.** They are not two dialects of one questionnaire. They do not
measure the same property, they do not disagree, and neither result can be used
to check the other.

| | App Store Connect | Google Play Console |
| --- | --- | --- |
| What it asks about | the app's **content** | the app's **purpose** |
| The axis | how *often* users encounter it | whether promotion/sale is the *focus* |
| Ignores | why the app exists | what the app contains |
| Answer given | Frequent | No |
| Result | **18+** | **3+** |

Same app, same facts, both answers true, and the outcomes as far apart as the
scales allow. That is not an error to be reconciled. It is what happens when
one instrument looks only at content and the other only at commerce, and the
app in question is neither a drinking companion nor a shop.

Neither console has a field for what this app actually is: a self-monitoring
and harm-reduction tool, whose entire point is to *reduce* the consumption it
is full of references to. Apple sees the references and cannot see the point.
Google sees no commerce and cannot see the references. The only place in either
process where the purpose can be stated at all is the reviewer note in
`fastlane/metadata/ios/review_information/notes.txt`, which is why it says so.

## App Store Connect

**Where:** the app → General → App Information → Age Ratings → Set Up Age
Ratings / Edit → Step 2: Mature Themes

### Alcohol, Tobacco, or Drug Use or References

> Select the frequency at which each type of content occurs in your app based
> on the definitions below. If you have in-app controls, consider what a user
> who has those turned on will encounter while using your app.
>
> - Infrequent: Users will rarely encounter this content in your app.
> - Frequent: Users will regularly encounter this content in your app.
>
> **Alcohol, Tobacco, or Drug Use or References**
>
> References to or depictions of the consumption of alcohol, tobacco products,
> or other licit or illicit substances. *May include: drunken behavior,
> cigarette smoking, or the taking of illegal drugs.*

**Answer: `Frequent`.**

The question asks one thing, and it is measurable: how often does a user
encounter the content? Alcohol is on every screen of this app, from the first
launch, before the user has entered anything — the Drinks screen ships a
catalogue of alcoholic beverages, Today shows grams of alcohol, the BAC
estimate updates every minute, Statistics counts drinking days and binge days.
"Users will rarely encounter this content" is not an interpretation of that; it
is a false statement.

Three things the question does **not** ask, all of which are tempting and none
of which are relevant:

- **Intensity.** An earlier version of this questionnaire used the combined
  labels "Infrequent or Mild" / "Frequent or Intense", where this app could
  honestly have been placed on the *mild* limb. The labels are now split, the
  intensity limb is gone, and only frequency remains. That the app depicts no
  drunkenness, glamorises nothing, and colours every excess red no longer bears
  on this answer.
- **Purpose.** See the table above.
- **A preferred outcome.** `Infrequent` yields 13+, which can
  then be raised to 16+; `Frequent` yields 18+ outright. Knowing that before
  answering is exactly the circumstance in which one reasons backwards from the
  desired number. The tell is simple: if the computed rating has to be
  corrected upward because it feels too low, the input was wrong, not the
  output. Apple's override exists for an app whose *own policy* is stricter
  than its content requires — not to repair an answer its author does not
  believe.

The in-app-controls clause does not help either: this app has no switch that
hides alcohol references. The biometric lock is not a content control.

### Everything else

`None` throughout — Profanity or Crude Humor, Horror/Fear Themes, and the
violence, sexual-content and gambling rows. No advertising, loot boxes,
messaging or chat, user-generated content, or unrestricted web access: the app
declares one permission (`NSFaceIDUsageDescription`), makes no network requests
and embeds no third-party SDKs. No kids age band. The social-media questions
added on 2026-07-09 are all "no": there is no feed and nothing is redistributed.

### Rating override

Not used. `Frequent` produces 18+ directly, and 18+ is what this app is —
spirits are 18+ in Germany regardless.

## Google Play Console

**Where:** the app → Monitor and improve → Policy and programs → App content →
Need Attention / Actioned → Content ratings → Questionnaire

### Content rating questionnaire (IARC)

> **Promotion or Sale of Age-Restricted Products or Activities**
>
> Does the app focus on promoting or selling items or activities that are
> typically age-restricted such as cigarettes, alcohol, firearms, or gambling?
>
> - Yes
> - No

**Answer: No.**

The section heading is the whole answer: *promotion or sale*. The app promotes
nothing (no ads, no in-app purchases, no affiliate links, no shop) and sells
nothing. The shipped drink catalogue is a data set to log against, not an
offer — a beer entry advertises beer the way a calorie counter sells cake. And
"focus" asks for more still: not merely that such items appear, but that
promoting or selling them is the app's point. Its focus is the opposite, and
the daily limits, the red excess days and the abstinence counters say so.

**Result: Rated for 3+ (IARC Generic).** A low rating for an alcohol app looks wrong beside
Apple's 18+, and it is nevertheless the correct output of the question Google
asked. It is not to be "corrected." The rating is not the publisher's to set
in any case: it is assigned by the IARC bodies (USK, PEGI, ESRB, ClassInd …)
from these answers, Google has no field to raise it, and a dispute goes to the
rating body via the link in the certificate email — not to Google.

### Target audience

**Where:** the app → Monitor and improve → Policy and programs → App content →
Need Attention / Actioned → Target audience and content → Target age

> **What are the target age groups of your app?**
>
> Based on your response we'll highlight any actions that you may need to take,
> and the policies you may need to comply with.
>
> Selecting certain target age groups, such as users over the age of 18, may
> allow additional restrictions to your availability on Google Play.
>
> Make sure you review the [Developer Policy
> Center](https://play.google.com/about/developer-content-policy/) before
> publishing your app. Apps that don't comply with these policies may be
> removed from Google Play. [Learn
> more](https://support.google.com/googleplay/android-developer/answer/9285070#age-groups)
>
> - 5 and under
> - 6–8
> - 9–12
> - 13–15
> - 16–17
> - 18 and over

**Answer: 16–17 and 18 and over.**

Google's rule is that more than one age group may be selected only if the app
was designed for and is suitable for each of them. Both are true here: the app
is built for adults, and a 16-year-old in Germany may legally drink beer and
wine and has the same reason to track it.

This is a **product decision, and an independent one**. It is not a consequence
of the rating questionnaire, and it does not bear on Apple's frequency answer:
targeting 16-year-olds does not make the app's alcohol references rarer.

**A consequence worth knowing:** Play's "restrict access for minors" feature —
which actually removes the app from search and download for users Google
identifies as under 18, rather than merely labelling it — requires "18 and
over" to be the *only* selected group. Selecting 16–17 as well puts it out of
reach, deliberately. Google's "restricted content and features" policy, linked
from the target-audience page, says the feature *must* be enabled for certain
apps; whether an alcohol tracker is one of them is a question this file does
not answer, and one worth settling before a Play release.

Note also that Google flags 16–17 as an age group that may count as children in
some regions, and asks whoever targets under-21s to check local law. That is a
legal question, not a technical one.

## What is deliberately not here

The App Privacy answers (App Store Connect) and the Data Safety form (Play).
Both reduce to "no data collected", and the reason is not a judgement call but
a fact of the code — no network, no SDKs, one permission. `PRIVACY.md` is the
record for those, and it is the document both stores link to.
