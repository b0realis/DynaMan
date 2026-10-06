# DynaMan — design document

A lean, maximum-fun **Dynablaster (1991)** battle-mode clone for **Godot 4.7**
by Prescription Games. No story mode — pure local battle, 1–4 players on one
keyboard (plus one gamepad per player). All-vector art in the Dynablaster
palette; every sound synthesized; everything built in code (the .tscn files
are node+script stubs), pure logic split from the scene for headless tests.
Same house style as sibling games.

## Arena

Grid of `w×h` cells (odd numbers; default 15×13, custom 9–31 × 9–25 in the
battle setup). Classic Bomberman skeleton:

- **Border**: indestructible walls all around.
- **Pillars**: indestructible walls at every (even x, even y) cell.
- **Bricks**: soft blocks filling the rest with probability `brick_density`
  (default 0.75). Flames destroy them.
- **Spawn corners**: the four corner cells (1,1), (w−2,1), (1,h−2),
  (w−2,h−2) plus their two corridor neighbors are always kept clear.
- Players spawn in corner order P1 top-left, P2 bottom-right, P3 top-right,
  P4 bottom-left (max distance for 2 players).

## Items (hidden under bricks)

Each brick hides an item with probability `bonus_density` (default 0.25).
A hidden item is a **skull** with probability `danger_share` (default 0.2),
otherwise bomb-up 40% / fire-up 40% / speed-up 20%.

