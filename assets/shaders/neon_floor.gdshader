// Feld im Neon-Stil: fast durchsichtiger violetter Boden mit leuchtendem Gitter.
// Blockierte Felder bleiben leer, ihre Ränder bekommen eine hellere Neonlinie.
// Andere Stile (FieldStyle) setzen nur Parameter: ohne weißen Kern und Lichthof wirkt das Raster
// wie gemalt (Druidenhain über Gras), mit Marmor, doppelten Hauptlinien und Rauten wie Art déco.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://assets/shaders/neon_floor.gdshaderinc"
