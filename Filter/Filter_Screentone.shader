Shader "TARARO/Filter_Screentone"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 1, 1)
        _Size ("Size", Range(0.0, 1)) = 0.5
    }
    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"

    sampler2D _GrabTexture;
    float2 _GrabTexture_TexelSize;
    fixed4 _Color;
    float _Size;

    //円
    float circle(float2 p, float2 center, float radius) 
    {
        return step(distance(p, center), radius);
    }

    // BT.601
    float rgbToGray(float4 i) {
        return 0.299*i.r + 0.587*i.g + 0.114*i.b;
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
                o.uv = v.uv;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
                float2 size = float2(_Size * 0.01, _Size * 0.01);
                size.y *= _ScreenParams.x / _ScreenParams.y;

                float2 grabUv = i.grabPos.xy / i.grabPos.w;
                float2 grabUvC = (floor(grabUv / size) + 0.5) * size;
				fixed4 grabColor = tex2D(_GrabTexture, UNITY_PROJ_COORD(grabUvC));
                float gray = rgbToGray(grabColor);

                grabUv.y *= _ScreenParams.y / _ScreenParams.x;
                grabUvC.y *= _ScreenParams.y / _ScreenParams.x;
                fixed4 fragColor = _Color * circle(grabUv, grabUvC, size.x / 2 * sqrt(2) * gray);

				return fragColor;
			}
            ENDCG
        }
    }
}
