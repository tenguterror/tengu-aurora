// ============================================================================
//  Composite 1: volumetric fog + god rays  -> colortex5 (rgb inscatter, a trans)
// ============================================================================
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifdef VSH
out vec2 uv;
void main() {
    gl_Position = ftransform();
    uv = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
in vec2 uv;

uniform sampler2D depthtex0;

#include "/lib/atmosphere.glsl"
#if !defined NETHER
#include "/lib/shadow.glsl"
#endif

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outFog;

float fogDensity(vec3 wp) {
    float t = frameTimeCounter;
    #if defined OVERWORLD
        float sy = sunDirW().y;
        float morning = smoothstep(0.35, 0.0, abs(sy - 0.08));
        float night = smoothstep(0.0, -0.2, sy);
        // dusk haze halved: it was washing the sunset sky out to pale lavender
        float base = 0.0012 + 0.0022 * morning + 0.0025 * night + 0.0050 * rainStrength;
        float height = exp(-max(wp.y - 63.0, 0.0) * 0.045) + 0.12 * exp(-max(wp.y - 63.0, 0.0) * 0.008);
        float n = noise3(wp * 0.035 + vec3(t * 0.35, t * 0.05, t * 0.15));
        n = n * 0.7 + 0.3 * noise3(wp * 0.11 - vec3(t * 0.2, 0.0, t * 0.3));
        return base * height * (0.35 + 1.3 * n) * FOG_DENSITY;
    #elif defined NETHER
        // wispy smoke rising off the lava ocean: stretched, sheared, high-contrast noise
        // finer noise so individual wisps fit inside the 192-block view range
        vec3 q = wp * vec3(0.032, 0.016, 0.032);
        // slow swaying + curling: oscillating and noise-driven domain warp
        q.x += sin(t * 0.35 + wp.y * 0.040 + wp.z * 0.010) * 0.35;
        q.z += cos(t * 0.27 + wp.y * 0.050 + wp.x * 0.010) * 0.35;
        q += (vec3(noise3(q * 2.1 + t * 0.06), noise3(q * 2.1 - t * 0.05 + 9.0), noise3(q * 2.1 + 17.0)) - 0.5) * 0.65;
        q.y -= t * 0.03;
        float n = fbm3(q);
        // thinner background haze + denser, higher-contrast wisps = separate plumes, not one layer
        // (0.20 in v1.9.6 built a solid wall near the lava; 0.085 + wider gaps keeps plumes separate)
        float wisps = pow(saturate(n * 1.9 - 0.70), 2.0);
        float band = smoothstep(18.0, 38.0, wp.y) * smoothstep(120.0, 55.0, wp.y);
        return (0.0004 + 0.085 * wisps * band) * NETHER_FOG;
    #else
        float n = fbm3(wp * 0.02 + vec3(t * 0.03, -t * 0.02, t * 0.02));
        float band = exp(-abs(wp.y - 60.0) * 0.02);
        // thin drifting haze: denser made the whole void a bright lavender wall
        return (0.0004 + 0.0030 * smoothstep(0.45, 0.85, n)) * (0.3 + band) * END_FOG;
    #endif
}

void main() {
    #ifndef VOLUMETRIC_FOG
    outFog = vec4(0.0, 0.0, 0.0, 1.0);
    #else
    float depth = texture(depthtex0, uv).r;
    vec3 vp = screenToView(uv, depth);
    vec3 eye = gbufferModelViewInverse[3].xyz;
    vec3 endP = viewToPlayer(vp);
    vec3 dir = normalize(endP - eye);

    float maxDist = depth >= 1.0 ? 320.0 : min(length(endP - eye), 320.0);
    #ifdef NETHER
    maxDist = min(maxDist, 192.0);
    #endif
    float dither = ignT(gl_FragCoord.xy);
    float skyEye = float(eyeBrightnessSmooth.y) / 240.0;

    #if defined OVERWORLD
        vec3 L = lightDirW();
        // low sun = long shafts through the densest dusk haze: damp them or they streak across terrain
        vec3 lightCol = getDirectColor() * GODRAY_STRENGTH * mix(0.35, 1.0, smoothstep(0.04, 0.30, abs(sunDirW().y)));
        vec3 ambCol = getAmbientColor() * mix(0.25, 1.0, skyEye) * mix(0.45, 1.0, smoothstep(-0.15, 0.1, sunDirW().y));
        float cosT = dot(dir, L);
        // forward peak capped: uncapped it hit ~14x and smeared shafts across geometry into the sun
        float phase = min(mix(hgPhase(cosT, 0.72), hgPhase(cosT, -0.15), 0.35) * 4.0 * PI, 2.5);
        if (isEyeInWater == 1) {
            // water scatters broadly and the sun is filtered by the surface: soft, dim shafts
            phase = mix(hgPhase(cosT, 0.45), hgPhase(cosT, 0.0), 0.5) * 4.0 * PI;
            lightCol *= vec3(0.3, 0.75, 0.9) * 0.22;
            ambCol *= vec3(0.2, 0.7, 0.9);
        }
    #elif defined END
        vec3 L = lightDirW();
        vec3 lightCol = getDirectColor() * 0.35 * GODRAY_STRENGTH;
        vec3 ambCol = vec3(0.30, 0.18, 0.48) * 0.12;
        float cosT = dot(dir, L);
        float phase = min(mix(hgPhase(cosT, 0.75), hgPhase(cosT, 0.0), 0.4) * 4.0 * PI, 4.0);
    #else
        vec3 tint = netherTint();
        vec3 ambCol = mix(vec3(0.30, 0.24, 0.21), tint * 0.3, 0.25) * 0.35;   // dark ashy smoke
    #endif

    vec3 scatter = vec3(0.0);
    float trans = 1.0;
    float prevT = 0.0;
    for (int i = 0; i < VL_STEPS; i++) {
        float fi = (float(i) + dither) / float(VL_STEPS);
        float tcur = fi * fi * maxDist;
        float ds = tcur - prevT;
        prevT = tcur;
        vec3 p = eye + dir * tcur;
        vec3 wp = p + cameraPosition;

        float dens = fogDensity(wp);
        if (isEyeInWater == 1) dens = 0.035;

        #if defined NETHER
            // smoke is lit from below by the lava sea, darker and redder higher up
            float lavaGlow = smoothstep(80.0, 26.0, wp.y);
            vec3 S = ambCol + vec3(1.5, 0.42, 0.07) * lavaGlow * lavaGlow * 0.55;
        #else
            float vis = shadowSimple(p);
            if (length(p) > shadowDistance) vis = skyEye;
            vec3 S = lightCol * phase * vis + ambCol;
        #endif

        float stepT = exp(-dens * ds);
        scatter += trans * S * (1.0 - stepT);
        trans *= stepT;
    }

    outFog = vec4(scatter, trans);
    #endif
}
#endif
