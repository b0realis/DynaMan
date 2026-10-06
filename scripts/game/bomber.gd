class_name Bomber
extends RefCounted
## One player entity — human or bot (v4.6: typed class, was a Dictionary).
##
## Owned by main.gd's `players` array; index in that array == `i`.
## main.gd moves it (_move_player), renders it (_update_player_sprite),
## and kills it (_kill_player). BomberBrain.drive_bot drives it when
## `bot` is true. All timers are in seconds and tick in _tick_status.
##
## Why a class and not a Dictionary: typo'd fields now fail loudly at
## parse time instead of silently minting a new key, and the editor can
## autocomplete every field below.

## Slot index (0-3): color, controls, HUD column, spawn corner.
var i := 0
## Grid-space position in CELLS (not pixels); fractional mid-walk.
var pos := Vector2.ZERO
var alive := true
## Rounds won this battle (first to Settings.wins_target + margin).
var wins := 0

# -- power-up state (reset every round) --------------------------------
var bombs_max := 1     ## how many bombs may be down at once
var bombs_out := 0     ## how many currently are
var flame := 2         ## blast arm length in cells
var speed := 4.0       ## cells per second (main.BASE_SPEED at spawn)
var kick := false      ## walk into a bomb to send it sliding
var vest_t := 0.0      ## flame-proof seconds remaining
var wallpass := false  ## may walk through soft bricks

# -- skull curse --------------------------------------------------------
var curse := -1            ## Curse enum in main.gd; -1 = healthy
var curse_t := 0.0         ## seconds of curse remaining
var nasty := false         ## contagious: touching others passes the curse
var nasty_immune_t := 0.0  ## grace after a cure — no instant re-infection
var frozen_t := 0.0        ## freezer touch (v6.8): seconds stuck solid
var freeze_immune_t := 0.0 ## grace after a thaw — no freeze-locking

# -- scene nodes (owned by main, freed on round rebuild) ----------------
var node: Node2D = null        ## world-space container at `pos`
var spr: Sprite2D = null       ## the bomber sprite inside `node`
var curse_spr: Sprite2D = null ## floating skull while cursed
var fx := {}                   ## aura nodes by name (vest glow, ...)

# -- render bookkeeping (see _update_player_sprite) ---------------------
var move_dir := Vector2.ZERO ## last input vector (picks view + flip)
var view := "front"          ## "front" / "back" / "side"
var flip := false
var frame := 0               ## walk-cycle frame
var anim_t := 0.0
var tex_key := ""            ## last texture cache key — skip re-fetch
var spr_base_y := 0.0        ## sprite rest y; walk-bob offsets from it

# -- battle stats (v6.3) — reset at rematch, shown on the trophy card --
var stat_bombs := 0  ## bombs placed this battle
var stat_bricks := 0 ## bricks blasted by this player's bombs
var stat_kills := 0  ## players + monsters caught in this player's blasts
var stat_items := 0  ## beneficial power-ups grabbed (skulls don't count)

# -- bot driver (v4.6, only read when `bot` is true) --------------------
var bot := false            ## AI-controlled slot (BomberBrain drives it)
## Team battle (v10.2): 0 or 1 when a 2v2 pairing is active, -1 in FFA.
var team := -1
## Revenge (v10.2): the fallen ride the border rim and lob bombs back.
var rim := false            ## dead but dangerous
var rim_pos := 0.0          ## scalar along the border perimeter (cells)
var rim_cd := 0.0           ## seconds until the next throw
var rim_node: Node2D = null ## the rim sprite (freed on round rebuild)
var bot_dir := Vector2.ZERO ## brain's current steering vector
var bot_bomb := false       ## brain wants the bomb button this frame
var bot_bomb_cell := Vector2i(-99, -99) ## THE PLANNED CELL for that bomb —
## placement must not re-round p.pos: the same frame's movement can
## shift the rounding a cell off-plan, dropping the bomb onto the
## verified escape route (the first demo run had bots trapping
## themselves exactly this way)
var bot_t := 0.0            ## seconds until the brain replans
var bot_goal := Vector2i(-99, -99) ## committed mining goal (NO_GOAL when none)

const NO_GOAL := Vector2i(-99, -99)


func _init(slot := 0, base_speed := 4.0) -> void:
	i = slot
	speed = base_speed
