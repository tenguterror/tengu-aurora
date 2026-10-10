// ============================================================================
//  Rain & snow: thin, sky-lit, wind-slanted streaks instead of blue lines
// ============================================================================
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifdef VSH
out vec2 texcoord;
out vec2 lmcoord;
out vec4 vcolor;
out vec3 playerPos;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);
    vcolor = gl_Color;

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

    // wind: lean the streaks, gusting slowly; indoors (no sky light) stays straight
    float skyEye = float(eyeBrightnessSmooth.y) / 240.0;
    float t = frameTimeCounter;
    vec2 wind = vec2(0.32 + 0.12 * sin(t * 0.37), 0.14 + 0.08 * sin(t * 0.53 + 1.3)) * (0.5 + 0.5 * rainStrength);
    playerPos.xz += wind * playerPos.y * skyEye;

    gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4(playerPos, 1.0));
    #ifdef TAA
    gl_Position.xy += taaJitter() * gl_Position.w;
    #endif
}
#endif

#ifdef FSH
in vec2 texcoord;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 playerPos;

uniform sampler2D gtexture;

#include "/lib/atmosphere.glsl"
#if !defined NETHER
#include "/lib/shadow.glsl"
#endif
#include "/lib/lighting.glsl"

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, texcoord) * vcolor;
    if (tex.a < 0.05 || isEyeInWater == 3) discard;

    bool snow = tex.r + tex.g > 1.5;

    // lit by the sky + a touch of sun/moon + nearby torches
    vec3 light = getAmbientColor() * 1.5 + getDirectColor() * 0.10;
    #ifdef OVERWORLD
    light *= 0.25 + 0.75 * lmcoord.y;
    #endif
    light += getBlockLight(lmcoord.x) * 0.8 + vec3(0.01);

    vec3 col;
    float alpha;
    if (snow) {
        col = toLinear(tex.rgb) * light * 1.8;
        alpha = tex.a * 0.85;
    } else {
        // neutral, slightly cool streaks; fainter near the camera so they don't block the view
        float streak = luma(tex.rgb);
        col = vec3(0.80, 0.86, 0.95) * light * (1.1 + streak);
        float dist = length(playerPos);
        alpha = saturate(tex.a * streak * 1.6) * 0.20 * smoothstep(0.5, 4.0, dist);
    }
    outColor = vec4(col, alpha);
}
#endif
