class_name RFPackBuilder
extends RefCounted
## Assembles the pack: the GDScript port of tools/build_pack.py (its docstring and comments hold why each table looks
## the way it does -- the document numbers below point at the same traced findings). Inputs are the decoded player
## files (RFCarDecoder, the levels from RFRfmDecoder, the SOUND/*.SDT bytes) plus the tables traced once and checked
## into this repo: tools/data/*.json and packs/registry/asset_ids.json. Writing goes through the engine's PackWriter.
##
## build_pack.py cut each frame out of convert_car.py's atlas; this takes each frame straight from the decoder. The
## frames are the same pixels (the parity check compares them).

const DATA_DIR := "res://tools/data"
const REGISTRY := "res://packs/registry/asset_ids.json"
const PACK_ID := "original_pc"
const PIXELS_PER_WORLD_UNIT := 32
const TERRAIN_CLASS_PREFIXES := [["terrain.coast.", "coast"], ["terrain.structure.", "structure"],
	["terrain.ground.buildable", "buildable"], ["terrain.ground.blank", "blank"], ["terrain.ground.", "ground"],
	["marker.", "marker"], ["decoration.", "decoration"]]
const TEAM_COLOUR_PRESETS := {"red": [0.0, 0.75, 0.55], "blue": [0.61, 0.70, 0.55], "yellow": [0.14, 0.80, 0.70],
	"grey": [0.0, 0.03, 0.50], "white": [0.0, 0.05, 0.85], "black": [0.0, 0.10, 0.18]}
const TEAM_PAIR_MIN_CONSISTENCY := 0.6
## id, original index, VHCL stock letter, default stock, selector script (document 73, 78)
const ORIGINAL_ROSTER := [["rf.tank", 0, "T", 3, "Tank"], ["rf.jeep", 1, "J", 8, "Jeep"], ["rf.msv", 2, "A", 3, "MSV"],
	["rf.heli", 3, "H", 3, "Heli"]]
const MUSIC_THEME_RULE := {0: "flag_threat", 3: "stock_or_roll"}
## The home pad's mechanism (document 89, the lift object's descriptors 0x44dab0 / 0x44d8f8 / 0x44d890): the pit walls
## (parts 0x44d9d0: north cel 0x33b, west 0x33c, east and south 0x33a), the hazard strip (0x33f), the lift plate
## (0x33d, flag 8: + side) and the two leaves (0x336 / 0x338, flag 8); the open pad's tile art 92 is a hole; the
## dock-ready glow is cel 1778 (documents 80, 103; issue #37).
const HOME_PAD := {"pit_walls": {"north": 827, "west": 828, "east": 826, "south": 826}, "hazard_strip": 831,
	"lift_plate": 829, "leaves": {"left": 822, "right": 824}, "dock_ready_glow": 1778}
const HOME_PAD_HOLE_ART := 92
const OFF_MAP := {"art": 2, "margin_tiles": 12}   ## the tile every cell past the map edge shows (document 112 / issue #69); how many tiles of it the port bakes
const HUD_PANEL_FRAME_CEL := 1940     ## the classic layout's frame around a panel (template slot 2, document 96)
const PROJECTILE_ART := {"shell": 1075, "shadow": 1076}   ## projectile type 0's quad and the ground shadow (documents 46, 48)

var out_dir := ""
var registry: Dictionary = {}     ## str(cel) -> {id, ...}
var car: RFCarDecoder
var frames: Dictionary = {}       ## sprite id -> Image (kept for the team-colour pass)
var sprites: Dictionary = {}      ## sprite id -> sprites.json entry
var team_pairs: Dictionary = {}   ## Vector2i(tan cel, green cel) -> true
var counts := {}


static func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func data(name: String) -> Variant:
	return _json(DATA_DIR.path_join(name))


func rid(cel: int) -> String:
	return String(registry[str(cel)]["id"])


func has_cel(cel: int) -> bool:
	return registry.has(str(cel)) and cel >= 0 and cel < car.count


func _pair(a: int, b: int) -> void:
	team_pairs[Vector2i(a, b)] = true


func _write(rel: String, doc: Variant) -> void:
	PackWriter.write_json(out_dir.path_join(rel), doc)


static func sprite_file(sprite_id: String) -> String:
	var parts := sprite_id.split(".")
	if parts.size() > 2:
		return "/".join(parts.slice(0, 2)) + "/" + ".".join(parts.slice(2)) + ".png"
	return "/".join(parts) + ".png"


static func terrain_class_for(id: String) -> String:
	for p in TERRAIN_CLASS_PREFIXES:
		if id.begins_with(p[0]):
			return p[1]
	return "other"


## Sprites: one loose frame per cel, filed by its registry id; sprites.json; terrain/tileset.json.
func sprites_and_tiles(progress: Callable) -> String:
	var reg: Variant = _json(REGISTRY)
	if not (reg is Dictionary):
		return "the asset registry (%s) is missing" % REGISTRY
	registry = reg["cels"]
	for n in car.count:
		if not registry.has(str(n)):
			return "cel %d has no registry entry" % n
	var sprites_dir := out_dir.path_join("sprites")
	for n in car.count:
		var k := car.kind(n)
		if k == "skipped":
			return "cel %d could not be decoded" % n
		var id := rid(n)
		if sprites.has(id):
			return "duplicate registry id %s" % id
		var img := car.image(n)
		if img == null:
			return car.last_error
		var rel := sprite_file(id)
		DirAccess.make_dir_recursive_absolute(sprites_dir.path_join(rel.get_base_dir()))
		img.save_png(sprites_dir.path_join(rel))
		frames[id] = img
		var w: int = car.cels[n]["w"]
		var h: int = car.cels[n]["h"]
		sprites[id] = {"file": rel, "w": w, "h": h, "pivot_x": RFPyCompat.round_digits(w / 2.0, 1),
				"pivot_y": RFPyCompat.round_digits(h / 2.0, 1), "pivot_source": "default_center",
				"kind": "sprite" if k == "sprite" else "effect"}
		if int(car.cels[n]["pre0"]) == 5:
			# document 9 / FUN_00424420's "brighten" translation table: 32 levels, +3 per level on every RGB
			# channel, clamped at 255 (tools/rf_effect_cel.py's own docstring already has the exact formula).
			# A generic engine blend (issue #64) reads this off the sprite, not a hardcoded engine constant,
			# so a different pack's own masks can use a different step or none at all.
			sprites[id]["recolour_mode"] = "brighten_add"
			sprites[id]["recolour_step"] = 3.0 / 255.0
		if n % 100 == 0 and progress.is_valid():
			progress.call(float(n) / car.count, "sprites: %d of %d" % [n, car.count])
	_write("sprites/sprites.json", {"atlas_pages": [], "sprites": sprites})

	var tileset := {}
	for art_id in 112:
		if art_id >= car.count:
			continue
		var id := rid(art_id)
		tileset[str(art_id)] = {"sprite_id": id, "terrain_class": terrain_class_for(id)}
	for side in 2:   # the home pads, 90 tan / 91 green (documents 77, 80)
		var art_id: int = [90, 91][side]
		if tileset.has(str(art_id)):
			tileset[str(art_id)]["side"] = side
			_pair(90, 91)
	if tileset.has(str(HOME_PAD_HOLE_ART)):
		tileset[str(HOME_PAD_HOLE_ART)]["hole"] = true
	# FUN_00408d60 draws every cell outside the map with tile record 2 (DAT_0044964c + 0x88, water_open.02); the margin is a port choice
	_write("terrain/tileset.json", {"tile_size_px": 32, "tiles": tileset, "off_map": OFF_MAP})
	counts["sprites"] = sprites.size()
	counts["tiles"] = tileset.size()
	return ""


