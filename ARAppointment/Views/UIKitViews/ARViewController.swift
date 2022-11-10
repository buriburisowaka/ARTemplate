//
//  ARViewController.swift
//  ARAppointment
//
//  Created by burisowa on 2022/10/11.
//

import UIKit
import RealityKit
import ARKit
import Combine
import ARCore

class ARViewController: UIViewController {
    
    private var arView: ARView!
    
    private var locationManager: CLLocationManager!
    
    private var garSession: GARSession!
    
    private var garFrame: GARFrame!
    
    private var localizationState: LocalizationState!
    
    private var markerEntitys: [UUID:AnchorEntity] = [:]
    
    private var lastStartLocalizationDate: Date!
    
    private var trackingLabel: UILabel!
    private var statusLabel: UILabel!
    private var addAnchorButton: UIButton!
    private var addTerrainAnchorButton: UIButton!
    private var clearAllAnchorsButton: UIButton!
    
    enum LocalizationState:Int {
        case LocalizationStatePretracking = 0
        case LocalizationStateLocalizing = 1
        case LocalizationStateLocalized = 2
        case LocalizationStateFailed = 3
    }
    
    private let kHorizontalAccuracyLowThreshold: CLLocationAccuracy = 10
    private let kHorizontalAccuracyHighThreshold: CLLocationAccuracy = 20
    private let kHeadingAccuracyLowThreshold: CLLocationDirectionAccuracy = 15
    private let kHeadingAccuracyHighThreshold: CLLocationDirectionAccuracy = 25
    
    private let kLocalizationFailureTime = 3 * 60.0
    private let kDurationNoTerrainAnchorResult = 10
    private let kFontSize = 14.0
    private let kGeospatialTransformFormat = "LAT/LONG: %.6f°, %.6f°\n    horizontal ACCURACY: %.2fm\nALTITUDE: %.2fm\n    vertical ACCURACY: %.2fm    \nHEADING: %.1f°\n    heading ACCURACY: %.1f°"
    
    private let kLocalizationTip = "Point your camera at buildings, stores, and signs near you."
    private let kLocalizationFailureMessage = "Localization not possible.\nClose and open the app to restart."
    
    private let kSavedAnchorsUserDefaultsKey = "anchors"
    
