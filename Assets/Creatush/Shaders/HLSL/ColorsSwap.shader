Shader "Creatush/ColorSwap5"
{
    // Recolors a UI Image's texture by remapping up to 5 target colors
    // to 5 replacement colors of your choice. Fully compatible with
    // Unity UI's Mask / RectMask2D / Maskable checkbox.

    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
        _ColorMask ("Color Mask", Float) = 15

        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0

        [Header(Mirroring)]
        [Toggle] _FlipHorizontal ("Flip Horizontal (Left/Right)", Float) = 0
        [Toggle] _FlipVertical ("Flip Vertical (Top/Bottom)", Float) = 0

        [Header(Swap Slot 1)]
        [Toggle] _Enable1 ("Enable", Float) = 1
        _TargetColor1  ("Target Color (found in texture)", Color) = (1,0,0,1)
        _ReplaceColor1 ("Replacement Color", Color) = (1,0,0,1)
        _Tolerance1 ("Match Tolerance", Range(0.001,1)) = 0.1

        [Header(Swap Slot 2)]
        [Toggle] _Enable2 ("Enable", Float) = 0
        _TargetColor2  ("Target Color (found in texture)", Color) = (0,1,0,1)
        _ReplaceColor2 ("Replacement Color", Color) = (0,1,0,1)
        _Tolerance2 ("Match Tolerance", Range(0.001,1)) = 0.1

        [Header(Swap Slot 3)]
        [Toggle] _Enable3 ("Enable", Float) = 0
        _TargetColor3  ("Target Color (found in texture)", Color) = (0,0,1,1)
        _ReplaceColor3 ("Replacement Color", Color) = (0,0,1,1)
        _Tolerance3 ("Match Tolerance", Range(0.001,1)) = 0.1

        [Header(Swap Slot 4)]
        [Toggle] _Enable4 ("Enable", Float) = 0
        _TargetColor4  ("Target Color (found in texture)", Color) = (1,1,0,1)
        _ReplaceColor4 ("Replacement Color", Color) = (1,1,0,1)
        _Tolerance4 ("Match Tolerance", Range(0.001,1)) = 0.1

        [Header(Swap Slot 5)]
        [Toggle] _Enable5 ("Enable", Float) = 0
        _TargetColor5  ("Target Color (found in texture)", Color) = (1,0,1,1)
        _ReplaceColor5 ("Replacement Color", Color) = (1,0,1,1)
        _Tolerance5 ("Match Tolerance", Range(0.001,1)) = 0.1
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
            Name "Default"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            struct appdata_t
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex        : SV_POSITION;
                fixed4 color         : COLOR;
                float2 texcoord      : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
                float4 mask          : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            fixed4 _Color;
            fixed4 _TextureSampleAdd;
            float4 _ClipRect;
            float4 _MainTex_ST;
            float _UIMaskSoftnessX;
            float _UIMaskSoftnessY;
            float _FlipHorizontal;
            float _FlipVertical;

            v2f vert(appdata_t v)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float4 vPosition = UnityObjectToClipPos(v.vertex);
                OUT.worldPosition = v.vertex;
                OUT.vertex = vPosition;

                float2 pixelSize = vPosition.w;
                pixelSize /= float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy));

                float4 clampedRect = clamp(_ClipRect, -2e10, 2e10);

                float2 uv = v.texcoord;
                uv.x = lerp(uv.x, 1.0 - uv.x, _FlipHorizontal);
                uv.y = lerp(uv.y, 1.0 - uv.y, _FlipVertical);
                OUT.texcoord = uv;

                OUT.mask = float4(v.vertex.xy * 2 - clampedRect.xy - clampedRect.zw,
                    0.25 / (0.25 * half2(_UIMaskSoftnessX, _UIMaskSoftnessY) + abs(pixelSize.xy)));

                OUT.color = v.color * _Color;
                return OUT;
            }

            sampler2D _MainTex;

            fixed4 _TargetColor1; fixed4 _ReplaceColor1; float _Tolerance1; float _Enable1;
            fixed4 _TargetColor2; fixed4 _ReplaceColor2; float _Tolerance2; float _Enable2;
            fixed4 _TargetColor3; fixed4 _ReplaceColor3; float _Tolerance3; float _Enable3;
            fixed4 _TargetColor4; fixed4 _ReplaceColor4; float _Tolerance4; float _Enable4;
            fixed4 _TargetColor5; fixed4 _ReplaceColor5; float _Tolerance5; float _Enable5;

            // Soft-matches col.rgb against target.rgb within tol, blends toward replace.
            fixed4 ApplySwap(fixed4 col, fixed4 target, fixed4 replace, float tol, float enable)
            {
                float dist = distance(col.rgb, target.rgb);
                float t = saturate(1.0 - dist / max(tol, 1e-5));
                t *= step(0.5, enable); // zero out entirely if slot disabled
                col.rgb = lerp(col.rgb, replace.rgb, t);
                return col;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                half4 color = tex2D(_MainTex, IN.texcoord) + _TextureSampleAdd;
                color *= IN.color;

                color = ApplySwap(color, _TargetColor1, _ReplaceColor1, _Tolerance1, _Enable1);
                color = ApplySwap(color, _TargetColor2, _ReplaceColor2, _Tolerance2, _Enable2);
                color = ApplySwap(color, _TargetColor3, _ReplaceColor3, _Tolerance3, _Enable3);
                color = ApplySwap(color, _TargetColor4, _ReplaceColor4, _Tolerance4, _Enable4);
                color = ApplySwap(color, _TargetColor5, _ReplaceColor5, _Tolerance5, _Enable5);

                #ifdef UNITY_UI_CLIP_RECT
                half2 m = saturate((_ClipRect.zw - _ClipRect.xy - abs(IN.mask.xy)) * IN.mask.zw);
                color.a *= m.x * m.y;
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip(color.a - 0.001);
                #endif

                return color;
            }
            ENDCG
        }
    }
}
