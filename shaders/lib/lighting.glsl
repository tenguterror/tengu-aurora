// ============================================================================
//  Surface lighting shared by deferred + forward passes
//  requires: common, atmosphere, (shadow when not NETHER)
// ============================================================================
#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL

vec3 getBlockLight(float bl) {
    vec3 torch = vec3(1.0, 0.55, 0.22);
    float f = pow(bl, 3.4) * 2.7 + pow(bl, 1.5) * 0.07;
    return torch * f * BLOCKLIGHT_BRIGHTNESS;
}

vec3 getHandLight(vec3 playerPos) {
    float hl = float(max(heldBlockLightValue, heldBlockLightValue2));
    if (hl < 0.5) return vec3(0.0);
    float f = saturate((hl - length(playerPos)) / 15.0);
    return getBlockLight(f);
}

float getEmissiveScale(int id) {
    if (id == ID_LAVA) return 4.5;
    if (id == ID_FIRE) return 5.0;
    if (id == ID_ORE) return 2.2;
    if (id == ID_END_PORTAL) return 6.0;
    return 4.0;
}

vec3 specularGGX(vec3 n, vec3 v, vec3 l, float rough, float f0) {
    vec3 h = normalize(v + l);
    float NdH = saturate(dot(n, h));
    float NdL = saturate(dot(n, l));
    float NdV = max(dot(n, v), 1e-3);
    float a = rough * rough;
    float a2 = a * a;
    float dd = NdH * NdH * (a2 - 1.0) + 1.0;
    float D = a2 / (PI * dd * dd);
    float k = a * 0.5;
    float G = NdL / (NdL * (1.0 - k) + k) * NdV / (NdV * (1.0 - k) + k);
    float F = f0 + (1.0 - f0) * pow(1.0 - saturate(dot(h, v)), 5.0);
    return vec3(min(D * G * F / (4.0 * NdV), 60.0));
}

// Lit colour without emission. directVis returns the light visibility (rgb)
vec3 shadeSurface(vec3 albedo, vec3 nW, vec2 lm, vec3 playerPos, float ao, float sss,
                  float dither, bool doShadow, out vec3 directVis) {
    vec3 direct = vec3(0.0);
    vec3 amb;
    directVis = vec3(0.0);

    #if defined OVERWORLD || defined END
        vec3 L = lightDirW();
        float NdL = dot(nW, L);
        float diff = mix(saturate(NdL), 0.30 + 0.45 * abs(NdL), sss);
        #ifdef OVERWORLD
        float skyGate = smoothstep(0.02, 0.30, lm.y);
        #else
        float skyGate = 1.0;
        #endif
        vec3 vis;
        if (doShadow && (NdL > -0.02 || sss > 0.0)) {
            vis = getShadow(playerPos, nW, NdL, sss, dither, lm.y);
        } else if (doShadow) {
            vis = vec3(0.0);
        } else {
            #ifdef OVERWORLD
            vis = vec3(smoothstep(0.75, 0.95, lm.y));
            #else
            vis = vec3(1.0);
            #endif
        }
        directVis = vis * skyGate;
        direct = getDirectColor() * diff * directVis;

        #ifdef OVERWORLD
        // softer falloff so cave mouths and overhangs still catch sky light
        amb = getAmbientColor() * (pow(lm.y, 1.5) * 0.85 + lm.y * 0.15) * (0.62 + 0.38 * (nW.y * 0.5 + 0.5));
        #else
        amb = getAmbientColor() * (0.7 + 0.3 * (nW.y * 0.5 + 0.5));
        #endif
    #else
        amb = getAmbientColor() * (0.75 + 0.25 * abs(nW.y));
    #endif

    amb *= ao * AMBIENT_BRIGHTNESS;
    vec3 block = getBlockLight(lm.x) * mix(ao, 1.0, 0.4) + getHandLight(playerPos);
    vec3 minLight = vec3(0.026, 0.028, 0.034) * ao + vec3(0.3) * nightVision;
    return albedo * (direct + amb + block + minLight);
}

#endif
