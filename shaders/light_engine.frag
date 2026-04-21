#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Light Engine Uniforms
uniform vec2 u_resolution;
uniform float u_exposure;
uniform float u_brightness;
uniform float u_contrast;
uniform float u_highlights;
uniform float u_shadows;
uniform float u_whites;
uniform float u_blacks;
uniform float u_blackPoint;
uniform float u_fade;
uniform float u_brilliance;
uniform float u_clarity;
uniform float u_sharpen;
uniform float u_texture;
uniform float u_luma_nr;
uniform float u_color_nr;
uniform float u_grain;
// HSL Engine Uniforms (x = Hue, y = Saturation, z = Luminance offsets)
uniform vec3 u_hsl_red;      // 0°
uniform vec3 u_hsl_orange;   // 30°
uniform vec3 u_hsl_yellow;   // 60°
uniform vec3 u_hsl_green;    // 120°
uniform vec3 u_hsl_aqua;     // 180°
uniform vec3 u_hsl_blue;     // 240°
uniform vec3 u_hsl_purple;   // 270°
uniform vec3 u_hsl_magenta;  // 300°

uniform sampler2D u_image;

out vec4 fragColor;

const float gamma = 2.2;
const vec3 LUMA_COEFF = vec3(0.2126, 0.7152, 0.0722); // Rec.709 perceived luminance

vec3 srgbToLinear(vec3 c) {
    return pow(c, vec3(gamma)); // Fast approx for mobile
}

vec3 linearToSrgb(vec3 c) {
    return pow(c, vec3(1.0 / gamma));
}

float gaussianWeight(float l, float center, float sigma) {
    float x = l - center;
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

// ---- HSL Utilities ----

vec3 rgb2hsl(vec3 c) {
    float cMin = min(c.r, min(c.g, c.b));
    float cMax = max(c.r, max(c.g, c.b));
    float delta = cMax - cMin;
    float l = (cMax + cMin) / 2.0;

    if (delta == 0.0) {
        return vec3(0.0, 0.0, l);
    }

    float s = l > 0.5 ? delta / (2.0 - cMax - cMin) : delta / (cMax + cMin);
    float h = 0.0;

    if (cMax == c.r) {
        h = (c.g - c.b) / delta + (c.g < c.b ? 6.0 : 0.0);
    } else if (cMax == c.g) {
        h = (c.b - c.r) / delta + 2.0;
    } else if (cMax == c.b) {
        h = (c.r - c.g) / delta + 4.0;
    }

    h /= 6.0;
    return vec3(h, s, l);
}

float hue2rgb(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0 / 2.0) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
}

vec3 hsl2rgb(vec3 c) {
    float h = c.x;
    float s = c.y;
    float l = c.z;

    if (s == 0.0) {
        return vec3(l);
    }

    float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    float p = 2.0 * l - q;
    
    return vec3(
        hue2rgb(p, q, h + 1.0 / 3.0),
        hue2rgb(p, q, h),
        hue2rgb(p, q, h - 1.0 / 3.0)
    );
}

// Distance along the hue wheel (handles 360 wrap around)
float hueDistance(float h1, float h2) {
    float diff = abs(h1 - h2);
    return min(diff, 1.0 - diff);
}

// Soft Cosine-like falloff for hue masking
float getHueWeight(float pixelHue, float targetHueDegrees) {
    float targetHue = targetHueDegrees / 360.0;
    float dist = hueDistance(pixelHue, targetHue);
    // Span determines how wide the color block is before it drops off
    // 30 degrees = ~0.083 span. Use 0.12 to give it a nice smooth overlap.
    float span = 0.12; 
    
    if (dist > span) return 0.0;
    
    // Smooth bell curve falloff (cosine wave shape mapped to the span)
    return 0.5 * (1.0 + cos(3.1415926535 * (dist / span)));
}

