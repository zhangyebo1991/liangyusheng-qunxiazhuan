# Godot Base Framework Design

Date: 2026-05-08
Project: liangyusheng-qunxiazhuan
Engine target: Godot 4.6

## Goal

Create the first Godot 4.6 project framework for a free single-player wuxia RPG in the style of classic open-ended martial arts RPGs.

The framework should be runnable in Godot after the engine is installed, easy for AI-assisted development to modify, and structured for a future vertical slice containing exploration, dialogue, quests, battle, rewards, and save/load.

## Scope

This change creates the foundation only:

- Godot project configuration and boot scene.
- Minimal placeholder scenes for boot, main menu, world, and battle.
- Global core services for event dispatch, game state, scene changes, and data loading.
- Domain classes for actor, item, martial art, quest, party, and combat result data.
- System classes for dialogue, quests, combat flow, and saves.
- Example JSON data for actors, items, martial arts, quests, and dialogue.
- Lightweight GDScript test runner and tests for pure logic.
- Developer documentation for structure and next steps.

This change does not create final art, final UI, full combat rules, real maps, or production content.

## Architecture

The project separates game rules from scene presentation:

- `scripts/domain/` contains small data and rule objects with no scene dependencies.
- `scripts/systems/` contains workflow services such as data loading, quests, dialogue, combat, and saves.
- `scripts/core/` contains global wiring: event bus, game state, scene manager, and bootstrap.
- `scenes/` contains Godot scenes that call systems and render placeholder UI.
- `data/` contains editable JSON content used by the initial systems.
- `tests/` contains logic tests that can run from the command line or Godot editor.

Scene nodes should depend on systems. Systems may depend on domain classes. Domain classes should not depend on scenes.

## Data Flow

On startup, the boot scene initializes global services and loads JSON data. The main menu can start a new game, which creates default game state and switches to the world scene. The world scene demonstrates dialogue and quest state. The battle scene demonstrates entering and resolving a simple combat flow.

Save data is versioned so future schema changes can migrate old saves instead of breaking them silently.

## Error Handling

Data loading should fail loudly in development with clear push errors and safe empty results. Save/load should return success values instead of assuming disk writes always work.

Game systems should validate required IDs before mutating state. Missing content IDs should not crash unrelated scenes.

## Testing

The first tests focus on non-visual logic:

- Data loader can parse example content.
- Quest system can start and complete a quest.
- Combat flow can produce a deterministic result.
- Save system can serialize and deserialize basic game state.

Visual scenes are verified by opening the project in Godot once Godot 4.6 is installed.

## Implementation Notes

Use GDScript as the primary language. Avoid external plugins in the first framework pass. Keep files small and named in `snake_case.gd` to match Godot conventions.

The first runnable version should prefer simple placeholders over incomplete abstractions. Any future editor tooling for quests, actors, martial arts, and maps can be added after the vertical slice proves the data model.
