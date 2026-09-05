# Changelog

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
