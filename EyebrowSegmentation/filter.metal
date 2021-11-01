#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h> // includes CIKernelMetalLib.h

extern "C" { namespace coreimage {
#define BIN_NUM 21

    struct bin_t {
        int index;
        int count;
    };
    
    float4 getEyebrowMatte(sampler src, sampler bkg,
                                   float p1x, float p1y,
                                   float p2x, float p2y,
                                   float p3x, float p3y,
                                   float p4x, float p4y,
                                   float p5x, float p5y,
                                   float p6x, float p6y,
                                   float p7x, float p7y,
                                   float p8x, float p8y,
                                   float p9x, float p9y,
                                   float p10x, float p10y,
                                   float p11x, float p11y,
                                   float p12x, float p12y
                                   ) {
        float2 poly[13];
        poly[0] = float2(p1x, p1y);
        poly[1] = float2(p2x, p2y);
        poly[2] = float2(p3x, p3y);
        poly[3] = float2(p4x, p4y);
        poly[4] = float2(p5x, p5y);
        poly[5] = float2(p6x, p6y);
        poly[6] = float2(p7x, p7y);
        poly[7] = float2(p8x, p8y);
        poly[8] = float2(p9x, p9y);
        poly[9] = float2(p10x, p10y);
        poly[10] = float2(p11x, p11y);
        poly[11] = float2(p12x, p12y);
        poly[12] = float2(p1x, p1y);
        float2 point;
        float2 normed_point;
        float vt;
        int i;
        int cross = 0;
        float4 color;
        float3 rgb;
        
        // 該当ピクセルの座標を正規化された形で取得する
        normed_point = src.coord();
        // 正規化されたピクセルを眉のランドマーク座標と比較するために画像のサイズ倍する
        // CoreImageとMetalで座標系が違うので、Xと(1 - Y)、Yと(1-X)で置換する必要がある
        point = float2((1 - normed_point.y) * src.size().x, (1 - normed_point.x) * src.size().y);
        
        // 該当ピクセルの内外判定
        for (i = 0; i < 12; i++) {
            if ( (poly[i].y <= point.y && poly[i+1].y > point.y) || (poly[i].y > point.y && poly[i+1].y <= point.y) ) {
                vt = (point.y - poly[i].y) / (poly[i+1].y - poly[i].y);
                
                if ( point.x < (poly[i].x + vt * (poly[i+1].x - poly[i].x)) ) {
                    cross++;
                }
            }
        }
        if (cross % 2 == 1) {
            // 交差回数が奇数＝該当ピクセルがランドマークの内側の場合、髮と肌のMatteを合算・反転して返す
            // (眉のランドマーク内の髮でも肌でもない領域＝眉の領域)
            
            if (src.sample(normed_point).r + bkg.sample(normed_point).r > 1.0) {
                color = float4(0, 0, 0, 1);
            } else {
                rgb = float3(1, 1, 1) - (src.sample(normed_point).rgb + bkg.sample(normed_point).rgb);
                color = float4(rgb, 1);
            }
        } else {
            // 交差回数が偶数の場合、ランドマークの外側なので黒を返す
            color = float4(0, 0, 0, 1);
        }

        return color;
    }

    float4 getEyebrowMatte11P(sampler src, sampler bkg,
                                   float p1x, float p1y,
                                   float p2x, float p2y,
                                   float p3x, float p3y,
                                   float p4x, float p4y,
                                   float p5x, float p5y,
                                   float p6x, float p6y,
                                   float p7x, float p7y,
                                   float p8x, float p8y,
                                   float p9x, float p9y,
                                   float p10x, float p10y,
                                   float p11x, float p11y
                                   ) {
        float2 poly[12];
        poly[0] = float2(p1x, p1y);
        poly[1] = float2(p2x, p2y);
        poly[2] = float2(p3x, p3y);
        poly[3] = float2(p4x, p4y);
        poly[4] = float2(p5x, p5y);
        poly[5] = float2(p6x, p6y);
        poly[6] = float2(p7x, p7y);
        poly[7] = float2(p8x, p8y);
        poly[8] = float2(p9x, p9y);
        poly[9] = float2(p10x, p10y);
        poly[10] = float2(p11x, p11y);
        poly[11] = float2(p1x, p1y);
        float2 point;
        float2 normed_point;
        float vt;
        int i;
        int cross = 0;
        float4 color;
        float3 rgb;
        
        // 該当ピクセルの座標を正規化された形で取得する
        normed_point = src.coord();
        // 正規化されたピクセルを眉のランドマーク座標と比較するために画像のサイズ倍する
        // CoreImageとMetalで座標系が違うので、Xと(1 - Y)、Yと(1-X)で置換する必要がある
        point = float2((1 - normed_point.y) * src.size().x, (1 - normed_point.x) * src.size().y);
        
        // 該当ピクセルの内外判定
        for (i = 0; i < 11; i++) {
            if ( (poly[i].y <= point.y && poly[i+1].y > point.y) || (poly[i].y > point.y && poly[i+1].y <= point.y) ) {
                vt = (point.y - poly[i].y) / (poly[i+1].y - poly[i].y);
                
                if ( point.x < (poly[i].x + vt * (poly[i+1].x - poly[i].x)) ) {
                    cross++;
                }
            }
        }
        if (cross % 2 == 1) {
            // 交差回数が奇数＝該当ピクセルがランドマークの内側の場合、髮と肌のMatteを合算・反転して返す
            // (眉のランドマーク内の髮でも肌でもない領域＝眉の領域)
            
            if (src.sample(normed_point).r + bkg.sample(normed_point).r > 1.0) {
                color = float4(0, 0, 0, 1);
            } else {
                rgb = float3(1, 1, 1) - (src.sample(normed_point).rgb + bkg.sample(normed_point).rgb);
                color = float4(rgb, 1);
            }
        } else {
            // 交差回数が偶数の場合、ランドマークの外側なので黒を返す
            color = float4(0, 0, 0, 1);
        }

        return color;
    }
    
    float4 getEyebrowMatte10P(sampler src, sampler bkg,
                                   float p1x, float p1y,
                                   float p2x, float p2y,
                                   float p3x, float p3y,
                                   float p4x, float p4y,
                                   float p5x, float p5y,
                                   float p6x, float p6y,
                                   float p7x, float p7y,
                                   float p8x, float p8y,
                                   float p9x, float p9y,
                                   float p10x, float p10y
                                   ) {
        float2 poly[11];
        poly[0] = float2(p1x, p1y);
        poly[1] = float2(p2x, p2y);
        poly[2] = float2(p3x, p3y);
        poly[3] = float2(p4x, p4y);
        poly[4] = float2(p5x, p5y);
        poly[5] = float2(p6x, p6y);
        poly[6] = float2(p7x, p7y);
        poly[7] = float2(p8x, p8y);
        poly[8] = float2(p9x, p9y);
        poly[9] = float2(p10x, p10y);
        poly[10] = float2(p1x, p1y);
        float2 point;
        float2 normed_point;
        float vt;
        int i;
        int cross = 0;
        float4 color;
        float3 rgb;
        
        // 該当ピクセルの座標を正規化された形で取得する
        normed_point = src.coord();
        // 正規化されたピクセルを眉のランドマーク座標と比較するために画像のサイズ倍する
        // CoreImageとMetalで座標系が違うので、Xと(1 - Y)、Yと(1-X)で置換する必要がある
        point = float2((1 - normed_point.y) * src.size().x, (1 - normed_point.x) * src.size().y);
        
        // 該当ピクセルの内外判定
        for (i = 0; i < 10; i++) {
            if ( (poly[i].y <= point.y && poly[i+1].y > point.y) || (poly[i].y > point.y && poly[i+1].y <= point.y) ) {
                vt = (point.y - poly[i].y) / (poly[i+1].y - poly[i].y);
                
                if ( point.x < (poly[i].x + vt * (poly[i+1].x - poly[i].x)) ) {
                    cross++;
                }
            }
        }
        if (cross % 2 == 1) {
            // 交差回数が奇数＝該当ピクセルがランドマークの内側の場合、髮と肌のMatteを合算・反転して返す
            // (眉のランドマーク内の髮でも肌でもない領域＝眉の領域)
            
            if (src.sample(normed_point).r + bkg.sample(normed_point).r > 1.0) {
                color = float4(0, 0, 0, 1);
            } else {
                rgb = float3(1, 1, 1) - (src.sample(normed_point).rgb + bkg.sample(normed_point).rgb);
                color = float4(rgb, 1);
            }
        } else {
            // 交差回数が偶数の場合、ランドマークの外側なので黒を返す
            color = float4(0, 0, 0, 1);
        }

        return color;
    }

    float4 minMaxModeLightness(sampler src) {
        float2 p0;
        float2 p;
        float4 color;
        float lightness;
        int index;
        int histogram[BIN_NUM] = {};
        int modeIndex;
        float minLightness, maxLightness, modeLightness;
        float4 lightnessInfo;
        
        maxLightness = 0.0;
        minLightness = 1.0;
        
        // 画像の各ピクセルの明度を計算して該当ビンをカウント
        for (int x = 0; x <= src.size().x; x++) {
            for (int y = 0; y <= src.size().y; y++) {
                p0 = float2(x, y);
                p = src.transform(p0);
                color = src.sample(p).rgba;
                
                if (color.a == 0.0) {
                    // 非髪領域（アルファ値0）は無視
                    continue;
                } else if ( color.a <= 0.05 && max3(color.r, color.g, color.b) <= 0.05 ) {
                    // 非髪領域（アルファ値0）と髪領域の中間に位置する領域（写真を切り取ると黒になる）がかなり多いので無視
                    continue;
                }
                
                // 明度を計算
                lightness = ( max3(color.r, color.g, color.b) + min3(color.r, color.g, color.b) ) / 2;
                // 明度から該当ビンのインデックスを計算
                index = int( floor( lightness * (BIN_NUM - 1) ) );
                histogram[index]++;
                
                if (lightness > maxLightness) {
                    maxLightness = lightness;
                }
                if (lightness < minLightness) {
                    minLightness = lightness;
                }
            }
        }
        
        // 最頻のビンを計算（カウントが同数の場合は便宜的にインデックスが小さい方）
        modeIndex = 0;
        for (int i = modeIndex + 1; i < BIN_NUM; i++) {
            if (histogram[modeIndex] < histogram[i]) {
                modeIndex = i;
            }
        }
        
        // 最頻値から明度を逆算
        modeLightness = float(modeIndex) / (BIN_NUM - 1);
        
        // 各明度で色を構成
        lightnessInfo = float4(minLightness, modeLightness, maxLightness, 1.0);
        return lightnessInfo;
    }
    
    float4 simpleSubtraction(sample_t input, sample_t bkg) {
        float3 color;
        color = input.rgb - bkg.rgb;
        return float4(color, input.a);
    }

}}
