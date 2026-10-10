// ============================================================================
//  Translucents: water (composited later), glass, ice, portals, slime...
// ============================================================================
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifdef VSH
in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 vcolor;
out vec3 normalW;
out vec3 playerPos;
flat out int matId;

#include "/lib/water.glsl"

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);
    vcolor = gl_Color;
    normalW = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
    matId = max(int(mc_Entity.x + 0.5), 0);

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

    if (matId == ID_WATER && normalW.y > 0.5) {
        vec3 wp = playerPos + cameraPosition;
        playerPos.y += waterHeight(wp.xz) * 0.045 - 0.03;
        viewPos = (gbufferModelView * vec4(playerPos, 1.0)).xyz;
    }

    gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
    #ifdef TAA
    gl_Position.xy += taaJitter() * gl_Position.w;
    #endif
}
#endif

#ifdef FSH
in vec2 texcoord;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 normalW;
in vec3 playerPos;
flat in int matId;

uniform sampler2D gtexture;

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
    vec4 tex = texture(gtexture, texcoord);
    tex.rgb *= vcolor.rgb;               // vcolor.a holds vanilla AO (separateAo)
    vec3 nW = normalize(normalW);
    vec3 wp = playerPos + cameraPosition;

    if (matId == ID_WATER) {
        if (nW.y > 0.5) {
            nW = waterNormal(wp, 0.11);
        } else {
            nW = normalize(nW + vec3(noise2(wp.xz * 2.0 + frameTimeCounter) - 0.5, 0.0, noise2(wp.zy * 2.0 - frameTimeCounter) - 0.5) * 0.08);
        }
        // the water body itself is composited in composite.fsh
        outColor = vec4(0.0);
        outReflect = vec4(encodeNormal(nW), lmcoord.y, 1.0);
        return;
    }

    if (tex.a < 0.01) discard;
    vec3 albedo = toLinear(tex.rgb);
    float dither = ignT(gl_FragCoord.xy);
    vec3 vis;
    vec3 col;
    float alpha = tex.a;

    if (matId == ID_NETHER_PORTAL) {
        float t = frameTimeCounter;
        float swirl = fbm2(wp.xy * 0.8 + wp.zy * 0.8 + vec2(t * 0.3, -t * 0.2));
        col = albedo * (2.5 + 2.5 * swirl) * EMISSIVE_STRENGTH;
        alpha = mix(alpha, 0.85, 0.5);
    } else {
        col = shadeSurface(albedo, nW, lmcoord, playerPos, 1.0, 0.0, dither, true, vis);

        // glossy reflection of the sky on glass / ice / slime
        vec3 V = normalize(playerPos - gbufferModelViewInverse[3].xyz);
        float NdV = saturate(dot(-V, nW));
        float F = 0.04 + 0.96 * pow(1.0 - NdV, 5.0);
        vec3 R = reflect(V, nW);
        #ifdef OVERWORLD
        vec3 refl = getSky(R, dither, 1) * smoothstep(0.3, 0.9, lmcoord.y);
        #else
        vec3 refl = getSky(R, dither, 1) * 0.5;
        #endif
        #if !defined NETHER
        vec3 L = lightDirW();
        refl += getDirectColor() * vis * specularGGX(nW, -V, L, 0.08, 0.04);
        #endif
        float rs = (matId == ID_GLASS || matId == ID_ICE) ? 0.85 : 0.35;
        col = mix(col, refl, F * rs);
        alpha = mix(alpha, 1.0, F * rs);
    }

    outColor = vec4(col, alpha);
    outReflect = vec4(0.0);
}
#endif
