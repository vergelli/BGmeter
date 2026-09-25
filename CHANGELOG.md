# Changelog

## [0.5.0]

- MATCH BALANCE strip under the score chart: one number from 0 to 100 that says how much of a match there was, from the kill ratio between the teams, the average gap between leader and runner-up, and the share of the match spent within ten percent. The number sits on a scale from red (a stomp) through gold to green (an even match), with a marker at its value. Hover the strip for a card with the components, when the match was decided (the last lead change) or that the lead never changed, and which team was ahead. Every stored match gets it. A toggle in Settings, Result window, turns it off.
- The recorder keeps every stretch the match spent RUNNING, so in Deathmatch and the other round formats the pause before a round and between rounds no longer counts as time at the base. Matches recorded before this keep counting every moment, as they did.
- Two team signals on the same strip: at base, the share of your team's positions close to the spawn (within six percent of the map's width) after the gates open, and stopped, how many teammates dealt no damage for the last 90 s of the match and when the first one stopped. Nobody is named. Matches without positions show only the second.
- Three icons of the addon's own for these: a balance, a camp and a sheathed sword.
- Team experience on the MATCH BALANCE strip: the sum of veterancy ranks and the sum of alliance ranks of each team, your team over the rival, as two bars in team colours next to the Registry's veterancy glyph and the game's alliance rank glyph. Your team is read from the group at the start and the end of the match; the rival is read from every enemy you target during it, so the hover says how many of them were seen (3/4). The alliance block shows at the default width, the veterancy block when the window is wider. Matches recorded before this show nothing here.
- Registry: a saved match no longer deletes from the cross; release its lock first. The footer says so when you try.
- Registry: a balance stat under the currencies, the average balance of your last twenty stored matches, coloured like the strip; hover for the all-time average and how it splits between wins and losses. The Arenas and Modes cards say the average balance per map and per game mode, wins and losses apart. Matches already stored are counted in once at load.
- Fixed: the match report window drew under the action bar, so a second bar shown at all times covered its bottom rows; it now sits on the same high tier as the addon's other windows, and the map panel opens above the report. Thanks to unit220 for the report and the testing.
- Fixed: the map panel decoded the whole match again on every render, up to ten times a second while hovering the chart; the open match is now decoded once and kept, and the About drawer's STORAGE panel shows what it holds under cache.
- Fixed: the player's own position was recorded twice, under the account name and the character name, so the map drew a teammate on top of you and the team heat counted you double. Teammates are now keyed by account name, like the scoreboard; matches recorded before this render correctly without a migration.

## [0.4.0]

