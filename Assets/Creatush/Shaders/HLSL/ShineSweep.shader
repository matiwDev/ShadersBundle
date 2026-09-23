// ShineSweep.shader
// A diagonal light band that scrolls across the sprite on a timer.
// Ported to CGPROGRAM + UnityUI.cginc - see HSV.shader's header comment for why.
//
// _SweepSoftness is new and purely additive: at its default (0) the band's
// shape and timing are IDENTICAL to before - it only widens each ramp
// outward from the same peak, so existing materials look unchanged until
// you raise it.

Shader "Creatush/ShineSweep"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)

        _SweepColor ("Sweep Color", Color) = (1,1,1,0.8)
        _SweepWidth ("Sweep Width", Range(0.01, 1)) = 0.2
        _SweepSoftness ("Sweep Softness", Range(0, 1)) = 0
        _SweepAngle ("Sweep Angle (deg)", Range(0,360)) = 20
        _SweepSpeed ("Sweep Speed", Float) = 1.0
        _SweepInterval ("Sweep Interval (sec)", Float) = 3.0

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
                fixed4 _SweepColor;
                float _SweepWidth, _SweepSoftness, _SweepAngle, _SweepSpeed, _SweepInterval;
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

                fixed4 col = tex2D(_MainTex, i.uv);
                col.rgb *= i.color.rgb;
                col.a *= i.color.a;

                float t = fmod(_Time.y, max(_SweepInterval, 0.0001)) * _SweepSpeed;
                float2 dir = float2(cos(radians(_SweepAngle)), sin(radians(_SweepAngle)));
                float coord = dot(i.uv - 0.5, dir) + 0.5;

                // At _SweepSoftness = 0 this is EXACTLY the original formula
                // (smoothstep(t-w,t,coord) * (1-smoothstep(t,t+w,coord))) -
                // increasing it only widens each ramp further out, the peak
                // at "coord == t" stays put.
                float w = _SweepWidth;
                float s = _SweepSoftness;
                float band = smoothstep(t - w - s, t, coord) * (1 - smoothstep(t, t + w + s, coord));

                col.rgb += _SweepColor.rgb * band * _SweepColor.a * col.a;

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
