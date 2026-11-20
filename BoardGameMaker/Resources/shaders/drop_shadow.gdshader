shader_type canvas_item;

// Shadow (and optional side edge) for a SEPARATE node that sits behind the object
// and is `margin` pixels larger than the object on every side (ObjectShadow.gd sets
// all of this up). The object itself is never scaled, padded or modified.
//
// object_thickness:
//  - Shadow: the silhouette is swept along the light direction by `object_thickness`
//    px, like the shadow of a slab (or a whole stack) instead of a sheet of paper.
//    The number of sweep steps adapts to the thickness, so tall stacks stay solid.
//  - Edge (optional, edge_color.a > 0): the silhouette is extruded by `object_thickness`
//    px along `edge_dir`, giving the object a visible side.

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45); // alpha 0 = no shadow
uniform vec2 object_size = vec2(100.0); // size of the source in px (local space)
uniform float margin = 32.0;            // how much larger this node is than the source, per side
uniform vec2 shadow_offset = vec2(6.0, 6.0); // px, in the source's local space
uniform float shadow_blur : hint_range(0.0, 128.0, 0.1) = 6.0; // px
uniform float shadow_strength : hint_range(0.0, 4.0, 0.01) = 1.0;

group_uniforms thickness;
uniform float object_thickness : hint_range(0.0, 256.0, 0.1) = 0.0; // px
uniform vec2 shadow_dir = vec2(0.0, 1.0);  // unit vector, local space: direction the shadow is swept in
uniform vec4 edge_color : source_color = vec4(0.0); // alpha 0 = no visible edge
uniform vec2 edge_dir = vec2(0.0, 1.0);    // unit vector, local space: direction the side is extruded in

// Quality knobs.
const int DISK = 16;         // blur samples per step (few sweep steps)
const int DISK_LOW = 8;      // blur samples per step (many sweep steps)
const int MAX_STEPS = 24;    // max steps along the thickness sweep
const int EDGE_STEPS = 8;    // steps used to extrude the edge
const float GOLDEN_ANGLE = 2.39996323;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

float alpha_at(sampler2D tex, vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(tex, uv).a * inside.x * inside.y;
}

// Average alpha over a spiral (Vogel) disk of radius `radius` (UV units per axis).
float blurred_alpha(sampler2D tex, vec2 uv, vec2 radius, int count) {
	if (radius.x < 0.00001 && radius.y < 0.00001) {
		return alpha_at(tex, uv);
	}
	float a = 0.0;
	for (int i = 0; i < DISK; i++) {
		if (i >= count) {
			break;
		}
		float r = sqrt((float(i) + 0.5) / float(count));
		float ang = float(i) * GOLDEN_ANGLE;
		a += alpha_at(tex, uv + vec2(cos(ang), sin(ang)) * r * radius);
	}
	return a / float(count);
}

void fragment() {
	// Map this larger node's UV back to the source's 0..1 UV space.
	vec2 uv = (UV - 0.5) * ((object_size + 2.0 * margin) / object_size) + 0.5;
	vec2 px = 1.0 / object_size; // one pixel in source UV units

	// --- Shadow: silhouette swept from the base position along shadow_dir ---
	float sh = 0.0;
	if (shadow_color.a > 0.0) {
		vec2 shadow_uv = uv - shadow_offset * px;
		int steps = 1;
		if (object_thickness > 0.01) {
			float spacing = max(shadow_blur * 0.5, 2.0); // px between sweep steps
			steps = clamp(int(ceil(object_thickness / spacing)) + 1, 2, MAX_STEPS);
		}
		int disk = steps > 4 ? DISK_LOW : DISK;
		for (int s = 0; s < MAX_STEPS; s++) {
			if (s >= steps) {
				break;
			}
			float d = steps > 1 ? object_thickness * float(s) / float(steps - 1) : 0.0;
			sh = max(sh, blurred_alpha(TEXTURE, shadow_uv - shadow_dir * d * px, shadow_blur * px, disk));
		}
		sh = clamp(sh * shadow_strength, 0.0, 1.0) * shadow_color.a * vertex_color.a;
	}

	// --- Edge: silhouette extruded along edge_dir (hidden under the object itself) ---
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