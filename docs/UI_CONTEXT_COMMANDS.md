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

## Primitive: ein eigenes Context Menu

Ein Primitive-Component besitzt weder Points noch Chains, also gilt für ihn
keine der Bezier-Zeilen. Sein Context Bar trägt genau zwei Commands, und sein
Info Bar zeigt nie einen Handle-Modus:

| Command | `active_context_command` | Info-Leiste |
| --- | --- | --- |
| `⌘1  Create Primitive` | `asset.create_primitive` | `1: Circle`, `2: Rectangle`, `3: Triangle` |
| `⌘2  Transform` | `asset.transform` | `1: Translate`, `2: Rotate`, `3: Scale` |

`⌘1` beansprucht den Canvas, zeichnet aber noch nichts: Erst die Formwahl
startet die Preview. Diese läuft dann in zwei Schritten — der erste Klick setzt
den Mittelpunkt, der zweite die Größe und bestätigt damit. `Esc` geht einen
Schritt zurück, von der Größe auf den Mittelpunkt und erst von dort aus dem
Command heraus. Solange nichts bestätigt ist, erreicht auch nichts das
Dokument.

`⌘2` arbeitet auf dem Component-Transform, demselben, mit dem jeder andere
Component verschoben, gedreht und skaliert wird. Beide Commands folgen Regel 5
oben: Ihre Zahlenauswahl ist ein Werkzeugmodus und lässt den Command aktiv.
