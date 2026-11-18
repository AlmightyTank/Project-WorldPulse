# WorldPulse Godot placeholder

Use **Godot 4.7.2 stable (standard)**. Import `game/godot/project.godot` in the Project Manager and press F5 to run the project. The Compatibility renderer and 16:9 (1920 x 1080) reference viewport keep the fixed perspective composition on resize, with letterboxing or pillarboxing as needed. A clay-colored marker is the scene's focal point; the inset light-on-dark readout stays legible over both sky and ground. All geometry is placeholder.

The main scene is `scenes/Main.tscn`, its status client is `scripts/world_status.gd`, and the offline smoke test is `tests/offline_smoke.gd`. `assets/` and `shaders/` are reserved for v0.1B and later.

On launch the readout sends one asynchronous `GET /api/world/status` request to `http://127.0.0.1:3000`. Set `WORLD_PULSE_API_URL` before launching Godot to override the base URL (for example, `http://127.0.0.1:3100`, without the API path). Start the backend and relaunch to refresh the status. The scene remains active offline, including when the request times out after 3 seconds.

## CI smoke test

From the repository root, with Godot 4.7.2 on `PATH`:

```sh
godot --headless --path game/godot --import
godot --headless --path game/godot --script res://tests/offline_smoke.gd
```

On Windows use the release's `_console.exe` for these commands. The smoke test boots the configured main scene and overrides the API URL within its own process with a loopback listener that accepts a connection but never replies. It checks that a real HTTP timeout changes the visible readout to offline and leaves the perspective camera active. It exits `1` on failure or if its 8-second deadline expires. No backend or external Internet connection is needed.
