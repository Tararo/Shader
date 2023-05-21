Shader "TARARO/Filter_Edge"
{
    Properties
    {
        _Threshold("Threshold", Range(0, 1)) = 0.1
        _BGColor("BackGround Color", Color) = (0,0,0,0)
    }
    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"

    sampler2D _GrabTexture;
    float2 _GrabTexture_TexelSize;

    float _Threshold;
    float4 _BGColor;

    // BT.601
    float rgbToGray(float4 i)
    {
        return 0.299*i.r + 0.587*i.g + 0.114*i.b;
    }

    float lerp3x3(float3x3 tex, float2 uv)
    {
        float2 cuv = clamp(uv, -1, 1);
        float2 nuv = floor(cuv);
        float2 lp = cuv - nuv;
        nuv += 1;
        return lerp(lerp(tex[nuv.x][nuv.y], tex[nuv.x + 1][nuv.y], lp.x), lerp(tex[nuv.x][nuv.y + 1], tex[nuv.x + 1][nuv.y + 1], lp.x), lp.y);
    }

    float filter3x3(float3x3 filter, float3x3 i)
    {
        float3x3 filtered = filter * i;
        return filtered._m00 + filtered._m01 + filtered._m02 +
            filtered._m10 + filtered._m11 + filtered._m12 +
            filtered._m20 + filtered._m21 + filtered._m22;
    }

    float2 sobelFiter(float3x3 i)
    {
        float3x3 sobelX = {-1, 0, 1,-2, 0, 2,-1, 0, 1};
        float3x3 sobelY = {-1,-2,-1, 0, 0, 0, 1, 2, 1};
        return float2(filter3x3(sobelX, i), filter3x3(sobelY, i));
    }

    void gradFilter(sampler2D tex, float2 uv, float2 texel, out float3x3 gradMag, out float2 gradVec)
    {
        // 5x5 gray sample
        float gray00 = rgbToGray(tex2D(tex, uv + float2(-2, -2) * texel));
        float gray01 = rgbToGray(tex2D(tex, uv + float2(-1, -2) * texel));
        float gray02 = rgbToGray(tex2D(tex, uv + float2( 0, -2) * texel));
        float gray03 = rgbToGray(tex2D(tex, uv + float2( 1, -2) * texel));
        float gray04 = rgbToGray(tex2D(tex, uv + float2( 2, -2) * texel));
        float gray10 = rgbToGray(tex2D(tex, uv + float2(-2, -1) * texel));
        float gray11 = rgbToGray(tex2D(tex, uv + float2(-1, -1) * texel));
        float gray12 = rgbToGray(tex2D(tex, uv + float2( 0, -1) * texel));
        float gray13 = rgbToGray(tex2D(tex, uv + float2( 1, -1) * texel));
        float gray14 = rgbToGray(tex2D(tex, uv + float2( 2, -1) * texel));
        float gray20 = rgbToGray(tex2D(tex, uv + float2(-2,  0) * texel));
        float gray21 = rgbToGray(tex2D(tex, uv + float2(-1,  0) * texel));
        float gray22 = rgbToGray(tex2D(tex, uv + float2( 0,  0) * texel));
        float gray23 = rgbToGray(tex2D(tex, uv + float2( 1,  0) * texel));
        float gray24 = rgbToGray(tex2D(tex, uv + float2( 2,  0) * texel));
        float gray30 = rgbToGray(tex2D(tex, uv + float2(-2,  1) * texel));
        float gray31 = rgbToGray(tex2D(tex, uv + float2(-1,  1) * texel));
        float gray32 = rgbToGray(tex2D(tex, uv + float2( 0,  1) * texel));
        float gray33 = rgbToGray(tex2D(tex, uv + float2( 1,  1) * texel));
        float gray34 = rgbToGray(tex2D(tex, uv + float2( 2,  1) * texel));
        float gray40 = rgbToGray(tex2D(tex, uv + float2(-2,  2) * texel));
        float gray41 = rgbToGray(tex2D(tex, uv + float2(-1,  2) * texel));
        float gray42 = rgbToGray(tex2D(tex, uv + float2( 0,  2) * texel));
        float gray43 = rgbToGray(tex2D(tex, uv + float2( 1,  2) * texel));
        float gray44 = rgbToGray(tex2D(tex, uv + float2( 2,  2) * texel));
        // 3x3 grad
        float grad00 = length(sobelFiter(float3x3(gray00, gray01, gray02, gray10, gray11, gray12, gray20, gray21, gray22)));
        float grad01 = length(sobelFiter(float3x3(gray01, gray02, gray03, gray11, gray12, gray13, gray21, gray22, gray23)));
        float grad02 = length(sobelFiter(float3x3(gray02, gray03, gray04, gray12, gray13, gray14, gray22, gray23, gray24)));
        float grad10 = length(sobelFiter(float3x3(gray10, gray11, gray12, gray20, gray21, gray22, gray30, gray31, gray32)));
        float2 gradCenter = sobelFiter(float3x3(gray11, gray12, gray13, gray21, gray22, gray23, gray31, gray32, gray33));
        float grad11 = length(gradCenter);
        float grad12 = length(sobelFiter(float3x3(gray12, gray13, gray14, gray22, gray23, gray24, gray32, gray33, gray34)));
        float grad20 = length(sobelFiter(float3x3(gray20, gray21, gray22, gray30, gray31, gray32, gray40, gray41, gray42)));
        float grad21 = length(sobelFiter(float3x3(gray21, gray22, gray23, gray31, gray32, gray33, gray41, gray42, gray43)));
        float grad22 = length(sobelFiter(float3x3(gray22, gray23, gray24, gray32, gray33, gray34, gray42, gray43, gray44)));

        gradMag = float3x3(grad00, grad01, grad02, grad10, grad11, grad12, grad20, grad21, grad22);
        gradVec = normalize(gradCenter);
    }

    float edgeFilter(float3x3 gradMag, float2 gradVec)
    {
        float grad0 = lerp3x3(gradMag, gradVec);
        float grad1 = gradMag._m11;
        float grad2 = lerp3x3(gradMag, -gradVec);
        return smoothstep(-_Threshold, 0, grad1 - grad0) * smoothstep(-_Threshold, 0, grad1 - grad2) * grad1;
        //return step(grad0, grad1) * step(grad2, grad1) * grad1;
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
                float2 grabUv = i.grabPos.xy / i.grabPos.w;

                float4 grabColor = tex2D(_GrabTexture, grabUv);

                //勾配の強度、向き
                float3x3 gradM;
                float2 gradV;
                gradFilter(_GrabTexture, grabUv, _GrabTexture_TexelSize, gradM, gradV);
                //エッジ取得
                float edge = edgeFilter(gradM, gradV);

                float4 fragColor = float4(0, 0, 0, 1);
                fragColor.rgb = _BGColor.rgb * (1 - edge) + grabColor.rgb * edge;

                return fragColor;
            }
            ENDCG
        }
    }
}
