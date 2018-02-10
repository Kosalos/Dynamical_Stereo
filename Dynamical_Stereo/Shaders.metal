#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

float cheb(float v) { return 4 * pow(v,3) - 3 * v; }

kernel void dynShader
(
 constant DynPt     *dyn      [[buffer(0)]],
 device atomic_uint &counter  [[buffer(1)]],
 constant Control   &control  [[buffer(2)]],
 device TVertex     *vertices [[buffer(3)]],
 uint p [[thread_position_in_grid]])
{
    float3 pt,old = dyn[p].pos;

    for(int i = 0; i < 50 + control.ptCount; ++i) {
        switch(control.formula) {
            case 0 :
                pt.x = old.x + 0.02 * (-control.p0 * old.x - old.y * old.y - old.z * old.z + control.p0 * control.p2);
                pt.y = old.y + 0.02 * (-old.y + old.x * old.y - control.p1 * old.x * old.z + control.p2);
                pt.z = old.z + 0.02 * (-old.z + control.p1 * old.x * old.y + old.x * old.z);
                break;
            case 1 :
                pt.x = old.x + sin(cheb(old.y)) * control.p0;
                pt.y = old.y + sin(cheb(old.x)) * control.p1;
                pt.z = (old.x * old.y) * control.p2;
                break;
            case 2 :
                pt.x = old.y + control.p0 * old.z;
                pt.y = control.p1 / old.y + control.p2 * old.y - old.x;
                pt.z = old.x * old.x / 20.0 - control.p0 * old.y * old.x;
                break;
            case 3 :
                pt.x = old.x + 0.2 * (-control.p0 * old.x - old.y * old.y - old.z * old.z + control.p0);
                pt.y = old.y + 0.2 * (old.y + old.x * old.y -control.p1 * old.x * old.z + control.p2);
                pt.z = old.z + 0.2 * (-old.z + control.p1 * old.x * old.y + old.x * old.z);
                break;
            case 4 :
                pt.x = control.p0 * old.x - old.y * control.p2;
                pt.y = -(control.p1 / old.y - old.y * control.p2) / old.x;
                pt.z = -(control.p1 / old.x - old.y * control.p2) / (old.x * old.y);
                break;
            case 5 :
                pt.x = old.x + 0.031 * sin(cheb(old.y + old.z)) * control.p0;
                pt.y = old.y + 0.031 * sin(cheb(old.x + old.z)) * control.p1;
                pt.z = old.z + 0.31 * sin(old.x + old.y) * control.p2;
                break;
        }

        old = pt;
        
        if(i > 50) {    // skip until attractor has settled down
            uint index = atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
            if(index >= VMAX) return;
            
            device TVertex &v = vertices[index];
            v.pos = pt;
            
            float ratio = float(i) / 50.0;
            float cr = control.color1r + (control.color2r - control.color1r) * ratio;
            float cg = control.color1g + (control.color2g - control.color1g) * ratio;
            float cb = control.color1b + (control.color2b - control.color1b) * ratio;
            v.color = float4(cr,cg,cb,1);
        }
    }
}

//===================================================================================

struct Transfer {
    float4 position [[position]];
    float pointsize [[point_size]];
    float4 color;
};

vertex Transfer texturedVertexShader
(
 constant TVertex *data[[ buffer(0) ]],
 constant Uniforms &uniforms[[ buffer(1) ]],
 unsigned int vid [[ vertex_id ]])
{
    TVertex in = data[vid];
    Transfer out;
    
    out.pointsize = uniforms.pointSize;
    out.color = in.color;
    out.position = uniforms.mvp * float4(in.pos, 1.0);
    return out;
}

fragment float4 texturedFragmentShader
(
 Transfer in [[stage_in]],
 texture2d<float> tex2D [[texture(0)]],
 sampler sampler2D [[sampler(0)]])
{
    return in.color;
}
















