Shader "Creatush/SpriteExtension"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        [HideInInspector] _Color ("Tint", Color) = (1,1,1,1)

        // Main Image Modifiers
        _GrayscaleAmount ("Grayscale Amount", Range(0, 1)) = 1.0
        _OverlayColor ("Overlay Color", Color) = (0, 0, 0, 0.5)

        // Outline 1
        _OutlineColor1 ("Outline 1 Color", Color) = (1, 1, 1, 1)
        _OutlineWidth1 ("Outline 1 Width", Range(0, 10)) = 1.0
        _OutlineOffset1 ("Outline 1 Offset", Vector) = (0, 0, 0, 0)

        // Outline 2
        _OutlineColor2 ("Outline 2 Color", Color) = (0, 0, 0, 1)
        _OutlineWidth2 ("Outline 2 Width", Range(0, 10)) = 2.0
        _OutlineOffset2 ("Outline 2 Offset", Vector) = (0, 0, 0, 0)

        // Soft Shadow
        _ShadowColor ("Shadow Color", Color) = (0, 0, 0, 0.5)
        _ShadowOffset ("Shadow Offset", Vector) = (2, -2, 0, 0)
        _ShadowSoftness ("Shadow Softness", Range(0, 10)) = 2.0

        // Required for UI Masking
        [HideInInspector] _StencilComp ("Stencil Comparison", Float) = 8
        [HideInInspector] _Stencil ("Stencil ID", Float) = 0
        [HideInInspector] _StencilOp ("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask ("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask ("Stencil Read Mask", Float) = 255
        [HideInInspector] _ColorMask ("Color Mask", Float) = 15
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

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
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
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            fixed4 _Color;

            float _GrayscaleAmount;
            fixed4 _OverlayColor;

            fixed4 _OutlineColor1;
            float _OutlineWidth1;
            float2 _OutlineOffset1;

            fixed4 _OutlineColor2;
            float _OutlineWidth2;
            float2 _OutlineOffset2;

            fixed4 _ShadowColor;
            float2 _ShadowOffset;
            float _ShadowSoftness;

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                o.color = v.color * _Color;
                return o;
            }

            // Helper to sample just the alpha channel
            float GetAlpha(float2 uv)
            {
                return tex2D(_MainTex, uv).a;
            }

            // 8-tap Faux-SDF Outline
            float GetOutline(float2 uv, float width, float2 offset)
            {
                float a = 0;
                float2 px = _MainTex_TexelSize.xy * width;
                uv += offset * _MainTex_TexelSize.xy; // Apply pixel-based offset

                a = max(a, GetAlpha(uv + float2(px.x, 0)));
                a = max(a, GetAlpha(uv + float2(-px.x, 0)));
                a = max(a, GetAlpha(uv + float2(0, px.y)));
                a = max(a, GetAlpha(uv + float2(0, -px.y)));
                a = max(a, GetAlpha(uv + float2(px.x, px.y)));
                a = max(a, GetAlpha(uv + float2(-px.x, px.y)));
                a = max(a, GetAlpha(uv + float2(px.x, -px.y)));
                a = max(a, GetAlpha(uv + float2(-px.x, -px.y)));

                return a;
            }

            // 5-tap Box Blur for Soft Shadows
            float GetShadow(float2 uv, float softness, float2 offset)
            {
                float a = 0;
                float2 px = _MainTex_TexelSize.xy * softness;
                uv += offset * _MainTex_TexelSize.xy;

                a += GetAlpha(uv);
                a += GetAlpha(uv + float2(px.x, px.y));
                a += GetAlpha(uv + float2(-px.x, px.y));
                a += GetAlpha(uv + float2(px.x, -px.y));
                a += GetAlpha(uv + float2(-px.x, -px.y));

                return saturate(a * 0.2); // Average out the taps
            }

            // Proper Alpha Compositing (A over B)
            fixed4 AlphaBlend(fixed4 top, fixed4 bottom)
            {
                fixed4 c;
                c.a = top.a + bottom.a * (1.0 - top.a);
                if (c.a == 0.0) return fixed4(0, 0, 0, 0);
                c.rgb = (top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / c.a;
                return c;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 1. Calculate Main Texture (Top Layer)
                fixed4 mainCol = tex2D(_MainTex, i.texcoord) * i.color;
                
                // Apply Grayscale
                float lum = dot(mainCol.rgb, float3(0.299, 0.587, 0.114));
                mainCol.rgb = lerp(mainCol.rgb, float3(lum, lum, lum), _GrayscaleAmount);
                
                // Apply Overlay Color (multiplied by main alpha so it stays inside bounds)
                mainCol.rgb = lerp(mainCol.rgb, _OverlayColor.rgb, _OverlayColor.a);

                // 2. Calculate Outlines
                float out1Alpha = GetOutline(i.texcoord, _OutlineWidth1, _OutlineOffset1) * _OutlineColor1.a;
                fixed4 outline1Layer = fixed4(_OutlineColor1.rgb, saturate(out1Alpha));

                float out2Alpha = GetOutline(i.texcoord, _OutlineWidth2, _OutlineOffset2) * _OutlineColor2.a;
                fixed4 outline2Layer = fixed4(_OutlineColor2.rgb, saturate(out2Alpha));

                // 3. Calculate Shadow
                float shadowAlpha = GetShadow(i.texcoord, _ShadowSoftness, _ShadowOffset) * _ShadowColor.a;
                fixed4 shadowLayer = fixed4(_ShadowColor.rgb, shadowAlpha);

                // 4. Composite Layers (Bottom to Top)
                fixed4 result = AlphaBlend(outline2Layer, shadowLayer);
                result = AlphaBlend(outline1Layer, result);
                result = AlphaBlend(mainCol, result);

                // Pre-multiply alpha for final output to play nice with UI Canvas
                result.rgb *= result.a;

                return result;
            }
            ENDCG
        }
    }
    // Connects the shader to the C# GUI script below
    CustomEditor "CustomShaderGUIs.SpriteExtensionGUI"
}