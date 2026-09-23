// UberSprite.shader
// Combines Mirror, Pixelate, HSV/Grayscale, Dissolve, Hit Flash, Outline and
// Shine Sweep behind independent shader_feature_local toggles - a material
// only ever compiles the exact combination it enables.
//
// Ported to CGPROGRAM + UnityUI.cginc (see HSV.shader's header comment for
// why) and uses the corrected tile-and-mirror math (see Mirror.shader).
//
// IMPORTANT: every property name, [Header]/[Toggle] attribute, and keyword
// below is unchanged from the previous version on purpose - Editor/UberSpriteGUI.cs
// finds properties by these exact names and was NOT modified alongside this file.
Shader "Creatush/UberSprite"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)

        [Header(Mirror)]
        [Toggle(_USEMIRROR_ON)] _UseMirror ("Enable Mirror", Float) = 0
        [Toggle] _MirrorX ("Mirror Horizontal", Float) = 0
        [Toggle] _ReverseX ("Reverse Horizontal", Float) = 0
        [Toggle] _MirrorY ("Mirror Vertical", Float) = 0
        [Toggle] _ReverseY ("Reverse Vertical", Float) = 0

        [Header(Pixelate)]
        [Toggle(_USEPIXELATE_ON)] _UsePixelate ("Enable Pixelate", Float) = 0
        _PixelCountX ("Pixel Grid Columns", Range(2,256)) = 32
        _PixelCountY ("Pixel Grid Rows", Range(2,256)) = 32
        _ColorLevels ("Color Levels (0 = off)", Range(0,16)) = 0

        [Header(HSV and Grayscale)]
        [Toggle(_USEHSV_ON)] _UseHSV ("Enable HSV Adjust", Float) = 0
        _HueShift ("Hue Shift", Range(0,1)) = 0
        _Saturation ("Saturation", Range(0,2)) = 1
        _Brightness ("Brightness", Range(0,2)) = 1
        _Grayscale ("Grayscale Amount", Range(0,1)) = 0

        [Header(Dissolve)]
        [Toggle(_USEDISSOLVE_ON)] _UseDissolve ("Enable Dissolve", Float) = 0
        _NoiseTex ("Dissolve Noise", 2D) = "white" {}
        _DissolveAmount ("Dissolve Amount", Range(0,1)) = 0
        _EdgeWidth ("Edge Width", Range(0.001, 0.5)) = 0.08
        _EdgeColor ("Edge Color", Color) = (1, 0.6, 0.1, 1)
        _EdgeIntensity ("Edge Intensity", Range(1,8)) = 3

        [Header(Hit Flash)]
        [Toggle(_USEHITFLASH_ON)] _UseHitFlash ("Enable Hit Flash", Float) = 0
        _FlashColor ("Flash Color", Color) = (1,1,1,1)
        _FlashAmount ("Flash Amount", Range(0,1)) = 0

        [Header(Outline and Glow)]
        [Toggle(_USEOUTLINE_ON)] _UseOutline ("Enable Outline", Float) = 0
        _OutlineColor ("Outline Color", Color) = (1,1,1,1)
        _OutlineWidth ("Outline Width (px)", Range(0,8)) = 2
        _OutlineOnly ("Outline Only (hide fill)", Range(0,1)) = 0

        [Header(Shine Sweep)]
        [Toggle(_USESHINESWEEP_ON)] _UseShineSweep ("Enable Shine Sweep", Float) = 0
        _SweepColor ("Sweep Color", Color) = (1,1,1,0.8)
        _SweepWidth ("Sweep Width", Range(0.01, 1)) = 0.2
        _SweepSoftness ("Sweep Softness", Range(0, 1)) = 0
        _SweepAngle ("Sweep Angle (deg)", Range(0,360)) = 20
        _SweepSpeed ("Sweep Speed", Float) = 1.0
        _SweepInterval ("Sweep Interval (sec)", Float) = 3.0

        // --- UI / Mask & SpriteMask stencil support ---
        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
        _ColorMask ("Color Mask", Float) = 15
        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0
        _ClipRect ("Clip Rect (auto by RectMask2D)", Vector) = (-32767, -32767, 32767, 32767)
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile __ UNITY_UI_CLIP_RECT
            #pragma multi_compile __ UNITY_UI_ALPHACLIP
            #pragma shader_feature_local _USEMIRROR_ON
            #pragma shader_feature_local _USEPIXELATE_ON
            #pragma shader_feature_local _USEHSV_ON
            #pragma shader_feature_local _USEDISSOLVE_ON
            #pragma shader_feature_local _USEHITFLASH_ON
            #pragma shader_feature_local _USEOUTLINE_ON
            #pragma shader_feature_local _USESHINESWEEP_ON
            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            struct appdata
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

            sampler2D _MainTex;
            float4 _MainTex_TexelSize; // auto-populated by Unity whenever _MainTex is assigned
            float4 _ClipRect;
            fixed4 _Color;

            #if defined(_USEDISSOLVE_ON)
                sampler2D _NoiseTex;
                float4 _NoiseTex_ST;
            #endif

            CBUFFER_START(UnityPerMaterial)
                // Mirror
                float _MirrorX, _ReverseX, _MirrorY, _ReverseY;

                // Pixelate
                float _PixelCountX, _PixelCountY, _ColorLevels;

                // HSV
                float _HueShift, _Saturation, _Brightness, _Grayscale;

                // Dissolve
                float _DissolveAmount, _EdgeWidth, _EdgeIntensity;
                fixed4 _EdgeColor;

                // Hit Flash
                fixed4 _FlashColor;
                float _FlashAmount;

                // Outline
                fixed4 _OutlineColor;
                float _OutlineWidth, _OutlineOnly;

                // Shine Sweep
                fixed4 _SweepColor;
                float _SweepWidth, _SweepSoftness, _SweepAngle, _SweepSpeed, _SweepInterval;
            CBUFFER_END

            // Tent/triangle-wave fold - see Mirror.shader for the derivation.
            float MirrorAxis(float u, float mirrorOn, float reverseOn)
            {
                float isSecondHalf = step(0.5, u);
                float leftSourceResult = lerp(u * 2.0, 2.0 - u * 2.0, isSecondHalf);
                float rightSourceResult = 1.0 - leftSourceResult;
                float folded = lerp(leftSourceResult, rightSourceResult, reverseOn);
                return lerp(u, folded, mirrorOn);
            }

            float3 RGBtoHSV(float3 c)
            {
                float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0*d + e)), d / (q.x + e), q.x);
            }

            float3 HSVtoRGB(float3 c)
            {
                float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.positionOS = v.vertex;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color * _Color;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 clipUV = (i.positionOS.xy / i.positionOS.w) * 0.5 + 0.5;
                clipUV.y = 1 - clipUV.y;
                float uiMask = UnityGet2DClipping(clipUV, _ClipRect);

                float2 uv = i.uv;

                // 1) Mirror fold happens first, on the raw UV.
            #if defined(_USEMIRROR_ON)
                uv.x = MirrorAxis(uv.x, _MirrorX, _ReverseX);
                uv.y = MirrorAxis(uv.y, _MirrorY, _ReverseY);
            #endif

                // 2) Pixelate quantizes whatever UV we have so far.
            #if defined(_USEPIXELATE_ON)
                float2 grid = float2(_PixelCountX, _PixelCountY);
                uv = floor(uv * grid) / grid + (0.5 / grid);
            #endif

                fixed4 col = tex2D(_MainTex, uv);

                // 3) HSV / grayscale state adjustment.
            #if defined(_USEHSV_ON)
                float3 hsv = RGBtoHSV(col.rgb);
                hsv.x = frac(hsv.x + _HueShift);
                hsv.y = saturate(hsv.y * _Saturation);
                hsv.z = saturate(hsv.z * _Brightness);
                float3 rgb = HSVtoRGB(hsv);
                float luma = dot(rgb, float3(0.299, 0.587, 0.114));
                col.rgb = lerp(rgb, luma.xxx, _Grayscale);
            #endif

            #if defined(_USEPIXELATE_ON)
                if (_ColorLevels > 0.5)
                {
                    col.rgb = floor(col.rgb * _ColorLevels) / _ColorLevels;
                }
            #endif

                // 4) Dissolve clip + emissive edge.
            #if defined(_USEDISSOLVE_ON)
                float2 noiseUV = uv * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                fixed n = tex2D(_NoiseTex, noiseUV).r;
                clip(n - _DissolveAmount);
                float edge = 1 - smoothstep(0, _EdgeWidth, n - _DissolveAmount);
                col.rgb += _EdgeColor.rgb * edge * _EdgeIntensity;
            #endif

                // 5) Hit flash tint.
            #if defined(_USEHITFLASH_ON)
                col.rgb = lerp(col.rgb, _FlashColor.rgb, _FlashAmount * _FlashColor.a);
            #endif

                // 6) Outline, sampled in the same UV space as everything above
                //    so it traces the mirrored/pixelated silhouette, not the raw one.
            #if defined(_USEOUTLINE_ON)
                float2 texel = _MainTex_TexelSize.xy * _OutlineWidth;
                float a = 0;
                a = max(a, tex2D(_MainTex, uv + float2( texel.x, 0)).a);
                a = max(a, tex2D(_MainTex, uv + float2(-texel.x, 0)).a);
                a = max(a, tex2D(_MainTex, uv + float2(0,  texel.y)).a);
                a = max(a, tex2D(_MainTex, uv + float2(0, -texel.y)).a);

                float outlineMask = saturate(a - col.a);
                float3 fillRGB = col.rgb * (1 - _OutlineOnly);
                float fillA = col.a * (1 - _OutlineOnly);

                col.rgb = lerp(fillRGB, _OutlineColor.rgb, outlineMask * _OutlineColor.a);
                col.a = saturate(fillA + outlineMask * _OutlineColor.a);
            #endif

                // 7) Shine sweep uses the ORIGINAL (pre-mirror/pixelate) UV so the
                //    glint always travels consistently regardless of those settings.
            #if defined(_USESHINESWEEP_ON)
                float t = fmod(_Time.y, max(_SweepInterval, 0.0001)) * _SweepSpeed;
                float2 dir = float2(cos(radians(_SweepAngle)), sin(radians(_SweepAngle)));
                float coord = dot(i.uv - 0.5, dir) + 0.5;
                float w = _SweepWidth;
                float s = _SweepSoftness;
                float band = smoothstep(t - w - s, t, coord) * (1 - smoothstep(t, t + w + s, coord));
                col.rgb += _SweepColor.rgb * band * _SweepColor.a * col.a;
            #endif

                col.rgb *= i.color.rgb;
                col.a *= i.color.a;

                #ifdef UNITY_UI_CLIP_RECT
                col.a *= uiMask;
                #endif
                #ifdef UNITY_UI_ALPHACLIP
                clip(col.a - 0.001);
                #endif

                return col;
            }
            ENDCG
        }
    }

    CustomEditor "CustomShaderGUIs.UberSpriteGUI"
    Fallback "UI/Default"
}
