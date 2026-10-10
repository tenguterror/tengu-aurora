// ============================================================================
//  Generic G-buffer program
//  Variants: GB_TERRAIN GB_ENTITIES GB_BLOCK GB_HAND GB_TEXTURED GB_BASIC
//            GB_ADDITIVE (glint / spider eyes / beacon) GB_LIGHTNING GB_DAMAGE
//  Opaque variants fill the G-buffer (lit later in deferred).
//  Forward variants also write a lit colour so they look right whether Iris
//  draws them before or after the deferred pass.
// ============================================================================
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifdef GB_GLINT
    #define GB_ADDITIVE
#endif
#if defined GB_HAND || defined GB_TEXTURED || defined GB_BASIC || defined GB_ADDITIVE || defined GB_LIGHTNING
    #define GB_FORWARD
#endif

#ifdef VSH
in vec4 mc_Entity;
in vec4 mc_midTexCoord;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 vcolor;
out vec3 normalW;
out vec3 playerPos;
out float bladeH;
flat out int matId;

#include "/lib/waving.glsl"

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);
    vcolor = gl_Color;
    normalW = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    matId = 0;
    bladeH = 1.0;

    #ifdef GB_TERRAIN
        matId = max(int(mc_Entity.x + 0.5), 0);
        vec3 wp = playerPos + cameraPosition;
        bool top = gl_MultiTexCoord0.t < mc_midTexCoord.t;
        if (matId == ID_GRASS || matId == ID_CROPS || matId == ID_GLOW_PLANT) bladeH = top ? 1.0 : 0.0;
        else if (matId == ID_TALL_LOWER) bladeH = top ? 0.55 : 0.0;
        else if (matId == ID_TALL_UPPER) bladeH = top ? 1.0 : 0.55;
        #ifdef WAVING_PLANTS
        playerPos += waveOffset(wp, matId, top, lmcoord.y);
        #endif
        #ifdef LAVA_WAVES
        if (matId == ID_LAVA && normalW.y > 0.5) {
            float t = frameTimeCounter;
            playerPos.y += (sin(t * 0.9 + wp.x * 0.7 + wp.z * 0.45) * 0.5 +
                            sin(t * 1.3 - wp.x * 0.4 + wp.z * 0.9) * 0.5) * 0.035 - 0.035;
        }
        #endif
        viewPos = (gbufferModelView * vec4(playerPos, 1.0)).xyz;
    #endif

    #ifdef GB_HAND
        matId = ID_HAND;
    #endif

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
in float bladeH;
flat in int matId;

uniform sampler2D gtexture;
uniform vec4 entityColor;
uniform int blockEntityId;

#ifdef GB_FORWARD
    #include "/lib/atmosphere.glsl"
    #if !defined NETHER
    #include "/lib/shadow.glsl"
    #endif
    #include "/lib/lighting.glsl"
#endif

#ifdef GB_DAMAGE
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outAlbedo;
#elif defined GB_GLINT
/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outColor;
#elif defined GB_FORWARD
/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outMaterial;
layout(location = 3) out vec4 outColor;
#else
/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outMaterial;
#endif

vec3 endPortalField(vec3 dir) {
    vec3 col = vec3(0.004, 0.012, 0.018);
    float t = frameTimeCounter * 0.015;
    for (int i = 1; i <= 4; i++) {
        float fi = float(i);
        vec3 p = dir * (40.0 + fi * 35.0) + vec3(t * fi * 9.0, t * 4.0, -t * fi * 6.0);
        vec3 c = floor(p);
        vec3 f = fract(p) - 0.5;
        float h = hash13(c + fi * 13.0);
        float star = step(0.93, h) * smoothstep(0.3, 0.0, length(f));
        vec3 tint = mix(vec3(0.15, 0.9, 0.75), vec3(0.45, 0.35, 1.0), hash13(c + 5.0));
        col += tint * star * (1.2 - fi * 0.2);
    }
    return col;
}

