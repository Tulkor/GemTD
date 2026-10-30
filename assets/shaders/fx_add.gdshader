shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled, fog_disabled;

#define FX_ADD
#include "res://assets/shaders/fx_sprite.gdshaderinc"
