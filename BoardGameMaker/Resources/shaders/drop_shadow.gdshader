shader_type canvas_item;

// Shadow (and optional side edge) for a SEPARATE node that sits behind the card
// and is `margin` pixels larger than the card on every side (CardShadow.gd sets
// all of this up). The card itself is never scaled, padded or modified.
//
// object_thickness:
//  - Shadow: instead of a single flat silhouette, the shadow is the silhouette
//    swept along the light direction by `object_thickness` px, like the shadow
//    of a slab rather than a sheet of paper.
//  - Edge (optional, edge_color.a > 0): the card's silhouette is extruded by
//    `object_thickness` px along `edge_dir`, giving the card a visible side.

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform vec2 card_size = vec2(100.0);   // size of the card in px (local space)
uniform float margin = 32.0;            // how much larger this node is than the card, per side
uniform vec2 shadow_offset = vec2(6.0, 6.0); // px, in the card's local space
uniform float shadow_blur : hint_range(0.0, 128.0, 0.1) = 6.0; // px
uniform float shadow_strength : hint_range(0.0, 4.0, 0.01) = 1.0;

group_uniforms thickness;
uniform float object_thickness : hint_range(0.0, 64.0, 0.1) = 0.0; // px
uniform vec2 shadow_dir = vec2(0.0, 1.0);  // unit vector, local space: direction the shadow is swept in
uniform vec4 edge_color : source_color = vec4(0.0); // alpha 0 = no visible edge
uniform vec2 edge_dir = vec2(0.0, 1.0);    // unit vector, local space: direction the side is extruded in

// Quality knobs.
const int DISK = 16;        // blur samples per step
const int STEPS = 4;        // steps along the thickness sweep (only used when thickness > 0)
const int EDGE_STEPS = 8;   // steps used to extrude the edge
const float GOLDEN_ANGLE = 2.39996323;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

float alpha_at(sampler2D tex, vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(tex, uv).a * inside.x * inside.y;
}

// Average alpha over a spiral (Vogel) disk of radius `radius` (in UV units per axis).
float blurred_alpha(sampler2D tex, vec2 uv, vec2 radius) {
	if (radius.x < 0.00001 && radius.y < 0.00001) {
		return alpha_at(tex, uv);
	}
	float a = 0.0;
	for (int i = 0; i < DISK; i++) {
		float r = sqrt((float(i) + 0.5) / float(DISK));
		float ang = float(i) * GOLDEN_ANGLE;
		a += alpha_at(tex, uv + vec2(cos(ang), sin(ang)) * r * radius);
	}
	return a / float(DISK);
}

void fragment() {
	// Map this larger node's UV back to the card's 0..1 UV space.
	vec2 uv = (UV - 0.5) * ((card_size + 2.0 * margin) / card_size) + 0.5;
	vec2 px = 1.0 / card_size; // one pixel in card UV units

	// --- Shadow: silhouette swept from the base position along shadow_dir ---
	vec2 shadow_uv = uv - shadow_offset * px;
	float sh = 0.0;
	for (int s = 0; s < STEPS; s++) {
		if (s > 0 && object_thickness <= 0.01) {
			break;
		}
		float d = object_thickness * float(s) / float(STEPS - 1);
		sh = max(sh, blurred_alpha(TEXTURE, shadow_uv - shadow_dir * d * px, shadow_blur * px));
	}
	sh = clamp(sh * shadow_strength, 0.0, 1.0) * shadow_color.a * vertex_color.a;

	// --- Edge: card silhouette extruded along edge_dir (hidden under the card itself) ---
	float ea = 0.0;
	if (edge_color.a > 0.0 && object_thickness > 0.01) {
		for (int k = 0; k < EDGE_STEPS; k++) {
			float d = object_thickness * float(k) / float(EDGE_STEPS - 1);
			ea = max(ea, alpha_at(TEXTURE, uv - edge_dir * d * px));
		}
		ea *= edge_color.a * vertex_color.a;
	}

	// Edge over shadow.
	float out_a = ea + sh * (1.0 - ea);
	vec3 out_rgb = (edge_color.rgb * ea + shadow_color.rgb * sh * (1.0 - ea)) / max(out_a, 0.00001);
	COLOR = vec4(out_rgb, out_a);
}
