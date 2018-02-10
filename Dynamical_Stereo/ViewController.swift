import UIKit
import MetalKit

var gDevice: MTLDevice!
let dynamical = Dynamical()

// used during development of rotated() layout routine to simulate other iPad sizes
//let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait 9.7, 10.5, 12.9" iPads
//let scrnIndex = 0
//let scrnLandscape:Bool = true

var paceRotate = CGPoint()
var pointSize:Float = 1
var pointSpread:Float = 0.2

var vc:ViewController! = nil

class ViewController: UIViewController {
    var rotateTimer = Timer()
    var renderer: Renderer!
    var sList:[SliderView]! = nil
    var dList:[DeltaView]! = nil
    var aOnOff:Bool = false
    @IBOutlet var mtkViewL: MTKView!
    @IBOutlet var mtkViewR: MTKView!
    @IBOutlet var formulaSeg: UISegmentedControl!
    @IBOutlet var autoOnOff: UISegmentedControl!
    @IBOutlet var paramXY: DeltaView!
    @IBOutlet var paramZ: SliderView!
    @IBOutlet var deltaXY: DeltaView!
    @IBOutlet var deltaZ: SliderView!
    @IBOutlet var color1XY: DeltaView!
    @IBOutlet var color1Z: SliderView!
    @IBOutlet var color2XY: DeltaView!
    @IBOutlet var color2Z: SliderView!
    @IBOutlet var ptSize: SliderView!
    @IBOutlet var ptSpread: SliderView!
    @IBOutlet var ptCount: SliderView!
    @IBOutlet var slButton: UIButton!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var resetButton: UIButton!
    
    @IBAction func onOffChanged(_ sender: UISegmentedControl) { aOnOff = sender.selectedSegmentIndex == 1 }
    
    @IBAction func resetPressed(_ sender: UIButton) {
        resetParams()
        updateWidgets()
    }
    
    @IBAction func formulaChanged(_ sender: UISegmentedControl) {
        control.formula = Int32(sender.selectedSegmentIndex)
        resetParams()
        updateWidgets()
    }
    
    var rendererL: Renderer!
    var rendererR: Renderer!
    
    override var prefersStatusBarHidden: Bool { return true }
    
    //MARK:-
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sList = [ paramZ,deltaZ,color1Z,color2Z,ptSize,ptSpread,ptCount ]
        dList = [ paramXY,deltaXY,color1XY,color2XY]
        
        gDevice = MTLCreateSystemDefaultDevice()
        mtkViewL.device = gDevice
        mtkViewR.device = gDevice
        
        guard let newRenderer = Renderer(metalKitView: mtkViewL, 0) else { fatalError("Renderer cannot be initialized") }
        rendererL = newRenderer
        rendererL.mtkView(mtkViewL, drawableSizeWillChange: mtkViewL.drawableSize)
        mtkViewL.delegate = rendererL
        
        guard let newRenderer2 = Renderer(metalKitView: mtkViewR, 1) else { fatalError("Renderer cannot be initialized") }
        rendererR = newRenderer2
        rendererR.mtkView(mtkViewR, drawableSizeWillChange: mtkViewR.drawableSize)
        mtkViewR.delegate = rendererR

        rotateTimer = Timer.scheduledTimer(timeInterval:0.01, target:self, selector: #selector(timerHandler), userInfo: nil, repeats:true)
        screenRotated()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        vc = self
        control.formula = 0
        pointSpread = 0.37
        resetParams()
        
        deltaXY.initializeFloat1(&control.delta0, 0,0.2, 0.02, "D 1,2")         // make delta controls less sensitive
        deltaXY.initializeFloat2(&control.delta1)
        deltaZ.initializeFloat(&control.delta2, .delta, 0,0.2, 0.02, "D 3")
        
        color1XY.initializeFloat1(&control.color1r, 0,1, 0.5, "C1")
        color1XY.initializeFloat2(&control.color1g)
        color1Z.initializeFloat(&control.color1b, .delta, 0,1, 0.5, "")
        color2XY.initializeFloat1(&control.color2r, 0,1, 0.5, "C2")
        color2XY.initializeFloat2(&control.color2g)
        color2Z.initializeFloat(&control.color2b, .delta, 0,1, 0.5, "")
        
        ptSize.initializeFloat(&pointSize, .delta, 1,15, 0.5, "Psize")
        ptSpread.initializeFloat(&pointSpread, .delta, 0.001,1, 0.02, "Pdelta")
        ptCount.initializeInt32(&control.ptCount, .delta, 50,500,50, "Pcount")

        updateWidgets()
        dynamical.initialize()
    }
    