## Coastal decorations (documents 35, 44) and coastal damage (document 44).
func decorations() -> void:
	var deco: Variant = data("coastal_decorations.json")
	if deco is Dictionary:
		var coastal: Dictionary = deco["decorations"]
		var corner_doc: Dictionary = {}
		var cd: Variant = data("coastal_decoration_corners.json")
		if cd is Dictionary:
			corner_doc = cd["decorations"]
		var ids := {}
		for k in coastal:
			ids[k] = true
		for k in corner_doc:
			ids[k] = true
		var order := ids.keys()
		order.sort_custom(func(a, b): return int(a) < int(b))
		var types := {}
		for coastal_id in order:
			var resolved := []
			if corner_doc.has(coastal_id):
				for part in corner_doc[coastal_id]:
					var cel := int(part["cel"])
					if not has_cel(cel):
						continue
					var entry := {"sprite_id": rid(cel), "flags": part["flags"], "corners": part["corners"],
							"offset": part["offset"], "zoff": part.get("zoff", 0.0), "jitter": part.get("jitter", false)}
					if int(part["flags"]) & 8:
						var v := []
						for i in 4:
							v.append(rid(cel + i) if has_cel(cel + i) else null)
						entry["variant_sprite_ids"] = v
						_pair(cel, cel + 1)
					resolved.append(entry)
			else:
				for part in coastal.get(coastal_id, []):
					var cel := int(part["cel"])
					if has_cel(cel):
						resolved.append({"sprite_id": rid(cel), "flags": part["flags"]})
			if not resolved.is_empty():
				types[coastal_id] = resolved
		_write("terrain/decorations.json", {"decoration_types": types})
		counts["decorations"] = types.size()
	var damage: Variant = data("coastal_damage.json")
	if damage is Dictionary:
		_write("terrain/coastal_damage.json", {"coastal": damage["coastal"]})


func manifest() -> void:
	_write("pack.json", {
		"id": PACK_ID, "name": "Return Fire (1996) -- Original PC Port Assets", "title": "Return Fire",
		"version": "0.1.0", "engine_api_version": "0.1.0",
		"author": "Silent Software (original assets); pack structure generated by returnfire-godot",
		"license": "Requires the user's own legally owned copy of Return Fire -- not for redistribution. See docs/PORTING_PLAN.md section 0.",
		"base_pack": null, "overrides": [], "pixels_per_world_unit": PIXELS_PER_WORLD_UNIT,
		"team_colours": {"team_a": "tan", "team_b": "green"}})


func _sids(cel: int, n: int) -> Array:
	var out := []
	for v in n:
		out.append(rid(cel + v))
	return out


