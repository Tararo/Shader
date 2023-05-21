Shader "TARARO/Filter_Glitch"
{
    Properties
    {
        [Header(Distortion)]
            _DistAmount("Amount", float) = 0.02
            _DistWidth("Width", Range(0.0, 1)) = 0.25
            _DistSpeed("Speed", float) = 0.5
            _DistFreq("Frequency", Range(0.0, 1)) = 0.5
            _DistQuant("Quantization", Range(0.0, 1)) = 0.5
            _DistColShi("Color Shift", Range(-1, 1)) = 0.5
        [Header(Scanlines)]
            _LineAlpha("Alpha", Range(0.0, 1)) = 0.1
            _LineWidth("Width", float) = 0.01
            _LineSpeed("Speed", float) = 0.25
        [Header(Grain)]
            _GrainAlpha("Alpha", Range(0.0, 1)) = 0.1
            _GrainSatu("Saturation", Range(0.0, 1)) = 0.5
        [Header(Saturation)]
            _SatuR("Red", Range(0.0, 1)) = 1.0
            _SatuG("Green", Range(0.0, 1)) = 0.9
            _SatuB("Blue", Range(0.0, 1)) = 0.8
    }
    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"

    sampler2D _GrabTexture;
    float2 _GrabTexture_TexelSize;
    float _DistAmount, _DistWidth, _DistSpeed, _DistFreq, _DistQuant, _DistColShi;
    float _LineAlpha, _LineWidth, _LineSpeed;
    float _GrainAlpha, _GrainSatu;
    float _SatuR, _SatuG, _SatuB;

    float2 random2(float2 st)
    {
        st = float2( dot(st,float2(127.1,311.7)), dot(st,float2(269.5,183.3)) );
        return -1.0 + 2.0*frac(sin(st)*43758.5453123);
    }

    float3 random3 (float3 st)
    {
        st = float3(dot(st, float3(127.7, 311.9, 208.1)), dot(st, float3(269.3, 214.3, 183.1)), dot(st, float3(118.1, 153.1, 370.9)));
        return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
    }

    float perlinNoise(float2 st) 
    {
        float2 p = floor(st);
        float2 f = frac(st);
        float2 u = f*f*(3.0-2.0*f);

        float v00 = random2(p+float2(0,0));
        float v10 = random2(p+float2(1,0));
        float v01 = random2(p+float2(0,1));
        float v11 = random2(p+float2(1,1));

        float o = 
        lerp(
            lerp( dot( v00, f - float2(0,0) ), dot( v10, f - float2(1,0) ), u.x ),
            lerp( dot( v01, f - float2(0,1) ), dot( v11, f - float2(1,1) ), u.x ), 
        u.y) * 2;

        return o;
    }

    // BT.601
    float rgbToGray(float3 i) {
        return 0.299*i.r + 0.587*i.g + 0.114*i.b;
    }

    float distNoise(float2 uv)
    {
        float t = _Time.y * _DistSpeed;
        float rnd = (perlinNoise(float2(sin(t), cos(t)) * t) + 1) / 2;
        float freq = _DistFreq * 0.99;
        float flicker = step(rnd, freq);
        t = floor(t / (1 - freq)) * (1 - freq);
        float width = 1 / (0.01 + _DistWidth * 0.09);
        float noise = perlinNoise(float2(t, uv.y * width + t));
        float quant = 0.01 + _DistQuant * 0.99;
        noise = floor(noise / quant) * quant;
        noise *= _DistAmount;
        noise *= flicker;
        return noise;
    }

    float4 aberration(sampler2D tex, float2 uv, float shift)
    {
        float4 color = float4(0, 0, 0, 1);
        color.r = tex2D(tex, float2(uv.x + shift * (1 + _DistColShi), uv.y)).r;
        color.g = tex2D(tex, float2(uv.x + shift, uv.y)).g;
        color.b = tex2D(tex, float2(uv.x + shift * (1 - _DistColShi), uv.y)).b;
        return color;
    }

    float4 scanLine(float2 uv)
    {
        float4 color = float4(0, 0, 0, _LineAlpha);
        float t = _Time.y * _LineSpeed;
        float width = 1 / (0.01 + _LineWidth * 0.09);
        float scan = step(frac(uv.y * width + t), 0.5);
        color.a *= scan;
        return color;
    }

    float4 grain(float2 uv)
    {
        float4 color = float4(0, 0, 0, _GrainAlpha);
        float t = _Time.y;
        float3 rnd = random3(float3(uv.x, uv.y, t));
        rnd = (rnd + 1) / 2;
        float gray = rgbToGray(rnd);
        color.rgb = lerp(gray, rnd, _GrainSatu);
        return color;
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
                float4 fragColor = float4(0, 0, 0, 1);
                float2 grabUv = i.grabPos.xy / i.grabPos.w;
                //Distortion
                float dnoise = distNoise(grabUv);
                fixed4 grabColor = aberration(_GrabTexture, grabUv, dnoise);
                fragColor = grabColor;
                //Grain
                fixed4 grainColor = grain(grabUv);
                fragColor.rgb = fragColor.rgb * (1 - grainColor.a) + grainColor.rgb * grainColor.a;
                //ScanLine
                fixed4 scanColor = scanLine(grabUv);
                fragColor.rgb = fragColor.rgb * (1 - scanColor.a) + scanColor.rgb * scanColor.a;
                //Saturation
                fragColor.rgb *= float3(_SatuR, _SatuG, _SatuB);

				return fragColor;
			}
            ENDCG
        }
    }
}
