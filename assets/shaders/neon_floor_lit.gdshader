// Feld im Neon-Stil: fast durchsichtiger violetter Boden mit leuchtendem Gitter.
// Blockierte Felder bleiben leer, ihre Ränder bekommen eine hellere Neonlinie.
// Andere Stile (FieldStyle) setzen nur Parameter: ohne weißen Kern und Lichthof wirkt das Raster
// wie gemalt (Druidenhain über Gras), mit Marmor, doppelten Hauptlinien und Rauten wie Art déco.
shader_type spatial;
// Beleuchtete Fassung (FieldStyle "floor_lit"): deckend, nimmt Sonne, Schatten und Treffer-Lichter an.
#define LIT
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/neon_floor.gdshaderinc"
