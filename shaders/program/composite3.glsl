// ============================================================================
//  Composite 3: temporal anti-aliasing (also cleans fog / shadow noise)
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
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

/* RENDERTARGETS: 3,6 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHistory;

// tonemapped space keeps bright pixels from dominating the blend
vec3 tmap(vec3 c)   { return c / (1.0 + luma(c)); }
vec3 untmap(vec3 c) { return c / max(1.0 - luma(c), 1e-3); }

vec3 toYCoCg(vec3 c) {
    return vec3(0.25 * c.r + 0.5 * c.g + 0.25 * c.b, 0.5 * c.r - 0.5 * c.b, -0.25 * c.r + 0.5 * c.g - 0.25 * c.b);
}
vec3 fromYCoCg(vec3 c) {
    return vec3(c.x + c.y - c.z, c.x + c.z, c.x - c.y - c.z);
}

void main() {
    vec3 cur = texture(colortex3, uv).rgb;
    #ifndef TAA
    outColor = vec4(cur, 1.0);
    outHistory = vec4(cur, 1.0);
    #else
    float d = texture(depthtex0, uv).r;

    vec2 prevUV = uv;
    if (d > 0.56) {
        vec3 pp = viewToPlayer(screenToView(uv, d));
        vec3 prevP = d >= 1.0 ? pp : pp + cameraPosition - previousCameraPosition;
        vec4 pv = gbufferPreviousModelView * vec4(prevP, 1.0);
        if (d >= 1.0) pv = vec4(mat3(gbufferPreviousModelView) * pp, 1.0);
        vec4 pc = gbufferPreviousProjection * pv;
        prevUV = (pc.xy / pc.w) * 0.5 + 0.5;
    }

    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 m1 = vec3(0.0);
    vec3 m2 = vec3(0.0);
    vec3 cT = toYCoCg(tmap(cur));
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec3 s = toYCoCg(tmap(texture(colortex3, uv + vec2(float(x), float(y)) * px).rgb));
            m1 += s;
            m2 += s * s;
        }
    }
    m1 /= 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - m1 * m1, 0.0));
    vec3 lo = m1 - sigma * 1.25;
    vec3 hi = m1 + sigma * 1.25;

    vec3 hist = toYCoCg(tmap(texture(colortex6, prevUV).rgb));
    hist = clamp(hist, lo, hi);

    float vel = length((uv - prevUV) * vec2(viewWidth, viewHeight));
    float w = mix(0.90, 0.70, saturate(vel / 10.0));
    if (prevUV.x < 0.0 || prevUV.x > 1.0 || prevUV.y < 0.0 || prevUV.y > 1.0) w = 0.0;

    vec3 res = untmap(fromYCoCg(mix(cT, hist, w)));
    res = max(res, 0.0);
    outColor = vec4(res, 1.0);
    outHistory = vec4(res, 1.0);
    #endif
}
#endif
