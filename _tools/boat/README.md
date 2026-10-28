# Fishing Boat (Blender → Roblox), 2026-10-28

1. Model: `_blender/fishing_boat.py` (run in Blender). It builds the scene "FishingBoat" and exports
   `_assets/fishing-boat/FishingBoat.fbx`.
   - Units are studs; the bow faces −Y and the waterline is z = 0.
   - Part names start with a colour group (Red_, White_, Blue_, Deck_, Dark_, Glass_, Navy_, Grey_, Black_, Seat_).
   - The shop/tool icon is a render of that scene: `_tools/shop/out/Boat.png` → image 127503029975255.
2. Upload: `python3 _tools/boat/upload_boat.py [--force]` puts the Model asset id in `uploaded.json`
   (current: 78259234163669).
3. Studio Edit: run `_tools/boat/assemble.luau` to rebuild `ServerStorage.FishingBoat`. It adds:
   - styles by prefix (Glass is SmoothPlastic, t 0.55);
   - an invisible `BoatRoot` (waterline) with the `Drive` LinearVelocity and `Upright` AlignOrientation;
   - the `Seat` on the red cushion (CanTouch off; Boats.client seats you when you walk up to it);
   - 8 invisible `BoatBarrier` walls along the deck edge.
4. Developer product: `Vehicles.Boat` in `_tools/shop/create_products.py` (id 3723413206, 399 R$).
   - Cash price: `ShopConfig.Vehicles` (100B).
   - Ownership is saved in the Perks list (`OwnsBoat` attribute).
   - Testing: admin chat `;vehicle me Boat` gives it.
5. Runtime: `src/server/Boats.server.luau` (tool, launch on water, collision groups) and
   `src/client/Boats.client.luau` (driving, deck clamp, sit on approach).
   - The map's `WaterWalkSupport` slabs go in collision group `WaterWalk`, which doesn't collide with
     `BoatHull`, so hulls float through them.
