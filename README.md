# Shader
作ったシェーダーを置いている。
___
## Art
シェーダーアート
- Art_Boid
    - ボイドアルゴリズムのシミュレーション結果を平面で表示
    - Custom Render Texture使用
    - Quadを想定
- Art_GameOfLife
    - ライフゲームを表示
    - Custom Render Texture使用
    - Quadを想定
- Art_Network
    - パーティクルネットワーク
    - Quadを想定
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