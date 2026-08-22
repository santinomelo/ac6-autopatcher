# A-Chassis Tune 6 (AC6) Automatic Patcher

[Español](README.md) · [English](README.en.md)

![Roblox](https://img.shields.io/badge/Roblox-Studio-00A2FF?logo=robloxstudio&logoColor=white)
![Luau](https://img.shields.io/badge/Luau-server-335FFF)
![License](https://img.shields.io/badge/license-MIT-green)

A server-side security patch for Roblox games using vulnerable versions of the **A-Chassis 6** sound system.

Some AC6 installations trust client-provided data such as the audio ID, destination, name, volume, and playback speed. An attacker can abuse that trust to ask the server to create and play arbitrary sounds.

This script replaces vulnerable remotes with a server-controlled implementation while preserving the classic AC6 sound protocol.

> [!IMPORTANT]
> Install it as a single `Script` inside `ServerScriptService`.

## Security model

- Treats all client-provided values as untrusted.
- Accepts requests only from the player currently driving the vehicle.
- Uses sound IDs and templates selected by the server.
- Prevents clients from choosing the sound destination.
- Limits volume, playback speed, and request frequency.
- Isolates malformed chassis errors so the patcher can continue running.
- Detects vehicles added after the server starts.
- Rechecks incomplete chassis when their missing dependencies appear.

> [!NOTE]
> `RemoteEvent` names, attributes, and client-accessible traffic can be inspected. This patch does not depend on keeping them secret. Its security comes from server-side validation of the driver, destination, audio ID, properties, and request rate before any action is executed.

## Compatibility

The patcher recognizes remotes named `AC6_FE_Sounds` and preserves these actions:

- `newSound`
- `updateSound`
- `playSound`
- `pauseSound`
- `stopSound`
- `removeSound`

It supports AC6 variants that use this `RemoteEvent` and server-controlled `Sound` templates.

If a chassis uses a different remote name, seat, protocol, or stores its IDs only in custom modules, you may need to adjust the `configuracion` table.

Technical names such as `RemoteEvent`, `VehicleSeat`, `Sound`, and `AC6_FE_Sounds` remain unchanged because they are part of Roblox or AC6 and are required for automatic detection.

## Installation

1. Create a `Script` inside `ServerScriptService`.
2. Name it `ParcheadorAutomaticoAC6` or choose another name.
3. Copy the contents of `ParcheadorAutomaticoAC6.server.luau` into it.
4. Make sure only one copy is installed.
5. Test every vehicle in a local server before publishing the game.

You do not need to manually replace each vehicle handler when the AC6 remote is recognized.

## Runtime status

Each patched remote receives these attributes:

- `ac6_version_parche`
- `ac6_estado_parche`
- `ac6_motivo_parche`

Possible states:

- `seguro_listo`: the chassis is protected and audio is available.
- `seguro_degradado`: the chassis is protected but temporarily uses the seat as the emitter.
- `seguro_esperando`: the chassis is protected and waiting for a compatible seat, template, or emitter.

If the initial scan finds no vulnerable remotes, the console displays:

```text
Parcheador AC6 no encontro vulnerabilidades en el escaneo inicial
```

The patcher remains active and continues checking vehicles added later.

## Edge cases

When a vulnerable remote is found in an incomplete chassis, the patcher neutralizes the unsafe remote first and retries after the required dependencies appear.

The vehicle remains protected, although engine audio may stay unavailable until its seat, template, or emitter is present.

Audio permissions are managed by Roblox. The patcher cannot grant an experience access to an audio asset it is not allowed to use.

## Verification performed

- Valid Luau syntax.
- Arbitrary sound creation payloads.
- Requests from players who are not driving.
- Client-controlled IDs and destinations.
- Excessive volume values.
- Vehicles added dynamically to `Workspace`.
- Incomplete chassis and dependencies added later.
- Non-clonable templates.
- Vehicles cloned from shared storage.

Test the script in Roblox Studio with the exact vehicle models used by your experience before publishing. Modified A-Chassis versions may use different structures.

## Sources

- [Roblox Developer Forum](https://devforum.roblox.com/t/fix-the-a-chassis-module-sound-exploit/1857115)
- [Reddit](https://www.reddit.com/r/robloxhackers/comments/s715ir/sound_exploit_for_a_brazilian_game_and_other/)
- [Neutralized exploit reference](https://pastebin.com/5FUE10fZ)

## License

This project is available under the [MIT License](LICENSE).
