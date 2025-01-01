Shader "Custom/RevealingShader"
{
    Properties
    {
        _MainTex ("Texture to be Revealed", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _AlphaClip ("Alpha Clip", Range(0, 1)) = 0.01
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "UniversalMaterialType" = "Lit"
            "Queue" = "Transparent"
        }
        Pass
        {
            Name "NormalPass"
            Tags { "LightMode" = "UniversalForward" }
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZTest LEqual
            ZWrite Off
            

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma multi_compile_fog
            
            #define MAX_ADDITIONAL_LIGHTS 4

            uniform float _LightRange;
            uniform float3 _SpotLightDir;
            uniform float _LightStrengthIntensity;
            uniform float _InnerSpotAngle;
            uniform float _OuterSpotAngle;
            uniform float _Lighted;
            uniform float3 _SpotLightPos;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            half4 _Color;
            float _AlphaClip;

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct VertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            // Calculate normalized distance from the light position
            float NormalizedDistance(float3 worldPos)
            {
                float dist = distance(worldPos, _SpotLightPos);
                return dist / _LightRange;
            }
            
            // Inverse square falloff based on distance
            float InverseSquareFalloff(float normalDist)
            {
                return 1.0f / (1.0f + _LightStrengthIntensity * normalDist * normalDist);
            }
            
            // Smooth range falloff for more control over light intensity
            float SmoothRange(float normalDist)
            {
                return saturate((1.0f - normalDist) * 5.0f);
            }

            // Calculate angle-based attenuation for the spotlight
            float AngleAttenuation(float3 lightDir)
            {
                lightDir = normalize(lightDir);
                float angle = dot(lightDir, normalize(_SpotLightDir));
                return smoothstep(_OuterSpotAngle, _InnerSpotAngle, angle);
            }
            
            // Sample depth from URP Additional Lights
            half SampleDepth(float3 worldPos, float3 normal)
            {
                half shadowDepth = 0.0f; // Accumulate weighted shadow depth
            
                float bestMatchWeight = 0.75f; // Keep track of the strongest matching weight, and give it a minimum
            
                for (int i = 0; i < 4; i++)
                {
                    // Fetch light properties
                    Light light = GetAdditionalPerObjectLight(i, worldPos);
                    float3 lightDir = normalize(light.direction);
            
                    // Compute direction similarity (dot product, higher is better)
                    float matchWeight = saturate(dot(lightDir, normalize(_SpotLightDir)));
            
                    // Track the best match, if any
                    if (matchWeight > bestMatchWeight)
                    {
                        bestMatchWeight = matchWeight;
                        shadowDepth = light.shadowAttenuation;
                    }
                }

                shadowDepth = saturate(shadowDepth);
            
                return shadowDepth;
            }

            // Vertex shader: transforms position and calculates shadow coordinates
            VertexOutput vert(VertexInput v)
            {
                VertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.normalWS = normalize(mul((float3x3)unity_ObjectToWorld, v.normalOS));
                return o;
            }

            // Fragment shader: calculates lighting and shadow effect
            float4 frag(VertexOutput i) : SV_TARGET
            {
                float3 toLight = normalize(_SpotLightPos - i.worldPos);

                float normalizedDist = NormalizedDistance(i.worldPos);
                float rangeAttenuation = saturate(InverseSquareFalloff(normalizedDist) * SmoothRange(normalizedDist));
                float angleAttenuation = AngleAttenuation(toLight);

                half shadowDepth = SampleDepth(i.worldPos, i.normalWS);

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                texColor.a *= shadowDepth * rangeAttenuation * angleAttenuation * _Lighted;

                if (texColor.a < _AlphaClip)
                    discard;

                return texColor;
            }
            ENDHLSL
        }
    }
}
