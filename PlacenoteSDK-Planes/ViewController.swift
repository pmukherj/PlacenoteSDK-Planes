/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import SceneKit
import ARKit
import os.log


class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, PNDelegate {

  
	// MARK: - IBOutlets
  @IBOutlet weak var sessionInfoView: UIView!
	@IBOutlet weak var sessionInfoLabel: UILabel!
	@IBOutlet weak var sceneView: ARSCNView!
  
  private var anchorSave: [Anchor] = []
  private var anchorIDs: [UUID] = []
  private var currMapID : String = ""
  private var anchorsLoaded: Bool = false
  private var planesDrawn: Bool = false
  
  private var localizing: Bool = false
  private var mapping: Bool = false
  private var arkitActive: Bool = false
  
  private var curMapID: String = ""
  private var camManager: CameraManager? = nil
  private var defaults: UserDefaults = UserDefaults.standard

  @IBOutlet var saveLoadButton: UIButton!
  
  //MARK - IBActions
  
  @IBAction func buttonClick(_ sender: Any) {
    
    if(anchorsLoaded) { //clear planes, clear out and delete map, start a new mapping session, start looking for planes again.
      anchorSave.removeAll()
      anchorIDs.removeAll()
      saveAnchors()
      clearPlanes()
      planesDrawn = false
      os_log("cleared anchors")
      saveLoadButton.setTitle("Save Map", for: .normal)
      anchorsLoaded = false
      LibPlacenote.instance.stopSession()
      LibPlacenote.instance.deleteMap(mapId: currMapID, deletedCb: {(deleted: Bool) -> Void in
        if (deleted) {
          print("Deleting: " + self.currMapID)
          self.defaults.removeObject(forKey: "MapID")
        }
        else {
          print ("Can't Delete: " + self.currMapID)
        }
      })
      localizing = false
      os_log("starting new session")
      mapping = true
      LibPlacenote.instance.startSession()
      
      let configuration = ARWorldTrackingConfiguration()
      configuration.planeDetection = .horizontal
      sceneView.session.run(configuration)
    }
    else { //savePlanes, stop mapping, save map, stop looking for planes.
      saveAnchors()
      saveLoadButton.setTitle("Clear Map", for: .normal)
      anchorsLoaded = true
      planesDrawn = true //session callbacks have already drawn the planes.
      
      LibPlacenote.instance.saveMap(
        savedCb: {(mapId: String?) -> Void in
          if (mapId != nil) {
            self.defaults.set(mapId, forKey: "MapID")
            self.mapping = false //we done mapping
            LibPlacenote.instance.stopSession()
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = []
            self.sceneView.session.run(configuration)
            
          } else {
            os_log("Failed to save map")
          }
          
      },
        uploadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
          //nothing to do here, because i dont care if the map is uploaded or not
      })
    }
  }
  
  
  // MARK: - View Life Cycle
  /// - Tag: StartARSession
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  
    guard ARWorldTrackingConfiguration.isSupported else {
        fatalError("""
            ARKit is not available on this device. For apps that require ARKit
            for core functionality, use the `arkit` key in the key in the
            `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
            the app from installing. (If the app can't be installed, this error
            can't be triggered in a production scenario.)
            In apps where AR is an additive feature, use `isSupported` to
            determine whether to show UI for launching AR experiences.
        """) // For details, see https://developer.apple.com/documentation/arkit
    }
    
    let configuration = ARWorldTrackingConfiguration()


    if (!loadMapAndAnchors()) {
      os_log ("No map or anchors found, looking for new planes")
      saveLoadButton.setTitle("Save Planes", for: .normal)
      anchorsLoaded = false
      mapping = true
      LibPlacenote.instance.startSession()
      configuration.planeDetection = .horizontal

    }
    else {
      os_log("Map and anchors loaded")
      saveLoadButton.setTitle("Clear Planes", for: .normal)
      configuration.planeDetection = []
    }
    
    /*
     Start the view's AR session with a configuration that uses the rear camera,
     device position and orientation tracking, and plane detection.
    */
    sceneView.session.run(configuration)
    sceneView.autoenablesDefaultLighting = true

    // Set a delegate to track the number of plane anchors for providing UI feedback.
    sceneView.session.delegate = self
  
    /*
     Prevent the screen from being dimmed after a while as users will likely
     have long periods of interaction without touching the screen or buttons.
    */
    UIApplication.shared.isIdleTimerDisabled = true
  
    // Show debug UI to view performance metrics (e.g. frames per second).
    sceneView.showsStatistics = true
    
    LibPlacenote.instance.multiDelegate += self
    
    if let camera: SCNNode = sceneView?.pointOfView {
      camManager = CameraManager(scene: sceneView.scene, cam: camera)
    }
  }
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Pause the view's AR session.
		sceneView.session.pause()
	}
	
	// MARK: - ARSCNViewDelegate
  /// - Tag: PlaceARContent
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    
    var c_anchor: Anchor
    let ind = getAnchorIndex(id: anchor.identifier)
    if (ind >= 0) { //anchor exists,
      print ("anchor already saved")
      c_anchor = anchorSave.remove(at: ind) //remove it for now, add it back after making necessary mods
      anchorIDs.remove(at: ind)
    }
    else {
     c_anchor = Anchor (tf:anchor.transform)
    }
    
    guard let planeAnchor = anchor as? ARPlaneAnchor else { //is it a plane?
      anchorSave.append(c_anchor) //save the anchor for later anyway
      anchorIDs.append(anchor.identifier)
      return
    }
    
    // Create a SceneKit plane to visualize the plane anchor using its position and extent.
    let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
    let planeNode = SCNNode(geometry: plane)
    planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
    planeNode.eulerAngles.x = -.pi / 2
    planeNode.opacity = 0.25
  
    let anchorPlane: Plane = Plane(height: planeAnchor.extent.z, width: planeAnchor.extent.x, center_x: planeAnchor.center.x, center_z: planeAnchor.center.z)!
    
    print ("adding plane @ " + String(planeAnchor.center.x) + "," + String(planeAnchor.center.z))
    c_anchor.planes.append(anchorPlane)
    anchorSave.append(c_anchor)
    anchorIDs.append(anchor.identifier)
    /*
     Add the plane visualization to the ARKit-managed node so that it tracks
     changes in the plane anchor as plane estimation continues.
     */
    node.addChildNode(planeNode)
    
    if (anchorIDs.count==1) { //this is the first anchor you've found
      addModel(anchor: anchor)
    }
  }

  
  
  
  /// - Tag: UpdateARContent
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
    guard let planeAnchor = anchor as?  ARPlaneAnchor,
        let planeNode = node.childNodes.first,
        let plane = planeNode.geometry as? SCNPlane
        else { return }
  
    
    
    // Plane estimation may shift the center of a plane relative to its anchor's transform.
    planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
  
    /*
     Plane estimation may extend the size of the plane, or combine previously detected
     planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
     corresponding node for one plane, then calls this method to update the size of
     the remaining plane.
    */
    os_log ("updating anchors")
    plane.width = CGFloat(planeAnchor.extent.x)
    plane.height = CGFloat(planeAnchor.extent.z)
    
    let ind: Int = getAnchorIndex(id: anchor.identifier)
    if (ind > -1) {
      let anchorPlane: Plane = Plane(height: planeAnchor.extent.z, width: planeAnchor.extent.x, center_x: planeAnchor.center.x, center_z: planeAnchor.center.z)!
      anchorSave[ind].planes[0] = anchorPlane
    }
  }
  

  // MARK: - ARSessionDelegate
  func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    guard let frame = session.currentFrame else { return }
    updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    
    print("Added " + String(anchors.count) + " anchor(s)")
    
    for anchor in anchors {
      anchorSave.append(Anchor(tf: anchor.transform))
      anchorIDs.append(anchor.identifier)
    }
  }

  func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
    guard let frame = session.currentFrame else { return }
    updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    
    print("Removed anchor")
    for anchor in anchors {
      let anchorInd = getAnchorIndex(id: anchor.identifier)
      anchorSave.remove(at: anchorInd)
      anchorIDs.remove(at: anchorInd)
    }
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
  }
  
  
  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    if (arkitActive && (mapping || localizing)) {
      os_log ("sending arframes!")
      let image: CVPixelBuffer = frame.capturedImage
      let pose: matrix_float4x4 = frame.camera.transform
      LibPlacenote.instance.setFrame(image: image, pose: pose)
    }
  }

    // MARK: - ARSessionObserver
	func sessionWasInterrupted(_ session: ARSession) {
		// Inform the user that the session has been interrupted, for example, by presenting an overlay.
		sessionInfoLabel.text = "Session was interrupted"
	}
	
	func sessionInterruptionEnded(_ session: ARSession) {
		// Reset tracking and/or remove existing anchors if consistent tracking is required.
		sessionInfoLabel.text = "Session interruption ended"
		resetTracking()
	}
    
    func session(_ session: ARSession, didFailWithError error: Error) {
      // Present an error message to the user.
      sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
      resetTracking()
  }

    // MARK: - Private methods

  private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
    // Update the UI to provide feedback on the state of the AR experience.
    var message: String = ""
    
    switch trackingState {
      case .normal where frame.anchors.isEmpty:
          // No planes detected; provide instructions for this app's AR interactions.
          message = "Move the device around to detect horizontal surfaces."
          arkitActive = true
      case .normal:
          // No feedback needed when tracking is normal and planes are visible.
          message = ""
          arkitActive = true
      case .notAvailable:
          message = "Tracking unavailable."
      
      case .limited(.excessiveMotion):
          message = "Tracking limited - Move the device more slowly."
      
      case .limited(.insufficientFeatures):
          message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
      
      case .limited(.initializing):
          message = "Initializing AR session."
    }

    sessionInfoLabel.text = message
    sessionInfoView.isHidden = message.isEmpty
  }

  private func resetTracking() {
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = .horizontal
    sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
  }
  
  private func getAnchorIndex(id: UUID) -> Int {
    var c_index: Int = 0
    for c_id in anchorIDs {
      if (c_id == id) {
        return c_index
      }
      c_index = c_index + 1
    }
    return -1
  }
  
  private func saveAnchors() {
    let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(anchorSave, toFile: Anchor.ArchiveURL.path)
    if isSuccessfulSave {
      os_log("Anchors Saved", log: OSLog.default, type: .debug)
    } else {
      os_log("Can't save Anchors", log: OSLog.default, type: .error)
    }
  }
  
  enum FileError : Error {
    case NoFileError(String)
  }
  
  private func loadAnchors() -> [Anchor]?  {
    var anchors : [Anchor] = []
    do {
      guard let readanchors : [Anchor] = try NSKeyedUnarchiver.unarchiveObject(withFile: Anchor.ArchiveURL.path) as? [Anchor] else { throw FileError.NoFileError("Archive not found") }
      anchors = readanchors
    }
    catch {
      os_log ("can't open file")
    }
    return anchors
  }
  
  private func renderPlanes() {
    for (index, c_anchor) in anchorSave.enumerated() {
      let anchor = ARAnchor(transform: c_anchor.transform.first!)
      anchorSave.append(c_anchor)
      anchorIDs.append(anchor.identifier)
      sceneView.session.add(anchor: anchor)
      if (index<1) { //first one
        addModel(anchor: anchor)
      }
      for c_pl in c_anchor.planes {
        let plane = SCNPlane(width: CGFloat(c_pl.width), height: CGFloat(c_pl.height))
        let planeNode = SCNNode(geometry: plane)
        var planetf = matrix_identity_float4x4
        
        print ("rendering @" + String (c_pl.center_x) + "," + String(c_pl.center_z))
        
        planetf.columns.3.x = c_pl.center_x
        planetf.columns.3.z = c_pl.center_z
        planetf = anchor.transform*planetf
        planeNode.transform = SCNMatrix4(planetf)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.opacity = 0.25
        sceneView.scene.rootNode.addChildNode(planeNode)
  
        
      }
    }
  }
  
  
  func addModel (anchor : ARAnchor) {
    let chairScene = SCNScene(named: "art.scnassets/rietvelt_chair.dae")
    let node = SCNNode()
    for child in (chairScene?.rootNode.childNodes)! {
      print ("added nodes")
      node.addChildNode(child)
    }
    
    print("added chair @ : " + String(describing: node.position))
    node.transform = SCNMatrix4(anchor.transform * simd_float4x4(node.transform))
    sceneView.scene.rootNode.addChildNode(node)
  }
  
  private func clearPlanes() {
    sceneView.scene.rootNode.enumerateChildNodes { (node, stop) -> Void in
      node.removeFromParentNode()
    }
  }
  
  private  func loadMapAndAnchors () -> Bool {
    
    guard let savedID = defaults.string(forKey: "MapID") else { return false }
    os_log ("Map Exists")
    currMapID = savedID
    anchorSave = loadAnchors()!
    guard anchorSave.count >= 0 else {return false}
    os_log ("Anchors are saved")
    
    DispatchQueue.global(qos: .background).async (execute: {() -> Void in
      while (!LibPlacenote.instance.initialized()) { //wait for it to initialize
        usleep(100);
      }
      LibPlacenote.instance.loadMap(mapId: self.currMapID, downloadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
        print("percentage:" + String(describing: percentage))
        if (completed) {
          os_log("Map load completed..localizing")
          self.anchorsLoaded = true
          self.localizing = true
          LibPlacenote.instance.startSession()
        }
      })
    })
    return true
  }
  
  
  func onPose(_ outputPose: matrix_float4x4, _ arkitPose: matrix_float4x4) {
    
  }
  
  func onStatusChange(_ prevStatus: LibPlacenote.MappingStatus, _ currStatus: LibPlacenote.MappingStatus) {
    if prevStatus != LibPlacenote.MappingStatus.running && currStatus == LibPlacenote.MappingStatus.running && !planesDrawn {
      os_log("Rendering Planes")
      clearPlanes() //clear planes if they are being drawn.
      renderPlanes()
      planesDrawn = true
    }
  }
  
  
  
  
}
