# Fuse machine (Blender → Roblox), 2026-10-27

1. Model: `_blender/fuse_machine.py` (run in Blender; builds scene "FuseMachine", exports
   `_assets/fuse-machine/FuseMachine.fbx`). Units are studs. Part names start with a colour group.
2. Upload: `python3 _tools/fuse/upload_fuse.py [--force]` → Model asset id in `uploaded.json`
   (current: 112193861169683; first upload 114885546968979).
3. In Studio Edit: run `_tools/fuse/assemble.luau` (set ASSET first). It loads the asset, restyles each part by its name prefix,
   scale it ×0.9, places it at `Zone00` (x 62, z 565, stairs facing −X), then shifts it +X so 1/3 of the base
   is buried in the wall. An orange `FuseFloorPad` (centered under the machine, sticking 3 studs past the front)
   holds a `FusePrompt` ProximityPrompt. Keep it as `Zone00.FuseMachine` with `KeepFinish = true`.
   - Navy (38,46,86), Purple (118,56,210) and Grey (168,170,182): SmoothPlastic.
   - Neon (255,70,230), Swirl (255,150,245, t 0.15) and Crystal (255,140,250): Neon.
   - Glass: SmoothPlastic, t 0.7, reflectance 0.15. Not the Glass material: Roblox hides
     transparent parts behind Glass, which would make the swirl invisible.
   - Each Glass part has a `Glow_*` copy inside it: Neon (215,70,255), t 0.6, at 93% of the
     size.
   - Colliding parts: the base, tier, core floor, steps, stair rails and the core tube.
   - Also add a `FusePad` with a `FusePrompt` (and the `FuseSign` "FUSE" billboard) and a
     `FuseFxHost` with pink sparkles.
4. Save the place. The old machines (the Steal an Egg mesh FuseMachine and PrismFusion) are in
   `ServerStorage.claude_BeforeFuseReplace_20261027`.
