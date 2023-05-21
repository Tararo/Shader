Shader "TARARO/art_boid"
{
	Properties
    {
        [Header(Custom Render Texture)]
            [NoScaleOffset]_BoidTex("8x8, rgba SFLOAT, Double Buffered", 2D) = "gray" {}
        [Header(Main)]
            _ObjectColor("Object Color", Color) = (0,1,1,1)
            _BGColor("BackGround Color", Color) = (0,0,0,1)
            _Position("Position(XYZ), Scale", Vector) = (0,0,6,0.5)
            _ObjectScale ("Object Scale", Float) = 0.2
            _Depth("Depth", Range(0, 1)) = 0.5
	}

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"

    sampler2D _BoidTex;
    float2 _BoidTex_TexelSize;
    fixed4 _ObjectColor;
    fixed4 _BGColor;
    float4 _Position;
    float _ObjectScale;
    float _Depth;


    //円
    float circle(float2 p, float2 center, float radius) 
    {
        return step(distance(p, center), radius);
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
                //--ローカル座標での処理--
                //視点位置
				float3 eye = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
                //視点→メッシュ
				float3 vdir = normalize(i.vertex.xyz - eye);
                //視点→メッシュのz=0座標
                float3 vpos = eye - vdir / vdir.z * eye.z;

                //boids
                [unroll(32)]
                for ( int i = 0; i < 32; i++ )
                {
                    //Custom Render TextureのUV座標
                    float2 CRTuv = (float2(i % 8, (i - i % 8) / 8) + 0.5) * _BoidTex_TexelSize;
                    //boidの位置
                    float3 boid = tex2Dlod(_BoidTex, float4(CRTuv.x, CRTuv.y, 0, 0));
                    boid = boid * _Position.w + _Position.xyz;
                    //視点→noid
                    float3 bdir = normalize(boid - eye);
                    //視点→boidのz=0座標
                    float3 bpos = eye - bdir / bdir.z * eye.z;
                    //boidの深度
                    float bz = distance(boid, bpos) * _Depth;

                    //Circle描画
                    float4 boidColor = _ObjectColor;
                    boidColor.a *= circle(vpos.xy, bpos.xy, _ObjectScale / (1 + bz));
                    boidColor.a /= 1 + bz;

                    fragColor.rgb = fragColor.rgb * (1 - boidColor.a) + boidColor.rgb * boidColor.a;
                }

				pout o;
				o.color = fragColor;

				return o;
			}
			ENDCG
		}
	}
}