#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 genie(float2 position, float4 rect, float2 target, float progress) {
    float x0 = rect.x;
    float y0 = rect.y;
    float w = rect.z;
    float h = rect.w;
    float span = max(target.y - y0, 1.0);

    float bend = smoothstep(0.0, 0.5, progress);
    float slide = smoothstep(0.28, 1.0, progress);
    float shift = slide * span;

    float t = clamp((position.y - y0) / span, 0.0, 1.0);
    float curve = bend * (t * t * (3.0 - 2.0 * t));
    float tip = 8.0;
    float left = mix(x0, target.x - tip * 0.5, curve);
    float right = mix(x0 + w, target.x + tip * 0.5, curve);
    float u = (position.x - left) / max(right - left, 0.001);
    float sourceY = position.y - shift;

    if (u < 0.0 || u > 1.0 || sourceY < y0 || sourceY > y0 + h || position.y > target.y) {
        return float2(-100000.0, -100000.0);
    }
    return float2(x0 + u * w, sourceY);
}

[[ stitchable ]] half4 goo(float2 position, SwiftUI::Layer layer, float threshold, float softness, half4 fill) {
    half4 sample = layer.sample(position);
    float alpha = smoothstep(threshold - softness, threshold + softness, float(sample.a));
    return half4(fill.rgb * fill.a * alpha, fill.a * alpha);
}
