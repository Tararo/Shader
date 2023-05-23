# Shader
作ったシェーダーを置いている。  
※Clusterでは、GeometryShader、DepthTextureが使えない。  
___
各ディレクトリの説明
- [Art](#art)
- [CustomRenderTexture](#customrendertexture)
- [Filter](#filter)
- [FX](#fx)
- [Include](#include)
- [Material](#material)
- [RayMarching](#raymarching)
___
## Art
シェーダーアート
- Art_Boid
    - ボイドアルゴリズムのシミュレーション結果を平面で表示
    - Custom Render Texture使用
    - メッシュはQuadを想定
- Art_GameOfLife
    - ライフゲームを表示
    - Custom Render Texture使用
    - メッシュはQuadを想定
- Art_Network
    - パーティクルネットワーク
    - メッシュはQuadを想定
___
## CustomRenderTexture
カスタムレンダーテクスチャに関わるシェーダー
- CRT_show
    - カスタムレンダーテクスチャをUVで展開して表示
    - 表示はぼかしなし
- CRT_Boid_init
    - ボイドアルゴリズム用のカスタムレンダーテクスチャの初期化
    - 速度は0、位置はランダム
- CRT_Boid
    - ボイドアルゴリズム
    - カスタムレンダーテクスチャは、8x8, RGBA SFLOAT, DoubleBufferd
- CRT_GameOfLife_init
    - ライフゲーム用のカスタムレンダーテクスチャの初期化
    - ランダム
- CRT_GameOfLife
    - ライフゲーム
    - カスタムレンダーテクスチャは、RG UINT, DoubleBufferd
___
## Filter
オブジェクトの後ろの描画にフィルタをかける
- Filter_DepthScan
    - 視点から等距離な位置を表示（ソナー風）
    - DepthTexture使用
- Filter_DepthToWorld
    - ワールド座標を元に格子を表示
    - DepthTexture使用
- Filter_Edge
    - Canny法によるエッジ検出
- Filter_Glitch
    - UVシフト、グレイン追加、走査線の描画、カラーバランス調整
- Filter_PixelArt
    - 正方形の領域の中心（重み0.5）、四隅（重み0.125）をサンプリングして、色を取得
    - 4bit×RGB=12bitカラーに変換
- Filter_Screentone
    - 正方形の領域の中心の明度を白丸の大きさで表現
    - 明度は、グレイスケール化（ITU-R BT.601）して取得
___
## FX
- ParticleNet
    - GeometryShaderによる、シェーダーパーティクル
___
## Include
.cgincを作成予定
___
## Material
- DitheringTransparency
    - 距離に応じたディザ抜き
    - ディザのパターンはBayerMatrix
- Glass_CullOff
    - ガラス風のシェーダー
    - 処理順は、GrabPass -> 裏面描画 -> GrabPass -> 表面描画
- GridTexture
    - ワールド座標から模様を生成
- TriplanarMapping
    - ワールド空間のXYZ軸からの投影マッピングによるテクスチャ貼り付け
- UnlitColor
    - 単色Unlitなシェーダー
    - 半透明、IntensityによるEmissionが可能
___
## RayMarching
レイマーチング
- Cube_DistortionSphere
    - 半径にノイズを付加した球
    - メッシュはCubeを想定
- Cube_GlassCube
    - ガラス風の半透明な立方体
    - メッシュはCubeを想定
- Cube_MengerSponge
    - メンガーのスポンジ
    - 模様を平行移動
    - メッシュはCubeを想定
- Cube_MengerSponge_2
    - メンガーのスポンジ
    - 模様を拡大、縮小
    - メッシュはCubeを想定
- Quad_FlowSphere
    - 床、天井、球体
    - メッシュはQuadを想定
- Quad_GridWave
    - 立方体を敷き詰めている
    - メッシュはQuadを想定
- Quad_Hole
    - 四角の穴
    - TriplanarMappingの要領でテクスチャを展開
    - メッシュはQuadを想定
- Quad_MengerSponge
    - メンガーのスポンジ
    - メッシュはQuadを想定
- Quad_WrongCube
    - 視線ベクトルが反転したレイマーチング
    - メッシュはQuadを想定