    //MARK:-
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.screenRotated()
        }
    }
    
    @objc func screenRotated() {
        let xs:CGFloat = view.bounds.width
        let ys:CGFloat = view.bounds.height
        //let xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
        //let ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y
        
        let gap:CGFloat = 5
        let cxs:CGFloat = 140   // slider width
        let bys:CGFloat = 35    // slider height
        let fullWidth:CGFloat = 720
        let fullHeight:CGFloat = cxs + bys + 20
        let left:CGFloat = (xs - fullWidth)/2
        
        var ixs = (xs - 4) / 2
        if ixs + fullHeight > ys { ixs = ys - fullHeight - 4 }
        mtkViewL.frame = CGRect(x:xs/2 - ixs - 2, y:0, width:ixs, height:ixs)
        mtkViewR.frame = CGRect(x:xs/2 + 2, y:0, width:ixs, height:ixs)

        let by:CGFloat = ixs + 10  // widget top
        var y:CGFloat = by
        var x:CGFloat = left
        
        paramXY.frame = CGRect(x:x, y:y, width:cxs, height:cxs)
        paramZ.frame  = CGRect(x:x, y:y + cxs+gap, width:cxs, height:bys)
        x += cxs + gap
        deltaXY.frame = CGRect(x:x, y:y, width:cxs, height:cxs)
        deltaZ.frame  = CGRect(x:x, y:y + cxs+gap, width:cxs, height:bys)
        x += cxs + gap * 2
        
        // color (small) -----------
        let cw:CGFloat = 100
        let ch:CGFloat = cxs / 2.7
        var cy:CGFloat = y
        color1XY.frame = CGRect(x:x, y:cy, width:cw, height:ch);   cy += ch
        color1Z.frame  = CGRect(x:x, y:cy, width:cw, height:bys);  cy += bys + gap + 2
        color2XY.frame = CGRect(x:x, y:cy, width:cw, height:ch);   cy += ch
        color2Z.frame  = CGRect(x:x, y:cy, width:cw, height:bys)
        x += cw + gap * 2
        
        // point -------------------
        let pw:CGFloat = 150
        y = by
        ptSize.frame   = CGRect(x:x, y:y, width:pw, height:bys); y += bys + gap
        ptSpread.frame = CGRect(x:x, y:y, width:pw, height:bys); y += bys + gap
        ptCount.frame  = CGRect(x:x, y:y, width:pw, height:bys)

        x += pw + gap * 2
        y = by

        // formula -----------------
        let fw:CGFloat = 150
        formulaSeg.frame  = CGRect(x:x, y:y, width:fw, height:bys); y += bys + gap * 3
        let x2 = x + fw/2 - 20
        autoOnOff.frame  = CGRect(x:x, y:y, width:fw/2, height:bys)
        resetButton.frame  = CGRect(x:x2, y:y, width:fw, height:bys); y += 90
        slButton.frame  = CGRect(x:x, y:y, width:fw/2, height:bys)
        helpButton.frame  = CGRect(x:x2, y:y, width:fw, height:bys)
    }
    
    //MARK:-
    
    func updateWidgets() {
        var min:Float = 0
        var max:Float = 0
        
        switch control.formula {
        case 0 : min = 0;  max = 10
        case 1 : min = -2; max = 2
        case 2 : min = -2; max = 2
        case 3 : min = -1; max = 3
        case 4 : min = -2; max = 2
        case 5 : min = -2; max = 2
        default : break
        }
        
        let hop:Float = fabs(max - min) / 120.0 // less sensitive
        paramXY.initializeFloat1(&control.p0, min, max, hop, "P 1,2")
        paramXY.initializeFloat2(&control.p1)
        paramZ.initializeFloat(&control.p2, .delta, min,max, hop, "P 3")
        
        formulaSeg.selectedSegmentIndex = Int(control.formula)
        for s in sList { s.setNeedsDisplay() }
        for d in dList { d.setNeedsDisplay() }
    }
    
    //MARK:-
    
    func resetParams() {
        control.ptCount = 300
        
        switch control.formula {
        case 0 :
            pointSpread = 0.0125
            control.p0 = +3.5193
            control.p1 = +7.4715
            control.p2 = +4.1325
        case 1 :
            control.p0 = -0.0338
            control.p1 = +0.0401
            control.p2 = -0.0021
        case 2 :
            control.p0 = 0.1038
            control.p1 = 0.5117
            control.p2 = 0.5503
        case 3 :
            control.p0 = +0.9795
            control.p1 = +0.5270
            control.p2 = +0.0750
        case 4 :
            control.p0 = -0.0237
            control.p1 = -0.1149
            control.p2 = +0.4091
        case 5 :
            control.p0 = 0
            control.p1 = 0
            control.p2 = 0
        default : break
        }
    }
    
    //MARK:-
    
    var autoAngle:Float = 0
    
    @objc func timerHandler() {
        
        if aOnOff {
            control.p0 += sinf(autoAngle) / (100.0 / control.delta0)
            control.p1 += sinf(autoAngle) / (100.0 / control.delta1)
            control.p2 += sinf(autoAngle) / (100.0 / control.delta2)
            
            autoAngle += 0.001
            paramXY.setNeedsDisplay()
            paramZ.setNeedsDisplay()
        }
        
        for s in sList { _ = s.update() }
        for d in dList { _ = d.update() }
        
        rotate(paceRotate.x,paceRotate.y)
        dynamical.calcVertices()
    }
    
    //MARK:-
    
    func rotate(_ x:CGFloat, _ y:CGFloat) {
        let center:CGFloat = 300    // 0.5 x nib image size
        arcBall.mouseDown(CGPoint(x: center, y: center))
        arcBall.mouseMove(CGPoint(x: center + x, y: center + y))
    }
    
    func parseTranslation(_ pt:CGPoint) {
        let scale:Float = 0.05
        translation.x = Float(pt.x) * scale
        translation.y = -Float(pt.y) * scale
    }
    
    func parseRotation(_ pt:CGPoint) {
        let scale:CGFloat = 0.05
        paceRotate.x = pt.x * scale
        paceRotate.y = pt.y * scale
    }
    
    var numberPanTouches:Int = 0
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) {
        let pt = sender.translation(in: self.view)
        let count = sender.numberOfTouches
        if count == 0 { numberPanTouches = 0 }  else if count > numberPanTouches { numberPanTouches = count }
        
        switch sender.numberOfTouches {
        case 1 : if numberPanTouches < 2 { parseRotation(pt) } // prevent rotation after releasing translation
        case 2 : parseTranslation(pt)
        default : break
        }
    }
    
    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        let min:Float = 1       // close
        let max:Float = 1000    // far
        
        translation.z *= Float(1 + (1 - sender.scale) / 10 )
        if translation.z < min { translation.z = min }
        if translation.z > max { translation.z = max }
    }
    
    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
        paceRotate.x = 0
        paceRotate.y = 0
    }
}