// ----------------------

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution.xy;
    vec4 texColor = texture(u_image, uv);
    
    // 1. Convert sRGB -> Linear
    vec3 col = srgbToLinear(texColor.rgb);

    // ==========================================
    // SPATIAL DETAILS (Pre-Light Denoising)
    // ==========================================
    // Tighten the spatial sampling radius. 
    // If the image is 4K but u_resolution is only screen size (400px), a large offset causes pixel skipping.
    // Stride skipping causes ghosting/aliasing which visually mimics digital noise (grain) instead of blurring.
    vec2 pO = 0.4 / u_resolution.xy; 
    vec3 cN = srgbToLinear(texture(u_image, uv + vec2(0.0, -pO.y)).rgb);
    vec3 cS = srgbToLinear(texture(u_image, uv + vec2(0.0, pO.y)).rgb);
    vec3 cE = srgbToLinear(texture(u_image, uv + vec2(pO.x, 0.0)).rgb);
    vec3 cW = srgbToLinear(texture(u_image, uv + vec2(-pO.x, 0.0)).rgb);
    vec3 blurCol = (col + cN + cS + cE + cW) * 0.2;
    
    float luma = dot(col, LUMA_COEFF);
    float blurLuma = dot(blurCol, LUMA_COEFF);
    float hpDiff = luma - blurLuma; // High pass detail difference

    // Luminance Noise Reduction
    if (u_luma_nr > 0.0) {
        float noiseMask = 1.0 - smoothstep(0.0, 0.05, abs(hpDiff)); 
        col = mix(col, blurCol, u_luma_nr * noiseMask * 0.8);
        luma = dot(col, LUMA_COEFF);
        hpDiff = luma - blurLuma; // Update detail
    }
    
    // Color Noise Reduction
    if (u_color_nr > 0.0) {
        vec3 hslSharp = rgb2hsl(col);
        vec3 hslBlur = rgb2hsl(blurCol);
        vec3 colorDenoised = hsl2rgb(vec3(hslBlur.x, hslBlur.y, hslSharp.z));
        col = mix(col, colorDenoised, u_color_nr);
    }

    // ==========================================
    // LIGHT ENGINE (Global Adjustments)
    // ==========================================

    // 1. Exposure (±2 EV overall shift)
    col *= pow(2.0, u_exposure * 2.0);
    luma = dot(col, LUMA_COEFF);
    float newLuma = luma;

    // 2. Brightness (midtones only: 30-70% range)
    if (u_brightness != 0.0) {
        float b = u_brightness * 0.5;
        float midWeight = gaussianWeight(newLuma, 0.5, 0.25);
        newLuma += b * midWeight; 
    }

    // 3. Contrast (tone curve S-curve pivoted at 0.35)
    if (u_contrast != 0.0) {
        float pivot = 0.35;
        float diff = newLuma - pivot;
        newLuma = pivot + diff * (1.0 + u_contrast * 1.5);
    }

    // 4. Highlights / Shadows
    float normHighlights = u_highlights * (1.0 - max(0.0, u_exposure * 0.5));
    float origL = newLuma; 
    float shadowWeight = gaussianWeight(origL, 0.0, 0.15); 
    newLuma += u_shadows * shadowWeight * (1.0 - origL) * 0.5;
    float highlightWeight = gaussianWeight(origL, 1.0, 0.15); 
    newLuma += normHighlights * highlightWeight * origL * 0.5; 

    // 5. Whites / Blacks
    if (u_whites != 0.0) {
        float wWeight = gaussianWeight(origL, 1.0, 0.05); // Very narrow top
        newLuma += u_whites * wWeight * 0.5;
    }
    if (u_blacks != 0.0) {
        float bWeight = gaussianWeight(origL, 0.0, 0.05); // Very narrow bottom
        newLuma += u_blacks * bWeight * 0.5;
    }

    // 6. Black Point
    if (u_blackPoint != 0.0) {
        float bp = u_blackPoint * 0.2; 
        newLuma = bp + newLuma * (1.0 - bp);
    }

    // 7. Fade (lift extreme blacks with exponent)
    if (u_fade > 0.0) {
        float fadeAmt = u_fade * 0.15; 
        newLuma += fadeAmt * pow(max(0.0, 1.0 - newLuma), 3.0);
    }

    // 8. Brilliance (smart contrast)
    if (u_brilliance != 0.0) {
        float bril = u_brilliance * 0.2; 
        // boost midtones
        newLuma += bril * gaussianWeight(newLuma, 0.4, 0.25);
        // compress extremely bright areas slightly to preserve detail
        newLuma -= bril * 0.5 * gaussianWeight(newLuma, 1.0, 0.2);
    }

    // 9. Clarity, Texture, Sharpen (High-pass micro contrast)
    if (u_clarity != 0.0 || u_sharpen != 0.0 || u_texture != 0.0) {
        // Linearly scale detail magnitude corresponding to exposure push
        float detailScaled = hpDiff * (newLuma / (luma + 0.0001)); 

        // Noise-Detail Balance: Dynamically reduce high-frequency filtering if Luma NR is active
        float noisePreserveRatio = max(0.0, 1.0 - u_luma_nr * 0.85);
        
        // Clarity: broad midtone emphasis (separated from fine texture)
        float clarWt = gaussianWeight(newLuma, 0.5, 0.3); 
        newLuma += detailScaled * u_clarity * clarWt * 1.5;

        // Texture: high frequency global surface details
        // Apply noisePreserveRatio so we don't recreate noise we just destroyed!
        newLuma += detailScaled * u_texture * 0.75 * noisePreserveRatio;
        
        // Sharpen: strict edge masking only (ignore flat spaces entirely)
        float edgeMask = smoothstep(0.02, 0.08, abs(detailScaled));
        newLuma += detailScaled * u_sharpen * edgeMask * 2.5 * noisePreserveRatio;
    }

    // Highlight rolloff built-in to prevent digital blowout
    if (newLuma > 0.8) {
        float excess = newLuma - 0.8;
        float k = 0.5; 
        newLuma = 0.8 + (excess / (excess + k)) * 0.2;
    }
    newLuma = max(0.0, newLuma);

    if (luma > 0.0001) {
        col *= (newLuma / luma);
    } else {
        col = vec3(newLuma);
    }
    col = clamp(col, 0.0, 1.0);

    // ==========================================
    // HSL ENGINE (Per-Color Adjustments)
    // ==========================================
    vec3 hslCol = rgb2hsl(col);
    float pixelHue = hslCol.x; // 0.0 to 1.0
    
    // Calculate blended offset based on hue distance from each of the 8 anchors
    vec3 totalOffset = vec3(0.0);
    float totalWeight = 0.0;
    float w;
    
    // Red & Orange get Hue-Shift protection to preserve skin tones
    w = getHueWeight(pixelHue, 0.0);
    vec3 redAdj = u_hsl_red; redAdj.x = clamp(redAdj.x, -0.05, 0.05); 
    totalOffset += redAdj * w; totalWeight += w;
    
    w = getHueWeight(pixelHue, 30.0);
    vec3 orangeAdj = u_hsl_orange; orangeAdj.x = clamp(orangeAdj.x, -0.05, 0.05);
    totalOffset += orangeAdj * w; totalWeight += w;
    
    w = getHueWeight(pixelHue, 60.0);  totalOffset += u_hsl_yellow * w; totalWeight += w;
    w = getHueWeight(pixelHue, 120.0); totalOffset += u_hsl_green * w; totalWeight += w;
    w = getHueWeight(pixelHue, 180.0); totalOffset += u_hsl_aqua * w; totalWeight += w;
    w = getHueWeight(pixelHue, 240.0); totalOffset += u_hsl_blue * w; totalWeight += w;
    w = getHueWeight(pixelHue, 270.0); totalOffset += u_hsl_purple * w; totalWeight += w;
    w = getHueWeight(pixelHue, 300.0); totalOffset += u_hsl_magenta * w; totalWeight += w;

    // Normalize overlapping color influences to prevent stacking artifacts
    if (totalWeight > 1.0) {
        totalOffset /= totalWeight;
    }

    // Apply Offsets
    // Hue: continuous rotation (treat as circular)
    hslCol.x = fract(hslCol.x + totalOffset.x); 
    if (hslCol.x < 0.0) hslCol.x += 1.0;
    
    // Saturation: clamp [0, 1.5]
    hslCol.y = clamp(hslCol.y + totalOffset.y, 0.0, 1.5);
    
    // Lightness: clamp [0, 1.0]
    hslCol.z = clamp(hslCol.z + totalOffset.z, 0.0, 1.0);

    // Only convert back to RGB if there was actually an HSL adjustment to save perf
    // Though branch divergence could be bad... we'll do it safely
    vec3 finalPushedCol = hsl2rgb(hslCol);
    
    // Mix it back. If saturation was 0.0 originally, there's no hue, don't invent color
    // (hsl2rgb handles this smoothly)
    col = mix(col, finalPushedCol, min(1.0, length(totalOffset) * 1000.0)); // basically if length > 0, swap
    // Wait, mix step using length is a branchless optimization but can be dangerous if near 0. 
    // We just safely use finalPushedCol:
    // Mix it back safely
    col = finalPushedCol;

    // Organic Film Grain Module (Luminance Only)
    if (u_grain > 0.0) {
        float rnd = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
        float grainVal = (rnd - 0.5) * 0.15 * u_grain;
        // Grain Model: Scale based on brightness (more in shadows, drops off heavily in pure highlights)
        float grainMask = pow(max(0.0, 1.0 - hslCol.z), 0.8); 
        
        // Apply purely to luminance channel to prevent chromatic artifacting
        hslCol.z = clamp(hslCol.z + grainVal * grainMask, 0.0, 1.0);
        col = hsl2rgb(hslCol);
    }

    // 9. Convert back from Linear -> sRGB
    vec3 finalColor = linearToSrgb(col);
    
    fragColor = vec4(finalColor, texColor.a);
}
