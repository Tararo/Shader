Shader "TARARO/Filter_PixelArt"
{
    Properties
    {
        _ColorBit("Color Bit", Int) = 12
        _Size ("Size", Range(0.0, 1)) = 0.5
    }
    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"

    sampler2D _GrabTexture;
    float2 _GrabTexture_TexelSize;
    int _ColorBit;
    float _Size;

    float4 rgbTo6bit(float4 i, float bit) {
        float div = pow(2, bit / 3);
        return floor(i * div) / div;
    }

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
        float4 grabPos : TEXCOORD1;
        float4 scrPos : TEXCOORD2;
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
        GrabPass {}
        CULL front
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.grabPos = ComputeGrabScreenPos(o.vertex);
                o.scrPos = ComputeScreenPos(o.vertex);
                o.uv = v.uv;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
                float2 size = float2(_Size * 0.01, _Size * 0.01);
                size.y *= _ScreenParams.x / _ScreenParams.y;
                float2 grabUv = i.grabPos.xy / i.grabPos.w;
                grabUv = (floor(grabUv / size) + 0.5) * size;
				fixed4 grabColorCenter = tex2D(_GrabTexture, UNITY_PROJ_COORD(grabUv));
                fixed4 grabColor00 = tex2D(_GrabTexture, UNITY_PROJ_COORD(grabUv + float2(-0.5, -0.5) * size));
                fixed4 grabColor01 = tex2D(_GrabTexture, UNITY_PROJ_COORD(grabUv + float2(-0.5, 0.5) * size));
                fixed4 grabColor10 = tex2D(_GrabTexture, UNITY_PROJ_COORD(grabUv + float2(0.5, -0.5) * size));
                fixed4 grabColor11 = tex2D(_GrabTexture, UNITY_PROJ_COORD(grabUv + float2(0.5, 0.5) * size));
                fixed4 grabColor = grabColorCenter * 0.5 + (grabColor00 + grabColor01 + grabColor10 + grabColor11) * 0.125;

                fixed4 fragColor = rgbTo6bit(grabColor, _ColorBit);

				return fragColor;
			}
            ENDCG
        }
    }
}