## build_pack.build_render(): a vehicle's render descriptor (PORTING_PLAN.md 2.7.2 / 2.7.6 step 5).
func _build_render(index: int, t: Dictionary) -> Variant:
	var parts := []
	for rec in t["parts"]:
		var flags := int(rec["flags"])
		parts.append({"cel": rec["cel"], "flags": rec["flags"], "corner_idx": rec["corner_idx"], "corners": rec["corners"],
				"sprite_ids": _sids(int(rec["cel"]), 3 if flags & 8 else 1)})
		if flags & 8:
			_pair(int(rec["cel"]), int(rec["cel"]) + 1)
	var render := {"parts": parts}
	if index == 0:
		var hull := []
		for p in parts.slice(0, 6):
			hull.append(int(p["cel"]))
		if hull != [167, 172, 182, 182, 187, 187]:
			return "unexpected Tank hull"
		var turret: Dictionary = data("tank_turret_parts.json")
		var tip: Dictionary = data("tank_turret_tip_linkage.json")["raw_fixed16_16"]
		var f := func(v: Array) -> Array: return v.map(func(c): return float(c) / 65536)
		parts.resize(6)
		for rec in turret["parts"]:
			var flags := String(rec["flags"]).hex_to_int()
			var p := {"cel": rec["cel"], "flags": flags, "corner_idx": rec["corner_idx"], "group": "turret",
					"sprite_ids": _sids(int(rec["cel"]), 3), "corners": (rec["corners_fixed16_16"] as Array).map(f)}
			if flags & 8:
				_pair(int(rec["cel"]), int(rec["cel"]) + 1)
			var ci: Array = p["corner_idx"]
			for k in ci.size():
				var idx := int(ci[k])
				if idx >= 15 and idx <= 21:
					p["corners"][k] = {"rig": "tip", "point": idx - 15}
			parts.append(p)
		render["rigs"] = {"tip": {"channel": "gun_elev_deg", "rotate": {"axis": "x", "scale": -1.0},
				"base": (tip["base"] as Array).map(f), "offset": f.call(tip["offset"][0]),
				"_source": "FUN_00402dc0: FUN_00409b10 / FUN_00410c60 over the tables 0x43e640 (base) and 0x43e40c (offset), documents 40, 64"}}
		render["groups"] = {"turret": {"rotate": [{"axis": "y", "channel": "turret_deg", "scale": -1.0}]}}
	elif index == 1:
		var rows: Array = t["swim"]["rows"]
		var wheel := []
		for i in 4:
			wheel.append(rid(457 + i))
		for ks in [[9, -1.0], [10, 1.0]]:
			var k: int = ks[0]
			if int(parts[k]["cel"]) != 457:
				return "unexpected Jeep wheel part"
			parts[k]["sprites_by"] = {"channel": "position_x", "wrap": 4, "sprites": wheel}
			var sets := []
			for r in rows:
				var a: float = r[0]
				var c: float = r[1]
				var d: float = r[2]
				var fz: float = r[3]
				if ks[1] < 0:
					sets.append([[-a, -12.0, c], [-a, 12.0, c], [-d, 12.0, fz], [-d, -12.0, fz]])
				else:
					sets.append([[a, 12.0, c], [a, -12.0, c], [d, -12.0, fz], [d, 12.0, fz]])
			parts[k]["corners_by"] = {"channel": "swim_amount", "scale": 8.0, "eps": 0.0001, "max": rows.size() - 1, "sets": sets}
		var h: float = t["swim"]["ring_half"]
		var ring := int(t["swim"]["ring_cel"])
		parts.append({"cel": t["swim"]["ring_cel"], "flags": 0, "sprite_ids": [rid(ring)],
				"corners": [[h, -h, 0.0], [h, h, 0.0], [-h, h, 0.0], [-h, -h, 0.0]],
				"visible": {"channel": "swim_amount", "scale": 8.0, "eps": 0.0001, "min": 4},
				"scale_by": {"channel": "swim_amount", "min": 0.25}})
	elif index == 2:
		var rack: Dictionary = t["rack"]
		render["rigs"] = {"rack": {"channel": "gun_elev_deg", "rotate": {"axis": "x", "scale": -1.0}, "base": rack["base"],
				"offset": rack["offset"],
				"adjust": [{"points": [4, 5], "axis": 1, "set": -6.0, "add_channel": "salvo_reload_remaining", "add_scale": 0.15}],
				"_source": "FUN_00402ec0, tables 0x43ed30 / 0x43ed9c, documents 59, 64"}}
		for p in parts:
			if int(p["corner_idx"][0]) >= 44:
				p["corners"] = (p["corner_idx"] as Array).map(func(i): return {"rig": "rack", "point": int(i) - 44})
		if int(parts[13]["cel"]) != 324 or (parts[2]["corner_idx"] as Array).map(func(i): return int(i)) != [44, 45, 46, 47]:
			return "unexpected MSV rack"
		parts[13]["sprites_by"] = {"channel": "salvo_index", "sprites": [rid(326), rid(325), rid(324)]}
	elif index == 3:
		var rot: Dictionary = data("heli_rotor.json")
		var n: float = rot["bar_length"]
		var y: float = rot["height"]
		var bar_b := func(w: float) -> Array: return [[w, 0.0, y], [w, -n, y], [-w, -n, y], [-w, 0.0, y]]
		var bar_a := func(w: float) -> Array: return [[w, n, y], [w, 0.0, y], [-w, 0.0, y], [-w, n, y]]
		for cb in [[int(rot["blade_b_cel"]), bar_b], [int(rot["blade_a_cel"]), bar_a]]:
			var cel: int = cb[0]
			var bar: Callable = cb[1]
			_pair(cel, cel + 1)
			var sets := []
			for w in rot["half_widths"]:
				sets.append(bar.call(float(w)))
			parts.append({"cel": cel, "flags": 8, "sprite_ids": _sids(cel, 2), "group": "rotor", "corners": bar.call(float(rot["half_widths"][3])),
					"corners_by": {"channel": "rotor_mode", "max": 3, "sets": sets}, "visible": {"channel": "rotor_mode", "max": 3}})
		for grp in ["rotor", "rotor_fold"]:
			parts.append({"cel": rot["folded_cel"], "flags": 0, "sprite_ids": _sids(int(rot["folded_cel"]), 1), "group": grp,
					"corners": rot["folded_corners"], "visible": {"channel": "rotor_mode", "min": 4}})
		render["groups"] = {
			"rotor": {"rotate": [{"axis": "y", "channel": "rotor_speed_steps", "rate": rot["steps_deg"], "scale": -1.0}]},
			"rotor_fold": {"parent": "rotor", "rotate": [{"axis": "y", "channel": "heli_spinup_progress", "scale": -float(rot["unfold_degrees"])}]}}
		render["body"] = {"rotate": [{"axis": "x", "channel": "pitch_deg", "scale": -1.0}, {"axis": "z", "channel": "bank_deg", "scale": 1.0}]}
	_water_overlay_parts(index, render, parts)
	for p in parts:
		p.erase("corner_idx")
	return render


## build_pack.water_overlay_parts(): what the original draws while a vehicle wades or sinks (document 122, issue #25; tools/data/water_overlays.json).
func _water_overlay_parts(index: int, render: Dictionary, parts: Array) -> void:
	var d: Dictionary = data("water_overlays.json")
	if not (d["types"] as Dictionary).has(str(index)):
		return
	var t: Dictionary = d["types"][str(index)]
	var w: Dictionary = t["wading"]
	parts.append({"cel": w["cel"], "flags": 0, "corners": w["corners"], "modes": [1], "sprite_ids": [rid(int(w["cel"]))],
			"sprites_by": {"channel": "wade_frame", "max": int(w["frames"]) - 1, "sprites": _sids(int(w["cel"]), int(w["frames"]))}})
	for sw in t.get("swim_wading", []):
		parts.append({"cel": sw["cel"], "flags": 0, "corners": sw["corners"], "modes": [3], "sprite_ids": [rid(int(sw["cel"]))],
				"sprites_by": {"channel": "wade_swim_frame", "max": int(sw["frames"]) - 1, "sprites": _sids(int(sw["cel"]), int(sw["frames"]))}})
	var depth := int(t["sink_depth"])
	for sk in t["sinking"]:
		parts.append({"cel": sk["cel"], "flags": 0, "corners": sk["corners"], "modes": [2], "sprite_ids": [rid(int(sk["cel"]))],
				"sprites_by": {"channel": "sink_frame", "sprites": _sids(int(sk["cel"]), 2 * depth), "team_stride": depth, "hide_outside": depth}})
	var r: Dictionary = d["ripple"]
	var top := 0
	for fr in r["frames"]:
		top = maxi(top, int(fr))
	parts.append({"cel": r["cel"], "flags": 0, "corners": r["corners"], "modes": [2], "sprite_ids": [rid(int(r["cel"]))],
			"sprites_by": {"channel": "ripple_frame", "max": top, "sprites": _sids(int(r["cel"]), top + 1)}})
	render["mode_channel"] = "water_view"
	render["replaced_in"] = [2]
	render["ripple"] = {"frames": r["frames"], "clock_mask": r["clock_mask"]}


