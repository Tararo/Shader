Shader "TARARO/Glass_CullOff"
{
    Properties
    {
        _Color("Albedo",Color) = (1, 1, 1, 0)
        _Specular("Specular", Range(0.0, 1.0)) = 1
        _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
        _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
        _Refract("Refraction", Range(0.0, 1.0)) = 0.5
        _RefractIndex("Refraction Index", Float) = 1.5
        _Aberration("Chromatic Aberration", Range(0.0, 1.0)) = 0.1
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    sampler2D _GrabTexture;
    fixed4 _Color;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float _Refract;
    float _RefractIndex;
    float _Aberration;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
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

    // フレネル反射係数
    float schlickFresnel(float cosine) {
        float r0 = (1 - _RefractIndex) / (1 + _RefractIndex);
        r0 = r0 * r0;
        return r0 + (1 - r0) * pow(1 - cosine, 5);
    }

    // GPU -> vertex shader
    struct appdata
    {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
    };

    // vertex shader -> fragment shader
    struct v2f
    {
        float4 pos : SV_POSITION;
        float3 normal  : TEXCOORD0;
        float3 worldPos : TEXCOORD1;
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

        GrabPass {}

        Cull Front
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

            // Vertex Shader
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normal  = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}
			
            // Fragment Shader
			fixed4 frag (v2f i) : SV_Target
			{
                float3 cameraPos = _WorldSpaceCameraPos;
                #if defined(USING_STEREO_MATRICES)
                cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
                #endif

                float3 normal = normalize(i.normal);
                float3 viewDir = normalize(i.worldPos - cameraPos);
                float distance = length(i.worldPos - cameraPos);

                // 屈折
                float3 refractDir = refract(viewDir, normal, 1.0 / _RefractIndex);
                float3 refractColor;

                float3 refractPos = i.worldPos + refractDir * distance * _Refract;
                float4 refractScreenPos = mul(UNITY_MATRIX_VP, float4(refractPos, 1.0));
                float2 refractScreenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                refractScreenUv.y = 1.0 - refractScreenUv.y;
                #endif
                refractColor.g = tex2D(_GrabTexture, refractScreenUv).g;

                refractPos = i.worldPos + refractDir * distance * _Refract * (1 + _Aberration);
                refractScreenPos = mul(UNITY_MATRIX_VP, float4(refractPos, 1.0));
                refractScreenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                refractScreenUv.y = 1.0 - refractScreenUv.y;
                #endif
                refractColor.r = tex2D(_GrabTexture, refractScreenUv).r;

                refractPos = i.worldPos + refractDir * distance * _Refract * (1 - _Aberration);
                refractScreenPos = mul(UNITY_MATRIX_VP, float4(refractPos, 1.0));
                refractScreenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                refractScreenUv.y = 1.0 - refractScreenUv.y;
                #endif
                refractColor.b = tex2D(_GrabTexture, refractScreenUv).b;

                // 出力色
				float4 fragColor = float4(0, 0, 0, 1);
                fragColor.rgb = lerp(refractColor, _Color.rgb, _Color.a);

				return fragColor;
			}
            ENDCG
        }

        GrabPass {}

        Cull Back
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

            // Vertex Shader
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normal  = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}
			
            // Fragment Shader
			fixed4 frag (v2f i) : SV_Target
			{
                float3 cameraPos = _WorldSpaceCameraPos;
                #if defined(USING_STEREO_MATRICES)
                cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
                #endif

                float3 normal = normalize(i.normal);
                float3 viewDir = normalize(i.worldPos - cameraPos);
                float distance = length(i.worldPos - cameraPos);
                //光源
                float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 lightColor = _LightColor0;
                if(IsNaN(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }

                //フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, viewDir)), _SpecularPow) * lightColor;

                // 反射
                float3 refViewVec = reflect(viewDir, normal);
                half4 reflectColor = refProbe(refViewVec, i.worldPos);

                float fresnel = schlickFresnel(max(0.0, dot(-viewDir, normal)));

                // 屈折
                float3 refractDir = refract(viewDir, normal, 1.0 / _RefractIndex);
                float3 refractColor;

                float3 refractPos = i.worldPos + refractDir * distance * _Refract;
                float4 refractScreenPos = mul(UNITY_MATRIX_VP, float4(refractPos, 1.0));
                float2 refractScreenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                refractScreenUv.y = 1.0 - refractScreenUv.y;
                #endif
                refractColor.g = tex2D(_GrabTexture, refractScreenUv).g;

                refractPos = i.worldPos + refractDir * distance * _Refract * (1 + _Aberration);
                refractScreenPos = mul(UNITY_MATRIX_VP, float4(refractPos, 1.0));
                refractScreenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                refractScreenUv.y = 1.0 - refractScreenUv.y;
                #endif
                refractColor.r = tex2D(_GrabTexture, refractScreenUv).r;

                refractPos = i.worldPos + refractDir * distance * _Refract * (1 - _Aberration);
                refractScreenPos = mul(UNITY_MATRIX_VP, float4(refractPos, 1.0));
                refractScreenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                refractScreenUv.y = 1.0 - refractScreenUv.y;
                #endif
                refractColor.b = tex2D(_GrabTexture, refractScreenUv).b;

                // 出力色
				float4 fragColor = float4(0, 0, 0, 1);
                fragColor.rgb = lerp(refractColor, _Color.rgb, _Color.a);
                fragColor.rgb = lerp(fragColor.rgb, reflectColor.rgb, fresnel * _Reflect);
                fragColor.rgb += speColor * fresnel * _Specular;

				return fragColor;
			}
            ENDCG
        }
    }
}