void main() {
    vec4 albedo;
    float ao = 1.0;
    #ifdef GB_BASIC
        albedo = vcolor;
    #elif defined GB_TERRAIN
        vec4 tex = texture(gtexture, texcoord);
        albedo = vec4(tex.rgb * vcolor.rgb, tex.a);
        ao = vcolor.a;                                   // separateAo = true
    #else
        albedo = texture(gtexture, texcoord) * vcolor;
    #endif

    #ifdef GB_ENTITIES
        albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    #endif

    #ifdef GB_DAMAGE
        outAlbedo = albedo;
        return;
    #else

    if (albedo.a < 0.1) discard;

    int id = matId;
    float emissive = 0.0;
    float sss = 0.0;
    vec3 nW = normalize(normalW);

    #if defined GB_TERRAIN
        float mx = max(albedo.r, max(albedo.g, albedo.b));
        float mn = min(albedo.r, min(albedo.g, albedo.b));
        float satur = (mx - mn) / max(mx, 1e-3);
        vec3 wp = playerPos + cameraPosition;

        bool foliage = (id >= ID_GRASS && id <= ID_GLOW_PLANT) || id == ID_GRASS_BLOCK;
        if (id >= ID_GRASS && id <= ID_GLOW_PLANT) {
            sss = id == ID_LEAVES ? 0.8 : 0.65;
            if (id != ID_LEAVES && id != ID_VINES && id != ID_GLOW_VINES) nW = vec3(0.0, 1.0, 0.0);
            // darker roots, sunlit tips: gives the meadow depth
            ao *= mix(0.42, 1.0, bladeH);
            albedo.rgb *= mix(0.80, 1.10, bladeH);
        }
        if (foliage && albedo.g > albedo.r && albedo.g > albedo.b) {
            // large-scale patchy colour variation + richer greens
            float v = noise2(wp.xz * 0.06) - 0.5;
            float v2 = noise2(wp.xz * 0.23 + 31.0) - 0.5;
            albedo.rgb *= 1.0 + v2 * 0.16;
            albedo.rgb = mix(albedo.rgb, albedo.rgb * vec3(1.12, 1.04, 0.80), saturate(v * 1.6 + 0.2));
            float gl = luma(albedo.rgb);
            albedo.rgb = saturate(mix(vec3(gl), albedo.rgb, 1.08));
        }
        if (id == ID_LAVA) {
            float t = frameTimeCounter;
            float n = fbm2(wp.xz * 0.35 + vec2(t * 0.05, t * 0.035));
            float n2 = noise2(wp.xz * 1.3 - vec2(t * 0.12, -t * 0.08));
            float heat = 1.0;
            albedo.rgb = saturate(albedo.rgb * heat);
            emissive = 1.0;
        } else if (id == ID_FIRE || id == ID_EMISSIVE) {
            emissive = 0.55 + 0.45 * mx;
        } else if (id == ID_EMISSIVE_PARTIAL || id == ID_GLOW_VINES || id == ID_GLOW_PLANT) {
            emissive = smoothstep(0.52, 0.85, mx) * (0.6 + 0.4 * satur);
        } else if (id == ID_MAGMA) {
            emissive = smoothstep(0.25, 0.6, albedo.r - albedo.b) * 0.9;
        } else if (id == ID_ORE) {
            #ifdef GLOWING_ORES
            emissive = smoothstep(0.30, 0.60, satur) * smoothstep(0.25, 0.5, mx) * 0.7;
            #endif
        }
    #elif defined GB_BLOCK
        if (blockEntityId == ID_END_PORTAL) {
            albedo.rgb = endPortalField(normalize(playerPos));
            emissive = 1.0;
            id = ID_END_PORTAL;
        }
    #elif defined GB_ADDITIVE || defined GB_LIGHTNING
        emissive = 1.0;
        id = ID_EMISSIVE;
    #elif defined GB_TEXTURED || defined GB_BASIC
        nW = vec3(0.0, 1.0, 0.0);
        #ifdef GB_TEXTURED
        if (isEyeInWater == 0 && albedo.b > albedo.r * 1.4 && albedo.b > albedo.g * 1.1) {
            // vanilla rain splashes are saturated blue - make them read as water
            albedo.rgb = vec3(luma(albedo.rgb)) * vec3(0.85, 0.92, 1.0) * 1.4;
            albedo.a *= 0.6;
        }
        #endif
    #endif

    outAlbedo   = vec4(albedo.rgb, 1.0);
    #ifndef GB_GLINT
    outNormal   = vec4(encodeNormal(nW), lmcoord);
    outMaterial = vec4(float(id) / 255.0, emissive, ao, sss);
    #endif

    #ifdef GB_FORWARD
        vec3 lin = toLinear(albedo.rgb);
        vec3 vis;
        float dither = ignT(gl_FragCoord.xy);
        #if defined GB_HAND
            vec3 lit = shadeSurface(lin, nW, lmcoord, playerPos, 1.0, 0.0, dither, false, vis);
        #elif defined GB_ADDITIVE || defined GB_LIGHTNING
            vec3 lit = lin * 4.0 * EMISSIVE_STRENGTH;
        #else
            vec3 lit = shadeSurface(lin, nW, lmcoord, playerPos, 1.0, 0.5, dither, false, vis);
        #endif
        outColor = vec4(lit, albedo.a);
    #endif

    #endif
}
#endif
