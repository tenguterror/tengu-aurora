// ============================================================================
//  Wind animation for foliage
// ============================================================================
#ifndef WAVING_GLSL
#define WAVING_GLSL

vec3 waveOffset(vec3 wp, int id, bool top, float skyLm) {
    vec3 off = vec3(0.0);
    if (id < ID_GRASS || id > ID_GLOW_PLANT) return off;

    float t = frameTimeCounter * WAVE_SPEED;
    float gust = (0.55 + 0.45 * sin(t * 0.33 + wp.x * 0.017 + wp.z * 0.011));
    float wind = gust * (1.0 + rainStrength * 1.3) * WAVE_AMOUNT;
    #ifdef OVERWORLD
    float exposure = smoothstep(0.15, 0.7, skyLm);
    #else
    float exposure = 0.55;
    #endif

    float ph = wp.x * 0.45 + wp.z * 0.31;
    vec2 sway = vec2(sin(t * 1.7 + ph) + 0.4 * sin(t * 3.1 + ph * 1.7),
                     0.6 * cos(t * 1.3 + ph * 0.8) + 0.3 * sin(t * 2.6 - ph)) * wind;
    float flutter = sin(t * 7.0 + wp.x * 2.1 + wp.y * 1.3 + wp.z * 1.7);

    if (id == ID_GRASS || id == ID_CROPS || id == ID_GLOW_PLANT) {
        if (top) off.xz = sway * 0.075 + flutter * 0.012 * wind;
    } else if (id == ID_TALL_LOWER) {
        if (top) off.xz = sway * 0.05;
    } else if (id == ID_TALL_UPPER) {
        off.xz = sway * (top ? 0.11 : 0.05);
    } else if (id == ID_LEAVES) {
        off = vec3(sway.x * 0.032, flutter * 0.016 * wind, sway.y * 0.032);
    } else {
        off.xz = sway * 0.045;
    }
    return off * exposure;
}

#endif