| Item | Effect |
|---|---|
| Bomb-up | +1 simultaneous bomb (start 1, cap 8) |
| Fire-up | +1 flame length (start 2, cap 10) |
| Speed-up | +0.5 cells/s (start 3.4, cap 6.4) |
| Kick (v1.5) | bump into a bomb to send it sliding — no extra button; stops at anything solid or anyone |
| Vest (v1.5) | 10 s fireproof (flames AND infection can't touch you); golden sparkle aura |
| Wall pass (v1.5) | walk through bricks (not walls or bombs) for the rest of the round; pale blue shimmer |
| Skull | 8 s curse: reversed, molasses, or no-bombs; purple wisp aura |
| Green skull (v1.5) | 12 s NASTY curse: auto-bomb or sluggish+reversed — and **contagious by touch** (vest blocks it); trails green infection smoke |

Good items split 30% bomb / 30% fire / 15% speed / 12% kick / 8% vest /
5% wall-pass; dangerous items are 70% purple skull, 30% green. Every
active effect has a particle aura that trails the runner (world-space
emitters), so status is readable at a glance mid-melee.

Flames burn revealed items (classic). Walking over picks up (sfx + sparkle).

## Bombs & flames

- Place on your cell (rounded); pulses, fuse **2.8 s**.
- The placing player can walk off it; once left, the bomb blocks everyone.
- Explosion: cross of flame, `flame_len` cells per arm; stops at walls,
  destroys the first brick hit and stops, burns revealed items and stops,
  **chains** other bombs instantly — gameplay-instant, but the BOOMs of a
  chain stagger ~70 ms per hop (v4.5): the classic machine-gun rattle of
  a whole row going off.
- Flames persist 0.45 s; any player/enemy whose cell is aflame dies.

## Enemies (v3.2 menagerie)

`enemy_count` (0–12) creatures spawn ≥5 cells (Manhattan) from any player and die to
flames. Multiplayer rolls only balloon 75% / chomper 25%; solo unlocks all:

| Type | Solo weight | Behavior |
|---|---|---|
| Balloon | 30% | wanders, bobs, blinks; touch kills |
| Chomper | 15% | patrols with a gold dust trail; within 3.5 cells it hunts for 5 s at 2.7 c/s, then cools 3 s |
| Saw blade | 12% | fast (3.4 c/s) straight-line ricochet, spins |
| Ghost | 12% | drifts through bricks (not walls/bombs), translucent |
| Bee swarm | 12% | erratic, jittery, frequent turns |
| Fire elemental | 9% | spits fireballs (5 c/s) down clear lines ≤6 cells; fireballs kill players (vest blocks), detonate bombs, splash a trail |
| Bomber enemy | 10% | gray AI bomberman: dodges blast lines, hunts, lays real bombs (owner-less, gray-tinted); doesn't touch-kill |

## Single player: monster hunt + exit portal (v3.9)

Solo is an **arcade hunt**, not a duel. Kill every monster, then find
the **exit portal** hidden under a random brick (`portal_cell`): blast
the brick to reveal the stone doorway (it sleeps, dimmed, while
monsters remain), clear the field to wake it (sparkle column, Sfx
`portal_open`), and step through — the bomber spirals into the door
(`_begin_exit`, `State.EXIT`, Sfx `portal`) and the trophy splash says
**YOU ESCAPED!**. Dying shows DEFEAT with R to retry. The portal brick
never hides an item; a portal revealed early just waits.

**Portal punishment (v4.0, capped + weaponized v4.2)**: flame the
revealed doorway and it answers — an angry warble, then once the blast
clears a bomber mini-boss in a random colour storms out with a matching
spawn burst, and the door slams shut (dim, sparkles gone) until every
boss is dead. **`Settings.max_bosses` (battle-setup slider, 1–5,
default 1) caps simultaneous bosses** — spawn-table rolls and portal
summons both respect it. And the bosses know the rule: a WALLED-OFF
boss below the cap flips a coin — 50/50 (v4.3) between bombing the
doorway for a colleague and mining bricks toward the prey. The flip is
committed until the resulting bomb is placed (re-rolling per step
would flip-flop the march); a boss that can reach you just hunts (kill
shot beats everything). Bosses stand at full player height
(`BOMBER_H_CELLS`) since v4.2. One spawn per offense (1 s guard), and
emergence WAITS for a safe doorway — follow-up bombs can cover the
portal when the timer fires, and newborns used to die instantly to
them (found by the probe, fixed in v4.3). Probe:
`tests/portal_punish_probe.tscn` (punish, random colour, door-shut,
cap, forced-intent summon execution — all deterministic).

The **bomber monster** is the rare mini-boss: 10% spawn roll, capped by
the Max mini-bosses slider (1–5, default 1), never in cramped 2-cell pockets, dressed in a random
colour rolled at spawn (its bombs and flames carry that colour). Its
brain (`_bomber_enemy_decide`) is the v3.6 planner, monster edition —
BFS hunt toward the nearest player, committed mining goals through
brick walls, kill shots when the prey enters blast range, and no bomb
without a verified escape (≤5 cells: it runs at 2.4 cells/s against a
2.8 s fuse; live flames are lava, predicted rays are crossable). Truly
caged, it glares at the wall for 8 s, then lights the fuse anyway.
Regression probes: `tests/ai_probe.tscn` (boss must mine and bomb, or
kamikaze if caged), `tests/portal_probe.tscn` (reveal → open → step in
→ escape → BATTLE_END, end to end).
The follow camera (arenas beyond the multiplayer clamp) is unchanged. Arenas beyond the multiplayer clamp
(21×17) are solo-only: cells stay a readable fixed size and the camera
follows the human, clamped to arena bounds. Battle-setup presets:
Classic 15×13 and Wide 21×11 (fills a FullHD frame).

## The menagerie (v6.8)

20 enemy types in five tiers (Menagerie.TIER — a future STORY MODE can
build waves from `by_tier()`; everything keys off the type string).
main.gd's destination walker moves every head; scripts/game/
menagerie.gd owns the abilities: state machines (burrow/hop/disguise/
telegraph-charge-stun/digest), steering goals (thief→loot,
muncher→bombs, woken mimic→you), touch rules (freezer FREEZES for
1.6 s instead of killing — vest-independent, with a 4 s re-freeze
grace), and flame rules (slime splits into two minis, snake bodies
chop, centipede/dragon bodies are armored, the dragon has 3 hp with
1.2 s i-frames and breathes elemental fireballs). Serpents follow the
head's recorded track at fixed arc-spacing — the snake-game drag.
Solo spawn odds live in _roll_enemy_type (tier-weighted, serpents
rare); multiplayer stays balloons + chompers so the real threat is
the other players. Mimics wear THIS arena's brick texture — 50 skins
of paranoia.

## Rounds & winning (v4.7 terms, player's call: one arena = a ROUND, the series = the BATTLE)

- **Endgame pressure (v4.5)**: the last 30 s pulse the timer red and flip
  `Music.urgent` (notes ~2× faster, a whole step higher). With **Sudden
  death** enabled in the battle setup (default OFF, multiplayer only),
  the last 45 s close the arena: pressure blocks spiral inward, one per
  0.55 s, crushing players (the vest is fireproof, not stone-proof),
  enemies, bricks and items — squeezed bombs detonate. A **BATTLE POINT**
  strip under the HUD names every player one round win from the battle,
  win-margin aware.
- Countdown 3-2-1-GO → battle → **last bomber standing** wins the round
  (multi-player) or **clear all monsters + escape through the exit
  portal** (single player, v3.9). Both players dying in the same blast
  = draw. Round timer (setup slider, 1:00–5:00, default 2:30) runs
  out → draw.
- **Revenge (v10.2, setup toggle)**: a dead multiplayer bomber turns
  into a RIM RIDER — a tinted sprite on the border ring (perimeter
  scalar, fractional cell mapping), steered tangentially by that seat's
  own keys/pad, lobbing a real bomb (owner index, flame 2) that lands
  3 cells in from the wall (fallback 2/4/1 if blocked), on a 2.4 s
  cooldown. Rim bombers stay dead for every round-end purpose; their
  kills credit normally (a rim assist can win their TEAM the round).
  Bot rim riders drift and lob when roughly aligned with an enemy.
- **Teams 2v2 (v10.2, setup cycler)**: Settings.team_mode picks one of
  the three pairings (TEAM_MASKS); teams engage only when the roster is
  exactly four (else FFA + countdown note). Round end = all survivors
  share a team; wins credit BOTH members in lockstep so wins_target /
  win_margin / BATTLE POINT stay untouched; ceremonies announce via
  _victory_name() ("TEAM P1 + P3"); HUD labels and player tags carry
  the team letter; BomberBrain._bot_victim skips teammates.
- **Bot difficulty (v10.2, setup cycler)**: "hard" = the classic brain;
  normal/easy multiply the replan interval (1.4x / 2.2x), gate bomb
  decisions (80% / 50%) and trim base speed (0.95x / 0.85x). Seat bots
  only — mini-boss monsters stay ruthless. party_probe guards teams
  lockstep and the rim rig.
- **Bots & demo (v4.6)**: humans take the first slots, bots fill the
  tail. `Settings.solo_bots` (0–3) joins them to a 1-human game — any
  bot at all flips solo from the arcade hunt to battle rules (the mode
  check is `players.size()`, not the humans setting). `Settings.players
  = 0` is the demo: `demo_bots` (2–4) battle alone, the countdown notes
  it, and BATTLE_END auto-rematches after 6 s so the attract loop never
  stops. Bots are ordinary `Bomber` entities driven by
  `BomberBrain.drive_bot`: same flee/kill/loot/tunnel priorities as the
  mini-boss, but bombs are latched with their PLANNED cell
  (`bot_bomb_cell`) — placement re-rounding a moving position once
  dropped bombs onto the verified escape route.
- **Bomb styles (v5.1)**: five costumes for the same bomb, picked in
  OPTIONS (Settings.bomb_style, classic default). Templates live in
  assets/bomber/bomb_*.svgt with %COL% team accents, served by
  BomberArt.bomb_texture(col, style). The shared heartbeat/panic-blink
  stays; each style adds its own idle motion in _tick_bombs (dynamite
  trembles, the mine spins with urgency, the aero bomb rocks on its
  nose, ACME sways) and parks the fuse-spark emitter at its own tip
  offset (_bomb_spark_off). Cosmetics only — fuse, blast and kick are
  identical in every costume. The potion (v6.0) is the odd one out
  visually: no wick — its "spark" emitter makes bubbles INSIDE the
  bulb (speed_scale tracks urgency, so the brew visibly boils harder),
  and at t < 0.5 s _uncork_potion swaps to the frothing open-bottle
  texture and launches the cork (bomb_potion_open/_cork.svgt).
  **Per seat since v8.9**: BATTLE SETUP has a style cycler under each
  player's colour button — "global" (the default) follows the OPTIONS
  cycler, anything else is that seat's own costume
  (Settings.bomb_style_for(i); monster bombers follow global). The
  style is snapshotted per bomb at placement (b["style"]), so ticks,
  spark offsets and the uncork are per-bomb and mixed-style battles
  animate every costume correctly.
- **Rumble (v4.6)**: `_rumble` maps pad N to player N; death is a long
  hard buzz, nearby blasts tap the pad scaled by distance. Bots and
  unplugged slots are skipped.
- **Arena tile skins (v4.8, 50 themes + preview + random in v4.9)**:
  `TileArt` (scripts/fx/tile_art.gd) owns the API/floors/labels; the
  drawings live in `TileSvg` (scripts/fx/tile_svg.gd), grouped by
  collection with colour-theory notes. OPTIONS shows a live mini
  preview (floor + wall + bricks, the real textures); "Random arena"
  (Settings.arena_random) rerolls main.gd's per-round `_skin` at every
  _start_round. Originally — wall SVG, brick SVG and the two floor-checker colours per
  skin, rasterized once and cached (BomberArt pattern; "classic"
  delegates to the original assets so the default stays pixel-perfect).
  Selected in OPTIONS ("Arena tiles" cycler → Settings.arena_skin),
  applied at board build; sprites scale by TEXTURE width since classic
  imports at 64 px and TileArt rasters at 128. Design rule: the brick
  must SAY its theme, and organic bricks (hedge/garden/forest/
  mountain) have no background rect so the floor shows through their
  gaps. Legibility rule learned in review: wall vs brick must read at
  a squint — the hedge wall went two shades darker and the volcano
  brick swapped its orange slab for a dark crust with a glowing crack
  net after the first in-game screenshots.
  **USER ARENAS (v9.1)**: a user theme is a named RECIPE, not code —
  per element (wall/brick) a shape from TileSvg.USER_SHAPES + one base
  colour (the tint set derives from it) or an embedded PNG, plus a
  floor tone, a music mood and a name. Stored in user://arenas.cfg,
  served through the SAME five TileArt calls (wall/brick/floors/label/
  mood), so the cycler, previews, Random pool and battles need no
  special cases; ids wear the "u_" prefix. ensure_legible() enforces
  the squint rule by retargeting the wall's luminance exactly (linear
  RGB scale). The ARENA THEME MAKER (OPTIONS, gold-trimmed button; 32 shapes since v9.5 — v9.2 added cobbles/crate/ice/barrel/gear/mushroom, v9.5 added hexes/shingles/bamboo/sandstone/circuit/weave/stainedglass/moai/scales/lattice (moai replaced the runestone in v9.6; the old id still renders) + eight organics (gem/pumpkin/shell/cactus/lantern/statue/egg/chest); name pools 32x32) edits the recipe with THE DIE (drawn die icon)
  rolling colour-theory harmonies; .dynarena files share themes
  (import remaps taken ids, never clobbering). arena_probe guards the
  registry, Settings validation, share round-trip, PNG elements and
  40 die rolls' legibility. Renderer lesson: preview textures are
  built in the refresh, not inside _draw — a texture created mid-draw
  renders white for that frame in the compatibility renderer.
