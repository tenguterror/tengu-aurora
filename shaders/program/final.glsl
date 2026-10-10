// ============================================================================
//  Final: bloom, exposure, ACES tonemap, colour grade, CAS sharpening
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
uniform sampler2D colortex5;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 fragColor;

vec3 acesFitted(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

float getExposure() {
    #if defined OVERWORLD
        float skyEye = float(eyeBrightnessSmooth.y) / 240.0;
        float dayF = smoothstep(-0.12, 0.22, sunDirW().y);
        float exposure = mix(3.2, 1.0, dayF);
        exposure = mix(3.4, exposure, smoothstep(0.0, 0.65, skyEye));
    #elif defined NETHER
        float exposure = 1.7;
    #else
        float exposure = 1.25;
    #endif
    return exposure * EXPOSURE * 0.8;
}

// everything up to the display image for one screen position (linear 0..1)
vec3 graded(vec2 p, float exposure) {
    vec3 col = texture(colortex3, p).rgb;

    // bloom
    vec3 bloom = texture(colortex5, p).rgb;
    col = mix(col, bloom, 0.075 * BLOOM_STRENGTH) + bloom * 0.025 * BLOOM_STRENGTH;

    col *= exposure;

    // night vision of the eye: dim light shifts towards a cool blue
    #ifdef OVERWORLD
    float skyEye = float(eyeBrightnessSmooth.y) / 240.0;
    float dayF = smoothstep(-0.12, 0.22, sunDirW().y);
    float dim = (1.0 - dayF) * skyEye * (1.0 - smoothstep(0.05, 0.6, luma(col)));
    float warm = saturate((col.r - col.b) / max(luma(col), 1e-4) * 0.9);   // torch / lava lit
    dim *= 1.0 - warm;
    col = mix(col, luma(col) * vec3(0.60, 0.80, 1.25), dim * 0.65);
    #endif

    col = acesFitted(col);

    // grading: contrast, saturation, vibrance
    col = saturate((col - 0.5) * CONTRAST + 0.5);
    float l = luma(col);
    col = mix(vec3(l), col, SATURATION);
    float mx = max(col.r, max(col.g, col.b));
    float mn = min(col.r, min(col.g, col.b));
    float vib = (VIBRANCE - 1.0) * (1.0 - (mx - mn));
    col = mix(vec3(luma(col)), col, 1.0 + vib);
    return saturate(col);
}

void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    float exposure = getExposure();
    vec3 col = graded(uv, exposure);

    // Contrast Adaptive Sharpening (after AMD FidelityFX CAS, MIT): sharpens soft
    // detail but backs off on edges that are already high-contrast, so it does not
    // re-cut the stair-steps that FXAA/TAA smoothed
    #if SHARPEN > 0
    {
        vec3 a = graded(uv + vec2(-px.x, -px.y), exposure);
        vec3 b = graded(uv + vec2(  0.0, -px.y), exposure);
        vec3 c = graded(uv + vec2( px.x, -px.y), exposure);
        vec3 d = graded(uv + vec2(-px.x,   0.0), exposure);
        vec3 f = graded(uv + vec2( px.x,   0.0), exposure);
        vec3 g = graded(uv + vec2(-px.x,  px.y), exposure);
        vec3 h = graded(uv + vec2(  0.0,  px.y), exposure);
        vec3 i = graded(uv + vec2( px.x,  px.y), exposure);

        vec3 mnRGB = min(min(min(d, col), min(f, b)), h);
        vec3 mxRGB = max(max(max(d, col), max(f, b)), h);
        mnRGB += min(mnRGB, min(min(a, c), min(g, i)));
        mxRGB += max(mxRGB, max(max(a, c), max(g, i)));

        vec3 amp = sqrt(saturate(min(mnRGB, 2.0 - mxRGB) / max(mxRGB, 1e-4)));
        float peak = -1.0 / mix(8.0, 5.0, float(SHARPEN) * 0.01);
        vec3 wgt = amp * peak;
        col = saturate(((b + d + f + h) * wgt + col) / (1.0 + 4.0 * wgt));
    }
    #endif

    // vignette
    vec2 vc = uv - 0.5;
    col *= 1.0 - dot(vc, vc) * VIGNETTE_STRENGTH * 1.4;

    col = pow(col, vec3(1.0 / 2.2));
    col += (hash12(gl_FragCoord.xy + float(frameCounter % 64)) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
#endif
