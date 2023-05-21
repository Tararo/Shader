Shader "TARARO/Art_Network"
{
	Properties
    {
        [Header(Main)]
            _ObjectColor("Object color", Color) = (0,0,0,1)
            _BGColor("BackGround color", Color) = (1,1,1,1)
            _Scale("Scale", Float) = 10
            _Blur("Blur", Float) = 0.02
            _Radius("Particle radius", Float) = 0.05
            _Width("Line width", Float) = 0.01
            _Length("Line fade length", Float) = 1
            _FluctSpeed("Fluctuation speed", Float) = 0.5
            _FluctAmount("Fluctuation amount", Range(0, 1)) = 0.5
	}

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"

    fixed4 _ObjectColor;
    fixed4 _BGColor;
    float _Scale;
    float _Blur;
    float _Radius;
    float _Width;
    float _Length;
    float _FluctSpeed;
    float _FluctAmount;

    //回転
    float2 rotate(float2 p, float2 vec)
    {
        float theta = -atan2(vec.y, vec.x);
        float2 pout;
        pout.x = p.x * cos(theta) - p.y * sin(theta);
        pout.y = p.x * sin(theta) + p.y * cos(theta);
        return pout;
    }

    //円_距離関数
    float circle(float2 p, float2 center, float radius) 
    {
        return max(distance(p, center) - radius, 0.0);
    }

    //直方体_距離関数
    float box(float2 p, float2 b)
    {
        float2 q = abs(p) - b / 2;
        return length(max(q,0.0));
    }

    //線分_距離関数
    float dLine(float2 p, float2 a, float2 b, float width)
    {
        float2 center = (a + b) / 2;
        float2 q = p - center;
        float2 vec = b - a;
        return box(rotate(q, vec), float2(length(vec), width));
    }

    //乱数(-1~1)
    float rand(float2 co)
    {
        return frac(sin(dot(co, float2(12.9898,78.233))) * 43758.5453);
    }

    //座標
    void particlePos(float2 co, out float2 pos, out float alpha)
    {
        float2 lattice = floor(co);
        float2 random = float2(rand(lattice + float2(0.5,0)), rand(lattice + float2(0,0.5)));
        float tFlu = _Time.y * _FluctSpeed;
        pos = lattice + random * (1 - (sin(tFlu * random) + 1) / 2 * _FluctAmount);
        alpha = (sin(tFlu * rand(lattice)) + 1) / 2;
    }

    //network
    float network(float2 p)
    {
        //座標
        float2 pos[9];
        //透明度
        float alpha[9];
        particlePos(p + float2(-1,-1), pos[0], alpha[0]);
        particlePos(p + float2( 0,-1), pos[1], alpha[1]);
        particlePos(p + float2( 1,-1), pos[2], alpha[2]);
        particlePos(p + float2(-1, 0), pos[3], alpha[3]);
        particlePos(p + float2( 0, 0), pos[4], alpha[4]);
        particlePos(p + float2( 1, 0), pos[5], alpha[5]);
        particlePos(p + float2(-1, 1), pos[6], alpha[6]);
        particlePos(p + float2( 0, 1), pos[7], alpha[7]);
        particlePos(p + float2( 1, 1), pos[8], alpha[8]);
        //円描画
        float circles = 0;
        for(int i = 0; i < 9; i++)
        {
            circles += max(1 - circle(p, pos[i], _Radius) / _Blur, 0) * alpha[i];
        }
        //線描画
        float lines = 0;
        for(int i = 0; i < 4; i++)
        {
            lines += max(1 - dLine(p, pos[i], pos[4], _Width) / _Blur, 0) * min(alpha[i], alpha[4]) * (1 - smoothstep(_Length * 0.9, _Length * 1.1, distance(pos[i], pos[4])));
        }
        for(int i = 0; i < 4; i++)
        {
            lines += max(1 - dLine(p, pos[i + 5], pos[4], _Width) / _Blur, 0) * min(alpha[i + 5], alpha[4]) * (1 - smoothstep(_Length * 0.9, _Length * 1.1, distance(pos[i + 5], pos[4])));
        }
        lines += max(1 - dLine(p, pos[1], pos[3], _Width) / _Blur, 0) * min(alpha[1], alpha[3]) * (1 - smoothstep(_Length * 0.9, _Length * 1.1, distance(pos[1], pos[3])));
        lines += max(1 - dLine(p, pos[3], pos[7], _Width) / _Blur, 0) * min(alpha[3], alpha[7]) * (1 - smoothstep(_Length * 0.9, _Length * 1.1, distance(pos[3], pos[7])));
        lines += max(1 - dLine(p, pos[7], pos[5], _Width) / _Blur, 0) * min(alpha[7], alpha[5]) * (1 - smoothstep(_Length * 0.9, _Length * 1.1, distance(pos[7], pos[5])));
        lines += max(1 - dLine(p, pos[5], pos[1], _Width) / _Blur, 0) * min(alpha[5], alpha[1]) * (1 - smoothstep(_Length * 0.9, _Length * 1.1, distance(pos[5], pos[1])));

        return max(circles, lines);
    }

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 pos : SV_POSITION;
        float4 vertex : TEXCOORD1;
    };

    struct pout
    {
        fixed4 color : SV_Target;
    };
    ENDCG
	
	SubShader
	{
		Tags
        {
            "RenderType" = "Opaque"
        }
		LOD 100
		Pass
		{
            Tags
            {
                "LightMode" = "ForwardBase"
            }
			CGPROGRAM

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.vertex = v.vertex;//メッシュのローカル座標
				o.uv = v.uv;
				return o;
			}

			pout frag(v2f i)
			{
                //出力色
				float4 fragColor = _BGColor;
                
                float2 nuv = i.uv * _Scale;
                nuv.x += _Time.y * 0.2;
                float4 particle = network(nuv);

                fragColor = _ObjectColor * particle + fragColor * (1 - particle);

				pout o;
				o.color = fragColor;

				return o;
			}
			ENDCG
		}
	}
}