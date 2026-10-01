@tool
extends EditorPlugin
## openfire's export hook (issue #61, stage 5). An "Open Fire" build (the `openfire_import` feature) carries the
## traced tables the in-game importer applies to the player's files. tools/data/*.json reach the build through the
## presets' include filter, but packs/registry/asset_ids.json can't: packs/ has a .gdignore (so the editor never
## imports a pack's thousands of PNGs), and export filters never look inside an ignored folder. This adds it.

const REGISTRY := "res://packs/registry/asset_ids.json"

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = _RegistryExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)


class _RegistryExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "OpenFireRegistry"

	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if "openfire_import" in features:
			add_file(REGISTRY, FileAccess.get_file_as_bytes(REGISTRY), false)
