// Gradient.shader
// Deliberately minimal. All authoring happens through the generic
// [Gradient] MaterialPropertyDrawer (GradientDrawer.cs) - this file has no
// CustomEditor line and needs no shader-specific script at all.
//
// UGUI-compliant: stencil block + _ClipRect so it plays correctly with
// CanvasRenderer, Mask, RectMask2D, and raycasting.
//
// Sprite masking: if the Image/SpriteRenderer this material is on has a
// Sprite assigned, _MainTex is that sprite and its alpha channel masks the
// gradient (so the gradient only shows inside the sprite's silhouette). With
// no sprite (default Image, no Source Image), _MainTex is opaque white and
// the gradient simply fills the whole rect.

Shader "Creatush/Gradient"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite (optional mask)", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

        [Header(Gradient)]
        [Gradient] _GradientTex ("Gradient (RGBA)", 2D) = "white" {}
        [Toggle] _GradientRadial ("Radial Gradient", Float) = 0
        _GradientAngle ("Linear Angle (deg)", Range(0,360)) = 0

        [Header(UI)]
        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0

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
            #pragma multi_compile __ UNITY_UI_CLIP_RECT
            #pragma multi_compile __ UNITY_UI_ALPHACLIP
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
            sampler2D _GradientTex;
            float4 _ClipRect;
            fixed4 _Color;

            CBUFFER_START(UnityPerMaterial)
                float _GradientRadial;
                float _GradientAngle;
            CBUFFER_END

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
                // UI mask
                float2 clipUV = (i.positionOS.xy / i.positionOS.w) * 0.5 + 0.5;
                clipUV.y = 1 - clipUV.y;
                float uiMask = UnityGet2DClipping(clipUV, _ClipRect);

                // Gradient coordinate: Linear (angle-controlled) or Radial,
                // picked by the same _GradientRadial toggle RadialRays uses.
                float2 p = i.uv - 0.5;
                float2 dir = float2(cos(radians(_GradientAngle)), sin(radians(_GradientAngle)));
                float tLinear = saturate(dot(p, dir) + 0.5);
                float tRadial = saturate(length(p) * 2.0);
                float t = lerp(tLinear, tRadial, _GradientRadial);

                fixed4 grad = tex2D(_GradientTex, float2(t, 0.5));

                // Sprite-as-mask: with no sprite assigned this is opaque
                // white (alpha = 1), so it's a no-op and the gradient fills
                // the whole rect.
                fixed spriteMaskAlpha = tex2D(_MainTex, i.uv).a;

                fixed4 col;
                col.rgb = grad.rgb * i.color.rgb;
                col.a = grad.a * spriteMaskAlpha * i.color.a;

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

    Fallback "UI/Default"
}
