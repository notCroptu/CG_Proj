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
        Tags { "RenderType" = "Transparent"  "Queue" = "Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows alpha:fade
        #pragma target 3.0

        float3 _SpotLightPos = float3(1, 2, 11);
        float _LightRange = 20.0f;
        // float3 _SpotLightDir;
        // float _LightStrengthIntensity;
        // float _InnerSpotAngle;
        // float _OuterSpotAngle;
        // float _Lighted;

        sampler2D _MainTex;
        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        struct Input
        {
            float2 uv_MainTex;
            float3 worldPos;
        };
        
        float NormalizedDistance(float3 worldPos)
        {
            float dist = distance(worldPos, _SpotLightPos);
            return dist / _LightRange;
        }
        
        float InverseSquareFalloff(float normalDist)
        {
            return 1.0f / (1.0f + 25.0f * normalDist * normalDist);
        }
        
        float SmoothStepRange(float normalDist)
        {
            return saturate((1.0f - normalDist) * 5.0f);
        }
        
        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            float normalizedDist = NormalizedDistance(IN.worldPos);
            float rangeAttenuation = saturate(InverseSquareFalloff(normalizedDist) * SmoothStepRange(normalizedDist));
                
            // Sample the texture and apply color
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;

            // Apply the range attenuation to the alpha channel for transparency
            o.Alpha = c.a * rangeAttenuation;
        }
        ENDCG
    }
    FallBack "Diffuse"
}