- The battle is won at **`wins_target` round wins (1–5, default 3)** — but
  only while leading the runner-up by **`win_margin` (1–2)**: with margin 2
  a tied rivalry keeps playing until someone pulls two rounds clear.
- **Victory splashes**: each round win shows the winner's bomber center
  screen with a gold **medal** bouncing down onto them; taking the battle
  shows a different-colored splash with the gold **trophy** falling —
  "PLAYER X WINS THE BATTLE!". `R` rematches, `Esc` pauses (Q quits).
- **Defeat splash** (solo, v4.4): the mirror ceremony. The loser center
  stage in their colour with the crying face (`cry.svgt`: eyes screwed
  shut, waterfall tears, wilted antenna), sobbing-shoulder loop and
  tear particles — while a personal **rain cloud** (the anti-medal)
  bounces down and drizzles on them. Sad trombone (`womp`). Covers
  death AND timeout ("TIME UP — DEFEAT..."). Tools:
  `tests/defeat_shot.tscn`, `tests/defeat_gif.tscn`.

## Player colours & tinted flames (v1.1, free-pick v3.5)

Each player picks a colour in the battle setup — since v3.5 via a full
colour-map `ColorPicker` popup (any colour; the classic 8-colour palette
rides along as quick presets). The bomber art is ONE set of SVG
templates (`assets/bomber/*.svgt`, big-head classic proportions, 2-frame
walk animations for front/back/side views) recolored at runtime
(`BomberArt`), so any palette costs no assets. **Bomb flames carry their
owner's colour** (v1.2; v3.8 made it LOUD: only the first flash is white —
every later layer runs a saturation-boosted `_vivid(col)`: flame ground
cools to colour in ~0.13 s, the additive bloom halo/heart are tinted, the
shockwave ring is a fat owner-colour band with a thin white leading edge,
and all particle ramps open at 30% white then live in colour): blobby
flame cells that "whoomp" open, boil, and
merge like lava, under a three-layer particle system — a heavy fireball at
the bomb, falling ember debris along every cell, and smoke rising a beat
later. **Camera shake on explosions** is an options toggle (default on;
shakes stack with chain blasts up to a cap).

