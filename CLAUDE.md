# Hinweise für Claude

## UI-Stil (Arcade), gilt für alles Neue
Lukas will, dass jede neue Oberfläche automatisch im Arcade-Stil gebaut wird, ohne dass er es extra sagen muss.
Alles kommt aus `scripts/ui/ui_theme.gd`, keine eigenen Farben oder Schriften erfinden:
- Panels: `UiTheme.panel(pad)`: eckig, pinker Rand (3 px), harter Cyan-Schatten.
- Überschriften: `UiTheme.title(label, size)`: Großbuchstaben, fett, pink mit Cyan-Schatten.
  Kleine Abschnittstitel: Großbuchstaben, fett (`UiTheme.font(true)`).
- Hauptaktion: `UiTheme.accent_button(...)`; ausgewählt/gedrückt: `UiTheme.box(UiTheme.CYAN, UiTheme.CYAN)` mit dunkler Schrift.
- Farben: `TEXT`, `MUTED`, `GOLD` (Akzent-Pink), `CYAN`, `COIN` (Goldbeträge), `HAVE` (grün), `MISSING` (rot), `PURPLE_LIGHT`.
- Schrift: DejaVu Sans Mono über das Theme (`UiTheme.get_theme()`), Ecken immer eckig.
- Lange Texte mit Autowrap, damit mit der breiten Monospace-Schrift nichts abgeschnitten wird.
- Alle sichtbaren Texte auf Deutsch schreiben und in `data/i18n/en.json` übersetzen.
