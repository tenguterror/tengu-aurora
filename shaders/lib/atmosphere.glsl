// ============================================================================
//  Sky, light colours, clouds  (per-dimension)
// ============================================================================
#ifndef ATMOSPHERE_GLSL
#define ATMOSPHERE_GLSL

// ---------------------------------------------------------------- OVERWORLD --
#if defined OVERWORLD

vec3 sunlightColor(float sy) {
    float t = smoothstep(-0.02, 0.45, sy);
    vec3 golden = vec3(1.0, 0.46, 0.17) * 1.9;
    vec3 noon   = vec3(1.0, 0.94, 0.85) * 3.3;
    return mix(golden, noon, t) * smoothstep(-0.07, 0.05, sy);
}

vec3 moonlightColor(float sy) {
    float phase = abs(float(moonPhase) - 4.0) / 4.0;   // 1 = full moon
    return vec3(0.46, 0.60, 1.0) * 0.62 * (0.55 + 0.45 * phase) * smoothstep(-0.07, 0.05, -sy);
}

uniform float auroraBiome;

// 0..1 how strongly the aurora is showing right now
float auroraVisibility() {
    #ifdef AURORA
        #ifdef AURORA_EVERYWHERE
        float biome = 1.0;
        #else
        float biome = auroraBiome;
        #endif
        return smoothstep(-0.04, -0.22, sunDirW().y) * (1.0 - rainStrength) * biome * AURORA_BRIGHTNESS;
    #else
        return 0.0;
    #endif
}

// colour of the shadow-casting light (sun by day, moon by night)
vec3 getDirectColor() {
    float sy = sunDirW().y;
    vec3 c = sunlightColor(sy) + moonlightColor(sy);
    return c * (1.0 - rainStrength * 0.82) * SUN_BRIGHTNESS;
}

vec3 getAmbientColor() {
    float sy = sunDirW().y;
    vec3 night = vec3(0.14, 0.20, 0.38) * 0.75;
    vec3 dusk  = vec3(0.58, 0.44, 0.52) * 0.26;
    vec3 day   = vec3(0.40, 0.57, 1.00) * 0.62;
    vec3 c = mix(night, dusk, smoothstep(-0.22, 0.0, sy));
    c = mix(c, day, smoothstep(0.0, 0.38, sy));
    c = mix(c, vec3(luma(c)) * vec3(0.88, 0.95, 1.08) * 0.9, rainStrength * 0.45);
    c += vec3(0.03, 0.13, 0.08) * auroraVisibility();   // green glow on the snow
    return c;
}

vec3 skyGradient(vec3 d) {
    vec3 sd = sunDirW();
    float sy = sd.y;
    float day = smoothstep(-0.15, 0.25, sy);
    float up = saturate(d.y);
    float h = pow(1.0 - up, 3.5);

    vec3 zen = mix(vec3(0.006, 0.010, 0.030), vec3(0.085, 0.25, 0.86) * 1.3, day);
    vec3 hor = mix(vec3(0.020, 0.032, 0.070), vec3(0.58, 0.78, 1.10) * 1.3, day);
    vec3 col = mix(zen, hor, h);

    // sunrise / sunset band
    float cosS = dot(d, sd);
    float tw = smoothstep(-0.28, 0.0, sy) * (1.0 - smoothstep(0.02, 0.38, sy));
    float side = pow(cosS * 0.5 + 0.5, 2.5);
    // deeper ember orange/red toward the sun, dusky violet away from it
    vec3 twCol = mix(vec3(0.46, 0.22, 0.60), vec3(1.95, 0.52, 0.10), side);
    twCol = mix(twCol, vec3(2.1, 0.32, 0.06), pow(side, 6.0) * 0.6);
    col = mix(col, twCol * (0.55 + 0.6 * side), tw * pow(1.0 - up, 1.6) * (0.70 + 0.30 * side));

    // mie halo around the sun + faint one around the moon
    col += sunlightColor(sy) * hgPhase(cosS, 0.80) * 0.14 * (1.0 - rainStrength * 0.8);
    col += vec3(0.30, 0.42, 0.75) * hgPhase(-cosS, 0.85) * 0.010 * smoothstep(0.05, -0.15, sy);

    // ground darkening below the horizon
    col *= mix(1.0, 0.22, smoothstep(0.0, -0.35, d.y));

    // overcast
    col = mix(col, vec3(luma(col)) * vec3(0.82, 0.9, 1.05) * 0.75, rainStrength * 0.6);
    return col;
}

