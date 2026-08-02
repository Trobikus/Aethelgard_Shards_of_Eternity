# Engine-Anforderungen

Aethelgard zielt auf **Godot 4.7.x** ab.

| | |
| --- | --- |
| Empfohlene Version | **4.7.1** stable |
| Renderer | Forward+ (Vulkan) |
| Sprache | GDScript |
| Physik | Godot Physics (Standard) |

## Upgrade-Hinweis (4.4 → 4.7)

Das Projekt wurde von `config/features` **4.4** auf **4.7** angehoben. Relevante Offizielle Guides:

- [Upgrading to 4.5](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.5.html)
- [Upgrading to 4.6](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.6.html)
- [Upgrading to 4.7](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html)

Für den aktuellen Prototyp-Code (CharacterBody3D, Area3D, NavigationAgent3D, Autoload-Signale) sind keine API-Umbrüche nötig. Nach dem ersten Öffnen mit 4.7 den Asset-Import abwarten und `.godot/` lokal neu erzeugen lassen (nicht committen).

## Lokal starten

1. Godot 4.7.1 herunterladen und installieren.
2. `project.godot` öffnen.
3. Hauptszene: `res://levels/test_level.tscn`.

## CI

GitHub Actions exportiert mit dem Image `barichello/godot-ci:4.7.1` und den Presets in `export_presets.cfg`.
