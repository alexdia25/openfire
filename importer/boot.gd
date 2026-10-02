class_name OpenFireBoot
extends Control
## openfire's main scene (issue #61, stage 4): the step before the engine's own front end. If the game's base pack
## (`openfire/packs/base_pack`: res://packs/original_pc in a dev checkout, user://packs/original_pc in an "Open Fire"
## export) is there, it goes straight on to GameFlow; if not, the first-run import screen comes first, before the
## title or anything else (decision 5). Also puts "Game files..." on GameFlow's Settings screen, which comes back
## here to import again (after moving or reinstalling Return Fire, or to add the music), and "Layout: ...", which switches the panel layout
## between classic and modern (documents 96, 124); the choice is saved in user://settings.cfg like the other settings.

const GAME_FLOW := "res://addons/openfire_engine/game/game_flow.tscn"
const BOOT := "res://importer/boot.tscn"

static var force_import := false   ## set by the Settings entry: show the import screen even though a pack exists

var screen: FirstRunScreen = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameSettings.load_settings()
	GameFlow.add_settings_entry("Game files...", OpenFireBoot.reimport)
	GameFlow.add_settings_entry(OpenFireBoot.layout_label, OpenFireBoot.toggle_layout)
	var base := ModLoader.base_pack_dir()
	if ModLoader.has_pack(base) and not force_import:
		_start_game.call_deferred()
		return
	force_import = false
	screen = FirstRunScreen.new()
	screen.target = base
	screen.finished.connect(_start_game)
	add_child(screen)


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_FLOW)


## GameFlow's "Game files..." entry: back to the import screen.
static func reimport() -> void:
	force_import = true
	(Engine.get_main_loop() as SceneTree).change_scene_to_file(BOOT)


## GameFlow's layout entry: the current layout in its label (openfire's own setting, not the engine's).
static func layout_label() -> String:
	return "Layout: %s" % GameSettings.hud_layout.capitalize()


static func toggle_layout() -> void:
	GameSettings.hud_layout = HudLayout.MODERN if HudLayout.is_classic() else HudLayout.CLASSIC
	GameSettings.save_settings()