## A vehicle type's ground shadow (the Heli's; tools/data/vehicle_shadow.json, issue #26), or {} for a type without one.
func _shadow_entry(d: Dictionary, index: int) -> Dictionary:
	if not d["types"].has(str(index)):
		return {}
	var out: Dictionary = (d["types"][str(index)] as Dictionary).duplicate(true)
	out["body"]["sprite"] = rid(int(out["body"]["cel"]))
	out["body"].erase("cel")
	var ids := []
	for c in out["rotor"]["cels"]:
		ids.append(rid(int(c)))
	out["rotor"]["sprites"] = ids
	out["rotor"].erase("cels")
	return {"shadow": out}


## A vehicle type's `wreck` table: the decal quads below plus the Destroyed Vehicle object's numbers (tools/data/wreck.json; issue #29).
static func _wreck_table(quads: Dictionary, d: Dictionary, index: int) -> Dictionary:
	var t := quads.duplicate()
	t.merge(d["shared"], true)
	t.merge(d["types"][str(index)], true)
	return t


## The wreck drawn when a vehicle dies (document 87).
static func _wrecks() -> Dictionary:
	var small := [{"sprites": ["effect.shadow.hard.wreck_small"], "height": 0.4, "half": [13.5, 13.5], "center": [0, 0], "shadow": true},
		{"sprites": ["vehicle.wreck.small.a.tan", "vehicle.wreck.small.a.green"], "height": 0.6, "half": [12, 12], "center": [0, 0]},
		{"sprites": ["vehicle.wreck.small.b.tan", "vehicle.wreck.small.b.green"], "height": 2.6, "half": [12, 12], "center": [0, 0]}]
	return {
		0: {"descriptor": "0x43ece8", "quads": small},
		1: {"descriptor": "0x440218", "quads": small},
		2: {"descriptor": "0x43f628", "quads": [
			{"sprites": ["effect.shadow.hard.wreck_large"], "height": 0.4, "half": [13.5, 13.5], "center": [0, 0], "shadow": true},
			{"sprites": ["vehicle.wreck.large.a.tan", "vehicle.wreck.large.a.green"], "height": 0.6, "half": [12, 12], "center": [0, 0]},
			{"sprites": ["vehicle.wreck.large.b.tan", "vehicle.wreck.large.b.green"], "height": 2.6, "half": [12, 12], "center": [0, 0]}]},
		3: {"descriptor": "0x440fa0", "quads": [
			{"sprites": ["vehicle.wreck.heli.tan", "vehicle.wreck.heli.green"], "height": 0.4, "half": [13.6, 27.2], "center": [0, 13.6]}]}}


## The behaviour modules each original vehicle's record handlers became (PORTING_PLAN.md 2.7.2 step 4).
static func _behaviour() -> Dictionary:
	return {
		0: {"drive": {"model": "ground"}, "aim": {"model": "gun_mount", "params": {"turret": true}},
			"slots": [{"handler": "cannon"}], "water": {"model": "hull_water"}},
		1: {"drive": {"model": "ground", "params": {"turn_accelerates": true, "road_follow": true}}, "aim": {"model": "none"},
			"slots": [{"handler": "lobbed_missile"}], "water": {"model": "hull_water", "params": {"can_swim": true}},
			"terrain": {"blocked_by_bushes": true, "blocked_by_rocks": true}, "flags": {"carries_flag": true}},
		2: {"drive": {"model": "ground"}, "aim": {"model": "gun_mount", "params": {"turret": false}},
			"slots": [{"handler": "rocket_salvo"}, {"handler": "mine_layer"}], "water": {"model": "hull_water"}},
		# only the Heli's drive function (FUN_0040e0e0) calls the creator of the map-edge guard (FUN_00434e80; document 112)
		3: {"drive": {"model": "rotor"}, "aim": {"model": "none"}, "slots": [{"handler": "heli_guns"}], "water": {"model": "none"},
			"flags": {"carries_flag": false, "triggers_edge_guard": true}}}


