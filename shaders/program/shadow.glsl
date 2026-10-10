// ============================================================================
//  Shadow pass
// ============================================================================
#define SHADOW_PASS
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/shadow.glsl"

#ifdef VSH
in vec4 mc_Entity;
in vec4 mc_midTexCoord;

out vec2 texcoord;
out vec4 vcolor;
out float worldY;
flat out int matId;

#include "/lib/waving.glsl"

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vcolor = gl_Color;
    matId = max(int(mc_Entity.x + 0.5), 0);
    vec2 lm = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);

    vec3 sview = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 pp = mat3(shadowModelViewInverse) * sview + shadowModelViewInverse[3].xyz;

    #ifdef WAVING_PLANTS
    bool top = gl_MultiTexCoord0.t < mc_midTexCoord.t;
    pp += waveOffset(pp + cameraPosition, matId, top, lm.y);
    #endif

    worldY = pp.y + cameraPosition.y;
    vec4 clip = gl_ProjectionMatrix * (shadowModelView * vec4(pp, 1.0));
    clip.xyz = distortShadow(clip.xyz);
    gl_Position = clip;
}
#endif

#ifdef FSH
in vec2 texcoord;
in vec4 vcolor;
in float worldY;
flat in int matId;

uniform sampler2D gtexture;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    if (tex.a < 0.1) discard;

    if (matId == ID_WATER) {
        outColor0 = vec4(1.0, 1.0, 1.0, 0.0);                 // alpha 0 = water flag
        outColor1 = vec4((worldY + 512.0) / 1024.0, 0.0, 0.0, 1.0);
    } else {
        vec3 tint = tex.rgb * vcolor.rgb;
        // stained glass -> saturated coloured light, opaque blocks don't matter
        tint = mix(vec3(1.0), tint, saturate(tex.a * 1.25));
        outColor0 = vec4(tint, 1.0);
        outColor1 = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
#endif
