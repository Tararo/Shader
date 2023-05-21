Shader "TARARO/raymarch_boid"
{
	Properties
    {
        [Header(Custom Render Texture, 8x8, rgba SFLOAT, Double Buffered)]
            _BoidTex("Boid Texture", 2D) = "gray" {}
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.2
            _Specular("Specular", Range(0.0, 1.0)) = 1
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
            _RefractIndex("Refraction Index", Float) = 1.3
        [Header(Fog)]
            _FogColor("Fog Color", Color) = (0,0,0,1)
            _FogSDepth("Fog Start Depth", Float) = 1
            _FogEDepth("Fog End Depth", Float) = 5
        [Header(Sphere)]
            _Position("Position", Vector) = (0,0,-0.5,0)
            _SpaceScale ("Space Scale", Float) = 0.2
            _ObjectScale ("Object Scale", Float) = 0.2
	}

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    sampler2D _BoidTex;
    float2 _BoidTex_TexelSize;
    fixed4 _Color;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float _RefractIndex;
    fixed4 _FogColor;
    float _FogSDepth;
    float _FogEDepth;
    float4 _Position;
    float _SpaceScale;
    float _ObjectScale;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    // フレネル反射係数
    float schlickFresnel(float cosine) {
        float r0 = (1 - _RefractIndex) / (1 + _RefractIndex);
        r0 = r0 * r0;
        return r0 + (1 - r0) * pow(1 - cosine, 5);
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

    //球の距離関数
    float sphere(float3 p, float3 center, float radius) 
    {
        return length(p - center) - radius;
    }

    float smoothMin(float d1, float d2, float k){
        float h = exp(-k * d1) + exp(-k * d2);
        return -log(h) / k;
    }

    float boidsphere(float3 p) {
        float d = 1000;
        float3 q = p - _Position;
        [unroll(32)]
        for ( int i = 0; i < 32; i++ )
        {
            float2 uv = (float2(i % 8, (i - i % 8) / 8) + 0.5) * _BoidTex_TexelSize;
            float3 pos = tex2Dlod(_BoidTex, float4(uv.x, uv.y, 0, 0));
            pos *= _SpaceScale;
            float ds = sphere(q, pos, _ObjectScale);
            d = min(d, ds);
        }
        return d;
    }

    //最終的な距離関数
    float dist(float3 p) {
        float d = boidsphere(p);
        return d;
    }

    //法線を導出する関数
    float3 getnormal(float3 p)
    {
        float d = 0.0001;
        return normalize(float3(
            dist(p + float3(d, 0.0, 0.0)) - dist(p + float3(-d, 0.0, 0.0)),
            dist(p + float3(0.0, d, 0.0)) - dist(p + float3(0.0, -d, 0.0)),
            dist(p + float3(0.0, 0.0, d)) - dist(p + float3(0.0, 0.0, -d))
        ));
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
        float depth : SV_Depth;
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
                //レイのスタート位置（カメラのローカル座標）.
				float3 ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
                //レイの方向（視点→メッシュ）.
				float3 rd = normalize(i.vertex.xyz - ro);
                //レイの歩幅
				float d = 0;
                //レイの長さ
                //Quad用改変
				//float t = 0;
                float t = length(i.vertex.xyz - ro);
                //レイの先端座標
				float3 p = float3(0, 0, 0);

                //レイマーチング
				//[unroll]
				for (int i = 0; i < 120; ++i)
                {
					p = ro + rd * t;
					d = dist(p);
					t += d;
                    //レイが遠くに行き過ぎたか衝突した場合ループを終える
					if (d < 0.001 || t > _FogEDepth * 2)
                    {
                        break;
                    }
				}
				p = ro + rd * t;

                //レイが衝突していないと判断すれば描画しない
				//if (d > 0.001)
                //{
				//	discard;
				//}
				
                //出力色
				float4 fragColor = float4(0,0,0,1);
                //法線
                float3 normal = getnormal(p);
                //光源
                float3 lightDir = normalize(ObjSpaceLightDir(float4(p,1)));
                float3 lightColor = _LightColor0;
                if(IsNaN(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }


                // 環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                //ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * lightColor;
                //フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, rd)), _SpecularPow) * lightColor;
                //反射
                float3 refViewVec = reflect(rd, normal);
                refViewVec = normalize(mul(unity_ObjectToWorld, refViewVec) - mul(unity_ObjectToWorld, float3(0, 0, 0)));
                half4 refColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refViewVec, 0);
                float fresnel = schlickFresnel(max(0.0, dot(-rd, normal)));

                fragColor.rgb = _Color.rgb * difColor;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, fresnel * _Reflect);
                fragColor.rgb += speColor * fresnel * _Specular;
                fragColor.rgb += ambColor * _Ambient;

                //フォグ
                float fog = smoothstep(_FogSDepth, _FogEDepth, t);
                fragColor.rgb = lerp(fragColor.rgb, _FogColor, fog);

				pout o;
				o.color = fragColor;
				//float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
				//o.depth = projectionPos.z / projectionPos.w;
				return o;
			}
			ENDCG
		}
	}
}