vec3 starField(vec3 d, float density, float scale) {
    vec3 p = d * scale;
    vec3 i = floor(p);
    vec3 f = fract(p) - 0.5;
    float h = hash13(i);
    float star = step(1.0 - density, h) * smoothstep(0.32, 0.0, length(f));
    float tw = 0.65 + 0.35 * sin(frameTimeCounter * (2.0 + h * 4.0) + h * 80.0);
    vec3 tint = mix(vec3(0.65, 0.78, 1.0), vec3(1.0, 0.82, 0.62), hash13(i + 7.0));
    return tint * star * tw;
}

vec3 celestial(vec3 d) {
    vec3 sd = sunDirW();
    float sy = sd.y;
    vec3 col = vec3(0.0);

    // sun disk with limb darkening
    float cosS = dot(d, sd);
    float sunDisk = smoothstep(0.99955, 0.99975, cosS);
    col += sunlightColor(sy) * sunDisk * 60.0 * (1.0 - rainStrength);

    // moon disk with craters and phase
    vec3 md = -sd;
    float cosM = dot(d, md);
    if (cosM > 0.9990) {
        vec3 right = normalize(cross(md, vec3(0.0, 0.0, 1.0) + vec3(1e-4)));
        vec3 upv = cross(right, md);
        vec2 lp = vec2(dot(d - md, right), dot(d - md, upv)) / 0.0443;  // disk radius ~ 1
        float r = length(lp);
        float disk = smoothstep(1.0, 0.92, r);
        float crater = 0.75 + 0.25 * fbm2(lp * 3.0 + 11.0);
        float phase = float(moonPhase) / 8.0 * TAU;
        vec3 sph = vec3(lp, sqrt(max(1.0 - r * r, 0.0)));
        float lit = smoothstep(-0.05, 0.12, dot(sph, normalize(vec3(sin(phase), 0.0, cos(phase)))));
        col += vec3(0.80, 0.86, 1.0) * disk * crater * (0.04 + 1.6 * lit) * (1.0 - rainStrength);
    }

    // stars
    float nightF = smoothstep(0.02, -0.18, sy) * (1.0 - rainStrength);
    col += starField(d, 0.0028, 220.0) * 0.9 * nightF * smoothstep(0.0, 0.15, d.y);
    return col;
}

// --- volumetric cumulus layer -----------------------------------------------
const float CLOUD_Y0 = 195.0;
const float CLOUD_Y1 = 290.0;

float cloudDensity(vec3 p, bool detail) {
    float t = frameTimeCounter;
    vec2 wind = vec2(t * 3.2, t * 1.1);
    float h = (p.y - CLOUD_Y0) / (CLOUD_Y1 - CLOUD_Y0);
    float base = fbm2((p.xz + wind) * 0.00085);
    float cov = CLOUD_COVERAGE + rainStrength * 0.30;
    float d = base - (1.0 - cov) - h * h * 0.30;
    d *= smoothstep(0.0, 0.12, h) * smoothstep(1.0, 0.75, h);
    if (detail && d > 0.0) {
        d -= noise3(vec3(p.x + wind.x, p.y, p.z + wind.y) * 0.022) * 0.10;
    }
    return saturate(d * 5.0);
}

