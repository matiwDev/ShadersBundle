Shader "Creatush/RoundedRect"
{
    Properties
    {
        // Required by Unity UI system
        [HideInInspector] _MainTex("Main Texture", 2D) = "white" {}

        [Header(Main Shape)]
        _Width("Width", Range(0,1)) = 1
        _Height("Height", Range(0,1)) = 1

        [Header(Corner Radius)]
        _CornerRadiusTL("Top Left", Range(0,0.5)) = 0.1
        _CornerRadiusTR("Top Right", Range(0,0.5)) = 0.1
        _CornerRadiusBR("Bottom Right", Range(0,0.5)) = 0.1
        _CornerRadiusBL("Bottom Left", Range(0,0.5)) = 0.1

        [Header(Fill)]
        [Toggle(_USEGRADIENT_ON)] _UseGradient("Use Gradient", Float) = 0
        _ColorStart("Color Start", Color) = (1,1,1,1)
        _ColorEnd("Color End", Color) = (0,0,0,1)
        _GradientAngle("Angle", Range(0,360)) = 0
        _GradientBlend("Blend", Range(0.1,5)) = 1
        _FillOpacity("Opacity", Range(0,1)) = 1
        _FillSoftness("Softness (Glow Spread)", Range(0,0.3)) = 0

        [Header(Outline 1)]
        [Toggle(_USEOUTLINE1_ON)] _UseOutline1("Enable Outline 1", Float) = 1
        [Toggle(_OUTLINE1GRADIENT_ON)] _UseOutline1Gradient("Use Gradient", Float) = 0
        _Outline1Color("Color 1", Color) = (0,0,0,1)
        _Outline1ColorStart("Gradient Start 1", Color) = (1,1,1,1)
        _Outline1ColorEnd("Gradient End 1", Color) = (0,0,0,1)
        _Outline1Offset("Offset 1", Float) = 0
        _Outline1Thickness("Thickness 1", Float) = 0.01

        [Header(Outline 2)]
        [Toggle(_USEOUTLINE2_ON)] _UseOutline2("Enable Outline 2", Float) = 0
        [Toggle(_OUTLINE2GRADIENT_ON)] _UseOutline2Gradient("Use Gradient", Float) = 0
        _Outline2Color("Color 2", Color) = (0,0,0,1)
        _Outline2ColorStart("Gradient Start 2", Color) = (1,1,1,1)
        _Outline2ColorEnd("Gradient End 2", Color) = (0,0,0,1)
        _Outline2Offset("Offset 2", Float) = 0
        _Outline2Thickness("Thickness 2", Float) = 0.02

        [Header(Shadow)]
        [Toggle(_USESHADOW_ON)] _UseShadow("Enable Shadow", Float) = 1
        _ShadowColor("Color", Color) = (0,0,0,1)
        _ShadowOffset("Offset XY, Expand ZW", Vector) = (0.02,-0.02,0,0)
        _ShadowSmoothness("Edge Smoothness", Range(0,0.1)) = 0.01
        _ShadowOpacity("Opacity", Range(0,1)) = 0.5
        [Toggle(_SHADOWCUSTOMRADIUS_ON)] _ShadowUseCustomRadius("Use Custom Shadow Radius", Float) = 0
        _ShadowRadiusTL("Shadow Top Left", Range(0,0.5)) = 0.1
        _ShadowRadiusTR("Shadow Top Right", Range(0,0.5)) = 0.1
        _ShadowRadiusBR("Shadow Bottom Right", Range(0,0.5)) = 0.1
        _ShadowRadiusBL("Shadow Bottom Left", Range(0,0.5)) = 0.1

        // UI Masking (auto-managed)
        [HideInInspector] _StencilComp("Stencil Comparison", Float) = 8
        [HideInInspector] _Stencil("Stencil ID", Float) = 0
        [HideInInspector] _StencilOp("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask("Stencil Read Mask", Float) = 255
        [HideInInspector] _ColorMask("Color Mask", Float) = 15
        [HideInInspector] _ClipRect("Clip Rect", Vector) = (-32767,-32767,32767,32767)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "IgnoreProjector"="True"
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
            #pragma shader_feature _USEGRADIENT_ON
            #pragma shader_feature _USEOUTLINE1_ON
            #pragma shader_feature _USEOUTLINE2_ON
            #pragma shader_feature _OUTLINE1GRADIENT_ON
            #pragma shader_feature _OUTLINE2GRADIENT_ON
            #pragma shader_feature _USESHADOW_ON
            #pragma shader_feature _SHADOWCUSTOMRADIUS_ON
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
                float2 gradientDir : TEXCOORD2;
            };

            float4 _ClipRect;

            CBUFFER_START(UnityPerMaterial)
                float _Width, _Height;
                float _CornerRadiusTL, _CornerRadiusTR, _CornerRadiusBR, _CornerRadiusBL;
                float4 _ColorStart, _ColorEnd;
                float _GradientAngle, _GradientBlend;
                float _FillOpacity, _FillSoftness;

                float4 _Outline1Color, _Outline2Color;
                float4 _Outline1ColorStart, _Outline1ColorEnd;
                float4 _Outline2ColorStart, _Outline2ColorEnd;
                float _Outline1Thickness, _Outline2Thickness;
                float _Outline1Offset, _Outline2Offset;

                float4 _ShadowColor;
                float4 _ShadowOffset;
                float _ShadowSmoothness, _ShadowOpacity;
                float _ShadowRadiusTL, _ShadowRadiusTR, _ShadowRadiusBR, _ShadowRadiusBL;
            CBUFFER_END

            // SDF for rectangle with individual corner radii
            // Optimized SDF calculation with branchless corner selection
            float sdRoundRectIndividual(float2 p, float2 halfSize, float4 radii)
            {
                float2 quadrant = saturate(sign(p * 1e5)); // Branchless quadrant detection
                float radius = lerp(
                    lerp(radii.w, radii.z, quadrant.x),
                    lerp(radii.x, radii.y, quadrant.x),
                    quadrant.y
                );

                float2 offset = halfSize - radius;
                float2 q = abs(p) - offset;
                return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            }

            // Outward-only outline band, now offset-aware
            float outlineOut(float dist, float inner, float outer, float smoothing)
            {
                return smoothstep(inner - smoothing, inner + smoothing, dist)
                    - smoothstep(outer - smoothing, outer + smoothing, dist);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.positionOS = v.vertex;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;

                float ang = radians(_GradientAngle);
                o.gradientDir = float2(cos(ang), sin(ang));
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // UI mask
                float2 clipUV = (i.positionOS.xy / i.positionOS.w) * 0.5 + 0.5;
                clipUV.y = 1 - clipUV.y;
                float mask = UnityGet2DClipping(clipUV, _ClipRect);

                float2 p = i.uv - 0.5;
                float2 halfSize = float2(_Width, _Height) * 0.5;
                float4 radii = float4(_CornerRadiusTL, _CornerRadiusTR, _CornerRadiusBR, _CornerRadiusBL);
                float dist = sdRoundRectIndividual(p, halfSize, radii);
                float aa = fwidth(dist);

                // Shared gradient t (used by fill + any outline set to gradient mode)
                float gradT = dot(p, i.gradientDir) + 0.5;
                gradT = pow(saturate(gradT), _GradientBlend);

                // Fill
                // _FillSoftness widens the edge transition symmetrically, so it also
                // feathers OUTWARD past the SDF boundary — that's what gives the glow
                // spread when paired with additive Dst Blend, rather than just a blurrier edge.
                float4 fillCol = _ColorStart;
                float fillEdge = aa + _FillSoftness;
                float fillAlpha = smoothstep(fillEdge, -fillEdge, dist) * _FillOpacity;
                #if _USEGRADIENT_ON
                {
                    fillCol = lerp(_ColorStart, _ColorEnd, gradT);
                }
                #endif

                // Shadow
                float shadowAlpha = 0;
                #if _USESHADOW_ON
                {
                    float2 pShadow = p - _ShadowOffset.xy;
                    float2 halfSizeSh = halfSize + _ShadowOffset.zw;

                    #if _SHADOWCUSTOMRADIUS_ON
                        float4 shadowRadii = float4(_ShadowRadiusTL, _ShadowRadiusTR, _ShadowRadiusBR, _ShadowRadiusBL);
                    #else
                        // Match the base shape's roundness; grow radii by the same amount
                        // the box was expanded so corners don't flatten out relatively.
                        float radiusGrow = (_ShadowOffset.z + _ShadowOffset.w) * 0.5;
                        float4 shadowRadii = radii + radiusGrow;
                    #endif

                    float distShadow = sdRoundRectIndividual(pShadow, halfSizeSh, shadowRadii);
                    shadowAlpha = smoothstep(_ShadowSmoothness + aa, -_ShadowSmoothness - aa, distShadow) * _ShadowOpacity;
                }
                #endif

                // Composite layers start with fill and shadow
                float4 col = lerp(_ShadowColor, fillCol * i.color, fillAlpha);
                float alpha = max(shadowAlpha, fillAlpha * i.color.a);

                // Outlines
                #if _USEOUTLINE1_ON
                {
                    float o1Inner = _Outline1Offset;
                    float o1Outer = _Outline1Offset + _Outline1Thickness;
                    float s1 = outlineOut(dist, o1Inner, o1Outer, aa);

                    float4 outline1Col = _Outline1Color;
                    #if _OUTLINE1GRADIENT_ON
                        outline1Col = lerp(_Outline1ColorStart, _Outline1ColorEnd, gradT);
                    #endif

                    col = lerp(col, outline1Col * i.color, s1);
                    alpha = max(alpha, s1 * outline1Col.a);
                }
                #endif
                #if _USEOUTLINE2_ON
                {
                    float o2Inner = _Outline2Offset;
                    float o2Outer = _Outline2Offset + _Outline2Thickness;
                    float s2 = outlineOut(dist, o2Inner, o2Outer, aa);

                    float4 outline2Col = _Outline2Color;
                    #if _OUTLINE2GRADIENT_ON
                        outline2Col = lerp(_Outline2ColorStart, _Outline2ColorEnd, gradT);
                    #endif

                    col = lerp(col, outline2Col * i.color, s2);
                    alpha = max(alpha, s2 * outline2Col.a);
                }
                #endif

                col.a = alpha * mask;
                return col;
            }
            ENDCG
        }
    }

    CustomEditor "CustomShaderGUIs.RoundedRectGUI"
}