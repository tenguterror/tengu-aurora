// ============================================================================
//  Deferred: sky + lighting of all opaque geometry, rain puddles
// ============================================================================
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/*
const int colortex0Format = RGBA8;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int shadowcolor0Format = RGBA8;
const int shadowcolor1Format = RGBA16;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex5ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
const vec4 shadowcolor1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

const bool colortex6Clear = false;
*/

#ifdef VSH
out vec2 uv;
void main() {
    gl_Position = ftransform();
    uv = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
in vec2 uv;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;

#include "/lib/atmosphere.glsl"
#if !defined NETHER
#include "/lib/shadow.glsl"
#else
#include "/lib/water.glsl"
#endif
#include "/lib/lighting.glsl"

/* RENDERTARGETS: 3,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outReflect;

void main() {
    float depth = texture(depthtex0, uv).r;
    vec3 viewPos = screenToView(uv, depth);
    vec3 pp = viewToPlayer(viewPos);
    vec3 eye = gbufferModelViewInverse[3].xyz;
    vec3 dirW = normalize(pp - eye);
    float dither = ignT(gl_FragCoord.xy);

    if (depth >= 1.0) {
        outColor = vec4(getSky(dirW, dither, 0), 1.0);
        outReflect = vec4(0.0);
        return;
    }

    vec4 c0 = texture(colortex0, uv);
    vec4 c1 = texture(colortex1, uv);
    vec4 c2 = texture(colortex2, uv);

    vec3 albedo = toLinear(c0.rgb);
    vec3 nW = decodeNormal(c1.xy);
    vec2 lm = c1.zw;
    int id = int(c2.x * 255.0 + 0.5);
    float emissive = c2.y;
    float ao = pow(saturate(c2.z), 1.4);
    float sss = c2.w;
    bool isHand = id == ID_HAND || depth < 0.56;

    vec4 refl = vec4(0.0);

    // ---- rain puddles + wet surfaces --------------------------------------
    #ifdef RAIN_PUDDLES
    #ifdef OVERWORLD
    // wetness alone lags rain by minutes (halflife): follow rainStrength while it rains,
    // and let wetness keep the ground wet for a while after it stops
    float wetAmt = max(wetness, rainStrength * 0.9);
    if (!isHand && wetAmt > 0.001 && id != ID_LAVA && emissive < 0.5) {
        vec3 wp = pp + cameraPosition;
        float exposed = smoothstep(0.86, 0.96, lm.y) * wetAmt;
        float upF = smoothstep(0.65, 0.95, nW.y);
        float n = fbm2(wp.xz * 0.09) * 0.75 + noise2(wp.xz * 0.65) * 0.25;
        bool absorbent = id == ID_GRASS_BLOCK;
        float thresh = absorbent ? 0.60 : 0.50;
        float puddle = smoothstep(thresh, thresh + 0.06, n + 0.10 * PUDDLE_AMOUNT - 0.10 + wetAmt * 0.05 * PUDDLE_AMOUNT) * upF * exposed;
        if (sss > 0.0) puddle = 0.0;
        float wet = exposed * (sss > 0.0 ? 0.35 : (absorbent ? 0.6 : 1.0));

        // wet = darker and slightly richer, without the hue shift a pow() causes;
        // standing water darkens the ground under it much more so the mirror reads
        albedo *= mix(1.0, 0.62, wet * 0.6);
        albedo *= mix(1.0, 0.45, puddle);
        if (puddle > 0.0) {
            vec2 rip = rainRipples(wp.xz) * 0.35 * smoothstep(28.0, 6.0, length(pp));
            nW = normalize(mix(nW, normalize(vec3(-rip.x, 1.0, -rip.y)), puddle));
        }
        float strength = max(puddle, wet * 0.3);
        if (strength > 0.01) refl = vec4(encodeNormal(nW), lm.y, strength * 0.5);
    }
    #endif
    #endif

    // ---- lighting -----------------------------------------------------------
    vec3 vis;
    vec3 col = shadeSurface(albedo, nW, lm, pp, ao, sss, dither, !isHand, vis);

    #if !defined NETHER
    vec3 L = lightDirW();
    if (sss > 0.0) {
        // light glowing through leaves and grass
        float VdL = saturate(dot(dirW, L));
        col += albedo * getDirectColor() * vis * (pow(VdL, 6.0) * 1.6 + 0.12) * sss;
    }
    if (refl.w > 0.0) {
        col += getDirectColor() * vis * specularGGX(nW, -dirW, L, mix(0.35, 0.06, refl.w * 2.0), 0.02) * refl.w * 2.0;
    }
    #endif

    if (id == ID_LAVA) {
        // the animated texture carries the detail; stretch its contrast into a heat value
        // and colour it along a blackbody ramp (deep red -> orange -> yellow-white)
        vec3 wp = pp + cameraPosition;
        float t = frameTimeCounter;
        // Faithful lava spans sqrt-luma ~0.39..0.75 (median 0.48): map that range, lifted so
        // the bulk reads orange and only the brightest streaks reach yellow
        float heat = pow(saturate((sqrt(luma(albedo)) - 0.38) / 0.40), 0.55);
        heat *= 0.92 + 0.16 * fbm2(wp.xz * 0.05 + vec2(t * 0.01, -t * 0.007));   // gentle slow drift

        vec3 bb = mix(vec3(0.30, 0.03, 0.005), vec3(0.95, 0.20, 0.02), smoothstep(0.0, 0.40, heat));
        bb = mix(bb, vec3(1.0, 0.42, 0.06), smoothstep(0.35, 0.70, heat));
        bb = mix(bb, vec3(1.0, 0.64, 0.20), smoothstep(0.75, 1.0, heat));
        col = bb * (0.45 + 1.35 * heat * heat) * EMISSIVE_STRENGTH;
    } else if (emissive > 0.0) {
        col += albedo * emissive * getEmissiveScale(id) * EMISSIVE_STRENGTH;
    }

    // ---- fade into the sky at the render distance ---------------------------
    float border = smoothstep(far * 0.72, far * 0.98, length(pp.xz));
    if (border > 0.0) col = mix(col, getSky(dirW, dither, 1), border);

    outColor = vec4(col, 1.0);
    outReflect = refl;
}
#endif
