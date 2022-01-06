Godot Rollback Netcode
======================

This is an addon for implementing rollback and prediction netcode in the Godot
game engine.

Beyond the basics (gathering input, saving/loading state, sending messages,
detecting mismatches, etc) this library aims to provide support for many of
the other aspects of implementing rollback in a real game, including timers,
animation, random number generation, and sound - along with high-quality
debugging tools to make solving problems easier.

Implementing rollback and prediction is HARD, and so every little bit of help
is important. :-)

Tutorials
---------

I'm working on a series of video tutorials on YouTube. You check back on
[my channel](https://www.youtube.com/SnopekGames),
but I'll post a more specific link once the first video is finished!

Installing
----------

This addon is implemented as an editor plugin.

If you've never installed a plugin before, please see the
[official docs on how to install plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html)

However, the short version is:

1. Copy the `addons/godot-rollback-netcode` directory from this project into
your Godot project *at the exact same path*. The easiest way to do this is in
the AssetLib right in the Godot editor - search for "Godot Rollback Netcode".

2. Enable the plugin by clicking **Project** -> **Project settings...**, going
to the "Plugins" tab, and clicking the "Enable" checkbox next to "Godot
Rollback Netcode".

Games using this addon
----------------------

- [Retro Tank Party](https://www.snopekgames.com/games/retro-tank-party)

If you release a game using this addon, please make an MR (Merge Request) to
add it to the list!

Overview
--------

This this is a quick overview of the different pieces that the addon includes.

### Singletons ###

- `res://addons/godot-rollback-netcode/SyncManager.gd`: This is the core of
  the addon. It will be added to your project automatically when you enable
  the plugin. It must be named `SyncManager` for everything to work
  correctly.
 
- `res://addons/godot-rollback-netcode/SyncDebugger.gd`: Adding this
  singleton will cause more debug messages to be printed to the console (and
  captured in the normal Godot logs) and make a debug overlay available. By
  default, the overlay can be shown by pressing F11, but you can assign any
  input event to the "sync_debug" action in the Input Map in your project's
  settings.

### Important properties, methods and signals on `SyncManager` ###

The `SyncManager` singleton is the core of this addon, and one of the primary
ways that your game will interact with the addon. (The other primary way is
via psuedo-virtual methods that you'll implement on your nodes - see the
section called "Psuedo-virtual methods" below for more information.)

#### Properties: ####

- `current_tick: int`: The current tick that we are executing. This will
  update during rollback to be tick that is presently being re-executed.

- `input_tick: int`: The tick we are currently gathering local input for. If
  there is an input delay configured in Project Settings, this be ahead of
  `current_tick` by the number of frames of input delay. This doesn't change
  during rollback.

- `started: bool`: will be true if synchronization has started; otherwise
  it'll be false. This property is read-only - you should call the `start()`
  or `stop()` methods to start or stop synchronizing.

#### Methods: ####

- `add_peer(peer_id: int) -> void`: Adds a peer using its ID within Godot's
  [High-Level Multiplayer API](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html).
  Once a peer is added, the `SyncManager` will start pinging it right away.
  All peers should be added before calling `SyncManager.start()`.

- `start() -> void`: Starts synchronizing! This should only be called on the
  "host" (ie. the peer with id 1), which will tell all the other clients to
  start as well. It's after calling this that the "Psuedo-virtual methods"
  described below will start getting called.

- `stop() -> void`: Stops synchronizing. If called on the "host" (ie. the
  peer with id 1) it will tell all the clients to stop as well.
  
- `clear_peers() -> void`: Clears the list of peers.

- `start_logging(log_file_path: String, match_info: Dictionary = {}) -> void`:
  Starts logging detailed information about the current match to the given
  log file. The common convention is to put the log file under
  "user://detailed_logs/". The `match_info` is stored at the start of the
  log, and is used when loading a replay of the match. This method should
  be called before `SyncManager.start()` or the "sync_started" signal.

- `stop_logging() -> void`: Stops logging. This method should be called
  after `SyncManager.stop()` or the "sync_stopped" signal.

- `spawn(name: String, parent: Node, scene: PackedScene, data: Dictionary = {}, rename: bool = true, signal_name: String = '') -> Node`:
  Spawns a scene and makes a "spawn record" in state so that it can be
  de-spawned or re-spawned as the result of a rollback.

  It returns the top-level node that was spawned, however, rather than doing
  most setup on the returned node, you should do it in response to the
  "scene_spawned" signal. This is because the scene could be re-spawned due
  to a rollback, and you want all the same setup to happen then as when it
  was originally spawned. (Note: there are rare cases when you want to do
  setup *only* when spawned initially, and not when re-spawned.)

  * `name`: The base name to use for the top-level node that is spawned.
  * `parent`: The parent node the spawned scene will be added to.
  * `scene`: The scene to spawn.
  * `data`: Data that will be passed `_network_spawn_preprocess()` and
    `_network_spawn()` on the top-level node. See the "Psuedo-virtual
     methods" described below for more information.
  * `rename`: If true, the actual name of the top-level node that is spawned
    will have an incrementing integer appended to it. If false, it'll try to
    use the `name` but this could lead to conflicts. Only set to false if you
    know for sure that no other sibling node will use that name.
  * `signal_name`: If provided, this is the name that'll be passed to the
    "scene_spawned" signal; otherwise the `name` will be used.

- `despawn(node: Node) -> void`: De-spawns a node that was previously
  spawned via `SyncManager.spawn()`, calls `_network_despawn()` and removes
  its "spawn record" in state.  By default, this will also remove the node
  from its parent and call `node.queue_free()`. However, if you have enabled
  "Reuse despawned nodes" in Project Settings, then the node will saved and
  reused when the same scene needs to be spawned later. This makes it
  especially important to clean-up the nodes internal state in
  `_network_despawn()` so that the node is "like new" when reused.

- `play_sound(identifier: String, sound: AudioStream, info: Dictionary = {}) -> void`:
  Plays a sound and records that we played this specific sound on the
  current tick, so that we won't play it again if we re-execute the same
  tick again due to a rollback.
  * `identifier`: A unique identifier for the sound. Only one sound with this
    identifier will be played on the current tick. The common convention is
    to use the node path of the node player sound with the sort of sound
    appended, for example:
    ```
    SyncManager.play_sound(str(get_path()) + ':shoot', shoot_sound)
    ```
  * `sound`: The sound resource to play.
  * `info`: A set of optional parameters, including:
    - `position`: A `Vector2` giving the position the sound should originate
      from. If omitted, positional audio won't be used.
    - `volume_db`: A `float` giving the volume in decibels.
    - `pitch_scale`: A `float` to scale the patch.
    - `bus`: The name of the bus to play the sound to. If none is given, the
      default bus configured in Project Settings will be used.

#### Signals: ####

- `sync_started ()`: Emitted when synchronization has started, as a result of
  `SyncManager.start()` on the "host".

- `sync_stopped ()`: Emitted when synchronization has stopped for any reason -
  it could be due to an error (in which case "sync_error" will have been
  emitted before this signal) or `SyncManager.stop()` being called locally or
  on the "host".

- `sync_lost ()`: Emitted when this client has gone far enough out of sync with
  the other clients that we need to pause for a period of time and attempt to
  regain synchronization. A message should be shown to the user so they know
  why the match has suddenly come to stop.

- `sync_regained ()`: Emitted if we've managed to regain sync after it had been
  lost. The message shown to the user when "sync_lost" was emitted should be
  removed.

- `sync_error (msg: String)`: Emitted when a fatal synchronization error has
  occurred and the match cannot continue. This could be for a number of
  reasons, which will be identified in a human-readable message in `msg`.

- `scene_spawned (name: String, spawned_node: Node, scene: PackedScene, data: Dictionary)`:
  Emitted when a scene is spawned via `SyncManager.spawn()` or re-spawned due
  to a rollback. Connect to this signal when you want to do some setup on a
  scene that was spawned, and you need to ensure that that setup also happens
  if the scene is re-spawned during rollback (you want this most of the time).

- `interpolation_frame ()`: If interpolation is enabled in Project Settings,
  the work of the `SyncManager` will be split between "tick frames" (where
  input is gathered, rollbacks are performed and ticks are executed) and
  a variable number of "interpolation frames" that happen between them.
  This signal is emitted at the end of each interpolation frame, so that
  you can perform some operation during a frame with with a more budget
  to spare (a lot more needs to happen during tick frames).
 
### Node types ###

**TODO**

### Psuedo-virtual methods ###

For a node to participate in rollback, it must be in the "network_sync" group,
which will cause `SyncManager` to call various psuedo-virtual methods on the
node:

- `_save_state() -> Dictionary`: Return the current node state. This same
  state will be passed to `_load_state()` when performing a rollback.

- `_load_state(state: Dictionary) -> void`: Called to roll the node back to a
  previous state, which originated from this node's `_save_state()` method.

- `_interpolate_state(old_state: Dictionary, new_state: Dictionary, weight: float) -> void`:
  Updates the current state of the node using values interpolated from the
  old to the new state. This will only be called if "Interpolation" is
  enabled in project settings.

- `_get_local_input() -> Dictionary`: Return the local input that this node
  needs to operate. Not all nodes need input, in fact, most do not. This is
  used most commonly on the node representing a player. This input will
  be passed into `_network_process()`.

- `_predict_remote_input(previous_input: Dictionary, ticks_since_real_input: int) -> Dictionary`:
  Return predicted remote input based on the input from the previous tick,
  which may itself be predicted. If this method isn't provided, the same
  input from the last tick will be used as-is.  This input will be passed
  into `_network_process()` when using predicted input.

- `_network_process(delta: float, input: Dictionary) -> void`: Process this
  node for the current tick. The input will contain data from either
  `_get_local_input()` (if it's real user input) or `_predict_remote_input()`
  (if it's predicted). If this doesn't implement those methods it'll always
  be empty.
 
The following methods are only called on scenes that are spawned/de-spawned
using `SyncManager.spawn()` and `SyncManager.despawn()`:

- `_network_spawn_preprocess(data: Dictionary) -> Dictionary`: Pre-processes
  the data passed to `SyncManager.spawn()` before it gets passed to
  `_network_spawn()`. The modified data returned by this method is what will
  get saved in state. This allows nodes to developer-friendly data in
  `SyncManager.spawn()` and this method can convert it into data that is
  better to be stored in state.

- `_network_spawn(data: Dictionary) -> void`: Called when a scene is spawned
  by `SyncManager.spawn()` or in rollback when this node needs to be
  respawned (ie. when we rollback to a tick before this node was despawned).

- `_network_despawn() -> void`: Called when a node is despawned by
  `SyncManager.despawn()` or in rollback when this node needs to be despawned
  (ie. when we rollback to a tick before this node was spawned).

### Project settings ###

The recommended way to configure `SyncManager` is via project settings
(although, you can change its properties at runtime as well).

You can find its project settings under **Network** -> **Rollback**, after the
plugin is enabled.

**TODO: add screenshot **

**TODO: Describe each setting **

### Adaptor classes ###

There are a few adaptor classes that can be used to modify the behavior of
`SyncManager`.

#### `NetworkAdaptor` ####

**TODO**

Parent class: `res://addons/godot-rollback-netcode/NetworkAdaptor.gd`

Default implementation: `res://addons/godot-rollback-network/RPCNetworkAdaptor.gd`

#### `MessageSerializer` ####

**TODO**

Parent class and default implementation: `res://addons/godot-rollback-netcode/MessageSerializer.gd`

#### `HashSerializer` ####

**TODO**

Parent class and default implementation: `res://addons/godot-rollback-netcode/HashSerializer.gd`

### "Log inspector" tool in Godot editor: ###

**TODO**

The most common "match flow"
----------------------------

While there's sure to be edge cases, this is this most common "match flow", or
the process your game goes through to start, play and stop a match using this
addon:

1. Get all players connected via Godot's
   [High-Level Multiplayer API](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)

2. Call `SyncManager.add_peer()` for each peer in the patch.

3. Initialize the match to its initial state on all clients. Sharing match
   configuration and letting the "host" know when each client is ready to
   start can be done using Godot RPC mechanism.

4. Call `SyncManager.start()` on the game's "host"

5. Begin the match in all clients in response to the "sync_started" signal.

6. When the match is over, call `SyncManager.stop()` on the game's "host". (If
   a client needs to leave the match early, they should inform the other
   clients via an RPC or some other mechanism, and then call
   `SyncManager.stop()` locally.)

7. Clean-up after the match in all clients in response to the "sync_stopped"
   signal.

8. If these same players wish to play another match (which can be worked out
   over RPC), then return to step nr 2.

9. If this client wishes to disconnect from these players entirely, call
   `SyncManager.clear_peers()` and disconnect from the High-Level Multiplayer
   API, possibly via `get_tree().multiplayer.close_connection()` (with ENet)
   or `get_tree.multiplayer.close()` (with WebRTC).

It's also a good idea to connect to the "sync_lost", "sync_regained" and
"sync_error" signals so you can provide the player with useful error messages
if something goes wrong.

If you are logging, you'll want to call `SyncManager.start_logging()` just
before calling `SyncManager.start()` and just after calling
`SyncManager.stop()`. The logs are meant to contain data from just a single
match, which is what the "Log inspector" tool will expect.

License
-------

Copyright 2021-2022 David Snopek.

Licensed under the [MIT License](LICENSE.txt).


