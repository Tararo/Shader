Shader "TARARO/Filter_DepthScan"
{
    Properties
    {
        _Color("Color",Color) = (1.0, 0.0, 0.0, 0.5)
        _Intensity("Intensity", Range(0.0, 1.0)) = 0.1
        _Dark("Dark", Range(0.0, 1.0)) = 0.5
        _Speed ("Speed", Range(0.0, 1)) = 0.3
        _Range ("Range", Range(0.0, 1.0)) = 1.0
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"

    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    fixed4 _Color;
    float _Intensity;
    float _Dark;
    float _Speed;
    float _Range;

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
    };

    struct v2f
    {
        float4 vertex : SV_POSITION;
        float2 uv : TEXCOORD0;
        float4 scrPos : TEXCOORD1;
    };
    ENDCG




    SubShader
    {
        ZWrite Off
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100
        Cull Front
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
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.scrPos = ComputeScreenPos(o.vertex);
                o.uv = v.uv;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float targetDepth = fmod(_Time.y * (_Speed * 0.95 + 0.05), _Range) * 100;

                float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.scrPos)));
                float lineWidth = 0.2;
                float colorDiff = 1 - saturate(abs(depth - targetDepth) / lineWidth);
                colorDiff *= saturate(((_Range * 100) - depth) / 10);
                float intensityDiff = saturate((colorDiff - 1 + _Intensity) * 2);

                fixed4 fragColor = fixed4(0, 0, 0, 1);
                float dark = 0.01 + 0.99 * _Dark;
                fragColor.rgb = ((_Color.rgb * _Color.a * colorDiff) + (1 * intensityDiff)) / dark;
                fragColor.a = dark;

                return fragColor;
            }

            ENDCG
        }
    }
}
