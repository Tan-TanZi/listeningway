**Downloads:**
- [Listeningway-x64-{{VERSION}}.zip](https://github.com/gposingway/listeningway/releases/download/v{{VERSION}}/Listeningway-x64-{{VERSION}}.zip) — 64-bit (FFXIV, FFVII Remake, modern AAA)
- [Listeningway-x86-{{VERSION}}.zip](https://github.com/gposingway/listeningway/releases/download/v{{VERSION}}/Listeningway-x86-{{VERSION}}.zip) — 32-bit (Dead Cells, FFX/X-2 HD, Skyrim LE, Dark Souls: PtDE, GTA SA, older indies/JRPGs)

**Which one?** Match your ReShade DLL. If you're not sure, open Task Manager while the game runs — a `*32` suffix on the process name means use **x86**, otherwise **x64**.

## Installation
1. Download the ZIP that matches your game's architecture.
2. Extract the contents of the ZIP. You will find these files:

    | File Name                  | Where to Place It          | Notes / Purpose                                    |
    | :------------------------- | :------------------------- | :------------------------------------------------- |
    | `Listeningway.addon`       | Game Directory             | ReShade loads `.addon` files from this directory.  |
    | `Listeningway.fx`          | `reshade-shaders/Shaders/` | The example shader effect file.                    |
    | `ListeningwayUniforms.fxh` | `reshade-shaders/Shaders/` | Include file needed by shaders using `#include`.   |

   *(Reminder: The `.addon` file goes directly into your main game folder with the ReShade DLL, not inside `reshade-shaders`!)*
3. Restart your game or application.

## Notes
- For more information and troubleshooting, see the [GitHub repository](https://github.com/gposingway/listeningway).
- The 32-bit (x86) build target was contributed by [@slendereater-sketch](https://github.com/slendereater-sketch); see the project README for full credits.
