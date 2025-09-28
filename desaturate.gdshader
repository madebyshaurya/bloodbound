shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

// Godot 4 way to access screen texture
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 col = texture(screen_tex, SCREEN_UV);
    float gray = dot(col.rgb, vec3(0.3, 0.59, 0.11)); // weighted grayscale
    col.rgb = mix(col.rgb, vec3(gray), strength);
    COLOR = col;
}
