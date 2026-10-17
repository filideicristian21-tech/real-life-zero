shader_type sky;
// Cielo HDRI (Poly Haven, CC0) che si scurisce verso sera e diventa notte blu (#1B2235).
uniform sampler2D panorama : filter_linear, repeat_enable;
uniform float day_energy = 1.0;
uniform float night = 0.0;
uniform float dusk = 0.0;
uniform float yaw = 0.0;
uniform vec3 dusk_tint = vec3(1.0, 0.62, 0.45);
uniform vec3 night_top = vec3(0.06, 0.08, 0.15);
uniform vec3 night_hor = vec3(0.106, 0.133, 0.208);

void sky() {
	vec3 d = normalize(EYEDIR);
	float u = atan(d.x, -d.z) / 6.2831853 + 0.5 + yaw;
	float v = acos(clamp(d.y, -1.0, 1.0)) / 3.14159265;
	vec3 c = texture(panorama, vec2(u, min(v, 0.499))).rgb * day_energy;
	// sotto l'orizzonte niente terreno dell'HDRI: colore neutro
	if (d.y < 0.0) {
		c = mix(c, vec3(0.32, 0.31, 0.29) * day_energy, clamp(-d.y * 6.0, 0.0, 1.0));
	}
	float h = 1.0 - clamp(d.y * 3.0, 0.0, 1.0);
	c = mix(c, c * mix(vec3(1.0), dusk_tint, h), dusk);
	vec3 n = mix(night_hor, night_top, clamp(d.y * 1.5, 0.0, 1.0));
	// qualche stella fissa
	vec2 g = floor(vec2(u * 900.0, v * 450.0));
	float st = step(0.9985, fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453)) * step(0.0, d.y);
	n += vec3(st * 0.6);
	COLOR = mix(c, n, night);
}
