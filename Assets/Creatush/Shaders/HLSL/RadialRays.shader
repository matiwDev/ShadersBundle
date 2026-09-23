// RadialRaysUI.shader
// A UGUI-compliant radial ray ("sunburst") shader for Image / RawImage components.
// Built on the same structure as Unity's built-in UI/Default shader, so it plays
// correctly with CanvasRenderer, Mask, RectMask2D, CanvasGroup alpha, and raycasting.
// Works in URP projects because Canvas UI is not rendered through the SRP render
// graph - it uses whatever shader is assigned to the material, exactly like this one.

Shader "Creatush/RadialRays"
{
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

        [Header(Radial Rays)]
        _RayCount ("1) Ray Count", Range(1, 128)) = 12
        _ArcRange ("2) Arc Range (Degrees)", Range(0, 360)) = 360
        _RaySpacing ("3) Ray Spacing", Range(0, 0.95)) = 0.3
        _Opacity ("4) Overall Opacity", Range(0, 1)) = 1
        _OpacitySpread ("5) Opacity Spread (Edge Decay)", Range(0, 1)) = 0

        [Header(Tint)]
        [Toggle] _UseVertexColor ("6) Tint With Vertex Color (Image.color)", Float) = 1
        [NoScaleOffset] _RayGradient ("6) Ray Gradient RGBA (used when off)", 2D) = "white" {}
        [Toggle] _GradientRadial ("Gradient Axis: Radial (off = Angular)", Float) = 1

        [Header(Optional Extras)]
        _ArcOffset ("Arc Start Rotation (Degrees)", Range(0, 360)) = 0
        _RayFeather ("Ray Edge Softness", Range(0.0001, 0.5)) = 0.05
        _InnerRadius ("Inner Radius (Cutout)", Range(0, 1)) = 0
        _OuterRadius ("Outer Radius (Ray Length)", Range(0, 1)) = 0.5

        [Header(Animation Optional Time Driven)]
        _RotationSpeed ("Rotation Speed (deg per sec)", Range(-360, 360)) = 0
        _AutoSweepSpeed ("Auto Sweep Speed (cycles per sec)", Range(0, 5)) = 0
        _SweepFeather ("Sweep Leading Edge Softness", Range(0.001, 0.5)) = 0.05
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
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
            #pragma multi_compile __ UNITY_UI_CLIP_RECT
            #pragma multi_compile __ UNITY_UI_ALPHACLIP

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
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            fixed4 _Color;
            float4 _ClipRect;
            float4 _MainTex_ST;

            float _RayCount;
            float _ArcRange;
            float _ArcOffset;
            float _RaySpacing;
            float _RayFeather;
            float _Opacity;
            float _OpacitySpread;
            float _InnerRadius;
            float _OuterRadius;
            float _RotationSpeed;
            float _AutoSweepSpeed;
            float _SweepFeather;
            float _UseVertexColor;
            sampler2D _RayGradient;
            float _GradientRadial;

            v2f vert(appdata_t v)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                OUT.worldPosition = v.vertex;
                OUT.vertex = UnityObjectToClipPos(OUT.worldPosition);
                OUT.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                OUT.color = v.color * _Color;
                return OUT;
            }

            float mod360(float a)
            {
                return a - 360.0 * floor(a / 360.0);
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                // --- Polar coordinates, UV centered at the rect's middle ---
                float2 centered = IN.texcoord - 0.5;
                float radius = length(centered) * 2.0; // 0 at center, 1 at inscribed circle edge
                float angleDeg = degrees(atan2(centered.y, centered.x));
                angleDeg = mod360(angleDeg);
                float a = mod360(angleDeg - _ArcOffset); // 0.._ArcRange window - fixed, unaffected by rotation

                float arcRangeSafe = max(_ArcRange, 0.001);
                float fullCircle = step(359.9, _ArcRange);

                // --- 1) Ray Count / 3) Ray Spacing ---
                float rayCount = max(round(_RayCount), 1.0);
                float slot = arcRangeSafe / rayCount;

                // Ray pattern rotates in place inside the fixed window: only the phase
                // used to pick each ray's slot position scrolls over time, so rays cycle
                // through the pie without the pie's start/end/decay/sweep moving at all.
                float rayPhase = _Time.y * _RotationSpeed;
                float aRays = mod360(a - rayPhase);

                float localA = fmod(aRays, slot);
                float halfSlot = slot * 0.5;
                float distFromCenter = abs(localA - halfSlot);
                float rayHalfWidth = halfSlot * saturate(1.0 - _RaySpacing);
                float feather = max(slot * max(_RayFeather, 0.0001), 0.0001);
                float rayMask = 1.0 - smoothstep(rayHalfWidth - feather, rayHalfWidth + feather, distFromCenter);

                // --- 2) Arc Range cutoff (soft edge, ignored for full 360) ---
                float arcFeather = 0.5;
                float inArc = 1.0 - smoothstep(arcRangeSafe - arcFeather, arcRangeSafe + arcFeather, a);
                inArc = lerp(inArc, 1.0, fullCircle);

                // --- 5) Opacity Spread: decay toward the two ends of the arc ---
                float t = saturate(a / arcRangeSafe); // 0 at arc start, 1 at arc end
                float spreadShape = pow(saturate(sin(UNITY_PI * t)), 3.0);
                float edgeFade = lerp(1.0, spreadShape, saturate(_OpacitySpread));
                edgeFade = lerp(edgeFade, 1.0, fullCircle); // a full circle has no "extremes"

                // --- Animated sweep reveal across the arc (radar / loading style) ---
                // Speed > 0: loops on its own via _Time.y. Speed == 0 (default): fully
                // revealed, matching the shader's behavior before this feature existed.
                float sweep = _AutoSweepSpeed > 0.0001 ? frac(_Time.y * _AutoSweepSpeed) : 1.0;
                float sweepMask = 1.0 - smoothstep(sweep, sweep + max(_SweepFeather, 0.001), t);

                // --- Optional radial length controls ---
                float outerR = max(_OuterRadius, _InnerRadius + 0.001);
                float radiusFeather = 0.015;
                float radiusMask = smoothstep(_InnerRadius - radiusFeather, _InnerRadius + radiusFeather, radius) *
                                    (1.0 - smoothstep(outerR - radiusFeather, outerR + radiusFeather, radius));

                fixed4 texCol = tex2D(_MainTex, IN.texcoord);

                // --- 6) Tint: vertex color (Image.color / Graphic tinting) or RGBA gradient ---
                half3 rgb;
                half gradA = 1.0;
                if (_UseVertexColor > 0.5)
                {
                    rgb = IN.color.rgb;
                }
                else
                {
                    float gt = _GradientRadial > 0.5 ? saturate(radius / max(outerR, 0.0001)) : t;
                    fixed4 g = tex2D(_RayGradient, float2(gt, 0.5));
                    rgb = g.rgb;
                    gradA = g.a; // gradient's own alpha channel feeds the mask
                }

                fixed4 color;
                color.rgb = rgb;
                color.a = rayMask * inArc * radiusMask * edgeFade * sweepMask * gradA *
                          saturate(_Opacity) * IN.color.a * texCol.a;

                #ifdef UNITY_UI_CLIP_RECT
                color.a *= UnityGet2DClipping(IN.worldPosition.xy, _ClipRect);
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip(color.a - 0.001);
                #endif

                return color;
            }
            ENDCG
        }
    }

    CustomEditor "RadialRaysGUI"
    Fallback "UI/Default"
}
