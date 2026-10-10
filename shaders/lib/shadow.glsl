// ============================================================================
//  Shadow mapping: distortion, soft PCF, coloured + water-caustic shadows
// ============================================================================
#ifndef SHADOW_GLSL
#define SHADOW_GLSL

#define SHADOW_DISTORT 0.85

float distortFactor(vec2 p) {
    return length(p) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
}
vec3 distortShadow(vec3 p) {
    return vec3(p.xy / distortFactor(p.xy), p.z * 0.2);
}

#ifndef SHADOW_PASS
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

#include "/lib/water.glsl"

vec3 playerToShadowClip(vec3 pp) {
    return (shadowProjection * (shadowModelView * vec4(pp, 1.0))).xyz;
}

// Visibility of the sun/moon for a surface point (player space).
vec3 getShadow(vec3 playerPos, vec3 nW, float NdL, float sss, float dither, float skyLm) {
    float dist = length(playerPos);
    #ifdef OVERWORLD
    float fallback = smoothstep(0.72, 0.95, skyLm);
    #else
    float fallback = 1.0;
    #endif
    float fade = smoothstep(shadowDistance * 0.80, shadowDistance * 0.97, dist);
    if (fade >= 1.0) return vec3(fallback);

    vec3 sc0 = playerToShadowClip(playerPos);
    float f = distortFactor(sc0.xy);
    float texelBlocks = 2.0 * shadowDistance / float(shadowMapResolution) * f;
    float bias = texelBlocks * mix(1.6 + 1.2 * (1.0 - saturate(abs(NdL))), 0.8, sss) + 0.01;
    vec3 sc = playerToShadowClip(playerPos + nW * bias);
    sc = distortShadow(sc) * 0.5 + 0.5;
    sc.z -= 0.00002;

    float radius = (1.4 + sss * 1.2) * SHADOW_SOFTNESS / float(shadowMapResolution);
    float s0 = 0.0;
    float s1 = 0.0;
    float ang = dither * TAU;
    for (int i = 0; i < 12; i++) {
        float r = sqrt((float(i) + 0.5) / 12.0);
        float th = float(i) * 2.39996323 + ang;
        vec2 off = vec2(cos(th), sin(th)) * r * radius * 1.6;
        s0 += texture(shadowtex0, vec3(sc.xy + off, sc.z));
        s1 += texture(shadowtex1, vec3(sc.xy + off, sc.z));
    }
    s0 /= 12.0;
    s1 /= 12.0;

    vec3 vis = vec3(s0);
    if (s1 > s0 + 0.002) {
        vec4 sc0col = texture(shadowcolor0, sc.xy);
        vec3 tint;
        if (sc0col.a < 0.5) {
            // under water: absorb by depth, then focus into caustics
            float wy = texture(shadowcolor1, sc.xy).r * 1024.0 - 512.0;
            float depth = max(wy - (playerPos.y + cameraPosition.y), 0.0);
            tint = exp(-WATER_ABSORB * depth * 0.6);
            #ifdef WATER_CAUSTICS
            tint *= causticsPattern(playerPos + cameraPosition, depth);
            #endif
        } else {
            tint = toLinear(sc0col.rgb);
        }
        vis += (s1 - s0) * tint;
    }
    return mix(vis, vec3(fallback), fade);
}

// Cheap single tap used by the volumetric pass (ignores translucents)
float shadowSimple(vec3 playerPos) {
    vec3 sc = distortShadow(playerToShadowClip(playerPos)) * 0.5 + 0.5;
    if (any(lessThan(sc.xy, vec2(0.0))) || any(greaterThan(sc.xy, vec2(1.0)))) return 1.0;
    return texture(shadowtex1, vec3(sc.xy, sc.z - 0.0002));
}
#endif

#endif
