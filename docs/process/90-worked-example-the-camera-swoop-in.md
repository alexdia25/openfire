# 90. Worked example: the camera swoop-in when a vehicle leaves the base

**Question:** document 89 found that `FUN_004161e0` / `FUN_00416300` are a camera rig and that the reference footage shows the game view opening on a tiny, distant pad that the camera swoops in on. What exactly does the camera do, and how long does it take? Scripts and
field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the camera struct and what the rig writes

The camera (view) struct is `0x48b4c0 + player * 0x24c` (this is the one of document 76 seen from a different base). `FUN_00416100(player, &pos, height, pitch)` (disassembled, `DisasmForce.java 0x416100 0x416160`):

```
00416122  MOV [ECX+0x12c],EAX   ; x     (also +0x10c)
00416131  MOV [ECX+0x130],EAX   ; y     (also +0x110)
0041613a  MOV [ECX+0x114],EAX   ; height = arg3        (also +0x134, the target)
0041614d  MOV [ECX+0x128],EDX   ; z of the followed object
00416153  MOV [ECX+0x144],EAX   ; pitch = arg4 (the target)
00416159  MOV [ECX+0x24],EAX    ; pitch = arg4         (the current value)
```

So the pair of fields `+0x114` / `+0x134` is *current / target height* and `+0x24` / `+0x144` *current / target pitch*. The camera constructor (`FUN_00416cb0`, decompiled) sets the defaults: current height 15.0, target height -170.0, pitch 32.0 (`0x200000`). The undock object's first handler
(`FUN_0042ee50`, document 89) calls `FUN_00416100(player, pos, 0xfa0000, 0x400000)`: **the camera snaps to height 250.0 and pitch 64.0**. Its second handler (`0x42eea0`) registers a camera rig with `FUN_004161e0(player, 0, obj, 0xa0000, 0x180000, table[0x4452c0 + type * 4], 0, NULL)`:
the same call the vehicle's own creation makes (`FUN_0040b1c0`, `0x40b23b`), i.e. the **normal** rig: **pitch target 24.0** (`0x180000`) and **height target from the per-type table at `0x4452c0`: Tank, Jeep, MSV -170.0 (`0xff560000`), Heli -100.0 (`0xff9c0000`)** (`DumpDwords.java 0x4452c0 8`).
The camera update (`FUN_00416fa0`) collects targets from the rig list (`FUN_00416300` copies a rig's height into `+0x134` and pitch into `+0x144` when unset) and then calls the easing function once for pitch and once for height:

```
0041701d  CALL 0x00417420   ; (cam, &cam+0x24  (pitch),  cam+0x144 (target), &cam+0x148 (rate), cam+0x154 (triple))
00417233  CALL 0x00417420   ; (cam, &cam+0x114 (height), cam+0x134 (target), &cam+0x140 (rate), cam+0x150 (triple))
```

## Step 2: the easing, `FUN_00417420`

Disassembled (`DisasmForce.java 0x417420 0x417500`) and translated; `FUN_0042cdd0` is the usual move-toward (`if a < b: a += step, clamp at b`), `FUN_00410e20` is a fixed-point square root (`FILD; FMUL 2^-16; FSQRT; FMUL 65536`, constants checked at `0x43d000`), `dt` (`0x480d2c`) is 1 per tick:

```
00417439  XOR EAX,[EBP+0x10] ; TEST EAX,0xffff0000 ; JNZ go     ; value ^ target: integer parts equal -> rate = 0, return 1
0041745a  ECX = target - value; direction = sign; ECX = |ECX|      ; the distance
00417473  EDI = triple[0] (accel);  EBX = triple[8] (max)          ; triple = {accel, brake, max}
0041747b  if (EBX != 0) { EAX = sqrt(distance * triple[4]);        ;   sqrt(dist * brake)
                          if (EBX > EAX) { EBX = EAX; EDI = triple[4]; } }   ; the cap bites: use the brake as the slew limit
004174a0  if (direction < 0) EBX = -EBX
004174a2  EAX = FUN_0042cdd0(rate, EBX, EDI * dt)                  ; rate moves toward +-speed by at most the slew limit
004174b9  value += rate * dt ; clamp at the target ; *rate = EAX
```

The rig struct is a copy of the template at `0x448e90`; its three triples (`DumpDwords.java 0x448e90 24`): `+0x3c` position `{0x1999, 0xccc, 0x40000}`, **`+0x48` height `{0.1, 0.05, 3.0}`**, **`+0x54` pitch `{0.04, 0.01, 1.0}`** (`0xa3d, 0x28f, 0x10000`).

The port, `game/camera_ease.gd` and `game/camera_swoop.gd`:

```gdscript
func step() -> bool:                                   # FUN_00417420, one tick
	if floorf(value) == floorf(target):                # (value ^ target) & 0xffff0000 == 0
		rate = 0.0
		return true
	var dist := absf(target - value)
	var sgn := -1.0 if target < value else 1.0
	var slew := accel                                  # triple[0]
	var speed := max_rate                              # triple[8]
	if speed != 0.0:
		var cap := sqrt(dist * brake)                  # FUN_00410e20(dist * triple[4])
		if speed > cap:
			speed = cap
			slew = brake                               # EDI = triple[4]
	rate = move_toward(rate, sgn * speed, slew)        # FUN_0042cdd0(rate, +-speed, slew * dt)
	value += rate
	if (sgn < 0.0 and value < target) or (sgn > 0.0 and value > target):
		value = target
	return false

const START_HEIGHT := 250.0                            # FUN_00416100's 0xfa0000
const START_PITCH := 64.0                              # 0x400000
const NORMAL_PITCH := 24.0                             # 0x180000
const HEIGHT_TRIPLE := [0x1999 / 65536.0, 0xccc / 65536.0, 3.0]
const PITCH_TRIPLE := [0xa3d / 65536.0, 0x28f / 65536.0, 1.0]
const HEIGHT_BY_TYPE := [-170.0, -170.0, -170.0, -100.0]   # the table at 0x4452c0
```

Checked by `tools/tests/camera_swoop_check.gd`: the height comes within one unit of its target at **tick 205 (about 3.3 s)** for a Tank/Jeep/MSV and **tick 181** for a Heli, the pitch at tick 134; the footage's swoop lasts about three seconds.

## Step 3: when it runs, and how the port uses it

The camera update runs while the view is shown, so the swoop starts when the game view starts fading in: exactly when the confirm script has released the lift object and it starts to rise (document 89's `pad_rising`; the hangar screen covers the view before). In the port
`terrain_view_3d.gd` starts a `CameraSwoop` on the rising edge of `MatchController.pad_rising` and, while it runs, sets the camera from the eased fractions instead of following normally:

```gdscript
var rising := controller != null and controller.pad_rising
if rising and not _was_rising and GameSettings.camera_swoop_in and controller.vehicle != null:
	_swoop = CameraSwoop.new(controller.vehicle.vehicle_type)
_was_rising = rising
if _swoop != null:
	_swoop.advance(delta * Vehicle.TICK_HZ)
	var height_px := camera_height_px * lerpf(1.0, SWOOP_START_ZOOM, _swoop.height_fraction())
	var tilt_deg := lerpf(camera_tilt_deg, SWOOP_START_TILT_DEG, _swoop.pitch_fraction())
	camera.position = _camera_target_position(track_pos, height_px, tilt_deg)
	_apply_tilt(tilt_deg)
```

**A bug found by the user and fixed:** with the camera far up, the pad's layers (the ground tile, the leaves 0.1 above it, the hazard strip, the plate) z-fought (the leaves flickered and the pit's hazard border dropped out). Godot's default near plane is 0.05, which spends almost all the depth precision on the first few units; `CAMERA_NEAR_PLANE = 10.0` (the camera is never closer than about 200 units to anything drawn) fixes it, checked by before/after screenshots at the same frames.

**The setting.** `GameSettings.camera_swoop_in` (`game/game_settings.gd`, default on) is read from `user://settings.cfg` (`[camera] swoop_in`), which is written with the defaults on first run; `RF_NO_SWOOP=1` forces it off for one run. There is no settings menu yet: a future one only has to bind to that variable and call `GameSettings.save_settings()`.
Screenshots of the real scene show the view opening on a small distant pad and pulling in, like the footage, and the normal view with the setting off.

## Not done / untraced

- **The mapping onto the port's camera is a port choice, not traced.** The eased fractions and the timing are the original's; `SWOOP_START_ZOOM = 4.0` (the pad looks about four times smaller at the start of the footage) and `SWOOP_START_TILT_DEG = 70.0` (much more top-down) were read off the footage. The original's height (+0x114, which passes through zero on its way from 250 to -170) and pitch (+0x24, 64 to 24, unit unknown) go through the view matrix (`FUN_00410be0` / `FUN_00410dc0` sine and cosine of `+0x24`)
  and the port's camera uses a different model, so the units were not converted. Tracing the matrix and the projection would replace these two constants.
- **The leaves are clipped to the pad tile** (a leaf 16 wide at `0.3 * age + 5` reaches x = 31 at its widest, past the tile's edge at 16): the port cuts them off at x = +-16, texture included, as if the mechanism were underground (the user's direction; the footage shows nothing outside the tile). Whether the original clips them the same way is untraced.
- The rig's position triple (`{0.1, 0.05, 4.0}`, used for the camera's x/y follow) and the per-tick camera follow in normal play are not modelled: the port keeps its own smoothing.
- Other callers of the rig function (`0x4184a4`, `0x43285b`, the flag capture) and the priority ordering when several rigs are active.
- Whether the swoop also plays at the very first start of a match (it does in the footage, where the start is an undock) is covered, since the start uses the same path.

**Next:** [the next-steps doc](NEXT_STEPS.md).
