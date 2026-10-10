// ============================================================================
//  Composite 4: bloom from the scene mip chain -> colortex5
// ============================================================================
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

const bool colortex3MipmapEnabled = true;

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

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outBloom;

void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 bloom = vec3(0.0);
    float wsum = 0.0;
    for (int lod = 2; lod <= 7; lod++) {
        float s = exp2(float(lod));
        vec3 acc = vec3(0.0);
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                float k = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
                acc += textureLod(colortex3, uv + vec2(float(x), float(y)) * px * s * 1.5, float(lod)).rgb * k;
            }
        }
        float w = pow(0.82, float(lod - 2));
        bloom += acc / 16.0 * w;
        wsum += w;
    }
    outBloom = vec4(bloom / wsum, 1.0);
}
#endif
