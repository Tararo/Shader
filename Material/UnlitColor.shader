<<<<<<< HEAD
﻿Shader "TARARO/UnlitColor"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Intensity("Intensity", Range(0.0, 5.0)) = 0.1
	}

    CGINCLUDE
    #pragma target 3.0
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"

    float4 _Color;
    float _Intensity;

    float3 LDR2HDR(fixed3 ldr, float intensity)
    {
        float factor = pow(2, intensity);
        float3 hdr = float3(ldr.r * factor, ldr.g * factor, ldr.b * factor);
        return hdr;
    }

    struct appdata
    {
        float4 vertex : POSITION;
        half3 normal : NORMAL;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
    };

    ENDCG
	
	SubShader
	{
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Tags
            {
                "LightMode" = "ForwardBase"
            }
			CGPROGRAM

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 出力色
                float4 fragColor = _Color;
                fragColor.rgb = LDR2HDR(fragColor.rgb, _Intensity);

                return fragColor;
            }
			ENDCG
		}

        UsePass "Standard/ShadowCaster"
	}
=======
﻿Shader "TARARO/UnlitColor"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Intensity("Intensity", Range(0.0, 5.0)) = 0.1
	}

    CGINCLUDE
    #pragma target 3.0
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"

    float4 _Color;
    float _Intensity;

    float3 LDR2HDR(fixed3 ldr, float intensity)
    {
        float factor = pow(2, intensity);
        float3 hdr = float3(ldr.r * factor, ldr.g * factor, ldr.b * factor);
        return hdr;
    }

    struct appdata
    {
        float4 vertex : POSITION;
        half3 normal : NORMAL;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
    };

    ENDCG
	
	SubShader
	{
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Tags
            {
                "LightMode" = "ForwardBase"
            }
			CGPROGRAM

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 出力色
                float4 fragColor = _Color;
                fragColor.rgb = LDR2HDR(fragColor.rgb, _Intensity);

                return fragColor;
            }
			ENDCG
		}

        UsePass "Standard/ShadowCaster"
	}
>>>>>>> origin/main
}