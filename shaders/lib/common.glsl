// ============================================================================
//  Common uniforms + utilities
// ============================================================================
#ifndef COMMON_GLSL
#define COMMON_GLSL

uniform int worldTime;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int moonPhase;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

const float PI  = 3.14159265359;
const float TAU = 6.28318530718;

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3  saturate(vec3 x)  { return clamp(x, 0.0, 1.0); }
float luma(vec3 c)      { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3  toLinear(vec3 c)  { return pow(max(c, 0.0), vec3(2.2)); }
float sqr(float x)      { return x * x; }

// ---- hashing / noise -------------------------------------------------------
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    float n000 = hash13(i);
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
    return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
               mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

float fbm2(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise2(p);
        p = p * 2.03 + vec2(17.13, 9.71);
        a *= 0.5;
    }
    return v / 0.9375;
}

float fbm3(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise3(p);
        p = p * 2.07 + vec3(13.1, 7.3, 3.7);
        a *= 0.5;
    }
    return v / 0.875;
}

// Interleaved gradient noise, rotated per frame by the golden ratio
float ign(vec2 fc) {
    return fract(52.9829189 * fract(dot(fc, vec2(0.06711056, 0.00583715))));
}
float ignT(vec2 fc) {
    return fract(ign(fc) + float(frameCounter % 256) * 0.6180339887);
}

// ---- normal encoding (octahedral) ------------------------------------------
vec2 encodeNormal(vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    vec2 e = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    return e * 0.5 + 0.5;
}
vec3 decodeNormal(vec2 e) {
    e = e * 2.0 - 1.0;
    vec3 n = vec3(e.xy, 1.0 - abs(e.x) - abs(e.y));
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

// ---- space conversions -------------------------------------------------------
vec3 screenToView(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}
vec3 viewToPlayer(vec3 v) {
    return mat3(gbufferModelViewInverse) * v + gbufferModelViewInverse[3].xyz;
}
vec3 viewToScreen(vec3 v) {
    vec4 p = gbufferProjection * vec4(v, 1.0);
    return (p.xyz / p.w) * 0.5 + 0.5;
}

vec3 sunDirW()   { return normalize(mat3(gbufferModelViewInverse) * sunPosition); }
vec3 lightDirW() { return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition); }

// ---- TAA jitter --------------------------------------------------------------
float halton(int i, int b) {
    float f = 1.0;
    float r = 0.0;
    int n = i;
    while (n > 0) {
        f /= float(b);
        r += f * float(n % b);
        n /= b;
    }
    return r;
}
vec2 taaJitter() {
    int i = frameCounter % 8 + 1;
    return (vec2(halton(i, 2), halton(i, 3)) * 2.0 - 1.0) / vec2(viewWidth, viewHeight);
}

float hgPhase(float c, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5));
}

// Water optics shared between passes
const vec3 WATER_ABSORB = vec3(0.34, 0.065, 0.040);

#endif
