shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.14;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float grey = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 pigment = mix(source.rgb, vec3(grey), 0.48) * vec3(0.67, 0.61, 0.51);
	float edge = smoothstep(0.12, 0.72, length((UV - vec2(0.5)) * vec2(1.0, 0.8)));
	COLOR = vec4(pigment, source.a * strength * (1.0 - edge * 0.7));
}
