// ============================================================================
//  Screen-space reflections (view-space march + binary refine)
// ============================================================================
#ifndef SSR_GLSL
#define SSR_GLSL

// returns (uv, -, confidence)
vec4 traceSSR(sampler2D depthTex, vec3 viewPos, vec3 dir, float dither) {
    float stepLen = 0.35 + length(viewPos) * 0.025;
    vec3 stepV = dir * stepLen;
    vec3 pos = viewPos + dir * 0.05 + stepV * dither;
    vec3 prev = viewPos;

    for (int i = 0; i < 28; i++) {
        if (pos.z > -near) break;
        vec3 sp = viewToScreen(pos);
        if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0) break;

        float d = texture(depthTex, sp.xy).r;
        if (d > 0.56) {
            vec3 sceneV = screenToView(sp.xy, d);
            float diff = pos.z - sceneV.z;                // < 0 -> ray is behind the surface
            float thickness = length(stepV) * 2.5 + 0.5;
            if (diff < 0.0 && diff > -thickness) {
                vec3 a = prev;
                vec3 b = pos;
                for (int j = 0; j < 5; j++) {
                    vec3 m = (a + b) * 0.5;
                    vec3 ms = viewToScreen(m);
                    float md = screenToView(ms.xy, texture(depthTex, ms.xy).r).z;
                    if (m.z - md < 0.0) b = m; else a = m;
                }
                vec3 hs = viewToScreen(b);
                if (texture(depthTex, hs.xy).r >= 1.0) break;   // sky: use fallback
                vec2 edge = min(hs.xy, 1.0 - hs.xy);
                float fade = smoothstep(0.0, 0.07, min(edge.x, edge.y));
                return vec4(hs.xy, 0.0, fade);
            }
        }
        prev = pos;
        stepV *= 1.32;
        pos += stepV;
    }
    return vec4(0.0);
}

#endif
