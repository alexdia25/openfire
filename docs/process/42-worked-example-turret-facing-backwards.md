# 42. Worked example: a symmetric hull hid a 180-degree facing bug for four documents

The user's question that caught this, right after the decoration fix: *"the turret and barrel
is facing backwards, should that be able to rotate independently?"* Two separate things in one
sentence -- a bug report, and a real design question -- and the bug turned out to predate every
one of the last four turret documents.

## The bug

`game/vehicle_box_3d.gd`'s `FACING_OFFSET_DEG` (the yaw correction that aligns the box's local
front with `Vehicle.heading_deg`'s real "0 = +X" convention) has been `90.0` since document 37
first built the box, "empirically matched against a real driven-forward screenshot" -- a real
check, genuinely performed, that still let a 180-degree error through.

A fresh `RF_DEBUG_DRIVE` run (`turn=0`, starting `heading_deg=0`) confirms the vehicle's real
motion is pure `+X` (`RF_DEBUG_CAMERA_LOG`: `vehicle_pos` goes `(2160, 2160)` ->
`(2221, 2160)` over 60 frames, `y` untouched) -- and since this project's camera never yaws
(document 27/28), world `+X` is screen-right with no ambiguity. The screenshot at that same
moment shows the barrel pointing screen-*left* -- directly backward from the confirmed
direction of travel.

## Why four documents of screenshot comparisons never caught it

`FACES` (the hull) is fully symmetric front-to-back: the top panels are centred on the origin,
the tread cels are the same texture mirrored to both sides, and the front/back detail parts
(cel 187) are the *identical* cel placed at `+Z` and `-Z`. A full 180-degree yaw rotates this
shape into something pixel-identical to itself. Every screenshot comparison from document 37
onward was checking "does the hull look right," and a symmetric shape can look right at both
the correct heading and its exact opposite -- the same class of blind spot the "heading 0 and
180 render pixel-identical" bug (document 21) hit for the flat sprite, for a different
underlying reason. `TURRET_PARTS` (document 39) is the first part of this vehicle with a real
directional feature -- a barrel that points one way -- and it was built in the same local space
as everything else, correctly, which is exactly why it faithfully rendered the vehicle's
existing 180-degree error for the first time anyone could actually see it.

## The fix

`FACING_OFFSET_DEG`: `90.0` -> `-90.0` (180 degrees off the old value). Re-ran the identical
`RF_DEBUG_DRIVE` comparison: the barrel now points screen-right, matching the logged direction
of travel. The hull itself shows no visible change, as expected from a shape with no
directional feature to flip.

## The other half of the question: should the turret aim independently?

Yes, in the original -- `FUN_00402dc0` (document 39) composes the turret's rotation as the
hull's own heading *plus* a separate turret-aim angle read from a linked sub-object, so the
original engine clearly supports the turret pointing a different way than the hull is driving.
This project doesn't model that yet: no AI/player aim-angle state exists anywhere in this
codebase, so the turret always renders at the hull's own heading -- a documented simplification
since document 39, unchanged by this fix. This fix corrects *which way "the same heading as the
hull" actually points*; it doesn't add independent aim. That stays open backlog (plan section
4, item 10) for whenever the user wants to pick it up.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