- Map: the recorder samples your position, your teammates' and every objective pin every 3 s, keeps the arena's tile art with the match, and stamps your kills and deaths with where they happened. A map button in the report header opens a panel under the report: the real arena map with a heat layer that cycles between your team's presence (viridis ramp) and your deaths and kills (ember ramp), both smoothed, your path in gold on a halo in your team's colour, teammates' paths on request, skulls where you died and where you got kills, and flags, relics and balls where they were at the scrubbed second. Your own path is sampled every second and drawn as a smooth curve. A slider under the map moves through the match, and hovering the timeline chart moves it too. Layers toggle from the panel. The panel docks under the report; drag it away to float it, drag it back to dock; it resizes from either edge and snaps to the map's shape so no dead space is left. A live minimap in a gold frame sits in the haul panel under the share rings (the report's minimum height grew so it always fits): the arena with your path and the objectives replaying the match on a loop (still, at the end of the match, with animations off); hover it and it lights up, click it and the full map opens. About shows a third storage bar for the map data.

## [0.3.0]

- Saved matches: a lock on every Registry row keeps that match forever, outside the "Matches kept" cap and with its charts if it still has them, up to ten. A Saved matches drawer at the bottom edge of the Registry (chest glyph) lists them, newest first, click to open; the hover says whether the charts survived. The Registry footer says so when the ten are full.
- About drawer at the bottom edge of the Registry (overview glyph): version, author and credits (hover the field for the names: unit220, TattoozNbooZ), a CAPACITY table with kept, cap and saved for matches and faces, and a STORAGE panel of two bars, matches and faces, reading bytes used over bytes available. Available is not a game limit: it is the size the store would reach at the addon's own caps, saved matches included, estimated the way the game writes saved variables.
- Competitive standing tiers moved up: Champion is the top 10, Mythic the top 25, Legendary the top 50, Epic the top 100, and two new tiers below, Superior (top 250, blue) and Fine (top 500, green). Every tier's glow breathes slowly, a small glint crosses the trophy every few seconds and a light then sweeps letter by letter across the tier word; Champions keep the chrome rainbow, and rank 1 gets a second glint. Animations off keeps the still glow.
- The Registry list scrollbar is the same bar the drawers use: wider, in the accent colour, with arrows at both ends.
- Settings: two new toggles under Result window, Damage race strip and Kill pressure strip.
- The drawer glyphs on the Registry edge behave like the game's own tabs: the open drawer wears its pressed art, hover shows the hover art.
- A KILL PRESSURE strip under the damage race: kills per minute, one bar per team, the two teams mirrored around a middle line. Hover a minute for the count. It shows when the window has room, like the race.
- The damage race lines are lightly smoothed, sit on a soft halo and fill toward the floor in their team's colour.
- The score chart marks each new round with a dashed line and a label, ticks the minutes along the bottom, shows the top score and names the teams in colour next to the title.
- Every chart strip wears a thin frame.
- In Chaosball your own possessions and in Capture the Relic the runs you scored are drawn in gold on the lane instead of the team colour, and the hover says "you".
- The veterancy link wears the campaign veterancy glyph and the leaderboard link the battlegrounds glyph, twice the size of the old arrow.
- Alliance Points and experience per minute, and damage per minute in the detail line, count played minutes only: the countdown before the gates open no longer deflates them. Matches recorded before this keep their old rates.
- Fixed: a rating drop of exactly three digits read as "-,245" on the standing panel.
- Fixed: a player who left before the end vanished from their team's damage race line. Each sampled player now stays on the team they were sampled on.
- Fixed: the Registry's "all time" record only counted the matches still kept; it now reads the ledger, which never forgets.
- Fixed: in multi-round matches the first lead of a new round counted as a lead change.
- Fixed: the momentum bar's "+N kills" hovers never showed in deathmatch.
- Internals: the Registry is split into panel, queue and menu; chart strips share one builder and one clear path; drawers register themselves.

## [0.2.0]

- A ledger of aggregates fills in at the end of every match and once from the matches already stored: per arena and per game mode it keeps matches, wins, losses, your damage, healing, kills and deaths, and your best damage there; plus personal marks for damage, healing, kills, assists, AP and win streak, each with the match it came from. It stays a few kilobytes no matter how many matches you play.
- Two more drawers on the Registry edge, above Familiar faces: Marks and Arenas. Arenas, with a MAPS / MODES switch, one row per map or game mode with matches and win rate, and a hover card with your averages and best match, click to open it; and Marks, your personal bests with where and when they happened, click to open the match. Only one drawer opens at a time.
- Familiar faces remember how many times you killed each of them and how many times they killed you; the hover says so.
- The recorder now samples every player's damage along with the team scores, stored as a compact string per player so a match costs a few kilobytes, and the report draws a DAMAGE RACE strip under the score chart: one line per team and your own line in gold. Matches recorded before this have no strip.
- The score chart shades the gap between the leading team and the runner-up in the leader's colour, fading toward the line below.
- Combat momentum is a smooth gradient now: one bar, the leading team's colour rising and falling with its kill margin instead of flat blocks, fading through neutral when the lead changes hands.
- Flag control lanes end in a fade instead of a hard cut, and every lane wears a faint top and bottom edge; the momentum bar wears the same edge.
- The emblem grew three times and leans out of the top-left corner of the Registry and the result window, a quarter of it past the edge.
- Hover cards are the addon's own now, framed like its windows with the accent strip, instead of the game's default tooltip. The familiar-faces drawer darkens its cover art toward the top and bottom so the names stay readable.
- Icons: the veterancy satchel uses the item-assistance glyph, the familiar-faces bookmark and drawer use the emotes face, and the badge in the result rows the written page.
- Familiar faces: the result window marks players you have met before with a written-page glyph and a count next to their name, green when they were mostly on your side, red when mostly against, grey when mixed. Hover the row for the split and when you last met. The Registry grows a faces glyph straddling its right edge, half in and half out, that opens a drawer listing everyone you have met, most matches first, with a search box and a scrollbar; each row carries a split pip, green for the share of matches on your side and red for the rest; the drawer wears the same cover art as the Registry and remembers whether it was open. In the result window the row hover is a single line. On first load the ledger is seeded from the matches already stored. A "Familiar faces" toggle in Settings hides the badges in the result window; `/bgmeter faces` and `/bgmeter forget faces` open the copybox with the list or the confirmation. The ledger keeps the 1500 most recent names.
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
