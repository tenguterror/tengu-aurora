// ============================================================================
//  Water waves, rain ripples, caustics
// ============================================================================
#ifndef WATER_GLSL
#define WATER_GLSL

float waterHeight(vec2 p) {
    float t = frameTimeCounter;
    float h = 0.0;
    h += sin(dot(p, vec2(0.82, 0.57)) * 0.9 + t * 1.25) * 0.28;
    h += sin(dot(p, vec2(-0.45, 0.89)) * 1.35 + t * 1.65) * 0.18;
    h += (noise2(p * 0.55 + vec2(t * 0.35, t * 0.22)) - 0.5) * 0.65;
    h += (noise2(p * 1.45 - vec2(t * 0.28, -t * 0.52)) - 0.5) * 0.34;
    h += (noise2(p * 3.70 + vec2(t * 0.75, -t * 0.18)) - 0.5) * 0.12;
    return h * WATER_WAVE_HEIGHT;
}

// Expanding rings from raindrops, returns a 2D slope
vec2 rainRipples(vec2 p) {
    vec2 grad = vec2(0.0);
    float t = frameTimeCounter;
    for (int k = 0; k < 2; k++) {
        vec2 q = p * (1.6 + float(k) * 0.7) + float(k) * 7.31;
        vec2 i = floor(q);
        vec2 f = fract(q);
        vec2 c = 0.25 + 0.5 * hash22(i);
        float ph = fract(t * 0.9 + hash12(i + 3.7));
        vec2 dv = f - c;
        float r = length(dv);
        float ring = sin((r - ph * 0.55) * 42.0) * smoothstep(0.08, 0.0, abs(r - ph * 0.55)) * (1.0 - ph);
        grad += dv / max(r, 1e-3) * ring;
    }
    return grad * rainStrength;
}

vec3 waterNormal(vec3 wp, float strength) {
    vec2 p = wp.xz;
    const float e = 0.08;
    float h0 = waterHeight(p);
    float hx = waterHeight(p + vec2(e, 0.0));
    float hz = waterHeight(p + vec2(0.0, e));
    vec2 slope = vec2(hx - h0, hz - h0) / e * strength;
    slope += rainRipples(p) * 0.35;
    return normalize(vec3(-slope.x, 1.0, -slope.y));
}

float worleyEdge(vec2 p, float t) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float d1 = 8.0;
    float d2 = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = vec2(float(x), float(y));
            vec2 o = hash22(i + g);
            o = 0.5 + 0.42 * sin(t + TAU * o);
            float d = length(g + o - f);
            if (d < d1) { d2 = d1; d1 = d; }
            else if (d < d2) { d2 = d; }
        }
    }
    return d2 - d1;
}

// ~1.0 on average, bright caustic lines
float causticsPattern(vec3 wp, float depth) {
    vec2 p = wp.xz * 0.62 + wp.y * 0.13;
    float t = frameTimeCounter * 0.9;
    float a = 1.0 - smoothstep(0.0, 0.16, worleyEdge(p, t));
    float b = 1.0 - smoothstep(0.0, 0.16, worleyEdge(p * 1.43 + vec2(3.1, 7.7), t * 1.27));
    float c = 0.32 + (a * a + b * b) * 1.25;
    return mix(1.0, c, smoothstep(0.0, 1.2, depth));
}

#endif
