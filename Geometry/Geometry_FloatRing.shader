Shader "TARARO/Geometry_FloatRing"
{
    Properties
    {
        [Header(Color)]
            _Color ("Color", Color) = (1,1,1,1)
            _Intensity("Color Intensity", Range(0, 4)) = 0
        [Header(Floating Object)]
            [IntRange]_ObjectNum("Object Number", Range(1, 32)) = 8
            _RingScale ("Ring Scale", Float) = 0.4
            _ObjectScale ("Object Scale", Float) = 0.1
            _FluctSpeed ("Fluctuation Speed", Float) = 0.2
            _FluctAmount ("Fluctuation Amount", Float) = 0.0
            _RotateSpeed ("Rotation Speed", Float) = 0.2
            _RevolveSpeed ("Revolution Speed", Float) = 0.2
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Geometry"
            "VRCFallback"="Hidden"
        }
        LOD 100

        Pass
        {
        CGPROGRAM
        #pragma vertex vert
	    #pragma geometry geom
	    #pragma fragment frag

        #include "UnityCG.cginc"

        #define PI 3.14159265

	    struct appdata
	    {
		    float4 vertex : POSITION;
	    };

	    struct v2g
	    {
		    float4 vertex : POSITION;
	    };

	    struct g2f
	    {
		    float4 vertex : SV_POSITION;
		    half4 color : TEXCOORD0;
	    };

        fixed4 _Color;
        float _Intensity;
        int _ObjectNum;
        float _RingScale;
        float _ObjectScale;
        float _FluctSpeed;
        float _FluctAmount;
        float _RotateSpeed;
        float _RevolveSpeed;

        bool AudioLinkIsSync()
        {
            #ifdef _AUDIOLINKSYNC_ON
                return true;
            #else
                return false;
            #endif            
        }

        float2 rand(float2 co)
        {
            float tmp = dot(co.xy, float2(12.9898,78.233));
		    return frac(float2(sin(tmp), cos(tmp)) * 43758.5453);
	    }

        float3x3 rotateToMatrix(float roll, float pitch, float yaw)
        {
            float2 R = float2(sin(roll * UNITY_PI), cos(roll * UNITY_PI));
            float2 P = float2(sin(pitch * UNITY_PI), cos(pitch * UNITY_PI));
            float2 Y = float2(sin(yaw * UNITY_PI), cos(yaw * UNITY_PI));
            return float3x3(
                P.y * Y.y, R.x * P.x * Y.y - R.y * Y.x, R.y * P.x * Y.y + R.x * Y.x,
                P.y * Y.x, R.x * P.x * Y.x + R.y * Y.y, R.y * P.x * Y.x - R.x * Y.y,
                - P.x, R.x * P.y, R.y * P.y
            );
        }

        half3 LDR2HDR(fixed3 ldr, float intensity)
        {
            float factor = pow(2, intensity);
            half3 hdr = half3(ldr.r * factor, ldr.g * factor, ldr.b * factor);
            return hdr;
        }

	    v2g vert (appdata v)
	    {
		    v2g o;
		    o.vertex = v.vertex;
		    return o;
	    }

        [maxvertexcount(96)]
        void geom (triangle v2g IN[3], inout TriangleStream<g2f> stream)
        {
		g2f o;
		float tFlu = _Time.y * _FluctSpeed;
		float tRot = _Time.y * _RotateSpeed;
        float tRev = _Time.y * _RevolveSpeed;

		    [unroll(32)]
		    for ( int i = 0; i < _ObjectNum; i++ )
            {
			    float2 random = rand(i);
			    float angle = 1.0f * i / _ObjectNum;
			    float3 pos = float3(cos(angle * 2.0f * PI), 0, sin(angle * 2.0f * PI));
                float radius = 0;
                float height = 0;
			    o.color = _Color;

                radius += _RingScale + cos(tFlu * (random.x + 0.5)) * _FluctAmount;
                pos.xz *=  radius;
                height += cos(tFlu * (random.y + 0.5)) * _FluctAmount;
                pos.y = height;
			    pos.xz = mul(pos.xz, float2x2(cos(tRev),-sin(tRev),sin(tRev),cos(tRev)));
                o.color.rgb = LDR2HDR(o.color.rgb, _Intensity);

			    [unroll]
			    for ( int j = 0; j < 3; j++ )
                {
			    	float3 vpos = IN[j].vertex;
                    vpos *= _ObjectScale;
                    vpos = mul(rotateToMatrix(tRot * (random.x + 0.5), tRot, tRot * (random.y + 0.5)), vpos);
			    	vpos += pos;
			    	o.vertex = float4(vpos, 1.0);
			    	o.vertex = UnityObjectToClipPos(o.vertex);
			    	stream.Append(o);
			    }
			    stream.RestartStrip();			
		    }
        }

        fixed4 frag (g2f i) : SV_Target
	    {
		    return i.color;
	    }
        ENDCG
        }
    }
}
