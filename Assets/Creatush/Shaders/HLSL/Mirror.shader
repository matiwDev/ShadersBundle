// Mirror.shader
// Compresses the WHOLE source texture into one half of the UV space and
// mirrors a flipped copy into the other half - the same tent/triangle-wave
// mapping confirmed working:
//   sourceIsLeft:  u<0.5 -> u*2 (direct, compressed);  u>=0.5 -> 2-2u (flipped)
//   sourceIsRight: u>=0.5 -> 2u-1 (direct, compressed); u<0.5 -> 1-2u (flipped)
// _ReverseX/_ReverseY choose which side is the source. Ported to CGPROGRAM +
// UnityUI.cginc - see HSV.shader's header comment for why.

Shader "Creatush/Mirror"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)

        [Toggle] _MirrorX ("Mirror Horizontal", Float) = 0
        [Toggle] _ReverseX ("Reverse Horizontal", Float) = 0
        [Toggle] _MirrorY ("Mirror Vertical", Float) = 0
        [Toggle] _ReverseY ("Reverse Vertical", Float) = 0

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
            float4 _ClipRect;
            fixed4 _Color;

            CBUFFER_START(UnityPerMaterial)
                float _MirrorX, _ReverseX, _MirrorY, _ReverseY;
            CBUFFER_END

            // Tent/triangle-wave fold: compresses the full source into one
            // half and mirrors a flipped copy into the other half.
            float MirrorAxis(float u, float mirrorOn, float reverseOn)
            {
                float isSecondHalf = step(0.5, u);
                float leftSourceResult = lerp(u * 2.0, 2.0 - u * 2.0, isSecondHalf);
                float rightSourceResult = 1.0 - leftSourceResult;
                float folded = lerp(leftSourceResult, rightSourceResult, reverseOn);
                return lerp(u, folded, mirrorOn);
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
                uv.x = MirrorAxis(uv.x, _MirrorX, _ReverseX);
                uv.y = MirrorAxis(uv.y, _MirrorY, _ReverseY);

                fixed4 col = tex2D(_MainTex, uv);
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
