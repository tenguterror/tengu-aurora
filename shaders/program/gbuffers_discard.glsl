// ============================================================================
//  Vanilla sky / sun / moon / clouds are replaced by the deferred sky
// ============================================================================
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifdef VSH
void main() {
    gl_Position = ftransform();
}
#endif

#ifdef FSH
/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

void main() {
    discard;
}
#endif
