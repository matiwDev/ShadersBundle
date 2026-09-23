// UVScroll.shader
// Panning UVs for lava, waterfalls, conveyor belts, and energy beams.
// Ported to CGPROGRAM + UnityUI.cginc - see HSV.shader's header comment for why.

Shader "Creatush/UVScroll"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)
        _ScrollSpeed ("Scroll Speed (u,v)", Vector) = (0.5, 0, 0, 0)

        [Toggle(_USELAYER2_ON)] _UseLayer2 ("Use Second Layer", Float) = 0
        _MainTex2 ("Layer 2 Texture", 2D) = "white" {}
        _ScrollSpeed2 ("Layer 2 Scroll Speed (u,v)", Vector) = (-0.3, 0.1, 0, 0)
        _Layer2Blend ("Layer 2 Blend", Range(0,1)) = 0.5

        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0

        [HideInInspector] _StencilComp ("Stencil Comparison", Float) = 8
        [HideInInspector] _Stencil ("Stencil ID", Float) = 0
        [HideInInspector] _StencilOp ("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask ("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask ("Stencil Read Mask", Float) = 255
        [HideInInspector] _ColorMask ("Color Mask", Float) = 15
        [HideInInspector] _ClipRect ("Clip Rect", Vector) = (-32767, -32767, 32767, 32767)
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
            #pragma multi_compile __ UNITY_UI_CLIP_RECT
            #pragma multi_compile __ UNITY_UI_ALPHACLIP
            #pragma shader_feature_local _USELAYER2_ON
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
            sampler2D _MainTex2;
            float4 _MainTex2_ST;
            float4 _ClipRect;
            fixed4 _Color;

            CBUFFER_START(UnityPerMaterial)
                float4 _ScrollSpeed;
                float4 _ScrollSpeed2;
                float _Layer2Blend;
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
                float2 clipUV = (i.positionOS.xy / i.positionOS.w) * 0.5 + 0.5;
                clipUV.y = 1 - clipUV.y;
                float uiMask = UnityGet2DClipping(clipUV, _ClipRect);

                float2 uv1 = i.uv + _ScrollSpeed.xy * _Time.y;
                fixed4 col = tex2D(_MainTex, uv1);

                #if defined(_USELAYER2_ON)
                float2 uv2 = (i.uv * _MainTex2_ST.xy + _MainTex2_ST.zw) + _ScrollSpeed2.xy * _Time.y;
                fixed4 col2 = tex2D(_MainTex2, uv2);
                col.rgb = lerp(col.rgb, col2.rgb, _Layer2Blend * col2.a);
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
    Fallback "UI/Default"
}
