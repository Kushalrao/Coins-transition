#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// A single curved band of light sweeping up the screen.
//
// Ported from the header reveal in the companion `Homepage transition`
// prototype, itself a port of Martin Ren's NameDrop write-up
// (https://martinrgb.github.io/blog/#/Namedrop_Animation). The light model is
// his, in full — four additive terms, not one:
//
//   1. a multiplicative blow-out, `colour += colour * wave * glow`, which
//      brightens the backdrop *by itself* rather than washing it toward flat
//      white. This is most of why it reads as light passing through the
//      content instead of a bar painted over it.
//   2. an additive core on the crest.
//   3. `simple_light_snippet` — a Phong specular against a normal taken from
//      the luminance gradient of the content underneath
//      (`procedural_normal_generator`), so the highlight crawls over whatever
//      the band crosses.
//   4. `downsample/upsample_snippet` — Ren's dual-Kawase chain, which is also
//      the standard bloom kernel and is what throws the hot halo out of the
//      contact point. Reproduced analytically as a radial falloff, since the
//      source is a point. Its radius runs AHEAD of the crest, so the light
//      leads the band rather than sitting on it.
//
// Radial, so the band arcs along the aurora's own leading edge rather than
// cutting straight across — it shares a centre with the bloom discs, which sit
// below the bottom edge, so the arc is convex upward and rises with them.
//
// The one thing deliberately NOT carried over is `two_dimensions_wave_snippet`,
// the trailing ripple train. Ren puts roughly three concentric rings behind the
// crest; travelling up a screen those read as several lines rather than one
// beam. Only the crest survives here.
//
// The crest profile has zero slope at both lips as well as at the peak, or the
// discontinuity in the displacement gradient shows up as a seam travelling with
// the band. `smoothstep` gives that for free where a parabola does not.

constant float kDepth = 1.0;
constant float kBump = 1.25;
constant float kSpecularExponent = 16.0;
constant float kLightHeight = 260.0;
constant float kEyeHeight = 300.0;
// Radius at which the wave is at full strength; past it the whole effect eases off.
constant float kFalloffRadius = 320.0;
// Ren's DEPTH, controlling how pronounced the content relief is.
constant float kReliefDepth = 1.5;

// Ren's luminance weights verbatim. The red coefficient is 1.2126 rather than
// the usual 0.2126 — kept as he has it, because it is what gives warm content
// its heavier relief.
static float auroraLuminance(float3 c) {
    return dot(c, float3(1.2126, 0.7152, 0.0722));
}

static float3 auroraSampleStraight(SwiftUI::Layer layer, float2 p, float2 size) {
    half4 s = layer.sample(clamp(p, float2(0.5), size - 0.5));
    float a = float(s.a);
    return a > 0.0 ? float3(s.rgb) / a : float3(s.rgb);
}

// `procedural_normal_generator`: relief from the luminance gradient of the content.
static float3 auroraContentNormal(SwiftUI::Layer layer, float2 p, float2 size, float offset) {
    float R = abs(auroraLuminance(auroraSampleStraight(layer, p + float2( offset, 0.0), size)));
    float L = abs(auroraLuminance(auroraSampleStraight(layer, p + float2(-offset, 0.0), size)));
    float D = abs(auroraLuminance(auroraSampleStraight(layer, p + float2(0.0,  offset), size)));
    float U = abs(auroraLuminance(auroraSampleStraight(layer, p + float2(0.0, -offset), size)));
    return normalize(float3((L - R) * 0.5, (U - D) * 0.5, 1.0 / kReliefDepth));
}

