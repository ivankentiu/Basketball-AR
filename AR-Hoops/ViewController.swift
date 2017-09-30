//
//  ViewController.swift
//  AR-Hoops
//
//  Created by Ivan Ken Tiu on 30/09/2017.
//  Copyright © 2017 FinalShift Inc. All rights reserved.
//

import UIKit
import ARKit
import Each

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var planeDetected: UILabel!
    
    let configuration = ARWorldTrackingConfiguration()
    var power: Float = 1.0
    let timer = Each(0.05).seconds
    // checks if there is a basketball net in sceneView
    var basketAdded: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        self.sceneView.session.run(configuration)
        self.sceneView.automaticallyUpdatesLighting = true
        self.configuration.planeDetection = .horizontal
        self.sceneView.delegate = self
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.cancelsTouchesInView = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.basketAdded == true {
            timer.perform(closure: { () -> NextStep in
                self.power += 1
                return .continue
            })
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.basketAdded == true {
            self.timer.stop()
            self.shootBall()
        }
        // reset power
        self.power = 1
    }
    
    func shootBall() {
        guard let pointOfView = sceneView.pointOfView else { return }
        self.removeEveryOtherBall()
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let cameraPosition = orientation + location
        let ball = SCNNode(geometry: SCNSphere(radius: 0.25))
        ball.geometry?.firstMaterial?.diffuse.contents = #imageLiteral(resourceName: "ball")
        ball.position = cameraPosition
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
        ball.physicsBody = body
        ball.name = "Basketball"
        body.restitution = 0.2
        ball.physicsBody?.applyForce(SCNVector3(orientation.x * power, orientation.y * power, orientation.z * power), asImpulse: true) // asImpulse accelerate immediately
        self.sceneView.scene.rootNode.addChildNode(ball)
    }

    @objc func handleTap(sender: UITapGestureRecognizer) {
        guard let sceneView = sender.view as? ARSCNView else { return }
        let touchLocation = sender.location(in: sceneView)
        let hitTestResult = sceneView.hitTest(touchLocation, types: .existingPlaneUsingExtent)
        if !hitTestResult.isEmpty {
            self.addBasket(hitTestResult: hitTestResult.first!)
        }
    }
    
    func addBasket(hitTestResult: ARHitTestResult) {
        if basketAdded == false {
            let basketScene = SCNScene(named: "Basketball.scnassets/Basketball.scn")
            let basketNode = basketScene?.rootNode.childNode(withName: "Basket", recursively: false)
            let positionOfPlane = hitTestResult.worldTransform.columns.3
            let xPosition = positionOfPlane.x
            let yPosition = positionOfPlane.y
            let zPosition = positionOfPlane.z
            basketNode?.position = SCNVector3(xPosition, yPosition, zPosition)
            basketNode?.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: basketNode!, options: [SCNPhysicsShape.Option.keepAsCompound: true, SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
            if let basketNodeTest = basketNode {
                self.sceneView.scene.rootNode.addChildNode(basketNodeTest)
            } else {
                print("no basket found")
            }
            // so not add court and ball at same time!
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.basketAdded = true
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.planeDetected.isHidden = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.planeDetected.isHidden = true
        }
    }
    
    func removeEveryOtherBall() {
        self.sceneView.scene.rootNode.enumerateChildNodes { (node,_) in
            if node.name == "Basketball" {
                node.removeFromParentNode()
            }
        }
    }
    
    // when ViewController Deinitializes (just reference since we only have one so it never deinitializes!
    deinit {
        self.timer.stop()
    }

}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}
