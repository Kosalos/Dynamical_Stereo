#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#define VMAX (int((255000000 / sizeof(TVertex)) - 10000))

typedef struct {
    vector_float3 pos;
} DynPt;

typedef struct {
    int formula;
    float p0,p1,p2;
    float delta0,delta1,delta2;
    float color1r,color1g,color1b;
    float color2r,color2g,color2b;
    int ptCount;
} Control;

typedef struct {
    int count;
} Counter;

typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float4x4 mvp;
    vector_float3 light;
    float pointSize;
} Uniforms;

typedef struct {
    vector_float3 pos;
    vector_float4 color;
} TVertex;

#endif /* ShaderTypes_h */

