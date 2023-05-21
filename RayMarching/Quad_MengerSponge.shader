<<<<<<< HEAD
﻿Shader "TARARO/quad_menger-sponge"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.2
            _Specular("Specular", Range(0.0, 1.0)) = 1
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
        [Header(Fog)]
            _FogColor("Fog Color", Color) = (0,0,0,1)
            _FogSDepth("Fog Start Depth", Float) = 1
            _FogEDepth("Fog End Depth", Float) = 5
        [Header(Cube)]
            _Position("Position", Vector) = (0,0,0.5,0)
            _DeformSpeed("Deformation Speed", Float) = 0.05
            _RotateSpeed("Rotation Speed", Float) = 0.1
        [Header(BackGround)]
            _Height("Height", Float) = 0.75
            _Width("Width", Float) = 0.75
            _Distortion("Distortion", Float) = 0.0
	}

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    fixed4 _Color;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    fixed4 _FogColor;
    float _FogSDepth;
    float _FogEDepth;
    float4 _Position;
    float _DeformSpeed;
    float _RotateSpeed;
    float _Height;
    float _Width;
    float _Distortion;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
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

    // Box Projectionを考慮した反射ベクトルを取得
    float3 boxProjection(float3 normalizedDir, float3 worldPosition, float4 probePosition, float3 boxMin, float3 boxMax)
    {
        // GraphicsSettingsのReflection Probes Box Projectionが有効な場合のみtrue
        #if UNITY_SPECCUBE_BOX_PROJECTION
            // Box Projectionが有効な場合はprobePosition.w > 0となる
            if (probePosition.w > 0) {
                float3 magnitudes = ((normalizedDir > 0 ? boxMax : boxMin) - worldPosition) / normalizedDir;
                float magnitude = min(min(magnitudes.x, magnitudes.y), magnitudes.z);
                normalizedDir = normalizedDir * magnitude + (worldPosition - probePosition);
            }
        #endif

        return normalizedDir;
    }

    // Reflection Probeから反射色を取得
    float4 refProbe(float3 reflectDirection, float3 worldPosition)
    {
        // Box Projection
        half3 refDir0 = boxProjection(reflectDirection, worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        half3 refDir1 = boxProjection(reflectDirection, worldPosition, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
        // SpecCube0
        float4 refColor0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refDir0, 0);
        refColor0.rgb = DecodeHDR(refColor0, unity_SpecCube0_HDR);
        // SpecCube1
        float4 refColor1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, refDir1, 0);
        refColor1.rgb = DecodeHDR(refColor1, unity_SpecCube1_HDR);

        // unity_SpecCube0_BoxMin.w にブレンド率が入ってくる
        return lerp(refColor1, refColor0, unity_SpecCube0_BoxMin.w);
    }

    // 立方体
    float box(float3 p, float3 b) {
        float3 q = abs(p) - b;
        return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
    }

    // menger sponge
    float mengersponge(float3 p) {
        float tDef = _Time.y * _DeformSpeed;
		float tRot = _Time.y * _RotateSpeed;
        float3 q = p - _Position;
        q = mul(rotateToMatrix(tRot, tRot, tRot), q);
        float s = 5 * (0.55 + abs(tan(tDef)));
        float d = box(q,float3(0.2, 0.2, 0.2));
        q = abs(q);

        [unroll]
        for( int m = 0; m < 3; m++ ) {
            float3 a = fmod( q*s, 2.0 )-1.0;
            s *= 3.0;
            float3 r = abs(1.0 - 3.0*abs(a));

            float da = max(r.x,r.y);
            float db = max(r.y,r.z);
            float dc = max(r.z,r.x);
            float c = (min(da,min(db,dc))-1.0)/s;

            d = max(d,c);
        }
        return d;
    }

    // 平面
    float plane(float3 p, float3 normal, float offset) {
        return dot(p, normal) + offset;
    }

    // 背景
    float background(float3 p) {
        float3 dp = float3(p.x * cos(p.z * _Distortion) - p.y * sin(p.z * _Distortion), p.y * cos(p.z * _Distortion) + p.x * sin(p.z * _Distortion), p.z);
        float d1 = plane(dp, float3(0, 1, 0), _Height);
        float d2 = plane(dp, float3(0, -1, 0), _Height);
        float d3 = plane(dp, float3(1, 0, 0), _Width);
        float d4 = plane(dp, float3(-1, 0, 0), _Width);
        return min(min(d1, d2), min(d3, d4));
    }

    //最終的な距離関数
    float dist(float3 p) {
        float cube = mengersponge(p);
        float bg = background(p);
        float d = min(cube, bg);
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
				[unroll]
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
                float3 refViewVec = normalize(reflect(UnityObjectToWorldDir(rd), UnityObjectToWorldNormal(normal)));
                float4 refColor = refProbe(refViewVec, mul(unity_ObjectToWorld, p));

                fragColor.rgb = _Color.rgb * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor * _Specular;

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
=======
﻿Shader "TARARO/quad_menger-sponge"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.2
            _Specular("Specular", Range(0.0, 1.0)) = 1
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
        [Header(Fog)]
            _FogColor("Fog Color", Color) = (0,0,0,1)
            _FogSDepth("Fog Start Depth", Float) = 1
            _FogEDepth("Fog End Depth", Float) = 5
        [Header(Cube)]
            _Position("Position", Vector) = (0,0,0.5,0)
            _DeformSpeed("Deformation Speed", Float) = 0.05
            _RotateSpeed("Rotation Speed", Float) = 0.1
        [Header(BackGround)]
            _Height("Height", Float) = 0.75
            _Width("Width", Float) = 0.75
            _Distortion("Distortion", Float) = 0.0
	}

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    fixed4 _Color;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    fixed4 _FogColor;
    float _FogSDepth;
    float _FogEDepth;
    float4 _Position;
    float _DeformSpeed;
    float _RotateSpeed;
    float _Height;
    float _Width;
    float _Distortion;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
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

    // Box Projectionを考慮した反射ベクトルを取得
    float3 boxProjection(float3 normalizedDir, float3 worldPosition, float4 probePosition, float3 boxMin, float3 boxMax)
    {
        // GraphicsSettingsのReflection Probes Box Projectionが有効な場合のみtrue
        #if UNITY_SPECCUBE_BOX_PROJECTION
            // Box Projectionが有効な場合はprobePosition.w > 0となる
            if (probePosition.w > 0) {
                float3 magnitudes = ((normalizedDir > 0 ? boxMax : boxMin) - worldPosition) / normalizedDir;
                float magnitude = min(min(magnitudes.x, magnitudes.y), magnitudes.z);
                normalizedDir = normalizedDir * magnitude + (worldPosition - probePosition);
            }
        #endif

        return normalizedDir;
    }

    // Reflection Probeから反射色を取得
    float4 refProbe(float3 reflectDirection, float3 worldPosition)
    {
        // Box Projection
        half3 refDir0 = boxProjection(reflectDirection, worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        half3 refDir1 = boxProjection(reflectDirection, worldPosition, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
        // SpecCube0
        float4 refColor0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refDir0, 0);
        refColor0.rgb = DecodeHDR(refColor0, unity_SpecCube0_HDR);
        // SpecCube1
        float4 refColor1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, refDir1, 0);
        refColor1.rgb = DecodeHDR(refColor1, unity_SpecCube1_HDR);

        // unity_SpecCube0_BoxMin.w にブレンド率が入ってくる
        return lerp(refColor1, refColor0, unity_SpecCube0_BoxMin.w);
    }

    // 立方体
    float box(float3 p, float3 b) {
        float3 q = abs(p) - b;
        return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
    }

    // menger sponge
    float mengersponge(float3 p) {
        float tDef = _Time.y * _DeformSpeed;
		float tRot = _Time.y * _RotateSpeed;
        float3 q = p - _Position;
        q = mul(rotateToMatrix(tRot, tRot, tRot), q);
        float s = 5 * (0.55 + abs(tan(tDef)));
        float d = box(q,float3(0.2, 0.2, 0.2));
        q = abs(q);

        [unroll]
        for( int m = 0; m < 3; m++ ) {
            float3 a = fmod( q*s, 2.0 )-1.0;
            s *= 3.0;
            float3 r = abs(1.0 - 3.0*abs(a));

            float da = max(r.x,r.y);
            float db = max(r.y,r.z);
            float dc = max(r.z,r.x);
            float c = (min(da,min(db,dc))-1.0)/s;

            d = max(d,c);
        }
        return d;
    }

    // 平面
    float plane(float3 p, float3 normal, float offset) {
        return dot(p, normal) + offset;
    }

    // 背景
    float background(float3 p) {
        float3 dp = float3(p.x * cos(p.z * _Distortion) - p.y * sin(p.z * _Distortion), p.y * cos(p.z * _Distortion) + p.x * sin(p.z * _Distortion), p.z);
        float d1 = plane(dp, float3(0, 1, 0), _Height);
        float d2 = plane(dp, float3(0, -1, 0), _Height);
        float d3 = plane(dp, float3(1, 0, 0), _Width);
        float d4 = plane(dp, float3(-1, 0, 0), _Width);
        return min(min(d1, d2), min(d3, d4));
    }

    //最終的な距離関数
    float dist(float3 p) {
        float cube = mengersponge(p);
        float bg = background(p);
        float d = min(cube, bg);
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
				[unroll]
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
                float3 refViewVec = normalize(reflect(UnityObjectToWorldDir(rd), UnityObjectToWorldNormal(normal)));
                float4 refColor = refProbe(refViewVec, mul(unity_ObjectToWorld, p));

                fragColor.rgb = _Color.rgb * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor * _Specular;

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
>>>>>>> origin/main
}