vec4 renderClouds(vec3 d, vec3 ro, float dither, int steps) {
    if (abs(d.y) < 0.002) return vec4(0.0, 0.0, 0.0, 1.0);
    float t0 = (CLOUD_Y0 - ro.y) / d.y;
    float t1 = (CLOUD_Y1 - ro.y) / d.y;
    float tn = max(min(t0, t1), 0.0);
    float tf = max(t0, t1);
    if (tf <= 0.0 || tn > 9000.0) return vec4(0.0, 0.0, 0.0, 1.0);
    tf = min(tf, tn + 1200.0);

    float stepL = (tf - tn) / float(steps);
    vec3 L = lightDirW();
    // night clouds were glowing white under the boosted night exposure: keep them moonlit grey
    float cloudNight = mix(0.45, 1.0, smoothstep(-0.15, 0.05, sunDirW().y));
    vec3 lightCol = getDirectColor() * cloudNight;
    vec3 ambTop = getAmbientColor() * 1.15 * cloudNight;
    vec3 ambBot = ambTop * 0.45;

    float cosT = dot(d, L);
    float phase = mix(hgPhase(cosT, 0.6), hgPhase(cosT, -0.25), 0.3) * 4.0 * PI;
    // forward peak (~7x) made clouds beside the moon glow white: cap it at night only
    phase = mix(min(phase, 1.4), phase, smoothstep(-0.15, 0.05, sunDirW().y));

    float trans = 1.0;
    vec3 scat = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        vec3 p = ro + d * (tn + (float(i) + dither) * stepL);
        float dens = cloudDensity(p, true);
        if (dens < 0.004) continue;

        float od = 0.0;
        for (int j = 1; j <= 3; j++) {
            od += cloudDensity(p + L * (float(j) * float(j) * 9.0), false) * float(j) * 9.0;
        }
        float lightT = exp(-od * 0.055) + 0.25 * exp(-od * 0.012);
        float powder = 1.0 - exp(-dens * 4.0);
        float h = saturate((p.y - CLOUD_Y0) / (CLOUD_Y1 - CLOUD_Y0));

        vec3 S = lightCol * lightT * phase * mix(0.7, 1.0, powder) * 0.55 + mix(ambBot, ambTop, h);
        float stepT = exp(-dens * stepL * 0.05);
        scat += trans * S * (1.0 - stepT);
        trans *= stepT;
        if (trans < 0.02) break;
    }

    float fade = exp(-tn * 0.00028) * smoothstep(0.0, 0.06, d.y);
    return vec4(scat * fade, mix(1.0, trans, fade));
}

// Curtains of light: march a stack of horizontal layers, each a warped ridged band
vec3 renderAurora(vec3 d, float dither) {
    float vis = auroraVisibility();
    if (vis < 0.005 || d.y < 0.02) return vec3(0.0);
    float t = frameTimeCounter * 0.045;
    vec3 col = vec3(0.0);
    const int LAYERS = 20;
    for (int i = 0; i < LAYERS; i++) {
        float fi = (float(i) + dither) / float(LAYERS);
        float h = 1.0 + fi * 0.7;
        vec2 p = d.xz / d.y * h * 0.55;
        vec2 q = p + vec2(noise2(p * 0.45 + t), noise2(p * 0.45 - t + 7.0)) * 1.3;
        float band = 1.0 - abs(noise2(vec2(q.x * 0.75 + t * 0.6, q.y * 0.22)) * 2.0 - 1.0);
        band = pow(band, 11.0);
        float rays = 0.55 + 0.45 * noise2(vec2(q.x * 14.0, q.y * 0.6 + t * 5.0));
        vec3 c = mix(vec3(0.08, 1.0, 0.42), vec3(0.55, 0.18, 1.0), smoothstep(0.25, 0.95, fi));
        c = mix(c, vec3(1.0, 0.25, 0.55), smoothstep(0.85, 1.0, fi) * 0.5);
        col += c * band * rays * (1.0 - fi * 0.7);
    }
    return col * 0.075 * vis * smoothstep(0.02, 0.22, d.y);
}

