#version 460 core

#include <flutter/runtime_effect.glsl>

// ── Uniforms ──────────────────────────────────────────────────────────────────
// Surface
uniform vec2 uSize;
uniform vec4 uBaseColor;
// Material (PBR)
uniform float uRoughness;
uniform float uMetallic;
uniform float uFresnel;
uniform float uSheen;
uniform float uClearcoat;
// Profile
uniform float uPatternType;
uniform float uFrequency;
uniform float uAmplitude;
uniform float uAngle;
// Lights (up to 4)
uniform float uNumLights;
// Light 0
uniform vec2 uLight0Dir;
uniform float uLight0Intensity;
uniform vec4 uLight0Color;
// Light 1
uniform vec2 uLight1Dir;
uniform float uLight1Intensity;
uniform vec4 uLight1Color;
// Light 2
uniform vec2 uLight2Dir;
uniform float uLight2Intensity;
uniform vec4 uLight2Color;
// Light 3
uniform vec2 uLight3Dir;
uniform float uLight3Intensity;
uniform vec4 uLight3Color;
// Curvature
uniform float uCurvature;
// Border
uniform float uBorderWidth;
uniform vec4 uBorderRadius; // top-left, top-right, bottom-right, bottom-left
// Ambient
uniform vec3 uAmbientSky;
uniform vec3 uAmbientGround;

// Normal map
uniform float uUseNormalMap; // 0.0 = procedural, 1.0 = texture
uniform sampler2D uNormalMap;

// Translucency
uniform float uTranslucency;

// Inset shadow bands
uniform float uOuterShadowIntensity;
uniform float uOuterShadowWidth;
uniform float uInnerShadowIntensity;
uniform float uInnerShadowWidth;

out vec4 fragColor;

// ── Heightmap functions ───────────────────────────────────────────────────────

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 rotate(vec2 p, float a) {
  float ca = cos(a);
  float sa = sin(a);
  return vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
}

float heightAt(vec2 uv) {
  int pat = int(uPatternType + 0.5);
  if (pat == 0) return 0.0;

  vec2 p = rotate(uv * uSize, uAngle);
  float freq = uFrequency * 6.2832 / 100.0;

  if (pat == 1) {
    return sin(p.x * freq) * uAmplitude;
  } else if (pat == 2) {
    return sin(p.x * freq) * sin(p.y * freq) * uAmplitude;
  } else {
    float nFreq = uFrequency / 100.0;
    return (valueNoise(p * nFreq) * 2.0 - 1.0) * uAmplitude;
  }
}

vec3 normalAt(vec2 uv) {
  float eps = 1.0 / max(uSize.x, uSize.y);
  float hc = heightAt(uv);
  float hx = heightAt(uv + vec2(eps, 0.0));
  float hy = heightAt(uv + vec2(0.0, eps));
  vec3 tx = vec3(eps * uSize.x, 0.0, (hx - hc) * uCurvature);
  vec3 ty = vec3(0.0, eps * uSize.y, (hy - hc) * uCurvature);
  return normalize(cross(tx, ty));
}

// ── Per-light shading ─────────────────────────────────────────────────────────

/// Computes diffuse + specular contribution for one light.
/// Fresnel, sheen, and clearcoat are computed separately in main() using
/// SDF edge proximity (they depend on the widget shape, not individual lights).
vec3 shadeLight(vec3 N, vec3 V, vec2 lightDir, float lightIntensity, vec3 lightColor) {
  if (lightIntensity < 0.001) return vec3(0.0);

  vec3 L = normalize(vec3(lightDir, 0.6));
  vec3 H = normalize(L + V);

  // Diffuse
  float NdotL = max(dot(N, L), 0.0);
  float diffuseStrength = (1.0 - uMetallic) * NdotL * lightIntensity;

  // Specular (Blinn-Phong, roughness-dependent spread)
  float shininess = mix(4.0, 128.0, pow(1.0 - uRoughness, 2.0));
  float NdotH = max(dot(N, H), 0.0);
  float spec = pow(NdotH, shininess);
  float specStrength = spec * lightIntensity;
  vec3 specColor = mix(vec3(1.0), uBaseColor.rgb, uMetallic);

  vec3 contrib = uBaseColor.rgb * diffuseStrength * 0.15;
  contrib += specColor * specStrength * 0.3;

  // Tint by light color
  contrib *= mix(vec3(1.0), lightColor, lightIntensity * 0.3);

  return contrib;
}

// ── Rounded rect SDF ──────────────────────────────────────────────────────────

