# Legacy CS:GO SWP Menu

**Author:** Jaymmz  
**File:** `legacy_swp_menu.sp`  
**Game:** CS:GO (legacy builds, GC/loadout unavailable)  

Legacy CS:GO SWP Menu is a SourceMod plugin that restores weapon loadout swapping on old CS:GO builds where the official inventory / loadout system no longer works.  
Players can use a simple chat command to choose which weapon they want for each official buy-menu swap slot, and the plugin will remember their preferences.

---

## Features

- **CT starting pistol (Slot 1)**
  - `P2000` ↔ `USP-S`
- **CT $500 pistol (Slot 4)**
  - `Five-SeveN` ↔ `CZ75-Auto`
- **T $500 pistol (Slot 4)**
  - `Tec-9` ↔ `CZ75-Auto`
- **Heavy pistol (Slot 5, both teams)**
  - `Desert Eagle` ↔ `R8 Revolver`
- **CT rifle (Slot 2)**
  - `M4A4` ↔ `M4A1-S`
- **Optional SMG**
  - `MP7` ↔ `MP5-SD` (only if `mp5sd` exists on this build)

Behavior details:

- Players open the menu via chat (`!swp` / `/swp`) or console (`sm_swp`).
- Per-player preferences are stored using `clientprefs` cookies.
- **CT starting pistol** is automatically swapped on spawn (P2000 ↔ USP-S).
- When a player buys a weapon in a swap slot, the plugin:
  - Lets the normal buy happen.
  - On the next frame, replaces the actual weapon entity to match the player’s preference (no free weapons, no extra money spent).
- When a swap happens, the player receives a **private colored chat hint** like:
  - `[Hint] CT rifle set to M4A1-S.`

> Note: The in-game Buy Menu icons and stats remain unchanged (for example, it may still show Tec-9), because those are rendered on the client side and cannot be updated from the server. The actual weapon entity, ammo, and behavior will match the chosen SWP weapon.

---

## Commands

- **Chat**
  - `!swp` – open the SWP weapon swap menu.
  - `/swp` – same as above.

- **Console**
  - `sm_swp` – open the SWP weapon swap menu.

---

## ConVars

Set these in a config (for example `cfg/sourcemod/legacy_swp_menu.cfg`) or via server console:

- `sm_legacy_swp_enabled`  
  - `1` – enable the plugin (default)  
  - `0` – disable the plugin

- `sm_legacy_swp_version`  
  - Read-only version string.

---

## Installation

### 1. Using the precompiled plugin (`.smx`) – recommended

1. Upload `legacy_swp_menu.smx` to your plugins folder:

   ```text
   addons/sourcemod/plugins/legacy_swp_menu.smx
   ```

2. Restart your server, or load the plugin manually:

   ```text
   sm plugins load legacy_swp_menu
   ```

3. Join the server and type `!swp` in chat to open the SWP menu and configure your weapon swaps.

### 2. (Optional) Compile from source

If you want to modify the source code or build your own version:

1. Copy `legacy_swp_menu.sp` to your scripting folder:

   ```text
   addons/sourcemod/scripting/legacy_swp_menu.sp
   ```

2. Compile the plugin:

   - Using `spcomp` on your server:

     ```bash
     cd addons/sourcemod/scripting
     spcomp legacy_swp_menu.sp
     ```

   - Or use the AlliedModders online compiler and download `legacy_swp_menu.smx`.

3. Place the newly compiled `legacy_swp_menu.smx` into:

   ```text
   addons/sourcemod/plugins/legacy_swp_menu.smx
   ```

---

## Notes for community server owners

- **Server-only plugin**  
  - This is a pure server-side SourceMod plugin.  
  - Players **do not** need any client mods or custom files.

- **Required SourceMod components**  
  - The plugin uses only **standard** SM extensions:
    - `sdktools`
    - `cstrike`
    - `clientprefs`
  - On a normal CS:GO SourceMod installation these are enabled by default.  
  - If you have manually disabled extensions, make sure these three are loaded.

- **Typical installation paths**
  - For a dedicated CS:GO server created via SteamCMD:
    - Windows:
      - Game folder: `...\steamcmd\csgo\csgo\`
      - Plugin source: `csgo\addons\sourcemod\scripting\legacy_swp_menu.sp`
      - Compiled plugin: `csgo\addons\sourcemod\plugins\legacy_swp_menu.smx`
    - Linux:
      - Game folder: `/path/to/csgo/csgo/`
      - Plugin source: `csgo/addons/sourcemod/scripting/legacy_swp_menu.sp`
      - Compiled plugin: `csgo/addons/sourcemod/plugins/legacy_swp_menu.smx`
  - If you use a game hosting panel, look for its `addons/sourcemod/` directory and place the files in the same relative paths as above.

---

## Limitations

Please be aware of a few engine/game limitations that this plugin **cannot** solve:

- **Buy Menu UI does not change**
  - The Buy Menu icons, weapon names, and stat bars are rendered on the **client side**.
  - Even if you swap Tec-9 → CZ75-Auto (or M4A4 → M4A1-S), the Buy Menu may still show the original weapon.
  - The plugin only changes the **actual weapon entity** you receive (class name, ammo, behavior), not the UI.

- **No GC / inventory integration**
  - This plugin does not and cannot talk to Valve’s GC or inventory systems.
  - It cannot sync skins, stickers, or official loadout selections. It only controls which base weapon you get in each slot.

- **Legacy CS:GO only**
  - Designed for legacy CS:GO builds where the GC / loadout system is broken or unavailable.
  - On very old builds without certain weapons (for example `mp5sd`), those options are automatically hidden and not used.

If you need the Buy Menu UI itself to change (icons, names, stats), that would require **client-side modifications** (custom Panorama/HUD files or a custom client), which is outside the scope of a SourceMod server plugin.

---

## Requirements

- **SourceMod:** 1.10+ (1.12 recommended).  
- **Game:** CS:GO legacy build (where the official GC / loadout is not functional).

---

## Credits

- **Plugin:** `Legacy CS:GO SWP Menu` by **Jaymmz**
- Thanks to the AlliedModders community and various CS:GO weapon documentation threads for loadout and entity name references.

