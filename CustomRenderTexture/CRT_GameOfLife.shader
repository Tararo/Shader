Shader "Hidden/CRT_GameOfLife"
{
    Properties
    {

    }

    CGINCLUDE
        #include "UnityCustomRenderTexture.cginc"

        // フラグメントシェーダー(更新)
        float4 UpdateFrag(v2f_customrendertexture i) : SV_Target
        {
            float2 uv = i.globalTexcoord;

            //1pxあたりの単位を計算する
            float du = 1.0 / _CustomRenderTextureWidth;
            float dv = 1.0 / _CustomRenderTextureHeight;

            //現在の位置の座標index(xy)を算出
            float2 index = floor(float2(uv.x / du, uv.y / dv));

            //セル取得
            float2 cuv = (index + 0.5) * float2(du, dv);
            //中心
            int cellC = tex2D(_SelfTexture2D, cuv);
            //隣接の生存数
            int cellN = 0;
            for(int y = 0; y < 3; y++)
            {
                for(int x = 0; x < 3; x++)
                {
                    float2 nuv = cuv + float2(x - 1, y - 1) * float2(du, dv);
                    cellN += tex2D(_SelfTexture2D, nuv);
                }
            }
            cellN -= cellC;

            //生死判定
            //死→生
            int cellLive = (1 - cellC) * step(cellN, 3.1) * (1 - step(cellN, 2.9));
            //生→死
            int cellDead = cellC * step(cellN, 3.1) * (1 - step(cellN, 1.1));

            //次のセル
            int cellNew = cellLive + cellDead;

            // 書き込み
            return float4(cellNew,0,0,1);
        }
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Update"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment UpdateFrag
            ENDCG
        }
    }
}