// mode 0: full sky (celestial + clouds), 1: gradient only, 2: cheap clouds (reflections)
vec3 getSky(vec3 d, float dither, int mode) {
    vec3 col = skyGradient(d);
    if (mode == 0) col += celestial(d);
    vec3 aurora = mode != 1 ? renderAurora(d, dither) : vec3(0.0);
    #ifdef CLOUDS
    if (mode != 1 && d.y > 0.0) {
        vec4 cl = renderClouds(d, cameraPosition + gbufferModelViewInverse[3].xyz, dither, mode == 0 ? CLOUD_STEPS : 8);
        // the aurora sits far above the cloud deck: even thin cloud should hide most of it
        col = (col + aurora * cl.a * cl.a) * cl.a + cl.rgb;
        return col;
    }
    #endif
    return col + aurora;
}

// ------------------------------------------------------------------- NETHER --
#elif defined NETHER

vec3 netherTint() {
    vec3 f = toLinear(fogColor);
    return f / max(max(f.r, max(f.g, f.b)), 1e-3);   // hue of the biome fog, normalised
}

vec3 getDirectColor()  { return vec3(0.0); }
vec3 getAmbientColor() { return mix(vec3(0.90, 0.50, 0.32), netherTint(), 0.30) * 0.15; }

vec3 getSky(vec3 d, float dither, int mode) {
    vec3 base = mix(vec3(0.60, 0.30, 0.18), netherTint(), 0.30) * 0.05;
    float n = fbm3(d * 3.0 + vec3(0.0, frameTimeCounter * 0.02, 0.0));
    return base * (0.7 + 0.6 * n);
}

// ---------------------------------------------------------------------- END --
#elif defined END

vec3 getDirectColor()  { return vec3(0.72, 0.55, 1.0) * 1.15 * SUN_BRIGHTNESS; }
vec3 getAmbientColor() { return vec3(0.34, 0.25, 0.52) * 0.30; }

vec3 starField(vec3 d, float density, float scale) {
    vec3 p = d * scale;
    vec3 i = floor(p);
    vec3 f = fract(p) - 0.5;
    float h = hash13(i);
    float star = step(1.0 - density, h) * smoothstep(0.32, 0.0, length(f));
    float tw = 0.6 + 0.4 * sin(frameTimeCounter * (1.5 + h * 3.0) + h * 60.0);
    vec3 tint = mix(vec3(0.75, 0.6, 1.0), vec3(0.6, 1.0, 0.95), hash13(i + 3.0));
    return tint * star * tw;
}

vec3 getSky(vec3 d, float dither, int mode) {
    float t = frameTimeCounter * 0.004;
    vec3 col = vec3(0.012, 0.007, 0.024);

    // swirling nebula
    vec3 q = d * 2.2 + vec3(t, 0.0, -t);
    float n1 = fbm3(q);
    float n2 = fbm3(q * 2.1 + n1 * 1.5);
    float neb = pow(saturate(n2 * 1.25 - 0.25), 2.5);
    vec3 nebCol = mix(vec3(0.55, 0.16, 0.85), vec3(0.10, 0.65, 0.75), smoothstep(0.35, 0.7, n1));
    col += nebCol * neb * 0.55;

    // galactic band
    float band = exp(-sqr(dot(d, normalize(vec3(0.35, 0.25, 1.0))) * 4.0));
    col += vec3(0.30, 0.18, 0.45) * band * 0.10 * (0.6 + n1);

    col += starField(d, 0.006, 160.0) * 0.9;
    col += starField(d, 0.003, 320.0) * 0.6;

    // the "void star" the god rays come from
    if (mode != 1) {
        vec3 L = lightDirW();
        float c = dot(d, L);
        col += vec3(0.85, 0.65, 1.0) * (smoothstep(0.9993, 0.9997, c) * 25.0 + hgPhase(c, 0.92) * 0.10 + hgPhase(c, 0.6) * 0.03);
    }
    return col;
}

#endif

#endif
