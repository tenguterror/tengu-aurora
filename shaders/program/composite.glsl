// ============================================================================
//  Composite 0: water body (refraction, absorption, reflections), puddle SSR,
//  underwater / in-lava view fog
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

uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#include "/lib/atmosphere.glsl"
#if !defined NETHER
#include "/lib/shadow.glsl"
#else
#include "/lib/water.glsl"
#endif
#include "/lib/lighting.glsl"
#include "/lib/ssr.glsl"

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

vec3 waterScatter(float skyL) {
    vec3 base = vec3(0.020, 0.170, 0.210);
    #ifdef OVERWORLD
    vec3 light = getAmbientColor() * (0.25 + 0.75 * skyL * skyL) + getDirectColor() * 0.06 * skyL;
    #else
    vec3 light = getAmbientColor() + getDirectColor() * 0.06;
    #endif
    return base * light;
}

vec3 reflectionFallback(vec3 Rw, float skyL, float dither) {
    #ifdef OVERWORLD
    vec3 sky = getSky(Rw, dither, 2);
    return mix(vec3(0.003, 0.004, 0.006), sky, smoothstep(0.2, 0.85, skyL));
    #else
    return getSky(Rw, dither, 1) * 0.6;
    #endif
}

void main() {
    vec3 color = texture(colortex3, uv).rgb;
    vec4 rdata = texture(colortex4, uv);
    float d0 = texture(depthtex0, uv).r;
    float d1 = texture(depthtex1, uv).r;
    vec3 vp0 = screenToView(uv, d0);
    vec3 pp0 = viewToPlayer(vp0);
    vec3 V = normalize(vp0);
    vec3 Vw = mat3(gbufferModelViewInverse) * V;
    float dither = ignT(gl_FragCoord.xy);

    if (rdata.w > 0.75 && d0 < 1.0) {
        // ======================= WATER =======================
        vec3 nW = decodeNormal(rdata.xy);
        vec3 nV = mat3(gbufferModelView) * nW;
        float skyL = rdata.z;

        if (isEyeInWater == 0) {
            // refraction
            vec2 dev = (mat3(gbufferModelView) * vec3(nW.x, 0.0, nW.z)).xy;
            vec3 vp1 = screenToView(uv, d1);
            float thick = d1 >= 1.0 ? 64.0 : distance(vp0, vp1);
            vec2 refrUV = clamp(uv + dev * 0.09 * saturate(thick * 0.3) / (1.0 + length(vp0) * 0.04), 0.001, 0.999);
            float d1r = texture(depthtex1, refrUV).r;
            if (d1r < d0) { refrUV = uv; d1r = d1; }
            vec3 under = texture(colortex3, refrUV).rgb;
            vec3 vp1r = screenToView(refrUV, d1r);
            thick = d1r >= 1.0 ? 64.0 : distance(vp0, vp1r);

            vec3 trans = exp(-WATER_ABSORB * thick);
            under = under * trans + waterScatter(skyL) * (1.0 - trans);

            // foam where the water gets shallow or touches a wall
            float foam = 0.0;
            #ifdef SHORE_FOAM
            if (nW.y > 0.5) {
                vec3 pp1 = viewToPlayer(screenToView(uv, d1));
                float vd = d1 >= 1.0 ? 99.0 : min(max(pp0.y - pp1.y, 0.0), thick * 0.6);
                float edge = 1.0 - smoothstep(0.0, 0.85, vd);
                if (edge > 0.0) {
                    vec3 wpos = pp0 + cameraPosition;
                    float ft = frameTimeCounter;
                    float n = fbm2(wpos.xz * 1.7 + vec2(ft * 0.22, ft * 0.17)) * 0.7 + noise2(wpos.xz * 5.0 - ft * 0.5) * 0.3;
                    float lines = smoothstep(0.55, 0.9, sin(vd * 14.0 - ft * 2.2) * 0.5 + 0.5) * edge * 0.6;
                    foam = saturate(smoothstep(0.62, 0.8, n + edge * 0.5) * edge + lines * n);
                }
            }
            #endif

            // reflection
            vec3 R = reflect(V, nV);
            vec3 Rw = mat3(gbufferModelViewInverse) * R;
            Rw.y = abs(Rw.y);
            float NdV = saturate(dot(-V, nV));
            float F = 0.02 + 0.98 * pow(1.0 - NdV, 5.0);
            vec3 refl = reflectionFallback(Rw, skyL, dither);
            #ifdef SSR
            vec4 hit = traceSSR(depthtex0, vp0, R, dither);
            if (hit.w > 0.0) refl = mix(refl, texture(colortex3, hit.xy).rgb, hit.w);
            #endif
            color = mix(under, refl, F);

            #if !defined NETHER
            vec3 L = lightDirW();
            float vis = shadowSimple(pp0 + vec3(0.0, 0.15, 0.0));
            if (length(pp0) > shadowDistance * 0.9) vis = smoothstep(0.7, 0.95, skyL);
            color += getDirectColor() * vis * specularGGX(nW, -Vw, L, 0.05, 0.02) * (1.0 - foam);
            vec3 foamLight = getDirectColor() * vis * saturate(L.y) + getAmbientColor() * (0.3 + 0.7 * skyL);
            #else
            vec3 foamLight = getAmbientColor() * 1.5;
            #endif
            color = mix(color, foamLight * 0.85, foam * 0.85);
        } else {
            // looking up at the surface from below: Snell's window
            vec2 refrUV = clamp(uv + nV.xy * 0.03, 0.001, 0.999);
            vec3 above = texture(colortex3, refrUV).rgb;
            float cosI = saturate(dot(-V, -nV));
            float window = smoothstep(0.62, 0.72, cosI);
            color = mix(waterScatter(skyL) * 0.8, above, window);
        }
    } else if (rdata.w > 0.005 && d0 < 1.0) {
        // =================== PUDDLES / WET ===================
        float strength = saturate(rdata.w * 2.0);
        vec3 nW = decodeNormal(rdata.xy);
        vec3 nV = mat3(gbufferModelView) * nW;
        vec3 R = reflect(V, nV);
        vec3 Rw = mat3(gbufferModelViewInverse) * R;
        float NdV = saturate(dot(-V, nV));
        // puddles get a higher reflectance floor: at 0.03 they vanished when looking down
        float F = mix(0.03, 0.22, smoothstep(0.5, 1.0, strength)) + 0.97 * pow(1.0 - NdV, 5.0);
        vec3 refl = reflectionFallback(Rw, rdata.z, dither);
        #ifdef SSR
        if (strength > 0.4) {
            vec4 hit = traceSSR(depthtex0, vp0, R, dither);
            if (hit.w > 0.0) refl = mix(refl, texture(colortex3, hit.xy).rgb, hit.w);
        }
        #endif
        color = mix(color, refl, F * strength * mix(0.5, 1.0, strength));
    }

    // ======================= VIEW MEDIUM =======================
    float dist = d0 >= 1.0 ? far : length(vp0);
    if (isEyeInWater == 1) {
        float skyEye = float(eyeBrightnessSmooth.y) / 240.0;
        vec3 trans = exp(-WATER_ABSORB * 1.15 * dist - 0.012 * dist);
        color = color * trans + waterScatter(skyEye) * (1.0 - trans);
    } else if (isEyeInWater == 2) {
        float f = 1.0 - exp(-dist * 0.9);
        color = mix(color, vec3(2.4, 0.55, 0.06), f);
    } else if (isEyeInWater == 3) {
        float f = 1.0 - exp(-dist * 0.7);
        color = mix(color, vec3(0.55, 0.65, 0.8), f);
    }

    outColor = vec4(color, 1.0);
}
#endif
