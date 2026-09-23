Shader "Creatush/TooltipSDF"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}

        // Changed default to 100, 100
        _CanvasSize ("Canvas Size", Vector) = (100, 100, 0, 0)
        _Width ("Face Width", Float) = 100
        _Height ("Face Height", Float) = 50
        
        // Corners
        _RadTL ("Top Left Radius", Float) = 5
        _RadTR ("Top Right Radius", Float) = 5
        _RadBR ("Bottom Right Radius", Float) = 5
        _RadBL ("Bottom Left Radius", Float) = 5
        
        // Face
        [Toggle] _FaceTransparent ("Face Transparent (Outlines Only)", Float) = 0
        _FaceColor ("Face Color 1", Color) = (1, 1, 1, 1)
        _FaceColor2 ("Face Color 2 (Gradient)", Color) = (0.8, 0.8, 0.8, 1)
        [Toggle] _UseGradient ("Use Gradient", Float) = 0
        
        _InnerShadowColor ("Inner Specular/Shadow Color", Color) = (0,0,0,0.5)
        _InnerShadowSize ("Inner Specular/Shadow Size", Float) = 5
        
        // Tip
        _TipPosX ("Tip Pos X", Float) = 0
        _TipPosY ("Tip Pos Y", Float) = -25
        _TipRot ("Tip Rotation", Float) = 180
        _TipSize ("Tip Length", Float) = 15
        _TipWidth ("Tip Width", Float) = 15
        
        // Outlines (1 to 5)
        _O1Width ("O1 Width", Float) = 0
        _O1Color ("O1 Color", Color) = (0,0,0,1)
        _O1Delta ("O1 Radius Delta", Float) = 0
        _O1OffX ("O1 Offset X", Float) = 0
        _O1OffY ("O1 Offset Y", Float) = 0

        _O2Width ("O2 Width", Float) = 0
        _O2Color ("O2 Color", Color) = (0,0,0,1)
        _O2Delta ("O2 Radius Delta", Float) = 0
        _O2OffX ("O2 Offset X", Float) = 0
        _O2OffY ("O2 Offset Y", Float) = 0

        _O3Width ("O3 Width", Float) = 0
        _O3Color ("O3 Color", Color) = (0,0,0,1)
        _O3Delta ("O3 Radius Delta", Float) = 0
        _O3OffX ("O3 Offset X", Float) = 0
        _O3OffY ("O3 Offset Y", Float) = 0

        _O4Width ("O4 Width", Float) = 0
        _O4Color ("O4 Color", Color) = (0,0,0,1)
        _O4Delta ("O4 Radius Delta", Float) = 0
        _O4OffX ("O4 Offset X", Float) = 0
        _O4OffY ("O4 Offset Y", Float) = 0

        _O5Width ("O5 Width", Float) = 0
        _O5Color ("O5 Color", Color) = (0,0,0,1)
        _O5Delta ("O5 Radius Delta", Float) = 0
        _O5OffX ("O5 Offset X", Float) = 0
        _O5OffY ("O5 Offset Y", Float) = 0

        // Shadow
        _ShadWidth ("Shadow Width", Float) = 5
        _ShadColor ("Shadow Color", Color) = (0,0,0,0.5)
        _ShadDelta ("Shadow Radius Delta", Float) = 0
        _ShadOffX ("Shadow Offset X", Float) = 0
        _ShadOffY ("Shadow Offset Y", Float) = -5
        _ShadOpacity ("Shadow Opacity", Range(0,1)) = 1
        _ShadSmooth ("Shadow Smoothness", Float) = 10

        _AlphaClip ("Alpha Clip Threshold", Range(0,1)) = 0
        _OverallOpacity ("Overall Opacity", Range(0,1)) = 1

        // Required for UI Masking
        [HideInInspector] _StencilComp ("Stencil Comparison", Float) = 8
        [HideInInspector] _Stencil ("Stencil ID", Float) = 0
        [HideInInspector] _StencilOp ("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask ("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask ("Stencil Read Mask", Float) = 255
        [HideInInspector] _ColorMask ("Color Mask", Float) = 15
        [HideInInspector] _ClipRect ("Clip Rect", Vector) = (-32767,-32767,32767,32767)
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off
        ColorMask [_ColorMask]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float4 positionOS : TEXCOORD1;
            };

            // Global Properties
            sampler2D _MainTex; // declared only so Canvas/Image doesn't warn about a missing _MainTex; never sampled, this is a pure SDF shape.
            float2 _CanvasSize;
            float _Width, _Height;
            float _RadTL, _RadTR, _RadBR, _RadBL;
            float _FaceTransparent;
            float4 _FaceColor, _FaceColor2;
            float _UseGradient;
            float4 _InnerShadowColor;
            float _InnerShadowSize;
            float _TipPosX, _TipPosY, _TipRot, _TipSize, _TipWidth;

            // Outlines
            float _O1Width, _O1Delta, _O1OffX, _O1OffY; float4 _O1Color;
            float _O2Width, _O2Delta, _O2OffX, _O2OffY; float4 _O2Color;
            float _O3Width, _O3Delta, _O3OffX, _O3OffY; float4 _O3Color;
            float _O4Width, _O4Delta, _O4OffX, _O4OffY; float4 _O4Color;
            float _O5Width, _O5Delta, _O5OffX, _O5OffY; float4 _O5Color;

            // Shadow
            float _ShadWidth, _ShadDelta, _ShadOffX, _ShadOffY, _ShadOpacity, _ShadSmooth; float4 _ShadColor;
            float _AlphaClip, _OverallOpacity;
            float4 _ClipRect;

            v2f vert (appdata_t v)
            {
                v2f o;
                o.positionOS = v.vertex;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            // User provided blend method
            void blend_float(float4 SourceColor, float SourceAlpha, float4 DestinationColor, out float4 Out)
            {
                Out = (SourceColor * SourceAlpha) + (DestinationColor * (1.0 - SourceAlpha));
            }

            // SDF Helpers
            float2 rotate2D(float2 v, float angleDegrees)
            {
                float rad = angleDegrees * (UNITY_PI / 180.0);
                float s = sin(rad);
                float c = cos(rad);
                return float2(v.x * c - v.y * s, v.x * s + v.y * c);
            }

            float sdRoundBox(float2 p, float2 b, float4 r)
            {
                r.xy = (p.x > 0.0) ? r.xy : r.zw;
                r.x  = (p.y > 0.0) ? r.x  : r.y;
                float2 q = abs(p) - b + r.x;
                return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
            }

            float sdTriangleIsosceles(float2 p, float2 q)
            {
                p.x = abs(p.x);
                float2 a = p - q * clamp(dot(p,q)/dot(q,q), 0.0, 1.0);
                float2 b = p - q * float2(clamp(p.x/q.x, 0.0, 1.0), 1.0);
                float s = -sign(q.y);
                float2 d = min(float2(dot(a,a), s*(p.x*q.y - p.y*q.x)),
                               float2(dot(b,b), s*(p.y - q.y)));
                return -sqrt(d.x)*sign(d.y);
            }

            // Master Shape Function
            float getShapeSDF(float2 p, float radDelta, float2 offset)
            {
                float2 localP = p - offset;
                
                // Box
                float4 r = float4(_RadTR, _RadBR, _RadTL, _RadBL) + radDelta;
                r = max(r, 0.0); // Prevent negative radius
                float boxDist = sdRoundBox(localP, float2(_Width, _Height) * 0.5, r);

                // Tip
                float2 tipP = localP - float2(_TipPosX, _TipPosY);
                tipP = rotate2D(tipP, -_TipRot);
                tipP.y -= _TipSize * 0.5; // Shift tip anchor
                float tipDist = sdTriangleIsosceles(tipP, float2(_TipWidth * 0.5, _TipSize));

                return min(boxDist, tipDist);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // UI mask (RectMask2D / Mask support)
                float2 clipUV = (i.positionOS.xy / i.positionOS.w) * 0.5 + 0.5;
                clipUV.y = 1 - clipUV.y;
                float uiMask = UnityGet2DClipping(clipUV, _ClipRect);

                // Map UV to local coordinate space (-0.5 to 0.5) * Canvas Size
                float2 p = (i.uv - 0.5) * _CanvasSize;
                
                // Anti-aliasing factor
                float aa = length(fwidth(p)) * 0.707;
                if (aa < 0.001) aa = 1.0; 

                float4 result = float4(0, 0, 0, 0);

                // --- 1. SHADOW (Backmost layer) ---
                if (_ShadWidth > 0.0 || _ShadSmooth > 0.0) {
                    float dShad = getShapeSDF(p, _ShadDelta, float2(_ShadOffX, _ShadOffY)) - _ShadWidth;
                    float aShad = smoothstep(_ShadSmooth, -_ShadSmooth, dShad) * _ShadOpacity;
                    blend_float(_ShadColor, aShad * _ShadColor.a, result, result);
                }

                // Helper macro to draw outlines back-to-front
                #define DRAW_OUTLINE(width, col, delta, offX, offY) \
                    if (width > 0.0) { \
                        float dOut = getShapeSDF(p, delta, float2(offX, offY)) - width; \
                        float aOut = smoothstep(aa, -aa, dOut); \
                        blend_float(col, aOut * col.a, result, result); \
                    }

                // --- 2. OUTLINES 5 down to 1 ---
                DRAW_OUTLINE(_O5Width, _O5Color, _O5Delta, _O5OffX, _O5OffY)
                DRAW_OUTLINE(_O4Width, _O4Color, _O4Delta, _O4OffX, _O4OffY)
                DRAW_OUTLINE(_O3Width, _O3Color, _O3Delta, _O3OffX, _O3OffY)
                DRAW_OUTLINE(_O2Width, _O2Color, _O2Delta, _O2OffX, _O2OffY)
                DRAW_OUTLINE(_O1Width, _O1Color, _O1Delta, _O1OffX, _O1OffY)

                // --- 3. FACE & CUTOUT ---
                float dFace = getShapeSDF(p, 0.0, float2(0,0));

                if (_FaceTransparent > 0.5)
                {
                    // Perfectly subtract/cut out the exact shape of the face from whatever outlines have drawn behind it
                    float mask = smoothstep(-aa, aa, dFace); // 0 inside the face, 1 outside
                    result *= mask; // Zeroes out the color and alpha precisely inside the face boundaries
                }
                else
                {
                    float aFace = smoothstep(aa, -aa, dFace);
                    
                    // Gradient calculation
                    float4 baseColor = _FaceColor;
                    if (_UseGradient > 0.5) {
                        float gradientFactor = saturate((p.y / _Height) + 0.5);
                        baseColor = lerp(_FaceColor2, _FaceColor, gradientFactor);
                    }
                    
                    // Inner Shadow / Specular (Applied at the inside edges)
                    float innerShadFactor = saturate(1.0 - (abs(dFace) / max(0.001, _InnerShadowSize)));
                    if (dFace > 0.0) innerShadFactor = 0.0; // Only apply inside
                    
                    float3 finalFaceRGB = lerp(baseColor.rgb, _InnerShadowColor.rgb, innerShadFactor * _InnerShadowColor.a);
                    
                    blend_float(float4(finalFaceRGB, 1), aFace * baseColor.a, result, result);
                }

                // Apply overall opacity
                result.a *= _OverallOpacity;

                // Apply UI mask (RectMask2D / Mask), then alpha clip as before
                result.a *= uiMask;
                clip(result.a - _AlphaClip - 0.0001);

                return result;
            }
            ENDCG
        }
    }
    CustomEditor "CustomShaderGUIs.TooltipSDFGUI"
}