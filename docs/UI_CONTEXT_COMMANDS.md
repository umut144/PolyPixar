# Context-Command Vertrag

Alle transienten Auswahlmenüs im mittleren Context-Bar folgen demselben
Lifecycle. Das gilt für Geometry (Sampling, Seeding, Meshing, UV Mapping) und
Style → Weighting und ist für neue Module verbindlich.

1. `CMD`/`Ctrl` plus Nummer aktiviert den Command und öffnet das zugehörige
   `PopupMenu`.
2. Jeder Menüeintrag trägt seinen fachlichen Wert als Metadata. Der Callback
   liest die Metadata über `get_item_index(id)`; Menü-IDs dürfen nicht als
   Array-Indizes behandelt werden.
3. Die Auswahl delegiert ausschließlich an den fachlichen Setter. Dieser
   aktualisiert Modell, Preview und Bake-Status.
4. Nach einer Auswahl wird das Popup geschlossen und der transiente
   `active_context_command` gelöscht. Dasselbe geschieht bei Escape oder einem
   anderen Popup-Abbruch (`popup_hide`). Dadurch bleibt kein Menü optisch oder
   logisch „stuck“.
5. Direkte Plain-Number-Shortcuts dürfen den Command aktiv lassen, solange sie
   als Werkzeugmodus dienen. Eine Popup-Auswahl beendet ihn immer.

Neue Method-Menüs sollen `_connect_context_method_menu(...)` verwenden und
nicht eigene `id_pressed`- oder `popup_hide`-Logik implementieren.
