shader_type sky;
// Cielo HDRI Poly Haven (CC0): giorno (kloofendal_48d), alba/tramonto (qwantani_dawn), notte (qwantani_night).
uniform sampler2D panorama : filter_linear, repeat_enable;
uniform sampler2D panorama_dawn : filter_linear, repeat_enable;
uniform sampler2D panorama_night : filter_linear, repeat_enable;
uniform float day_energy = 1.0;
uniform float night = 0.0;
uniform float dusk = 0.0;
uniform float yaw = 0.0;
uniform float dawn_energy = 0.9;
uniform float night_energy = 0.45;
uniform vec3 night_tint = vec3(0.75, 0.85, 1.15);

void sky() {
	vec3 d = normalize(EYEDIR);
	float u = atan(d.x, -d.z) / 6.2831853 + 0.5;
	float v = acos(clamp(d.y, -1.0, 1.0)) / 3.14159265;
	vec2 uv = vec2(u + yaw, min(v, 0.499));
	vec3 c = texture(panorama, uv).rgb * day_energy;
	vec3 cd = texture(panorama_dawn, uv).rgb * dawn_energy;
	c = mix(c, cd, dusk);
	vec3 cn = texture(panorama_night, vec2(u, min(v, 0.499))).rgb * night_energy * night_tint;
	c = mix(c, cn, night);
	// sotto l'orizzonte niente terreno dell'HDRI: colore neutro
	if (d.y < 0.0) {
		vec3 g = mix(vec3(0.32, 0.31, 0.29) * day_energy, vec3(0.05, 0.06, 0.09), night);
		c = mix(c, g, clamp(-d.y * 6.0, 0.0, 1.0));
	}
	COLOR = c;
}
