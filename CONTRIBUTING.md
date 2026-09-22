# Build from source

Use Windows x64, Python 3.10+ and the LuaJIT commit in `dependencies.json`, built with `msvcbuild.bat nogc64`. Set `HD2_LUAJIT` to that executable and `HD2_GAME_ROOT` to your supported Helldivers 2 installation.

Run `python -B scripts/build.py`. It runs the focused tests and creates `releases/Controllable-Hover-Pack-v1.3.zip`. In the multi-mod workspace, releases share the parent directory. Intermediate files stay in ignored `build/`. The builder never installs the mod or launches the game. The release preserves the tested gameplay payload. Runtime verification metadata remains distinct from full-release status.

Keep the manager GUID and `mods/cowboybingus/hover_pack_cancel` resource identity stable for compatibility. Gameplay settings and input behavior are covered by the Lua tests. Commit only authored source, synthetic fixtures, documentation and artwork; exclude local paths, captures, tools, game files and credentials.
