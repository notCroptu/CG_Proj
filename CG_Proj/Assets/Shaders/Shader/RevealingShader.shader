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
            float3 _SpotLightDir = float3(0, -1, 0);
            float _LightStrengthIntensity = 1.0f;
            float _InnerSpotAngle = cos(radians(15.0));
            float _OuterSpotAngle = cos(radians(30.0));
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
            
            float SmoothRange(float normalDist)
            {
                return saturate((1.0f - normalDist) * 5.0f);
            }

            float AngleAttenuation(float3 lightDir)
            {
                lightDir = normalize(lightDir);

                // Since both directions are normalized it's fine to get the angle between them using dot product
                float angle = dot(lightDir, (normalize(_SpotLightDir)));

                return smoothstep(_OuterSpotAngle, _InnerSpotAngle, angle);
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
                float3 toLight = normalize(_SpotLightPos - i.worldPos);

                float normalizedDist = NormalizedDistance(i.worldPos);
                float rangeAttenuation = saturate(InverseSquareFalloff(normalizedDist) * SmoothRange(normalizedDist));
                float angleAttenuation = AngleAttenuation(toLight);

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;

                texColor.a *= rangeAttenuation * angleAttenuation;

                return texColor;
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}