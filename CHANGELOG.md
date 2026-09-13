# Changelog

## [Unreleased]

- Combat momentum is a heat map now: one lane per team, hotter where that team scored more kills in the last minute, on a ramp that runs from the team's own colour to white-hot. The peak skulls sit on the lane of the team that owned them. Hover a run for the kill count.
- Familiar faces: the result window marks players you have met before with a note glyph and a count next to their name, green when they were mostly on your side, red when mostly against, grey when mixed. Hover the row for the split and when you last met. The Registry grows a bookmark on its right edge that opens a drawer listing everyone you have met, most matches first, with a search box and a scrollbar; each row carries a split pip, green for the share of matches on your side and red for the rest; the drawer wears the same cover art as the Registry and remembers whether it was open. In the result window the row hover is a single line. On first load the ledger is seeded from the matches already stored. A "Familiar faces" toggle in Settings hides the badges in the result window; `/bgmeter faces` and `/bgmeter forget faces` open the copybox with the list or the confirmation. The ledger keeps the 1500 most recent names.
- Fixed: flag occupation counted the time before a flag existed as neutral, so Crazy King showed a grey share far bigger than what happened. A flag's lane now opens when the flag activates and closes when it deactivates; the time it did not exist is left empty and stays out of every percentage.

## [0.1.7]

- Registry: the top three competitive standings are Champions now, not only the first, and their trophy wears a fast chrome rainbow glow. The glow stays still with animations off.

## [0.1.6]

- Fixed: the satchel only looked at the repeatable reward past rank 100. It now covers every unclaimed veterancy reward on the track, from the first claimable rank on, ranks with more than one reward included, and one click claims them all.
- `/bgmeter vet` reports whether the track holds unclaimed rewards and how many are waiting.

## [0.1.5]

- Registry: a satchel icon appears next to your veterancy rank whenever a reward is waiting. Click it to claim without leaving the window; the tooltip says how many are waiting. The arrow to the game's veterancy screen stays.
- `/bgmeter vet` now reports how many repeatable rewards are claimable.

## [0.1.4]

- Fixed: past veterancy rank 100 the haul bar stayed full and the progress read above the tier total (for example 218,527 / 168,000). Progress now wraps per repeatable reward, the bar resets each time, and the icon and title stay at the last base rank. Reported by unit220.
- Haul and registry show how many repeatable rewards you have earned past max rank, and completing one during a match counts as a rank up.
- `/bgmeter vet` opens a copyable dump of every raw veterancy value the game reports. If your veterancy display looks wrong, paste it in a report.
- Registry: an arrow next to your competitive standing opens the game's Battlegrounds > Competitive leaderboard, like the veterancy arrow does for the veterancy screen.


## [0.1.3]

- Fixed: with the launcher icon turned off, toggling the cursor (or changing the launcher setting) closed the registry. The registry now closes only when you leave the HUD. Reported by unit220.

## [0.1.2]

- Fixed: toggling the cursor no longer closes the menu or the post-battle report. Reported by unit220.
- Fixed: above veterancy rank 100 the haul showed a "?" icon. The icon and title now stay at the last base rank. Reported by unit220.
- Escape closes the registry, the report and the export window. Toggling the cursor never closes them, and opening them does not take the cursor. A new setting, "Registry opens with cursor", turns the cursor on when the registry opens, off by default.
- Report: the mouse wheel over the title bar moves between matches. Double-click on the title bar restores the default size. The registry title bar does the same.
- Registry: deleting a match now takes two clicks on the cross. The first click turns it red for three seconds.
- Registry: an arrow next to your veterancy rank opens the game's veterancy screen.
- Haul: six rings under the AP line show your share of your team's damage, healing, kills (kills plus assists), damage taken, objectives (captures, or ball time in Chaosball) and medals. They need a little vertical room, so the veterancy block above them is slightly tighter.
- Registry: before your first battle of the session, the record slot shows your all-time wins and losses.
- Registry: kills are highlighted in each row's K/D/A.
- Registry: a scrollbar next to the list when there are more matches than rows. Click the track to jump, drag the thumb, or use the wheel.
- API version updated for the current game patch.

## [0.1.1]

- Fixed: after a competitive leaderboard period reset, the menu kept showing the previous period's rank. It now shows "unranked" (with your current rating on hover) until you place again.
- The top-100 celebration now also fires when you enter the leaderboard from unranked.

## [0.1.0]

Initial release.

- Battle Registry: match history with per-row K/D/A, mode, delete, and tooltips; warrior panel (AvA rank, veterancy, competitive standing with rank tiers, currencies, session record); battleground queue with live status.
- Post-battle report: full scoreboard (every player's damage, healing, K/D/A, medals, captures), match timeline, combat momentum, per-mode objective charts (flags, relics, chaosball), personal haul (AP, XP, veterancy, medals) and competitive standing.
- Works with every current battleground mode, including multi-round formats.
- Sound design, ESC-close, right-click whisper/invite from the scoreboard, top-100 celebration.
