extends Node
## Dev one-shot: export the synthesized "boom" to a listenable WAV.
func _ready() -> void:
	var dir := OS.get_environment("DYNAMAN_SHOT_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	var wav: AudioStreamWAV = Sfx._streams["boom"]
	wav.save_to_wav(dir + "/boom.wav")
	print("saved ", dir, "/boom.wav")
	get_tree().quit()
