# bgmeter

A personal **post-battle Battleground** window for The Elder Scrolls Online.
When a match ends it shows two faces of the fight:

- **The Battle** — the full scoreboard of *every* player (damage, healing,
  K/D/A, score, medals) as a sortable meter table. The stock UI hides damage and
  healing for everyone but the row you click; bgmeter shows them all, with class
  icons, an MVP crown, and gold-tinted column leaders.
- **The Haul** — what *you* walked away with: veterancy season-track progress,
  **AP / XP / CP** with the real in-game icons, the medals you earned, your
  **competitive leaderboard rank** (with ▲/▼ movement since last match), and the
  efficiency bridge (AP/min · AP/kill). Personal bests get a ★.

It keeps a browsable **history** of your recent matches and a **session** tally
(W-L + AP earned) for the night.

## Commands

| Command | What it does |
|---|---|
| `/bgmeter` | Show / hide the window |
| `/bgmeter demo` | Inject a synthetic match and open the window (no BG needed) |
| `/bgmeter dump` | Print the live scoreboard + progression + standing to chat |
| `/bgmeter last` | Open the most recent match |
| `/bgmeter toggle` / `hide` | Window controls |
| `/bgmeter clear` | Clear match history |
| `/bgmeter debug` | Toggle debug logging |

There's also a **"Toggle bgmeter window"** keybind, and a **gear** in the
window's top-right for settings (auto-open, sounds, animations, which panels to
show, clear history, reset position).

## Notes

- Personal tool, not published. Built with AI assistance (Claude).
- Reads the native Battleground scoreboard + progression events — no combat-event
  scraping, no external libraries.
- Veterancy advancement may be Cyrodiil/IC-fed rather than BG-fed; the panel
  shows your standing as context and lights the "this match" delta only when one
  actually occurs. Confirm with `/bgmeter dump`.
- See `../docs/HANDOFF.md` for architecture and the full API reference.
