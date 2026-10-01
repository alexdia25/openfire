class_name FirstRunScreen
extends Control
## "Open Fire" mode's first screen (issue #61, stage 4; decision 5): shown before anything else when the game's base
## pack doesn't exist yet. The player points it at their own Return Fire (PC) install -- and, for the music, the game
## CD's image or drive if it isn't in that folder -- and RFImporter turns it into the pack on a background thread
## (decision 6) while a progress bar runs. Deliberately minimal (the issue's "functional only" first pass); meant to
## become the first page of a real settings menu later rather than be built twice.
##
## Emits `finished` once a pack is in place at `target`. A failed import shows why and lets the player pick again;
## nothing is ever written at `target` unless the import succeeded (RFImporter's guarantee).

signal finished

const PREFS := "user://open_fire.cfg"   ## remembers the folders the player chose last

var target := ""            ## where the pack goes (the project's openfire/packs/base_pack)
var _install: LineEdit
var _cd: LineEdit
var _go: Button
var _bar: ProgressBar
var _status: Label
var _error: Label
var _continue: Button
var _dialog: FileDialog
var _dialog_for: LineEdit
var _thread: Thread
var _importer: RFImporter


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # anchors alone leave a Control added in code at size 0
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "OPEN FIRE"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var intro := Label.new()
	intro.text = ("Open Fire plays Return Fire using the files from your own copy of the game. Choose the folder the PC "
			+ "(Windows 95) version is installed in. They are converted once, on this computer, and never leave it.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.modulate = Color(1, 1, 1, 0.75)
	box.add_child(intro)

	var prefs := ConfigFile.new()
	prefs.load(PREFS)
	_install = _path_row(box, "Return Fire folder", String(prefs.get_value("import", "install", "")))
	_cd = _path_row(box, "Music (optional): the game CD's .iso, or the CD drive", String(prefs.get_value("import", "cd", "")))

	_go = Button.new()
	_go.text = "Import"
	_go.pressed.connect(func(): start_import(_install.text.strip_edges(), _cd.text.strip_edges()))
	box.add_child(_go)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.visible = false
	box.add_child(_bar)
	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_status)
	_error = Label.new()
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	box.add_child(_error)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.visible = false
	_continue.pressed.connect(func(): finished.emit())
	box.add_child(_continue)

	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.dir_selected.connect(func(p): _dialog_for.text = p)
	_dialog.file_selected.connect(func(p): _dialog_for.text = p)
	add_child(_dialog)


func _path_row(box: VBoxContainer, label: String, value: String) -> LineEdit:
	var l := Label.new()
	l.text = label
	box.add_child(l)
	var row := HBoxContainer.new()
	box.add_child(row)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var browse := Button.new()
	browse.text = "Browse..."
	browse.pressed.connect(func():
		_dialog_for = edit
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR if edit == _install else FileDialog.FILE_MODE_OPEN_ANY
		_dialog.filters = PackedStringArray() if edit == _install else PackedStringArray(["*.iso ; CD image"])
		_dialog.popup_centered_ratio(0.6))
	row.add_child(browse)
	return edit


## Checks `install` at once (a wrong folder is answered immediately) and, if it looks right, imports it on a thread.
func start_import(install: String, cd := "") -> void:
	_error.text = ""
	_continue.visible = false
	var why := RFImporter.validate_install(install)
	if why != "":
		_error.text = why
		return
	var prefs := ConfigFile.new()
	prefs.load(PREFS)
	prefs.set_value("import", "install", install)
	prefs.set_value("import", "cd", cd)
	prefs.save(PREFS)
	_set_busy(true)
	_importer = RFImporter.new()
	_thread = Thread.new()
	_thread.start(func() -> String:
		return _importer.run(install, target, func(f: float, msg: String) -> void: _progress.call_deferred(f, msg), cd))


func is_importing() -> bool:
	return _thread != null


func error_text() -> String:
	return _error.text


func _progress(fraction: float, message: String) -> void:
	_bar.value = fraction
	_status.text = message


func _process(_delta: float) -> void:
	if _thread == null or _thread.is_alive():
		return
	var why: String = _thread.wait_to_finish()
	_thread = null
	_set_busy(false)
	if why != "":
		_status.text = ""
		_error.text = "The import did not finish: %s" % why
		return
	if _importer.warnings.is_empty():
		finished.emit()
		return
	_status.text = "Imported, with notes:"
	_error.text = "\n".join(_importer.warnings)
	_continue.visible = true


func _set_busy(busy: bool) -> void:
	_go.disabled = busy
	_install.editable = not busy
	_cd.editable = not busy
	_bar.visible = busy
	if busy:
		_bar.value = 0.0


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()   # never leave the import running behind a closed screen
