#ifndef COMMON_2D_INCLUDED
#define COMMON_2D_INCLUDED

// Shared across the whole 2D Unlit bundle.
// Include AFTER Core.hlsl in every shader's HLSLPROGRAM block:
//   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//   #include "Common2D.hlsl"

// ---------------------------------------------------------------------
// Standard vertex I/O shared by every shader in this bundle.
// (A shader can add its own extra TEXCOORD channels alongside these.)
// ---------------------------------------------------------------------
struct Attributes2D
{
    float3 positionOS : POSITION;
    float4 color      : COLOR;
    float2 uv         : TEXCOORD0;
};

struct Varyings2D
{
    float4 positionHCS : SV_POSITION;
    float4 color       : COLOR;
    float2 uv          : TEXCOORD0;
    float2 clipPos     : TEXCOORD1; // world-space XY, used for RectMask2D soft clipping
};

// Fills everything except any shader-specific extra channels.
Varyings2D Vert2DBase(Attributes2D IN, float4 mainTexST, half4 tintColor)
{
    Varyings2D OUT = (Varyings2D)0;
    VertexPositionInputs vpi = GetVertexPositionInputs(IN.positionOS);
    OUT.positionHCS = vpi.positionCS;
    OUT.clipPos = vpi.positionWS.xy;
    OUT.color = IN.color * tintColor;
    OUT.uv = IN.uv * mainTexST.xy + mainTexST.zw;
    return OUT;
}

// ---------------------------------------------------------------------
// UI / Mask system support (RectMask2D soft clip + optional alpha clip).
// Matches the behaviour of Unity's built-in UI/Default shader so that
// Canvas -> RectMask2D and 2D Renderer -> SpriteMask both work without
// any extra setup: Unity feeds _ClipRect / stencil properties in via
// MaterialPropertyBlock automatically as long as the property names match.
// ---------------------------------------------------------------------
half UIClipRectFade(float2 worldPos, float4 clipRect)
{
    half2 inside = smoothstep(clipRect.xy - 1.0h, clipRect.xy + 1.0h, worldPos)
                 * (1.0h - smoothstep(clipRect.zw - 1.0h, clipRect.zw + 1.0h, worldPos));
    return inside.x * inside.y;
}

// Call at the end of every fragment shader, right before returning color.
half4 ApplyUIClipping(half4 color, float2 clipPos, float4 clipRect)
{
#if defined(UNITY_UI_CLIP_RECT)
    color.a *= UIClipRectFade(clipPos, clipRect);
#endif
#if defined(UNITY_UI_ALPHACLIP)
    clip(color.a - 0.001h);
#endif
    return color;
}

// ---------------------------------------------------------------------
// Mirror fold: reflects a UV axis around a pivot.
// Reflects one half of a 0..1 UV axis onto the other half, folded exactly
// at the midpoint (0.5) - matches art authored with content in one half
// and the other half left blank for the reflection to fill.
// mirrorOn  = 0 -> untouched, 1 -> folded
// reverseOn = 0 -> the LOW half (u<=0.5) is kept as-is, the HIGH half
//                   becomes a flipped copy of it
// reverseOn = 1 -> the HIGH half (u>=0.5) is kept as-is, the LOW half
//                   becomes a flipped copy of it
// ---------------------------------------------------------------------
float MirrorAxis(float u, float mirrorOn, float reverseOn)
{
    float d = u - 0.5;
    float folded = lerp(0.5 - abs(d), 0.5 + abs(d), reverseOn);
    return lerp(u, folded, mirrorOn);
}

// ---------------------------------------------------------------------
// Small math utilities reused by several shaders.
// ---------------------------------------------------------------------
float Hash21(float2 p)
{
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

float3 RGBtoHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 HSVtoRGB(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

#endif // COMMON_2D_INCLUDED
