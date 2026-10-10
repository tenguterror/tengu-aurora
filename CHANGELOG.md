# Changelog

## 2.0.0 (2026-10-09): first release

The first full release, signed off after an in-game test pass of every dimension and weather.
Shader code is identical to 1.9.9; the in-game menu now shows the version.

## 1.9.4 – 1.9.9 (2026-10-09): test-pass fixes

- **Lava**: heat mapping re-fitted to the actual texture brightness, so it is orange with
  readable texture instead of blown-out yellow-white.
- **End**: thinner fog, weaker void-star scattering and lower exposure, so the nebula and
  stars show instead of a lavender fog wall.
- **God rays**: forward scattering capped, damped while the sun is low, and soft and dim
  underwater, so shafts no longer streak across terrain or blow out the seabed.
- **Aurora**: now drawn behind the clouds.
- **Sunset**: deeper orange/red band near the sun and half the dusk haze.
- **Night clouds**: dimmed and their moon-side glow capped, so they read moonlit grey.
- **Nether smoke**: finer, higher-contrast noise over a thin base haze, so it forms separate plumes.
- **Rain puddles**: follow the rain immediately instead of waiting on the slow wetness timer,
  more of them, darker ground underneath and stronger reflections, so they are visible from above.

## 1.0 – 1.9.3: development

- Water look established (refraction, absorption, reflections), shore foam.
- Night ambient lighting raised with a blue tint.
- Rain made grey-white, faint and wind-slanted.
- Lava switched to texture-driven blackbody colours.
- Nether smoke reworked into swaying ashy wisps lit from below.
