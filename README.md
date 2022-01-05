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

I'm working on a series of video tutorials on YouTube. I'll post a link to the
playlist once the first is finished!

Installing
----------

This addon is implement as an editor plugin.

If you've never installed a plugin before, please see
[official docs on how to install plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html)

However, the sort version is:

1. Copy `addons/godot-rollback-netcode` directory from this project copied
into your Godot project *at the exact same path*, that is
`addons/godot-rollback-netcode`.

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
   the addon. It should be added to your project automatically when you enable
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

**TODO**

#### Methods: ####

 - add_peer()
 - start()
 - stop()
 - clear_peers()
 - start_logging()
 - stop_logging()
 - spawn()
 - despawn()
 - play_sound()

**TODO**

#### Signals: ####

 - sync_started
 - sync_stopped
 - sync_lost
 - sync_regained
 - sync_error
 - scene_spawned
 - interpolation_frame
 
**TODO**

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

1. Get all players connected via Godot's High-Level Multiplayer API

2. Initialize the game to its initial state on all clients.

3. Call `SyncManager.start()`

4. In response to the `sync


License
-------

Copyright 2021-2022 David Snopek.

Licensed under the [MIT License](LICENSE.txt).