[[ stitchable ]]
half4 auroraBeam(float2 position, SwiftUI::Layer layer, float2 size,
                 float2 center, float radius, float band,
                 float refraction, float glow, float2 lightPosition,
                 float reliefOffset, float reliefStrength, float specularStrength,
                 float bloomRadius, float bloomStrength, float shading,
                 float haloAtCrest)
{
    if (band < 0.5) {
        return layer.sample(position);
    }

    float d = distance(position, center);
    float fromCrest = d - radius;

    // --- bloom ---------------------------------------------------------------
    // A hot core at the origin spilling into a soft halo: a tight falloff that
    // blows the centre out, plus a wide one for the spill. It reaches past the
    // wavefront, so it is computed before anything else can return.
    // `haloAtCrest` chooses what the halo is anchored to. Ren's original sits on
    // the ORIGIN, which is right for NameDrop because there the origin *is* the
    // contact point the light pours out of. Here the origin is the bottom edge
    // of the screen and the band travels away from it, so anchoring there floods
    // the page from below and has to be kept nearly off to stay tolerable. Set
    // to 1 the halo rides the crest instead — the true equivalent of the contact
    // point — and can then burn at full strength, because it moves with the beam
    // rather than swelling out of one corner.
    float haloBasis = mix(d, fabs(fromCrest), haloAtCrest);
    float bloomFall = 1.0 - clamp(haloBasis / max(bloomRadius, 1.0), 0.0, 1.0);
    float bloom = (0.62 * pow(bloomFall, 3.0) + 0.38 * pow(bloomFall, 1.3)) * bloomStrength;

    // Ahead of the band there is no glass — but the halo still washes over it.
    if (fromCrest > band) {
        if (bloom <= 0.002) {
            return layer.sample(position);
        }
        half4 ahead = layer.sample(position);
        float aheadAlpha = float(ahead.a);
        float3 aheadColour = aheadAlpha > 0.0 ? float3(ahead.rgb) / aheadAlpha : float3(ahead.rgb);
        aheadColour = clamp(aheadColour + bloom, 0.0, 1.0);
        return half4(half3(aheadColour * max(aheadAlpha, 0.0001)), ahead.a);
    }

    float2 outward = d > 0.0001 ? (position - center) / d : float2(0.0, -1.0);

    // --- crest ---------------------------------------------------------------
    float across = clamp(fromCrest / band, -1.0, 1.0);
    float crest = 1.0 - smoothstep(0.0, 1.0, fabs(across));
    // A smooth ridge for the normal; the crest's own derivative peaks awkwardly.
    float crestSlope = 6.0 * fabs(across) * (1.0 - fabs(across)) * sign(fromCrest);

    // Everything weakens as the band travels outwards.
    float attenuation = clamp(kFalloffRadius / max(radius, kFalloffRadius), 0.32, 1.0);
    float wave = crest * attenuation;
    float activity = clamp(crest, 0.0, 1.0);

    // --- refraction ----------------------------------------------------------
    // Signed about the crest, so the two sides bend opposite ways. That is what
    // makes it read as a lens rather than a bright stripe.
    float bend = across * crest;
    float2 from = position + outward * bend * refraction * attenuation;
    // Sampling past the edge comes back transparent, which would punch a hole
    // through the page wherever the band bends outwards near a border.
    from = clamp(from, float2(0.5), size - 0.5);

    half4 source = layer.sample(from);
    float alpha = float(source.a);
    float3 colour = alpha > 0.0 ? float3(source.rgb) / alpha : float3(source.rgb);

    // --- surface -------------------------------------------------------------
    // The band gives the large shape; the content's own luminance gives the
    // fine relief the highlight crawls over.
    // `shading` steepens the glass. It matters most over a pale field: additive
    // light cannot read on white, so what makes the band visible there is the
    // shadow it casts on its own shoulders, not the brightness of its core.
    float3 waveNormal = float3(outward * crestSlope * kBump * shading, 1.0 / kDepth);
    float3 relief = auroraContentNormal(layer, from, size, reliefOffset);
    float3 normal = normalize(waveNormal + float3(relief.xy * reliefStrength * activity, 0.0));

    float3 surface = float3(position, 0.0);
    float3 toLight = normalize(float3(lightPosition, kLightHeight) - surface);
    float3 toEye = normalize(float3(position, kEyeHeight) - surface);

    // Lambert, measured against a flat facing-up surface so only the relief
    // shades. At shading = 1 this is the header reveal's original 1.5 / 0.6 /
    // 1.7 exactly; above 1 the shoulders darken further and the band gains
    // form against a background it cannot outshine.
    float lambert = dot(normal, toLight) - dot(float3(0.0, 0.0, 1.0), toLight);
    float amp = 1.5 * shading;
    float lo = max(0.30, 1.0 - 0.40 * shading);
    float hi = 1.0 + 0.70 * shading;
    colour *= clamp(1.0 + lambert * amp, lo, hi);

    // "Blow out the colour" — the light carried along the band. The first term
    // brightens the backdrop by itself, which is what keeps it reading as light
    // rather than as white paint.
    colour += colour * wave * glow;
    colour += max(wave, 0.0) * max(wave, 0.0) * glow * 0.22;

    // Phong specular, riding the content relief.
    float specular = pow(clamp(dot(normalize(reflect(-toLight, normal)), toEye), 0.0, 1.0),
                         kSpecularExponent);
    colour += specular * specularStrength * activity * attenuation;

    // The halo, over the glass as well as ahead of it.
    colour += bloom;

    return half4(half3(clamp(colour, 0.0, 1.0) * max(alpha, 0.0001)), source.a);
}