    weak var delegate: ARViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView = ARView()
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)
        
        let font = UIFont.systemFont(ofSize: kFontSize)
        
        trackingLabel = UILabel()
        trackingLabel.translatesAutoresizingMaskIntoConstraints = false
        trackingLabel.font = font
        trackingLabel.textColor = UIColor.white
        trackingLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        trackingLabel.numberOfLines = 6
        arView.addSubview(trackingLabel)
        
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = font
        statusLabel.textColor = UIColor.white
        statusLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        statusLabel.numberOfLines = 2
        arView.addSubview(statusLabel)
        
        arView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        arView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        arView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        arView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        trackingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        trackingLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        trackingLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        trackingLabel.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        statusLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        statusLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        statusLabel.heightAnchor.constraint(equalToConstant: 160).isActive = true
        
        delegate?.test(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        // AR Session Start
        initializeARView()
        
    }
    
    func initializeARView() {
        arView.automaticallyConfigureSession = false
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.session.delegate = self
        runARSession()
    }
    
    func runARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = .horizontal
        arView.session.run(configuration)
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }
    
    func checkLocationPermission() {
        let auth = locationManager.authorizationStatus
        switch auth {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedAlways, .authorizedWhenInUse:
            if locationManager.accuracyAuthorization != .fullAccuracy {
                return
            }
            setUpGARSession()
        default:
            break
        }
    }
    
    func setUpGARSession() {
        guard garSession == nil else {
            return
        }
        
        do {
            try garSession = GARSession(apiKey: "AIzaSyD9o0S1BxPMUFWo3wfGSLO6XwnfKP355QI",
                                        bundleIdentifier: nil)
            
            localizationState = .LocalizationStateFailed
            
            if !garSession.isGeospatialModeSupported(.enabled) {
                print("GARGeospatialModeEnabled is not supported on this device.")
                return
            }
            
            let configuration = GARSessionConfiguration()
            configuration.geospatialMode = .enabled
            
            var error: NSError?
            garSession.setConfiguration(configuration, error: &error)
            if error != nil {
                print(String(format: "Failed to configure GARSession: %d", error!.code))
                return
            }
            localizationState = .LocalizationStatePretracking
            lastStartLocalizationDate = Date()
            
            let angle = Float((.pi / 180) * (180.0 - 0))
            let eastUpSouthQAnchor = simd_quaternion(angle, simd_float3(0.0, 1.0, 0.0))
            
            // テスト的に入れてみる
            do {
                // 自宅の２階
                let coordinate = CLLocationCoordinate2DMake(36.091526,
                                                            136.211851)
                try garSession.createAnchorOnTerrain(coordinate: coordinate,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                var road = CLLocationCoordinate2DMake(36.091646,
                                                      136.211851)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.091746,
                                                  136.211871)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.091546,
                                                  136.211991)
                
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.091036998747754,
                                                      136.21232830211474)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                road = CLLocationCoordinate2DMake(36.090847899948365,
                                                  136.21234466638938)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.09075137821728,
                                                  136.21235509493152)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.09066860395898,
                                                  136.21236392532487)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.09052160807854,
                                                  136.21237628787557)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.09044882360882,
                                                  136.21238335219024)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.09038037742378,
                                                  136.21239069997162)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.063722573861256,
                                                  136.2196679790896)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.06345762369818,
                                                  136.2187887474407)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.06370154610312,
                                                  136.2195379152362)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
                
                road = CLLocationCoordinate2DMake(36.063487062649266,
                                                  136.21895522917302)
                try garSession.createAnchorOnTerrain(coordinate: road,
                                                     altitudeAboveTerrain: 0,
                                                     eastUpSouthQAnchor: eastUpSouthQAnchor)
            } catch let error  {
                let nsError = error as NSError
                print(String(format: "Error oooooooooooo %@", nsError.localizedDescription))
                return
            }
            
        } catch {
            // エラーが発生した場合の処理
            let nsError = error as NSError
            print(String(format: "Failed to create GARSession: %d", nsError.code))
        }
        
    }
    
    func updateWithGARFrame(garFrame: GARFrame) {
        self.garFrame = garFrame
        updateLocalizationState()
        updateMarkerEntitys()
        updateTrackingLabel()
        updateStatusLabel()
        
    }
    
    func updateLocalizationState() {
        let now = Date()
        
        if let earth = garFrame.earth, earth.earthState != .enabled {
            localizationState = .LocalizationStateFailed
        } else if let earth = garFrame.earth, earth.trackingState == .tracking {
            localizationState = .LocalizationStatePretracking
        } else {
            if localizationState == .LocalizationStatePretracking {
                localizationState = .LocalizationStateLocalizing
            } else if localizationState == .LocalizationStateLocalizing {
                if let geospatialTransform = self.garFrame.earth?.cameraGeospatialTransform,
                   geospatialTransform.horizontalAccuracy <= kHorizontalAccuracyLowThreshold,
                   geospatialTransform.headingAccuracy <= kHeadingAccuracyLowThreshold {
                    localizationState = .LocalizationStateLocalized
                    
                } else if now.timeIntervalSince(lastStartLocalizationDate) >= kLocalizationFailureTime {
                    localizationState = .LocalizationStateFailed
                }
            } else {
                if let geospatialTransform = self.garFrame.earth?.cameraGeospatialTransform,
                   geospatialTransform.horizontalAccuracy <= kHorizontalAccuracyHighThreshold,
                   geospatialTransform.headingAccuracy <= kHeadingAccuracyHighThreshold {
                    localizationState = .LocalizationStateLocalizing
                    lastStartLocalizationDate = now
                }
            }
        }
    }
    
    func updateMarkerEntitys() {
        for anchor in garFrame.anchors {
            if anchor.trackingState != .tracking {
                continue
            }
            var anchorEntity = markerEntitys[anchor.identifier]
            if anchorEntity == nil {
                let model = try? Entity.load(named: "nendan")
                guard let model = model else { return }
                model.scale = SIMD3<Float>.one * 1
                model.position = [0,0.015,0]
//
                let plane = ModelEntity(mesh: .generatePlane(width: 2, depth: 2), materials: [OcclusionMaterial()])
                plane.generateCollisionShapes(recursive: false)
                plane.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .static)
                
                anchorEntity = AnchorEntity()
                markerEntitys[anchor.identifier] = anchorEntity
                
                anchorEntity?.addChild(plane)
                anchorEntity?.addChild(model)
                
                arView.scene.addAnchor(anchorEntity!)
                
//                model.present()
            }
            anchorEntity?.transform.matrix = anchor.transform
        }
        
        
    }
    
    func updateTrackingLabel() {
        guard let earth = garFrame.earth else {
            trackingLabel.text = ""
            return
        }
        if localizationState == .LocalizationStateFailed {
            if earth.earthState != .enabled  {
                let earthState = stringFromGAREarthState(earchState: earth.earthState)
                trackingLabel.text = String(format: "Bad EarthState: %@", earthState)
            } else {
                trackingLabel.text = ""
            }
            return
        }
        
        if earth.trackingState == .paused {
            trackingLabel.text = "Not tracking."
        }
        
        if let geospatialTransform = earth.cameraGeospatialTransform {
            var heading = geospatialTransform.heading
            if heading > 180.0 {
                heading -= 360.0
            }
            trackingLabel.text = String(format: kGeospatialTransformFormat,
                                        geospatialTransform.coordinate.latitude,
                                        geospatialTransform.coordinate.longitude,
                                        geospatialTransform.horizontalAccuracy,
                                        geospatialTransform.altitude,
                                        geospatialTransform.verticalAccuracy,
                                        heading,
                                        geospatialTransform.headingAccuracy)
        }
    }
    
    func updateStatusLabel() {
        switch localizationState {
        case .LocalizationStateLocalized:
            break
        case .LocalizationStateLocalizing:
            statusLabel.text = kLocalizationTip
            break
        case .LocalizationStateFailed:
            statusLabel.text = kLocalizationFailureMessage
            break
        default:
            break
        }
    }
    
    func stringFromGAREarthState(earchState: GAREarthState) -> String {
        switch earchState {
        case .errorInternal:
            return "ERROR_INTERNAL"
        case .errorNotAuthorized:
            return "ERROR_NOT_AUTHORIZED"
        case .errorResourceExhausted:
            return "ERROR_RESOURCE_EXHAUSTED"
        default:
            return "ENABLED"
        }
    }
    
    func terrainStateString(terrainAnchorState: GARTerrainAnchorState) -> String {
        switch terrainAnchorState {
        case .none:
            return "None"
        case .success:
            return "Success"
        case .errorInternal:
            return "ErrorInternal"
        case .taskInProgress:
            return "TaskInProgress"
        case .errorNotAuthorized:
            return "ErrorNotAuthorized"
        case .errorUnsupportedLocation:
            return "UnsupportedLocation"
        default:
            return "Unknown"
        }
    }
}

extension ARViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let garSession = garSession, localizationState != .LocalizationStateFailed else {
            return
        }
        
        do {
            let garFrame = try garSession.update(frame)
            updateWithGARFrame(garFrame: garFrame)
        } catch {
            print("session error")
        }
        
        
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
    }

    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
    }

    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
}

extension ARViewController: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()
    }
}

extension Entity {
    func present() {
        
        /* The sunflower model's hardcoded scale.
        An app may wish to assign a unique scale value per App Clip Code model. */
//        let finalScale = SIMD3<Float>.one * 50
//
//        // To display the model, initialize it at a small scale, then animate by transitioning to the original scale.
//        self.move(
//            to: Transform(
//                scale: self.scale,
//                rotation: simd_quatf.init(angle: Float.pi, axis: SIMD3<Float>(x: 0, y: 0.050, z: 0))
//            ),
//            relativeTo: self
//        )
        self.move(
            to: Transform(
                scale: SIMD3<Float>.one,
                rotation: simd_quatf.init(angle: Float.pi, axis: SIMD3<Float>(x: 0, y: 1, z: 0)),
                translation: [0,2.0,0]
            ),
            relativeTo: self,
            duration: 1
        )
    }
}