/// Select corner radius for the quadrant of [p] relative to rect center.
/// Uses smooth blending near axes to avoid discontinuities in the SDF
/// gradient (which cause visible lines when computing normals via
/// finite differences).
float pickRadius(vec2 p, vec4 r) {
  // Blend width in pixels — must be wider than borderNormal's eps
  // so the finite-difference stencil never straddles a hard jump.
  float bw = 3.0;
  float sx = smoothstep(-bw, bw, p.x); // 0 = left, 1 = right
  float sy = smoothstep(-bw, bw, p.y); // 0 = top,  1 = bottom
  float topR    = mix(r.x, r.y, sx);   // topLeft ↔ topRight
  float bottomR = mix(r.w, r.z, sx);   // bottomLeft ↔ bottomRight
  return mix(topR, bottomR, sy);
}

/// Signed distance to a rounded rect with per-corner radii.
/// [b] = half-size of the rect.
float roundedRectSDF(vec2 p, vec2 b) {
  float cr = pickRadius(p, uBorderRadius);
  vec2 q = abs(p) - b + vec2(cr);
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - cr;
}

/// Same SDF but with a deflated rect (for the inner border edge).
float roundedRectSDFDeflated(vec2 p, vec2 b, float deflate) {
  vec4 r = max(uBorderRadius - vec4(deflate), vec4(0.0));
  float cr = pickRadius(p, r);
  vec2 q = abs(p) - (b - vec2(deflate)) + vec2(cr);
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - cr;
}

vec3 borderNormal(vec2 p, vec2 halfSize) {
  float eps = 1.5;
  float d0 = roundedRectSDF(p, halfSize);
  float dx = roundedRectSDF(p + vec2(eps, 0.0), halfSize) - d0;
  float dy = roundedRectSDF(p + vec2(0.0, eps), halfSize) - d0;
  vec2 grad = normalize(vec2(dx, dy));
  return normalize(vec3(grad * 0.6, 1.0));
}

