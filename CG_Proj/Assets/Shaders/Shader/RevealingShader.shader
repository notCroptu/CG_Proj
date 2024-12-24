Shader "Custom/RevealingShader"
{
    Properties
    {
        _MainTex ("Texture to be Revealed", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float3 _SpotLightPos = float3(1, 2, 11);
            float _LightRange = 20.0f;
            // float3 _SpotLightDir;
            float _LightStrengthIntensity;
            // float _InnerSpotAngle;
            // float _OuterSpotAngle;
            // float _Lighted;
        
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            half _Glossiness;
            half _Metallic;
            half4 _Color;

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };
        
            float NormalizedDistance(float3 worldPos)
            {
                float dist = distance(worldPos, _SpotLightPos);
                return dist / _LightRange;
            }
            
            float InverseSquareFalloff(float normalDist)
            {
                return 1.0f / (1.0f + _LightStrengthIntensity * normalDist * normalDist);
            }
            
            float SmoothStepRange(float normalDist)
            {
                return saturate((1.0f - normalDist) * 5.0f);
            }

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float4 frag(VertexOutput i) : SV_TARGET
            {
                float normalizedDist = NormalizedDistance(i.worldPos);
                float rangeAttenuation = saturate(InverseSquareFalloff(normalizedDist) * SmoothStepRange(normalizedDist));

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;

                texColor.a *= rangeAttenuation;

                return texColor;
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}