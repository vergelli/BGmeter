# Match balance

One number from 0 to 100 that says how much of a match there was, independent of who won. This document is the definition, the reasoning behind each choice, what it is not, and the literature it borrows from. The code is `Match.balance` in `core/match.lua`; the score is stored with every match as `bal`.

## Definition

A match has teams $T$ ($k \in \{2, 3\}$) and score samples at instants $t_1 < \dots < t_n$, one every 5 s, $n \ge 4$. $s_j(i)$ is team $j$'s score at sample $i$ as the game shows it; $K_j$ its kills on the final scoreboard.

Final score: $F = \max_j s_j(n)$.

Margin at sample $i$, leader over runner-up as a fraction of the final score:

$$m_i = \frac{s_{(1)}(i) - s_{(2)}(i)}{F} \quad (F > 0;\ 0 \text{ otherwise})$$

Three components, each in $[0, 1]$:

- **kill ratio** $R = \min_j K_j / \max_j K_j$ (1 when nobody killed anyone)
- **closeness** $1 - M$, where $M = \frac{1}{n}\sum_i m_i$ is the mean margin
- **contested share** $C = \frac{1}{n}\sum_i \mathbf{1}[m_i < \theta]$, $\theta = 0.10$

$$B = \left\lfloor 100 \cdot \frac{R + (1 - M) + C}{3} + \tfrac12 \right\rfloor$$

$B = 100$ only when kills were equal, no sample had a lead and every sample sat within $\theta$; $B \to 0$ as one team takes every kill and holds a full-score lead throughout.

## Where it comes from

It was not taken from a paper. It was designed for this addon on 2026-09-25 from three questions a player asks about a match, each turned into a bounded, unit-free signal, and validated against Fede's own recorded matches before it shipped (the trades that looked even scored high; the stomps scored low; the two synthetic shapes that gamed one component were rejected, which is why there are three). What it borrows:

- **The fight itself.** Kills are the currency every Battleground mode shares, and the ratio of the losing team's kills to the winner's is the only component that is mode-independent. It answers "did the other side fight back at all".
- **The score over time.** Sports economics has studied "competitive balance" since Rottenberg (1956) and the uncertainty-of-outcome hypothesis: a contest is worth watching in proportion to how uncertain its result is while it runs. Within a single game, the usual proxies are the size of the lead over time and how long the lead stayed small. The mean margin and the contested share are those two proxies, normalised by the final score so a 500-point mode and a 50-point mode read the same.
- **Closeness in the last minutes is not enough.** Basketball analytics defines "clutch" as within five points in the last five minutes; we deliberately do not weight the end more than the start, because in Battlegrounds the end of a stomp is also close to nothing (the losing team stops). The contested share over the whole match, with $\theta$ at ten percent of the final score, is the same idea applied uniformly.
- **How to combine.** Three signals, equal weights, arithmetic mean. This follows the standard guidance for composite indicators (OECD/JRC Handbook on Constructing Composite Indicators, 2008): normalise every component to the same range, state the weights, and prefer equal weights unless there is a ground truth to fit them against. There is no ground truth for "this match was balanced", so no regression, no learned weights, and the formula stays readable in a tooltip.
- **What was rejected.** A win-probability model (as in the excitement indices used for American football, e.g. Lock and Nettleton 2014) would need a fitted model per mode and per team size, retrained with every patch; the addon would then carry a model nobody can inspect. Lead changes alone were rejected because a match can flip its leader twice in the first minute and be a stomp for the remaining ten; they are reported next to the score ("decided at", "lead never changed") but do not enter it.

## What it is not

- **Not a rating of you.** It is a property of the match. A 20 can be your win and a 90 can be your loss; that is the point.
- **Not comparable across modes without care.** Crazy King's score accelerates as flags accumulate, so its margins grow even in a live match: CK reads structurally lower (about 21 on average in the first dataset against 53 for Domination). Any study compares within a mode and a team size.
- **Not aware of surrender.** A team that stops fighting after a clear lead lowers the kill ratio and the contested share, which is right; it does not know why they stopped. The strip shows "at base" and "stopped" next to the score for that reason.
- **Not robust below four samples.** Matches shorter than 20 seconds of recording have no score.

## The hover card

The card under the strip prints the formula with its values, so the number is never alone:

```
BALANCE 65
= ( kill ratio 0.71 + closeness 0.79 + contested 0.45 ) / 3
decided 4:12  ·  Pit Daemons ahead
```

## References

- Rottenberg, S. (1956). The Baseball Players' Labor Market. *Journal of Political Economy* 64(3). The origin of the uncertainty-of-outcome hypothesis.
- Humphreys, B. R. (2002). Alternative Measures of Competitive Balance in Sports Leagues. *Journal of Sports Economics* 3(2). The survey of season-level balance measures the within-game proxies descend from.
- Lock, D., Nettleton, D. (2014). Using random forests to estimate win probability before each play of an NFL game. *Journal of Quantitative Analysis in Sports* 10(2). The win-probability approach this design chose not to take, and why.
- OECD, JRC (2008). *Handbook on Constructing Composite Indicators: Methodology and User Guide*. Normalisation, weighting and the case for equal weights without a ground truth.