void main() {
  vec2 fragPos = FlutterFragCoord().xy;
  vec2 uv = fragPos / uSize;
  vec2 center = uSize * 0.5;
  vec2 p = fragPos - center;
  vec2 halfSize = center;

  // SDF: negative = inside shape, positive = outside
  float outerDist = roundedRectSDF(p, halfSize);
  float innerDist = roundedRectSDFDeflated(p, halfSize, uBorderWidth);

  // Outside the outer rounded rect — fully transparent
  if (outerDist > 0.5) {
    fragColor = vec4(0.0);
    return;
  }

  // Anti-alias the outer edge
  float outerAlpha = 1.0 - smoothstep(-0.5, 0.5, outerDist);

  // Determine if we're in the border zone or fill zone
  // borderBlend: 1.0 = fully in border, 0.0 = fully in fill
  float borderBlend = smoothstep(-0.5, 0.5, innerDist);

  // ── Normal ──
  vec3 fillNormal;
  if (uUseNormalMap > 0.5) {
    // Sample normal map: RGB channels encode XYZ in tangent space
    // Convention: (128,128,255) = flat facing camera = (0,0,1)
    vec3 mapNormal = texture(uNormalMap, uv).rgb * 2.0 - 1.0;
    fillNormal = normalize(mapNormal);
  } else {
    fillNormal = normalAt(uv);
  }
  // Only compute border normal when actually in/near the border zone.
  // Deep in the fill (borderBlend == 0), skip it entirely to avoid
  // any residual SDF gradient artifacts.
  vec3 N;
  if (borderBlend > 0.001) {
    vec3 edgeNormal = borderNormal(p, halfSize);
    N = mix(fillNormal, edgeNormal, borderBlend);
  } else {
    N = fillNormal;
  }

  vec3 V = vec3(0.0, 0.0, 1.0);

  // ── Accumulate lighting ──
  // Hemisphere ambient: lerp between ground and sky based on normal Y
  float skyBlend = N.y * 0.5 + 0.5;
  vec3 ambientColor = mix(uAmbientGround, uAmbientSky, skyBlend);
  // High ambient floor (0.88) keeps the surface close to baseColor.
  // Lights add subtle modulation on top, not dramatic reconstruction.
  vec3 litColor = uBaseColor.rgb * 0.88 * ambientColor;

  int numLights = int(uNumLights + 0.5);
  if (numLights > 0) {
    litColor += shadeLight(N, V, uLight0Dir, uLight0Intensity, uLight0Color.rgb);
  }
  if (numLights > 1) {
    litColor += shadeLight(N, V, uLight1Dir, uLight1Intensity, uLight1Color.rgb);
  }
  if (numLights > 2) {
    litColor += shadeLight(N, V, uLight2Dir, uLight2Intensity, uLight2Color.rgb);
  }
  if (numLights > 3) {
    litColor += shadeLight(N, V, uLight3Dir, uLight3Intensity, uLight3Color.rgb);
  }

  // ── SDF-based edge effects (fresnel, sheen, clearcoat) ────────────────────
  // In 3D these depend on NdotV which is always 1.0 for flat 2D widgets.
  // Instead, use SDF distance from the widget edge as a proxy for
  // "viewing angle" — pixels near the edge are treated as if at a
  // glancing angle.
  //
  // -outerDist = distance from outer edge INTO the widget (positive inside).
  // Small values = near edge, large values = deep in center.

  // ── Fresnel: bright inner rim ──
  float fresnelWidth = 6.0 + uFresnel * 30.0;
  float fresnelEdge = 1.0 - smoothstep(0.0, fresnelWidth, -outerDist);
  float fresnelGlow = uFresnel * fresnelEdge * fresnelEdge;
  vec3 fresnelColor = mix(vec3(1.0), uBaseColor.rgb, uMetallic);
  litColor += fresnelColor * fresnelGlow * 0.45;

  // ── Sheen: soft broad glow, strongest near edges ──
  // Unlike fresnel (sharp rim), sheen spreads broadly across the surface
  // with a gentle falloff — simulating light scattering in fabric/velvet.
  float sheenWidth = 30.0 + uSheen * 60.0;
  float sheenEdge = 1.0 - smoothstep(0.0, sheenWidth, -outerDist);
  litColor += uBaseColor.rgb * uSheen * sheenEdge * 0.3;

  // ── Clearcoat: glossy highlight near the top edge (light-facing side) ──
  // Instead of a per-light NdotH hotspot (which is subpixel on flat UI),
  // clearcoat brightens the edge region that faces the dominant light.
  // This simulates a glossy topcoat catching light at the widget's rim.
  if (uClearcoat > 0.001 && numLights > 0) {
    float ccWidth = 8.0 + uClearcoat * 25.0;
    float ccEdge = 1.0 - smoothstep(0.0, ccWidth, -outerDist);
    // Weight by how much this edge faces the primary light
    vec3 L0 = normalize(vec3(uLight0Dir, 0.6));
    // Use the border normal direction to determine light-facing edges
    vec2 edgeDir = normalize(p);
    float lightFacing = max(dot(edgeDir, uLight0Dir), 0.0);
    float ccGlow = uClearcoat * ccEdge * ccEdge * lightFacing * uLight0Intensity;
    litColor += vec3(ccGlow * 0.5);
  }

  // Border gets slightly different base tone
  vec3 borderBase = uBaseColor.rgb * 1.05;
  vec3 finalBase = mix(uBaseColor.rgb, borderBase, borderBlend);

  vec3 finalColor = mix(litColor, litColor * (finalBase / max(uBaseColor.rgb, vec3(0.01))), borderBlend);

  // ── Inset shadow bands ──────────────────────────────────────────────────
  bool hasShadowBands = (uOuterShadowIntensity > 0.001 || uInnerShadowIntensity > 0.001);

  if (hasShadowBands) {
    // Fill zone: transparent when shadow bands are active
    if (borderBlend < 0.001) {
      fragColor = vec4(0.0);
      return;
    }

    // Compute position within border zone (0.0 = outer edge, 1.0 = inner edge)
    // -outerDist = how far inside from outer edge (positive inside the shape)
    // For typical border widths (1-3px) relative to corner radii (6px+),
    // the linear mapping is geometrically accurate to sub-pixel precision.
    float borderThickness = uBorderWidth;
    float distFromOuter = -outerDist;
    float borderPos = clamp(distFromOuter / borderThickness, 0.0, 1.0);

    // Outer shadow band: occupies [0, outerWidth] of border, hard at outer edge, smooth falloff inward
    float outerShadow = (1.0 - smoothstep(0.0, uOuterShadowWidth, borderPos)) * uOuterShadowIntensity;

    // Inner shadow band: occupies [1-innerWidth, 1] of border, hard at inner edge, smooth falloff outward
    float innerShadow = smoothstep(1.0 - uInnerShadowWidth, 1.0, borderPos) * uInnerShadowIntensity;

    // Darken the lit color
    finalColor *= (1.0 - outerShadow) * (1.0 - innerShadow);
  }

  // ── Translucency ──
  float baseAlpha = uBaseColor.a * (1.0 - uTranslucency);
  vec3 diffuseComponent = uBaseColor.rgb * 0.7 * ambientColor;
  vec3 highlightComponent = max(finalColor - diffuseComponent, vec3(0.0));
  float highlightLum = dot(highlightComponent, vec3(0.299, 0.587, 0.114));
  float effectiveAlpha = mix(baseAlpha, uBaseColor.a, clamp(highlightLum * 2.0, 0.0, 1.0));

  fragColor = vec4(clamp(finalColor, 0.0, 1.0), effectiveAlpha * outerAlpha);
}
