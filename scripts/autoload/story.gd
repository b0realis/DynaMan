extends Node
## Campaign hook (autoload "Story"). The battle scene can host the fights
## of a campaign mode; this release ships without one, so `active` is
## always false and everything here is inert.

var active := false
var pack: Array = []
var skin := "classic"


func bonus(_key: String) -> int:
	return 0


func has_kick() -> bool:
	return false


func finish_battle(_won: bool) -> void:
	pass
