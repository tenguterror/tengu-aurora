// ============================================================================
//  Composite 2: depth-aware blur of the fog buffer and apply it
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
uniform sampler2D depthtex0;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

float linDepth(float d) {
    return (2.0 * near * far) / (far + near - (d * 2.0 - 1.0) * (far - near));
}

void main() {
    vec3 color = texture(colortex3, uv).rgb;
    float d = texture(depthtex0, uv).r;
    float ld = linDepth(d);
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);

    vec4 fog = vec4(0.0);
    float wsum = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(float(x), float(y)) * px * 1.5;
            float sd = linDepth(texture(depthtex0, uv + o).r);
            float w = exp(-abs(sd - ld) / max(ld * 0.05, 0.05)) * (x == 0 && y == 0 ? 2.0 : 1.0);
            fog += texture(colortex5, uv + o) * w;
            wsum += w;
        }
    }
    fog /= max(wsum, 1e-4);

    color = color * fog.a + fog.rgb;

    // blindness / darkness effect
    float dist = d >= 1.0 ? far : length(screenToView(uv, d));
    float dark = max(blindness, darknessFactor);
    if (dark > 0.0) color *= mix(1.0, exp(-dist * 0.35), dark);

    outColor = vec4(color, 1.0);
}
#endif