## Vehicle types (document 57) -> one definition per vehicle (build_pack.emit_vehicle_definitions) + roster.json.
## `sound`: the converted SOUND/*.SDT files, upper-case "NAME.WAV" -> bytes (matched without regard to case, as the
## Python pipeline's file lookups are on Windows).
func vehicles(sound: Dictionary) -> String:
	var vtd: Variant = data("vehicle_types.json")
	if not (vtd is Dictionary):
		return ""
	var vt: Dictionary = vtd["types"]
	for t in vt.values():
		if t.has("swim"):
			t["swim"]["ring_sprite"] = rid(int(t["swim"]["ring_cel"]))
		for part in t["parts"]:
			var flags := int(part["flags"])
			part["sprite_ids"] = _sids(int(part["cel"]), 3 if flags & 8 else 1)
			if flags & 8:
				_pair(int(part["cel"]), int(part["cel"]) + 1)
	var loops_doc: Variant = data("engine_loops.json")
	if not (loops_doc is Dictionary):
		loops_doc = {"loops": {}, "by_vehicle_type": []}
	var loop_by_descriptor := {}
	for k in loops_doc["loops"]:
		loop_by_descriptor[loops_doc["loops"][k]["descriptor"]] = k
	var behaviour := _behaviour()
	var wrecks := _wrecks()
	var wreck_data: Dictionary = data("wreck.json")
	var shadow_data: Dictionary = data("vehicle_shadow.json")
	var definitions := []
	var roster := []
	for entry in ORIGINAL_ROSTER:
		var vid: String = entry[0]
		var index: int = entry[1]
		var t: Dictionary = vt[str(index)]
		var created: Variant = t.get("created_sound")
		var on_create := {"sound": created["cue"], "descriptor": created["descriptor"]} if created else {"sound": null}
		if created and created["cue"] == null:
			if loop_by_descriptor.has(created["descriptor"]):
				on_create["loop"] = loop_by_descriptor[created["descriptor"]]
			else:
				on_create["_untraced"] = "descriptor %s is not one of the traced sound cues (NEXT_STEPS)" % created["descriptor"]
		var by_type: Array = loops_doc["by_vehicle_type"]
		var loop_key: Variant = by_type[index] if index < by_type.size() else null
		var sounds := {}
		if loop_key:
			var loop: Dictionary = {"id": loop_key}
			loop.merge(loops_doc["loops"][loop_key])
			sounds["engine_loop"] = loop
		var render: Variant = _build_render(index, t)
		if render is String:
			return render
		var picture_cel := 2094 + index * 2
		_pair(picture_cel, picture_cel + 1)
		var b: Dictionary = behaviour[index]
		var drive := {}
		for k in ["max_forward_per_tick", "max_reverse_per_tick", "accel_per_tick2", "friction_per_tick2", "turn_steps_per_tick"]:
			drive[k] = t[k]
		drive.merge(b["drive"], true)
		definitions.append([vid, {
			"id": vid, "name": t["name"], "original_index": index,
			"_source": "RFIRE.BIN vehicle-type record 0x%x (0x4456b8 + %d * 0x2e8), document 57 and on" % [0x4456B8 + index * 0x2E8, index],
			"stats": {"hit_points": t["hit_points"], "armor": t["armor"], "fuel": t["fuel"], "sink_depth": t["sink_depth"],
				"dock_tolerance": t["dock_tolerance"], "death_wait_ticks": t["death_wait_ticks"]},
			"drive": drive, "aim": b["aim"],
			"weapons": {"ammo": t["ammo"], "cooldown_ticks": t["weapon_cooldown_ticks"], "slots": b["slots"]},
			"water": b["water"],
			"terrain": b.get("terrain", {"blocked_by_bushes": false, "blocked_by_rocks": false}),
			"flags": b.get("flags", {"carries_flag": false}),
			"shape": t["shape"], "events": {"on_create": on_create}, "sounds": sounds,
			"camera": {"swoop_height": t.get("camera_swoop_height")},
			"music": {"theme_line": t.get("music_theme_line"), "priority": t.get("music_priority"),
				"death_line": t.get("music_death_line"), "theme_rule": MUSIC_THEME_RULE.get(index, "record_line")},
			"selector": {"script": entry[4], "picture": [rid(picture_cel), rid(picture_cel + 1)]},
			"render": render, "wreck": _wreck_table(wrecks[index], wreck_data, index),
			"_record": {"stats.hit_points": "+0x28", "stats.armor": "+0x24", "stats.fuel": "+0x210",
				"stats.sink_depth": "+0x158", "stats.dock_tolerance": "+0x254", "stats.death_wait_ticks": "+0x260",
				"drive": "+0x168..+0x178", "weapons.ammo": "+0x1a8 / +0x1dc", "weapons.cooldown_ticks": "+0x1a4 / +0x1d8",
				"events.on_create": "+0x240", "camera.swoop_height": "table 0x4452c0", "render": "+0x148 (draw descriptor)"}}])
		definitions.back()[1].merge(_shadow_entry(shadow_data, index))
		roster.append({"id": vid, "stock_key": entry[2], "default_stock": entry[3]})
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("audio"))
	for l in loops_doc["loops"].values():
		if sound.has(String(l["wav"]).to_upper()):
			_store(out_dir.path_join("audio").path_join(l["wav"]), sound[String(l["wav"]).to_upper()])
	for d in definitions:
		_write("vehicles/%s/vehicle.json" % d[0], d[1])
	_write("vehicles/roster.json", {"vehicles": roster})
	return ""


