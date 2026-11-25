shader_type canvas_item;

// Colors with alpha support (using source_color for the Inspector color picker)
uniform vec4 start_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Default Red
uniform vec4 end_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);   // Default Blue

// Control points in UV space (0.0 to 1.0) defining the gradient line
uniform vec2 start_point = vec2(0.0, 0.0);
uniform vec2 end_point = vec2(1.0, 1.0);

void fragment() {
    vec2 ba = end_point - start_point;
    float l2 = dot(ba, ba);
    
    float t = 0.0;
    if (l2 > 0.00001) {
        // Project current pixel UV onto the line vector between start and end
        t = dot(UV - start_point, ba) / l2;
    }
    
    // Clamp t between 0 and 1 so the gradient stays strictly between the points
    t = clamp(t, 0.0, 1.0);
    
    // Interpolate between start and end colors (handles RGBA / alpha transparency)
    vec4 final_color = mix(start_color, end_color, t);
    
    COLOR = final_color;
}