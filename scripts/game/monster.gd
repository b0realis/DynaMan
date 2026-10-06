class_name Monster
extends RefCounted
## One enemy entity (v4.6: typed class, was a Dictionary).
##
## Owned by main.gd's `enemies` array. Movement is a destination walker
## (_move_enemies): pick `dest` one cell ahead, glide to it, decide
## again. `type` selects the behaviour: "balloon" drifts, "chomper"
## chases, "saw" charges lanes, "ghost" wall-passes, "bees" swarm,
## "elemental" shoots fireballs — and "bomber" is the mini-boss, driven
## by BomberBrain instead of _enemy_decide.
##
## Optional fields use sentinels instead of key-presence (the Dictionary
## habit): NO_DEST / NO_GOAL / desper_t < 0 / intent == "" / trail null.

var type := "balloon"
## Grid-space position in CELLS; fractional mid-walk.
var pos := Vector2.ZERO
## Current heading, one cell axis; ZERO = needs a fresh decision.
var dir := Vector2i.ZERO
## Committed walk target one cell ahead; NO_DEST = none yet.
var dest := NO_DEST

# -- per-type timers (seconds) ------------------------------------------
var anim_t := 0.0     ## walk/wobble animation clock
var blink_t := 0.0    ## time until the next blink
var blink_hold := 0.0 ## how long the current blink stays closed
var chase_t := 0.0    ## chomper: seconds left of active pursuit
var cool_t := 0.0     ## chomper/saw: cooldown after a charge
var shoot_t := 0.0    ## elemental: time until the next fireball

# -- bomber mini-boss only (BomberBrain state) --------------------------
var bombs_out := 0
var bombs_max := 1
var flame := 2
var intent := ""      ## committed coin flip: "summon" / "mine" / ""
var goal := NO_GOAL   ## committed mining/summon bomb site
var desper_t := -1.0  ## when the walled-in clock started; <0 = not desperate

# -- menagerie extensions (v6.8) ----------------------------------------
var hp := 1           ## hits to kill (dragon: 3, others 1)
var mode := ""        ## per-type state: "burrow"/"air"/"disguised"/
					  ## "telegraph"/"charge"/"stun"/"digest"/"" — see
					  ## Menagerie for each type's state machine
var special_t := 0.0  ## the type's personal timer (hop/burrow/summon/...)
var stock := 0        ## per-type counter (warlock summons used, ...)
var kind := ""        ## sub-variant ("mini" slime)
var birth_grace := 0.0 ## newborn flame immunity (v10.4: a split mini
					   ## must not die in its parent's own blast)
var body: Array = []  ## multi-tile serpents: segment sprites (head=node)
var track: Array = [] ## serpents: recent head positions, newest first

# -- scene nodes (owned by main, freed with the entity) -----------------
var node: Sprite2D = null
var trail: CPUParticles2D = null ## chomper dust; null for other types
var col := Color.WHITE           ## tint (boss: its random colour)

const NO_DEST := Vector2i(-99, -99)
const NO_GOAL := Vector2i(-99, -99)


func has_dest() -> bool:
	return dest != NO_DEST


func clear_dest() -> void:
	dest = NO_DEST