static func _store(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## Projectiles (46, 58), the flag (65), the skull (88), the mine (60), the Jeep missile (61), the palette (20).
func small_tables() -> void:
	var pj: Variant = data("projectile_types.json")
	if pj is Dictionary:
		for parts in pj["descriptors"].values():
			for part in parts:
				var flags := int(part["flags"])
				part["sprite_ids"] = _sids(int(part["cel"]), 2 if flags & 8 else 1)
				if flags & 8:
					_pair(int(part["cel"]), int(part["cel"]) + 1)
		# each type's launch sound (FUN_004148f0 plays record +0x18 on the new projectile; document 117) as a cue id
		var by_addr := {}
		var cue_doc: Variant = data("sound_cues.json")
		if cue_doc is Dictionary:
			for cid in cue_doc["cues"]:
				by_addr[String(cue_doc["cues"][cid]["addr"])] = cid
		for t in pj["types"]:
			if by_addr.has(String(t.get("sound_descriptor", ""))):
				t["sound"] = by_addr[String(t["sound_descriptor"])]
		var guard: Variant = data("edge_guard.json")
		if guard is Dictionary:
			# the guard's rocket is the one homing type (FUN_00415100): its numbers ride on that projectile type's row
			var hom: Dictionary = (guard["homing"] as Dictionary).duplicate()
			var htype := int(hom["projectile"])
			hom.erase("projectile")
			pj["types"][htype]["homing"] = hom
		_write("vehicles/projectile_types.json", {"types": pj["types"], "descriptors": pj["descriptors"],
				"art": {"shell": rid(PROJECTILE_ART["shell"]), "shadow": rid(PROJECTILE_ART["shadow"])}})
		if guard is Dictionary:
			_write("world/edge_guard.json", _edge_guard_table(guard))
	var inf: Variant = data("infantry.json")
	if inf is Dictionary:
		_write("world/infantry.json", _infantry_table(inf))
	var deb: Variant = data("debris.json")
	if deb is Dictionary:
		# The flying wreckage (FWall pieces; document 119, issue #81): records, op lists, table rows, and the burn-out frames' sprite ids.
		var dt: Dictionary = deb.duplicate(true)
		dt.erase("_source")
		for k in dt["records"]:
			var fr: Variant = dt["records"][k].get("frames")
			if fr is Dictionary:
				fr["sprites"] = _sids(int(fr["cel_first"]), int(fr["count"]))
		_write("world/debris.json", dt)
	var fl: Variant = data("flag.json")
	if fl is Dictionary:
		for group in ["ground", "carried"]:
			for part in fl[group].values():
				var cel := int(part["cel"])
				var n := 1 if cel == 1881 else 26
				part["sprite_ids"] = _sids(cel, n)
				if n == 26:
					for i in 13:
						_pair(cel + i, cel + 13 + i)
		_write("markers/flag.json", fl)
	var skull := []
	for f in range(1, 8):
		skull.append([rid(2125 + f), rid(2125 + f + 7)])
		_pair(2125 + f, 2125 + f + 7)
	_write("ui/death_skull.json", {"frames": skull})
	_write("effects/mine.json", {"sprites": _sids(1081, 3)})
	var missile := []
	for f in 12:
		missile.append([rid(1779 + f), rid(1779 + f + 12)])
		_pair(1779 + f, 1779 + f + 12)
	_write("projectiles/jeep_missile.json", {"frames": missile})
	_write("sprites/palette.json", {"_source": "ART.CAR shared PLUT at 0x282CC, offset to slot 10 (document 20)", "rgb": car.runtime_palette()})


## The radar (69), the HUD panels (70, 74, 103, 108), the vehicle-choice screen (78).
func hud() -> void:
	var runtime := car.runtime_palette()
	var rd: Variant = data("radar.json")
	if rd is Dictionary:
		var used := {int(rd["land"]): true, int(rd["water"]): true, int(rd["flagged_tile"]): true}
		for c in rd["flag_blip"]["colours"]:
			used[int(c)] = true
		for v in rd["coastal_colours"].values():
			for c in v:
				used[int(c)] = true
		var rgb := {}
		for k in used:
			rgb[str(k)] = runtime[k]
		rd["rgb"] = rgb
		if rd.has("ping"):
			rd["ping"]["sprite_ids"] = (rd["ping"]["cels"] as Array).map(func(c): return rid(int(c)))
		_write("hud/radar.json", rd)
	var hp: Variant = data("hud_panels.json")
	if hp is Dictionary:
		for pn in hp["panels"].values():
			pn["sprite_id"] = rid(int(pn["base_cel"]))
			var s9: Dictionary = pn.get("slot9", {})
			if s9.has("grid_cel"):
				s9["grid_sprite_id"] = rid(absi(int(s9["grid_cel"])))
				s9["grid_is_negative"] = int(s9["grid_cel"]) < 0
			if s9.has("cursor"):
				s9["cursor"]["sprite_id"] = rid(int(s9["cursor"]["cel"]))
		var nearest := func(word: int) -> Array:   # document 74: the game's 15-bit -> palette conversion (0xf8 masks)
			var r := (word >> 7) & 0xF8
			var g := (word >> 2) & 0xF8
			var bl := (word << 3) & 0xF8
			var best: Array = runtime[0]
			var best_d := 1 << 30
			for c in runtime:
				var d := (int(c[0]) - r) ** 2 + (int(c[1]) - g) ** 2 + (int(c[2]) - bl) ** 2
				if d < best_d:
					best_d = d
					best = c
			return best
		var fuel := {}
		for k in hp["fuel_colour_words"]:
			fuel[k] = nearest.call(int(hp["fuel_colour_words"][k]))
		var ammo := {}
		for k in hp["ammo_colour_words"]:
			ammo[k] = nearest.call(int(hp["ammo_colour_words"][k]))
		hp["fuel_rgb"] = fuel
		hp["ammo_rgb"] = ammo
		hp["select"]["icon_ids"] = (hp["select"]["icon_cels"] as Array).map(func(c): return rid(int(c)))
		hp["select"]["digit_ids"] = _sids(int(hp["select"]["digit_base_cel"]), 10)
		hp["pips"]["sprite_id"] = rid(int(hp["pips"]["cel"]))
		for k in ["flag_cel", "home_cel"]:
			hp["compass"][k.replace("_cel", "_sprite_id")] = rid(int(hp["compass"][k]))
		if hp.has("weapon_select"):
			var ids := {}
			for k in hp["weapon_select"]["cels"]:
				ids[k] = rid(int(hp["weapon_select"]["cels"][k]))
			hp["weapon_select"]["sprite_ids"] = ids
		hp["frame_sprite_id"] = rid(HUD_PANEL_FRAME_CEL)
		_write("hud/panels.json", hp)
	var sel: Variant = data("selector.json")
	if sel is Dictionary:
		var cels: Dictionary = sel["cels"]
		var r := func(c) -> String: return rid(int(c)) if int(c) != 0 else ""
		var base := int(cels["picture_base"])
		for t in 4:
			_pair(base + t * 2, base + t * 2 + 1)
		var s := {}
		for k in ["box", "highlight", "platform_cap", "platform_body", "strip_centre", "map_frame", "radar", "panel_frame", "panel_interior"]:
			s[k] = r.call(cels[k])
		s["hangar"] = r.call(sel["hangar"]["cel"])
		s["pictures"] = range(4).map(func(t): return [r.call(base + t * 2), r.call(base + t * 2 + 1)])
		s["pointer"] = range(3).map(func(i): return r.call(int(cels["pointer"]) + i))
		s["strip"] = range(2).map(func(i): return r.call(int(cels["strip"][0]) + i))
		s["cloud"] = range(3).map(func(i): return r.call(int(cels["cloud"]) + i))
		s["dirt"] = range(4).map(func(i): return r.call(int(cels["dirt"]) + i))
		s["digits"] = range(10).map(func(i): return r.call(int(cels["digit_base"]) + i))
		s["icon"] = (cels["icon"] as Array).map(func(c): return r.call(c))
		s["weapon_icon"] = (cels["weapon_icon"] as Array).map(func(c): return r.call(c))
		s["second_icon"] = (cels["second_icon"] as Array).map(func(c): return r.call(c))
		sel["sprites"] = s
		_write("hud/selector.json", sel)


## The foot soldiers (documents 113 and 116, issue #74): world/infantry.json, with the sprite ids per team / facing / frame and the
## buildings that release soldiers, read from the coastal table's field [3] (`flags`): bits 16-19 min, 20-23 max, 0x8000 flips the team;
## only entries with at least 2 hit points qualify (the release is a hit that leaves exactly 1).
func _infantry_table(inf: Dictionary) -> Dictionary:
	var t := inf.duplicate(true)
	for k in ["_source", "cel_first", "dir_stride", "frame_count", "team_offset", "shadow_cel"]:
		t.erase(k)
	var sets := {}
	for team_name in ["tan", "green"]:
		var shift := 0 if team_name == "tan" else int(inf["team_offset"])
		var dirs := []
		for d in 5:
			dirs.append(_sids(int(inf["cel_first"]) + d * int(inf["dir_stride"]) + shift, int(inf["frame_count"])))
		sets[team_name] = dirs
	t["sprites"] = sets
	var w: Dictionary = inf["wade"]
	t["wade"] = {"frame_first": w["frame_first"], "quad": w["quad"]}
	t["corpse"] = {"lifetime": inf["corpse"]["lifetime"], "quad": inf["corpse"]["quad"]}
	var wade_sprites := {}
	for team_name in ["tan", "green"]:
		var wshift := 0 if team_name == "tan" else int(w["team_offset"])
		wade_sprites[team_name] = _sids(int(w["cel_first"]) + wshift + int(w["frame_first"]), int(w["frame_count"]))
	t["wade_sprites"] = wade_sprites
	t["corpse_sprites"] = _sids(int(inf["corpse"]["cel_first"]), int(inf["corpse"]["variants"]))
	t["shadow_sprite"] = rid(int(inf["shadow_cel"]))
	var buildings := {}
	var damage: Variant = data("coastal_damage.json")
	if damage is Dictionary:
		for cid in damage["coastal"]:
			var entry: Dictionary = damage["coastal"][cid]
			var flags := int(entry["flags"])
			var lo := (flags >> 16) & 0xF
			var hi := (flags >> 20) & 0xF
			if int(entry["hp"]) >= 2 and (flags & 0xFF8000) != 0 and hi - lo >= 1:
				buildings[cid] = {"min": lo, "max": hi, "flip_team": (flags & 0x8000) != 0}
	t["buildings"] = buildings
	return t


## The map-edge guard (the submarine; document 112) with its frames as sprite ids: world/edge_guard.json.
func _edge_guard_table(guard: Dictionary) -> Dictionary:
	var t := guard.duplicate(true)
	t.erase("homing")
	t.erase("_source")
	t["frames"] = _sids(int(t["cel_first"]), int(t["cel_count"]))
	t.erase("cel_first")
	t.erase("cel_count")
	return t


## The home pad's mechanism art (document 89) as sprite ids: terrain/home_pad.json.
func home_pad() -> void:
	var w: Dictionary = HOME_PAD["pit_walls"]
	_write("terrain/home_pad.json", {
		"pit_walls": {"north": rid(w["north"]), "west": rid(w["west"]), "east": rid(w["east"]), "south": rid(w["south"])},
		"hazard_strip": rid(HOME_PAD["hazard_strip"]), "lift_plate": _sids(HOME_PAD["lift_plate"], 2),
		"leaves": {"left": _sids(HOME_PAD["leaves"]["left"], 2), "right": _sids(HOME_PAD["leaves"]["right"], 2)},
		"dock_ready_glow": rid(HOME_PAD["dock_ready_glow"])})


## Water (62), gates (56), sound cues (82, 100), collision shapes (53), explosions (50, 51).
func world_tables(sound: Dictionary) -> void:
	var water: Variant = data("water_tables.json")
	if water != null:
		_write("terrain/water.json", water)
	var gd: Variant = data("gates.json")
	if gd is Dictionary:
		var gj: Dictionary = gd["gates"]
		for g in gj.values():
			for d in g["descs"]:
				for part in d["parts"]:
					var flags := int(part["flags"])
					part["sprite_ids"] = _sids(int(part["cel"]), 2 if flags & 8 else 1)
					if flags & 8:
						_pair(int(part["cel"]), int(part["cel"]) + 1)
				d["sprite_open"] = rid(int(d["cel_open"]))
				d["sprite_closed"] = rid(int(d["cel_closed"]))
		_write("terrain/gates.json", {"gates": gj})
	var cues: Variant = data("sound_cues.json")
	if cues is Dictionary and not sound.is_empty():
		var audio := {}
		var copied := {}
		for cue_id in cues["cues"]:
			var cue: Dictionary = cues["cues"][cue_id]
			var wav := String(cue["wav"])
			if not sound.has(wav.to_upper()):
				continue
			if not copied.has(wav):
				_store(out_dir.path_join("audio").path_join(wav), sound[wav.to_upper()])
				copied[wav] = true
			audio[cue_id] = {"file": wav, "category": "sfx", "priority": cue.get("priority", {}).get("start", 0),
					"priority_later": cue.get("priority", {}).get("later", 0), "priority_ticks": cue.get("priority", {}).get("ticks", 0),
					"flags": cue.get("flags", 0), "level": cue.get("level", 0x10000), "pitch": cue.get("pitch", 0)}
		_write("audio/audio.json", audio)
		counts["audio"] = audio.size()
	var cs: Variant = data("coastal_shapes.json")
	if cs != null:
		_write("terrain/coastal_shapes.json", cs)
	var ex: Variant = data("explosion_records.json")
	if ex is Dictionary:
		var records := {}
		var by_coastal := {}
		var by_crush := {}
		for addr in ex["records"]:
			var r: Dictionary = ex["records"][addr]
			var parts := []
			for part in r["parts"]:
				var fr := []
				for k in int(part["end"]) - int(part["start"]) + 1:
					var e: Variant = registry.get(str(int(part["cel"]) + k))
					fr.append(String(e["id"]) if e else "")
				parts.append({"start": part["start"], "end": part["end"], "fade": part["fade"],
						"variant_mode": part["variant_mode"], "corners": part["corners"], "frames": fr})
			records[addr] = {"duration": r["duration"], "rate_per_tick": r["rate_per_tick"], "scale": r["scale"],
					"parts": parts, "script": r["script"]}
			for cid in r["coastal_destroy_effect_ids"]:
				by_coastal[str(int(cid))] = addr
			for cid in r["coastal_field10_ids"]:
				by_crush[str(int(cid))] = addr
		_write("effects/explosions.json", {"records": records, "coastal_destroy_effect": by_coastal,
				"coastal_crush_effect": by_crush, "impact_tables": ex["impact_tables"]})


## levels/<name>/: level.json + art.bin from the decoded .RFM files ({stem: {meta, art}}).
func levels(decoded: Dictionary) -> void:
	for stem in decoded:
		# insertion order, not PackWriter's sorted keys: readers may peek "name" near the top without parsing the
		# whole file (the engine's MapViewPanel._peek_name), as they can in build_pack.py's copy of convert_rfm's output
		var path := out_dir.path_join("levels/%s/level.json" % stem)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(decoded[stem]["meta"], " ", false, true) + "
")
		_store(out_dir.path_join("levels/%s/art.bin" % stem), decoded[stem]["art"])
	counts["levels"] = decoded.size()


## build_pack.emit_team_colours(): every (tan, green) pair the traced data implies, checked to really be a recolour,
## to sprites/team_sets.json; the colours' measured HSV means and the port presets to teams/colours.json.
func team_colours() -> void:
	var by_id := {}
	for n in car.count:
		by_id[rid(n)] = n
	var pairs := {}
	var named := {}
	for p in team_pairs:
		if p.x < car.count and p.y < car.count and p.x >= 0 and p.y >= 0:
			pairs[[rid(p.x), rid(p.y)]] = true
	for sid in by_id:
		var segs := String(sid).split(".")
		if "tan" in segs:
			var other_segs := []
			for x in segs:
				other_segs.append("green" if x == "tan" else x)
			var other := ".".join(other_segs)
			if by_id.has(other):
				pairs[[sid, other]] = true
				named[sid] = true
	var order := pairs.keys()
	order.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var accepted := {}
	var rejected := {}
	var acc := {"tan": [0.0, 0.0, 0.0, 0.0, 0], "green": [0.0, 0.0, 0.0, 0.0, 0]}
	for pr in order:
		var tan_id: String = pr[0]
		var green_id: String = pr[1]
		if tan_id == green_id or accepted.has(tan_id):
			continue
		var a: Image = frames[tan_id]
		var b: Image = frames[green_id]
		if a.get_size() != b.get_size():
			rejected[tan_id] = "%s: size %s vs %s" % [green_id, RFPyCompat.tuple2(a.get_width(), a.get_height()), RFPyCompat.tuple2(b.get_width(), b.get_height())]
			continue
		var pa := a.get_data()
		var pb := b.get_data()
		var mapping := {}   # tan rgb -> {green rgb -> count}
		var footprint_diff := 0
		var changed := 0
		var opaque := 0
		for i in range(0, pa.size(), 4):
			var ta := pa[i + 3] == 0
			if pa[i + 3] != 0:
				opaque += 1
			if ta != (pb[i + 3] == 0):
				footprint_diff += 1
			elif pa[i + 3] != 0 and (pa[i] != pb[i] or pa[i + 1] != pb[i + 1] or pa[i + 2] != pb[i + 2] or pa[i + 3] != pb[i + 3]):
				changed += 1
				var ka := (pa[i] << 16) | (pa[i + 1] << 8) | pa[i + 2]
				var kb := (pb[i] << 16) | (pb[i + 1] << 8) | pb[i + 2]
				if not mapping.has(ka):
					mapping[ka] = {}
				mapping[ka][kb] = int(mapping[ka].get(kb, 0)) + 1
		var limit := (0.3 if named.has(tan_id) else 0.05) * opaque
		if opaque == 0 or footprint_diff > limit:
			rejected[tan_id] = "%s: footprints differ (%d of %d px)" % [green_id, footprint_diff, opaque]
			continue
		if changed == 0:
			rejected[tan_id] = "%s: identical, nothing team-coloured" % green_id
			continue
		var best_sum := 0
		for m in mapping.values():
			best_sum += (m.values() as Array).max()
		var consistency := float(best_sum) / changed
		if consistency < TEAM_PAIR_MIN_CONSISTENCY:
			rejected[tan_id] = "%s: not a recolour (consistency %.2f)" % [green_id, consistency]
			continue
		accepted[tan_id] = green_id
		for i in range(0, pa.size(), 4):
			if pa[i + 3] != 0 and pb[i + 3] != 0 and (pa[i] != pb[i] or pa[i + 1] != pb[i + 1] or pa[i + 2] != pb[i + 2] or pa[i + 3] != pb[i + 3]):
				for kp in [["tan", pa], ["green", pb]]:
					var px: PackedByteArray = kp[1]
					var hsv := RFPyCompat.rgb_to_hsv(px[i] / 255.0, px[i + 1] / 255.0, px[i + 2] / 255.0)
					var s: Array = acc[kp[0]]
					s[0] += cos(hsv.x * 2 * PI)
					s[1] += sin(hsv.x * 2 * PI)
					s[2] += hsv.y
					s[3] += hsv.z
					s[4] += 1
	var mean := func(key: String) -> Array:
		var s: Array = acc[key]
		var n := maxi(s[4], 1)
		return [RFPyCompat.round_digits(RFPyCompat.fmod_py(atan2(s[1], s[0]) / (2 * PI), 1.0), 4),
			RFPyCompat.round_digits(s[2] / n, 4), RFPyCompat.round_digits(s[3] / n, 4)]
	_write("sprites/team_sets.json", {"pairs": accepted, "rejected": rejected, "masks": {}})
	var colours := {"tan": {"source": "original", "variant": 0, "hsv": mean.call("tan")},
		"green": {"source": "original", "variant": 1, "hsv": mean.call("green")}}
	for name in TEAM_COLOUR_PRESETS:
		colours[name] = {"source": "port_preset", "hsv": TEAM_COLOUR_PRESETS[name]}
	_write("teams/colours.json", {"reference": "tan", "colours": colours})
	counts["team_pairs"] = accepted.size()