## Controls

| Player | Move | Bomb |
|---|---|---|
| P1 | W A S D | Space |
| P2 | arrows | Ctrl (either) |
| P3 | I J K L | O |
| P4 | numpad 8 4 5 6 | numpad 0 |

Each player also accepts gamepad (device N-1): d-pad/left stick + button A.
The table above is the FACTORY layout (v10.0): the live table is
Settings._player_keys — rebindable in OPTIONS → CONTROLS (physical
keycodes, persisted, system keys and duplicates refused, keypad keys
display as "Kp N" to stay distinguishable from the arrows), applied to
the InputMap via _apply_player_keys(). controls_probe guards the API.

## Movement feel

Free movement at `speed` cells/s, one axis at a time; the cross axis eases
to the corridor center, and a corner-assist slides you around pillar edges
when you're within 0.35 cells of the opening — the classic Bomberman glide.

## Visual language (Dynablaster palette)

Green field (two-tone checker), gray beveled hard blocks, light-red brick
soft blocks, white round bombers (P2 charcoal, P3 red, P4 blue), black
bombs with a spark, orange/yellow cross flames (code-drawn, animated),
item tiles dark blue with gold border, pink balloon enemies. HUD: dark
blue bar, white text, gold accents — menu shares a sibling game's typography.

## Settings persisted (user://dynaman.cfg)

players, arena_w, arena_h, brick_density, bonus_density, danger_share,
enemy_count, sfx/music on+volume, fullscreen. Version bumps 0.1 per change.
