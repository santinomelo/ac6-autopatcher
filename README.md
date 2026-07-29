# AC6 AutoPatcher

AC6 AutoPatcher is a server-side security layer for Roblox experiences that use vulnerable A-Chassis 6 sound remotes.

The project was created after identifying that some AC6 installations trust client-controlled sound identifiers, parents, names, volume values, and playback settings. An attacker can abuse that behavior to create and reproduce arbitrary sounds through the server.

AC6 AutoPatcher replaces recognized insecure remotes with a server-authoritative implementation while preserving the standard AC6 sound protocol.

## Security model

- Treats every client argument as untrusted.
- Accepts requests only from the current `VehicleSeat` occupant.
- Uses sound identifiers and templates selected by the server.
- Never accepts a destination instance from the client.
- Restricts volume and playback speed.
- Rate-limits requests per player.
- Isolates failures so one malformed chassis cannot stop the global monitor.
- Replaces vulnerable remotes synchronously when vehicles are inserted.
- Rechecks incomplete chassis until their dependencies become available.

## Supported protocol

The patcher recognizes `AC6_FE_Sounds` remotes and supports the traditional actions:

- `newSound`
- `updateSound`
- `playSound`
- `pauseSound`
- `stopSound`
- `removeSound`

Action names and remote names are matched without case sensitivity. Arbitrary sound names are rejected unless a corresponding server-owned `Sound` template exists.

## Installation

1. Create a `Script` inside `ServerScriptService`.
2. Name it `AC6AutoPatcher`.
3. Copy the contents of `AC6AutoPatcher.server.lua` into the script.
4. Keep only one copy of the patcher in the experience.
5. Test every vehicle in a local server before publishing the experience.

No per-vehicle handler replacement is required for recognized AC6 remotes.

## Runtime states

Every replacement remote receives these attributes:

- `ac6_patch_version`
- `ac6_patch_state`
- `ac6_patch_reason`

Possible states include:

- `secure_ready`: the chassis is protected and its audio dependencies are available.
- `secure_degraded`: the chassis is protected and temporarily uses the driver seat as its sound emitter.
- `secure_waiting`: the chassis is protected but is waiting for a compatible seat, template, or emitter.

If the initial scan does not find a recognized vulnerable remote, the server prints:

```text
AC6 AutoPatcher no encontro vulnerabilidades en el escaneo inicial
```

The monitor remains active after that message and continues processing dynamically inserted vehicles.

## Configuration

The configuration table at the beginning of the script controls:

- Services monitored for vulnerable remotes.
- Accepted remote names.
- Accepted driver-seat names.
- Preferred sound-emitter names.
- Request limits.
- Dependency retry interval.
- Volume and playback-speed limits.
- Driver-seat emitter fallback.

The default configuration monitors `Workspace`, `ReplicatedStorage`, `ServerStorage`, `StarterPack`, and `Players`.

Remove services that cannot contain vehicles in your experience to reduce the monitoring scope.

## Compatibility

The project targets AC6 variants that expose an `AC6_FE_Sounds` `RemoteEvent` and contain server-owned sound templates.

Custom chassis may require configuration changes when they use:

- A different remote name.
- A different driver-seat name.
- A completely different argument protocol.
- Sound identifiers stored only inside custom modules.
- A non-AC6 vehicle system.

If a recognized chassis is missing dependencies, the patcher fails closed: the vulnerable remote is neutralized, but engine audio may remain unavailable until the required server-owned objects appear.

Audio ownership and experience permissions are separate from this vulnerability. The patcher cannot grant an experience permission to use an audio asset.

## Validation

The source has been checked for Luau syntax and tested against simulated cases covering:

- The arbitrary sound creation payload.
- Unauthorized players.
- Client-controlled sound identifiers and parents.
- Excessive volume.
- Dynamic vehicle insertion.
- Incomplete chassis.
- Delayed dependencies.
- Non-archivable sound templates.
- Vehicles cloned from shared storage.

Always perform a Roblox Studio local-server test with the exact vehicle models used by the destination experience.

## License

This project is released under the MIT License.
