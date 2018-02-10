import UIKit
import Metal
import simd

extension TVertex {
    init(_ p:float3) {
        pos = p
        color = float4(1,1,1,1)
    }
}

extension Control {
    init() {
        formula = 0
        p0 = 0;  p1 = 0;  p2 = 0
        delta0 = 0; delta1 = 0; delta2 = 0
        color1r = 1;  color1g = 1;  color1b = 1
        color2r = 1;  color2g = 1;  color2b = 1
    }
}

let DWIDTH:Int = 15  // source points are an 3D cloud this wide
let DCOUNT:Int = DWIDTH * DWIDTH * DWIDTH    // #points in grid

let threadGroupCount = MTLSizeMake(20,1,1)
let threadGroups: MTLSize = MTLSizeMake(DCOUNT / threadGroupCount.width, 1,1)

let Vmax = (255000000 / MemoryLayout<TVertex>.stride) - 10000
var vCount:Int = 0
var control = Control()

class Dynamical {
    var pipeLineVertices:MTLComputePipelineState! = nil
    var commandQueue:MTLCommandQueue! = nil

    var dyn = Array(repeating:DynPt(), count:Int(DCOUNT))
    var vBuffer:MTLBuffer! = nil    // vertices for render
    var dBuffer:MTLBuffer! = nil    // input dyn points
    var cBuffer:MTLBuffer! = nil    // control
    var zBuffer:MTLBuffer! = nil    // vertex count
    
    let vSize:Int = MemoryLayout<TVertex>.stride * Vmax
    let dSize:Int = MemoryLayout<DynPt>.stride * Int(DCOUNT)
    let cSize:Int = MemoryLayout<Control>.stride
    let zSize:Int = MemoryLayout<Counter>.stride
    
    init() {
        reset()
    }
    
    func reset() {
        var index:Int = 0
        let scale:Float = 0.08
        for x in 0 ..< DWIDTH {
            let px = Float(x - DWIDTH/2) * scale
            for y in 0 ..< DWIDTH {
                let py = Float(y - DWIDTH/2) * scale
                for z in 0 ..< DWIDTH {
                    let pz = Float(z - DWIDTH/2) * scale
                    dyn[index].pos.x = px
                    dyn[index].pos.y = py
                    dyn[index].pos.z = pz
                
                    index += 1
                }
            }
        }
    }

    func initialize() {
        commandQueue = gDevice.makeCommandQueue()
        
        vBuffer = gDevice.makeBuffer(length: vSize, options:[MTLResourceOptions.storageModeShared])
        dBuffer = gDevice.makeBuffer(length: dSize, options:[MTLResourceOptions.storageModeShared])
        cBuffer = gDevice.makeBuffer(length: cSize, options:[MTLResourceOptions.storageModeShared])
        zBuffer = gDevice.makeBuffer(length: zSize, options:MTLResourceOptions.storageModeShared)

        func makePipeline(_ name:String) -> MTLComputePipelineState {
            let defaultLibrary = gDevice.makeDefaultLibrary()
            guard let f = defaultLibrary!.makeFunction(name: name) else { fatalError("Error attaching shader: " + name) }
            
            do {
                return try gDevice.makeComputePipelineState(function: f)
            }
            catch { fatalError("Error making pipline to: " + name) }
        }
        

        pipeLineVertices = makePipeline("dynShader")
    }
    
    //MARK:-

    func calcVertices() {
        if dBuffer == nil { return }
        
        memset(zBuffer.contents(),0,zSize)
        dBuffer.contents().copyBytes(from: &dyn, count:dSize)
        cBuffer.contents().copyBytes(from: &control, count:cSize)

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeLineVertices)
        commandEncoder.setBuffer(dBuffer,   offset: 0, index: 0)
        commandEncoder.setBuffer(zBuffer,   offset: 0, index: 1)
        commandEncoder.setBuffer(cBuffer,   offset: 0, index: 2)
        commandEncoder.setBuffer(vBuffer,   offset: 0, index: 3)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        var result = Counter()
        memcpy(&result,zBuffer.contents(),MemoryLayout<Counter>.stride)
        vCount = Int(result.count)
    }
    
    //MARK:-
    
    func render(_ renderEncoder:MTLRenderCommandEncoder) {
        if vCount > 0 {
            renderEncoder.setVertexBuffer(vBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount:vCount)
        }
    }
}
