// ============================================================================
//  Composite 3: FXAA edge smoothing + temporal anti-aliasing
//  (TAA also cleans fog / shadow noise)
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

vec3 tapT(vec2 p) { return tmap(texture(colortex3, p).rgb); }

// FXAA (Lottes' edge-directed filter): smooths stair-stepped edges in the current
// frame, so edges stay clean even when TAA has to throw its history away
vec3 fxaa(vec2 p, vec2 px) {
    vec3 cM  = tapT(p);
    vec3 cNW = tapT(p + vec2(-1.0, -1.0) * px);
    vec3 cNE = tapT(p + vec2( 1.0, -1.0) * px);
    vec3 cSW = tapT(p + vec2(-1.0,  1.0) * px);
    vec3 cSE = tapT(p + vec2( 1.0,  1.0) * px);
    float lM = luma(cM), lNW = luma(cNW), lNE = luma(cNE), lSW = luma(cSW), lSE = luma(cSE);
    float lMin = min(lM, min(min(lNW, lNE), min(lSW, lSE)));
    float lMax = max(lM, max(max(lNW, lNE), max(lSW, lSE)));
    if (lMax - lMin < max(0.0312, lMax * 0.125)) return cM;   // flat area: leave it alone

    vec2 dir = vec2(-((lNW + lNE) - (lSW + lSE)), (lNW + lSW) - (lNE + lSE));
    float reduce = max((lNW + lNE + lSW + lSE) * 0.03125, 1.0 / 128.0);
    float rcpMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + reduce);
    dir = clamp(dir * rcpMin, -8.0, 8.0) * px;

    vec3 a = 0.5 * (tapT(p + dir * (1.0 / 3.0 - 0.5)) + tapT(p + dir * (2.0 / 3.0 - 0.5)));
    vec3 b = a * 0.5 + 0.25 * (tapT(p - dir * 0.5) + tapT(p + dir * 0.5));
    float lB = luma(b);
    return (lB < lMin || lB > lMax) ? a : b;
}

// Catmull-Rom history fetch (5 bilinear taps): keeps the history sharp,
// where plain bilinear blurs a little more every frame
vec3 historyCatmullRom(vec2 p) {
    vec2 size = vec2(viewWidth, viewHeight);
    vec2 pos = p * size;
    vec2 c = floor(pos - 0.5) + 0.5;
    vec2 f = pos - c;
    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);
    vec2 w12 = w1 + w2;
    vec2 t0 = (c - 1.0) / size;
    vec2 t3 = (c + 2.0) / size;
    vec2 t12 = (c + w2 / w12) / size;
    vec3 r = texture(colortex6, vec2(t12.x, t0.y)).rgb * (w12.x * w0.y)
           + texture(colortex6, vec2(t0.x, t12.y)).rgb * (w0.x * w12.y)
           + texture(colortex6, t12).rgb               * (w12.x * w12.y)
           + texture(colortex6, vec2(t3.x, t12.y)).rgb * (w3.x * w12.y)
           + texture(colortex6, vec2(t12.x, t3.y)).rgb * (w12.x * w3.y);
    float wsum = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
    return max(r / wsum, 0.0);
}

// pull history toward the neighbourhood mean until it fits the colour box
// (clipping instead of clamping: less ghosting, less colour shift)
vec3 clipToBox(vec3 boxMin, vec3 boxMax, vec3 h) {
    vec3 c = 0.5 * (boxMax + boxMin);
    vec3 e = 0.5 * (boxMax - boxMin) + 1e-4;
    vec3 v = h - c;
    vec3 a = abs(v / e);
    float m = max(a.x, max(a.y, a.z));
    return m > 1.0 ? c + v / m : h;
}

void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);

    #ifdef FXAA
    vec3 curT = fxaa(uv, px);
    #else
    vec3 curT = tapT(uv);
    #endif

    #ifndef TAA
    vec3 res = untmap(curT);
    outColor = vec4(res, 1.0);
    outHistory = vec4(res, 1.0);
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

    // neighbourhood colour statistics
    vec3 m1 = vec3(0.0);
    vec3 m2 = vec3(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec3 s = (x == 0 && y == 0) ? toYCoCg(curT) : toYCoCg(tapT(uv + vec2(float(x), float(y)) * px));
            m1 += s;
            m2 += s * s;
        }
    }
    m1 /= 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - m1 * m1, 0.0));
    vec3 cT = toYCoCg(curT);

    vec3 hist = toYCoCg(tmap(historyCatmullRom(prevUV)));
    hist = clipToBox(min(m1 - sigma * 1.1, cT), max(m1 + sigma * 1.1, cT), hist);

    // accumulate harder while still (more samples per edge), let go faster when moving
    float vel = length((uv - prevUV) * vec2(viewWidth, viewHeight));
    float w = mix(0.94, 0.75, saturate(vel / 6.0));
    if (prevUV.x < 0.0 || prevUV.x > 1.0 || prevUV.y < 0.0 || prevUV.y > 1.0) w = 0.0;

    vec3 res = untmap(fromYCoCg(mix(cT, hist, w)));
    res = max(res, 0.0);
    outColor = vec4(res, 1.0);
    outHistory = vec4(res, 1.0);
    #endif
}
#endif
