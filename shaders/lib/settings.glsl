// ============================================================================
//  TENGU AURORA - settings
// ============================================================================

#define INFO 0 //[0]

// ---- Shadows ----
const int shadowMapResolution = 3072; //[1024 2048 3072 4096 6144 8192]
const float shadowDistance = 192.0; //[96.0 128.0 160.0 192.0 224.0 256.0 320.0]
const float shadowDistanceRenderMul = 1.0;
const float sunPathRotation = -25.0; //[-45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0]
const bool shadowHardwareFiltering = true;
const float ambientOcclusionLevel = 1.0;
const float eyeBrightnessHalflife = 6.0;
const float wetnessHalflife = 180.0;
const float drynessHalflife = 900.0;

#define SHADOW_SOFTNESS 1.0 //[0.5 0.75 1.0 1.25 1.5 2.0 3.0]

// ---- Lighting ----
#define SUN_BRIGHTNESS 1.0 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define AMBIENT_BRIGHTNESS 1.0 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define BLOCKLIGHT_BRIGHTNESS 1.0 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define EMISSIVE_STRENGTH 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 2.5 3.0]
#define GLOWING_ORES

// ---- Waving ----
#define WAVING_PLANTS
#define WAVE_SPEED 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WAVE_AMOUNT 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 2.0]

// ---- Water / Lava ----
#define WATER_WAVE_HEIGHT 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WATER_CAUSTICS
#define SSR
#define LAVA_WAVES
#define SHORE_FOAM

// ---- Weather ----
#define RAIN_PUDDLES
#define PUDDLE_AMOUNT 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 2.0]

// ---- Atmosphere ----
#define VOLUMETRIC_FOG
#define VL_STEPS 16 //[8 12 16 24 32]
#define FOG_DENSITY 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define GODRAY_STRENGTH 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define CLOUDS
#define AURORA
//#define AURORA_EVERYWHERE
#define AURORA_BRIGHTNESS 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define CLOUD_COVERAGE 0.45 //[0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7]
#define CLOUD_STEPS 24 //[12 16 24 32 48]
#define NETHER_FOG 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define END_FOG 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]

// ---- Post ----
#define TAA
#define BLOOM_STRENGTH 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define EXPOSURE 1.0 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.75 2.0]
#define SATURATION 1.12 //[0.8 0.9 1.0 1.05 1.1 1.12 1.15 1.18 1.2 1.3 1.4]
#define VIBRANCE 1.12 //[0.8 0.9 1.0 1.1 1.12 1.2 1.3 1.4 1.5]
#define CONTRAST 1.05 //[0.9 0.95 1.0 1.05 1.1 1.15 1.2]
#define VIGNETTE_STRENGTH 0.35 //[0.0 0.1 0.2 0.3 0.35 0.4 0.5 0.6]
#define SHARPEN 0.35 //[0.0 0.1 0.2 0.3 0.35 0.4 0.5 0.6 0.8]

// ---- Material IDs (block.properties) ----
#define ID_GRASS 1
#define ID_TALL_LOWER 2
#define ID_TALL_UPPER 3
#define ID_LEAVES 4
#define ID_VINES 5
#define ID_CROPS 6
#define ID_GLOW_VINES 7
#define ID_GLOW_PLANT 8
#define ID_GRASS_BLOCK 9
#define ID_WATER 10
#define ID_GLASS 11
#define ID_ICE 12
#define ID_SLIME 13
#define ID_LAVA 20
#define ID_FIRE 21
#define ID_EMISSIVE 22
#define ID_EMISSIVE_PARTIAL 23
#define ID_ORE 24
#define ID_MAGMA 25
#define ID_NETHER_PORTAL 26
#define ID_END_PORTAL 27
#define ID_HAND 250
