//
//  ViewController.swift
//  Overwatch
//
//  Created by Andrew Trice on 3/4/16.
//  Copyright © 2016 Andrew Trice. All rights reserved.
//

import UIKit
import DJISDK
import VideoPreviewer
import MapKit

class ViewController: DJIBaseViewController, DJICameraDelegate, DJIFlightControllerDelegate, DJIGimbalDelegate, MKMapViewDelegate {
    
    static var sharedInstance:ViewController? = nil
    
    @IBOutlet weak var fpvView : UIView!
    @IBOutlet weak var debugOutput: UITextView!
    
    @IBOutlet weak var viewFinder: UIImageView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var positionOutput: UITextView!
    
    @IBOutlet weak var productConnectionStatus: UILabel!
    @IBOutlet weak var productModel: UILabel!
    @IBOutlet weak var productFirmwarePackageVersion: UILabel!
    @IBOutlet weak var openComponents: UIButton!
    @IBOutlet weak var sdkVersionLabel: UILabel!
    
    @IBOutlet weak var captureHighResButton: UIButton!
    @IBOutlet weak var captureLowResButton: UIButton!
    
    var connectedProduct:DJIBaseProduct?=nil
    var componentDictionary = Dictionary<String, Array<DJIBaseComponent>>()
    var aircraft : DJIAircraft? = nil
    
    var isSettingMode:Bool = false
    var imageMedia: DJIMedia? = nil
    var flightController: DJIFlightController? = nil
    var currentState: DJIFlightControllerCurrentState?=nil
    var currentGimbalPitch:Float = 0
    var currentGimbalHeading:Float = 0
    
    var aircraftStateString = ""
    var aircraftMapAnnotation: MKPointAnnotation? = nil
    var aircraftMapMarker: MKAnnotationView? = nil
    
    var pendingAircraftState: NSMutableDictionary? = nil
    
    let APP_KEY = "6230781d3b55bc83403fe6e4"
    
    override func viewDidLoad() {
        
        self.captureHighResButton.enabled = false;
        self.captureLowResButton.enabled = false;
        
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        debug("Initializing...")
        DJISDKManager.registerApp(APP_KEY, withDelegate: self)
        
        ViewController.sharedInstance = self;
        DataManager.sharedInstance
        
        updatePosition()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func connectVideo() {
        debug("attaching video feed...")
        let camera: DJICamera? = self.fetchCamera()
        if camera != nil {
            camera!.delegate = self
        }
        
        // start to check the pre-condition
        self.getCameraMode()
        self.isSettingMode = false
        
        //fc = self.fetchFlightController()
        
        
        VideoPreviewer.instance().start()
        // captureButton.enabled = false
        getCameraMode()
        
        UIView.animateWithDuration(1.5) {
            self.fpvView.alpha = 1.0
            self.viewFinder.alpha = 1.0
        }
    }
    
    func disconnectVideo() {
        debug("detaching video feed...")
        let camera: DJICamera? = self.fetchCamera()
        if camera != nil {
            camera!.delegate = nil
        }
        VideoPreviewer.instance().stop();
        VideoPreviewer.instance().unSetView()
        VideoPreviewer.instance().reset()
        
        self.captureHighResButton.enabled = false;
        self.captureLowResButton.enabled = false;
    }
    
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        VideoPreviewer.instance().setView(self.fpvView)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        VideoPreviewer.instance().unSetView()
    }
    
    
    func debug(value:Any) {
        
        //set new value
        let value = "\(value)\n\n\(debugOutput.text)"
        debugOutput.text = value
        
        //scroll to bottom
        //let range = NSMakeRange(value.characters.count - 1, 1);
        //debugOutput.scrollRangeToVisible(range)
        
        NSLog(value);
    }
    
    
    
    
    
    func getCameraMode() {
        debug("getCameraMode")
        let camera: DJICamera? = self.fetchCamera()
        if camera != nil {
            
            camera?.getCameraModeWithCompletion({[weak self](mode: DJICameraMode, error: NSError?) -> Void in
                
                if error != nil {
                    self?.debug("ERROR: getCameraModeWithCompletion::\(error!.description)")
                    self?.showAlertResult("ERROR: getCameraModeWithCompletion::\(error!.description)")
                }
                else if mode == DJICameraMode.ShootPhoto {
                    self!.captureHighResButton.enabled = true;
                    self!.captureLowResButton.enabled = true;
                }
                else {
                    self?.setCameraMode()
                }
                
                })
        }
    }
    
    func setCameraMode() {
        let camera: DJICamera? = self.fetchCamera()
        if camera != nil {
            
            if !self.isSettingMode {
                self.isSettingMode = true
                camera?.setCameraMode(DJICameraMode.ShootPhoto, withCompletion: {[weak self](error: NSError?) -> Void in
                    
                    self?.isSettingMode = false
                    if error != nil {
                        self?.debug("ERROR: setCameraMode:withCompletion::\(error!.description)")
                        self?.showAlertResult("ERROR: setCameraMode:withCompletion:\(error!.description)")
                    }
                    else {
                        // Normally, once an operation is finished, the camera still needs some time to finish up
                        // all the work. It is safe to delay the next operation after an operation is finished.
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), {() -> Void in
                            
                            //     self?.captureButton.enabled = true
                            self!.captureHighResButton.enabled = true;
                            self!.captureLowResButton.enabled = true;
                        })
                    }
                })
            }
        }
    }
    
    //DJIFlightControllerDelegate
    func flightController(fc: DJIFlightController, didUpdateSystemState state: DJIFlightControllerCurrentState) {
        self.currentState = state
        
        //debug( "\(state.aircraftLocation)\n\(state.altitude)\n\(fc.compass.heading)" )
        updatePosition()
    }
    
    
    func gimbalController(controller: DJIGimbal, didUpdateGimbalState gimbalState: DJIGimbalState) {
        //debug("Gimbal attitude\npitch: \(gimbalState.attitudeInDegrees.pitch)\nroll: \(gimbalState.attitudeInDegrees.roll)\nyaw:   \(gimbalState.attitudeInDegrees.yaw)")
        
        self.currentGimbalPitch = gimbalState.attitudeInDegrees.pitch
        self.currentGimbalHeading = gimbalState.attitudeInDegrees.yaw
        updatePosition()
    }
    
    func getBatteryAsText(battery:DJIAircraftRemainingBatteryState) -> String {
        switch battery {
            case DJIAircraftRemainingBatteryState.Low: return "LOW"
            case DJIAircraftRemainingBatteryState.VeryLow: return "VERY LOW!"
            default: return "Normal"
        }
    }
    
    func updatePosition() {
        
        var lat = "-", lon = "-", alt = "-", heading = "-", x = "-", y = "-", z = "-", battery = "-"
        
        if let state = currentState {
            lat = String(format: "%5f", state.aircraftLocation.latitude)
            lon = String(format: "%5f", state.aircraftLocation.longitude)
            alt = "\(state.altitude)"
            x = String(format: "%5f", state.velocityX)
            y = String(format: "%5f", state.velocityY)
            z = String(format: "%5f", state.velocityZ)
            battery = getBatteryAsText(state.remainingBattery)
            
        }
        
        if let fc = flightController {
            heading = "\(fc.compass.heading)"
            
        }
        
        aircraftStateString =
            "AIRCRAFT\n" +
            "battery:\t\(battery)\n" +
            "lat:\t\t\(lat)\n" +
            "lon:\t\t\(lon)\n" +
            "alt:\t\t\(alt) (m)\n" +
            "head:\t\(heading)\n" +
            "velocity (m/s) {\n" +
            "    x:\t\(x)\n" +
            "    y:\t\(y)\n" +
            "    z:\t\(z)\n" +
            "}\n\n" +
            "CAMERA\n" +
            "head:\t\(currentGimbalHeading)\n" +
            "pitch:\t\(self.currentGimbalPitch )"
        
        if positionOutput.text != aircraftStateString  {
            positionOutput.text = aircraftStateString
            updateMapLocation()
        }
        
    }
    
    func updateMapLocation() {
        
        if let state = currentState {
            if state.aircraftLocation.latitude > -180 && state.aircraftLocation.longitude > -180 {
                let viewRegion = MKCoordinateRegionMakeWithDistance(state.aircraftLocation, 500, 500);
                let adjustedRegion = mapView.regionThatFits(viewRegion);
                mapView.setRegion(adjustedRegion, animated: false)
                
                aircraftMapAnnotation!.coordinate = CLLocationCoordinate2D(latitude: state.aircraftLocation.latitude, longitude: state.aircraftLocation.longitude)
                
                if let fc = flightController {
                    let radians = (fc.compass.heading) / 180.0 * M_PI
                    aircraftMapMarker!.transform = CGAffineTransformMakeRotation(CGFloat(radians))
                }
            }
        }
    }
    
    func initMapView() {
        
        mapView.delegate = self
        
        aircraftMapAnnotation = MKPointAnnotation()
        mapView.addAnnotation(aircraftMapAnnotation!)
        
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView?{
        
        let reuseId = "aircraftIcon"
        
        var anView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
        if anView == nil {
            
            aircraftMapMarker = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            aircraftMapMarker!.image = UIImage(named:"map-marker.png")
            aircraftMapMarker!.canShowCallout = false
            anView = aircraftMapMarker
        }
        else {
            anView!.annotation = annotation
        }
        return anView
    }
    
    
    
    
    
    
    
    
    
    
    
    func captureAircraftState() -> NSMutableDictionary {
        
        var lat = "-", lon = "-", alt = "-", heading = "-", x = "-", y = "-", z = "-", aircraft = "undefined"
        
        if let state = currentState, fc = flightController {
            aircraft = self.aircraft!.model!
            lat = String(format: "%5f", state.aircraftLocation.latitude)
            lon = String(format: "%5f", state.aircraftLocation.longitude)
            alt = "\(state.altitude)"
            x = String(format: "%5f", state.velocityX)
            y = String(format: "%5f", state.velocityY)
            z = String(format: "%5f", state.velocityZ)
            heading = "\(fc.compass.heading)"
        }
        
        let now = NSDate()
        
        let aircraftState:NSMutableDictionary = [
            "aircraft": aircraft,
            "latitude": lat,
            "longitude": lon,
            "altitude": alt,
            "heading": heading,
            "velocityX": x,
            "velocityY": y,
            "velocityZ": z,
            "cameraHeading": String(currentGimbalHeading),
            "cameraPitch": String(currentGimbalPitch),
            "timestamp": String(now),
            "sort": String(now.timeIntervalSince1970),
            "type": "overwatch.image"
        ]

        return aircraftState;
    }
    
    
    
    
    
    
    
    
    
    
    
    @IBAction func onLowResButtonPress(sender: UIButton) {
        debug("capture low res image from video stream")
        
        let now = NSDate()
        let aircraftState:NSMutableDictionary = self.captureAircraftState();
        
        // 720p is max resolution for feed from aircraft, 
        // so create an image snapshot no more than 720 pixels high
        // and add jpg compression for faster across-the-wire transmission
        let snapshot = self.fpvView.scaledSnapshot(720.0)
        if let data = UIImageJPEGRepresentation(snapshot, 0.75) {
            
            let filename = getDocumentsDirectory().stringByAppendingPathComponent("\(now.timeIntervalSince1970)")
            data.writeToFile(filename, atomically: true)
            
            DataManager.sharedInstance.saveData(aircraftState, attachmentFile: filename)
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    var oldCameraMode:DJICameraMode? = nil
    var storingPhoto:Bool = false
    var pendingMedia:DJIMedia? = nil
    
    func camera(camera: DJICamera, didUpdateSystemState systemState: DJICameraSystemState) {
        
        
        if (self.oldCameraMode != systemState.mode) {
            var cameraMode:String = ""
            switch (systemState.mode) {
            case DJICameraMode.MediaDownload: cameraMode="MediaDownload"; break;
            case DJICameraMode.Playback: cameraMode="Playback"; break;
            case DJICameraMode.RecordVideo: cameraMode="RecordVideo"; break;
            case DJICameraMode.ShootPhoto: cameraMode="ShootPhoto"; break;
            case DJICameraMode.Unknown: cameraMode="Unknown"; break;
            }
            debug("camera:didUpdateSystemState: \(cameraMode)")
            self.oldCameraMode = systemState.mode
        }
        
        if (!self.storingPhoto && systemState.isStoringPhoto) {
            debug("aircraft is storing photo")
            self.storingPhoto = true
        }
        if (self.storingPhoto && !systemState.isStoringPhoto) {
            
            debug("storing photo complete")
            self.storingPhoto = false
            
            if let _ = self.pendingAircraftState, media = self.pendingMedia {
                
                let camera: DJICamera? = self.fetchCamera()
                camera!.setCameraMode(DJICameraMode.MediaDownload, withCompletion: {[weak self](error: NSError?) -> Void in
                    if error != nil {
                        self?.debug("ERROR: camera:didGenerateNewMediaFile:setCameraMode: \(error!.description)")
                        self!.resetToCaptureState()
                    }
                    else {
                        //wait for setCameraMode to finish
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), {() -> Void in
                            self?.debug("downloading media.  live video will be temporarily interrupted while transmitting media.")
                            self?.downloadMedia(media, completion: { (data) in
                                if (data == nil) {
                                    self?.debug("error downloading media from aircraft.")
                                    self!.resetToCaptureState()
                                }
                                else {
                                    self?.debug("downloaded media from aircraft.")
                                    self!.writeHighResCaptureEntry(data);
                                }
                            })
                        })
                        
                    }
                    
                })
            }
        }

        
    }
    
    func camera(camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMedia) {
        debug("generated new media file")
        self.pendingMedia = newMedia;
    }
    
    
    @IBAction func onHighResButtonPress(sender: UIButton) {
        debug("capturing hi res image from camera media")
        
        
        self.pendingAircraftState = self.captureAircraftState();
        
        
        let camera: DJICamera? = self.fetchCamera()
        if camera != nil {
            self.captureHighResButton.enabled = false;
            self.captureLowResButton.enabled = false;
            camera?.startShootPhoto(DJICameraShootPhotoMode.Single, withCompletion: {[weak self](error: NSError?) -> Void in
                if error != nil {
                    self?.debug("ERROR: startShootPhoto:withCompletion::\(error!.description)")
                    self!.resetToCaptureState()
                } else {
                    self?.debug("hi res image captured on aircraft")
                }
            })
        }
    }
    
    func writeHighResCaptureEntry(downloadData:NSData?) {
        
        if let data = downloadData, aircraftState = self.pendingAircraftState {
            
            self.debug("Saving high resolution data to local storage")
            let now = NSDate()
            let filename = getDocumentsDirectory().stringByAppendingPathComponent("\(now.timeIntervalSince1970)")
            data.writeToFile(filename, atomically: true)
            
            DataManager.sharedInstance.saveData(aircraftState, attachmentFile: filename)
        }
        else {
            
            self.debug("ERROR: Unable to save high resolution asset to local storage")
        }
        self.resetToCaptureState()
    }
    
    func resetToCaptureState() {
        
        self.pendingAircraftState = nil
        self.pendingMedia = nil
            
        self.debug("Resetting camera state")
        self.connectVideo();
        VideoPreviewer.instance().setView(self.fpvView)
    }
    
    
    /**
     *  The full image is even larger than the preview image. A JPEG image is around 3mb to 4mb. Therefore,
     *  SDK does not cache it. There are two differences between the process of fetching preview iamge and
     *  the one of fetching full image:
     *  1. The full image is received fully at once. The full image file is separated into several data packages.
     *     The completion block will be called each time when a data package is ready.
     *  2. The received data is the raw image file data rather than a UIImage object. It is more convenient to
     *     store the file into disk.
     */
    
    func downloadMedia(imageMedia:DJIMedia, completion: (data: NSData?) -> Void) {
       
        //self.showFullImageButton.enabled = false
        
        let downloadData: NSMutableData = NSMutableData()
        imageMedia.fetchMediaDataWithCompletion({[weak self](data:NSData?, stop:UnsafeMutablePointer<ObjCBool>, error:NSError?) -> Void in
            
            if error != nil {
                self?.debug("ERROR: fetchMediaDataWithCompletion:\(error!.description)")
                completion(data: nil)
            }
            else {
                downloadData.appendData(data!)
                if Int64(downloadData.length) == imageMedia.fileSizeInBytes {
                    dispatch_async(dispatch_get_main_queue(), {() -> Void in
                        //self?.showPhotoWithData(downloadData)
                        //self?.showFullImageButton.enabled = true
                        
                        self?.debug("Image data received: \(downloadData.length)b of \( imageMedia.fileSizeInBytes )b")
                        completion(data: downloadData)
                    })
                }
            }
         })
    }
    
    
    
    
    @IBAction func onSegmentControlValueChanged(sender: UISegmentedControl) {
        let product: DJIBaseProduct? = ConnectedProductManager.sharedInstance.connectedProduct
        if product != nil {
            if sender.selectedSegmentIndex == 0 {
                debug("Switching to software decoder")
                VideoPreviewer.instance().setDecoderWithProduct(product, andDecoderType:VideoPreviewerDecoderType.SoftwareDecoder)
            }
            else {
                debug("Switching to hardware decoder")
                VideoPreviewer.instance().setDecoderWithProduct(product, andDecoderType:VideoPreviewerDecoderType.HardwareDecoder)
            }
        }
    }
    
    
    
    func getDocumentsDirectory() -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    
    
    override func product(product: DJIBaseProduct, connectivityChanged isConnected: Bool) {
        
        super.product(product, connectivityChanged: isConnected)
        
        if(isConnected) {
            debug("Product Connected")
        } else {
            debug("Product Disconnected")
        }
    }


    
    
    
    
    
    func camera(camera: DJICamera, didReceiveVideoData videoBuffer: UnsafeMutablePointer<UInt8>, length size: Int){
        let pBuffer = UnsafeMutablePointer<UInt8>.alloc(size)
        memcpy(pBuffer, videoBuffer, size)
        VideoPreviewer.instance().dataQueue.push(pBuffer, length: Int32(size))
    }
    /*
    func camera(camera: DJICamera, didUpdateSystemState systemState: DJICameraSystemState) {
        if systemState.mode == DJICameraMode.Playback || systemState.mode == DJICameraMode.MediaDownload {
            if !self.isSettingMode {
                camera.setCameraMode(DJICameraMode.ShootPhoto, withCompletion: {[weak self](error: NSError?) -> Void in
                    if error == nil {
                        self?.isSettingMode = false
                        
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), {() -> Void in
                            
                            //self?.isInShootPhotoMode = true
                            //set hi res button enabled
                        })
                    }
                })
            }
        }
        
        
    }*/

}




extension ViewController : DJISDKManagerDelegate
{
    func sdkManagerDidRegisterAppWithError(error: NSError?) {
        
        guard error == nil  else {
            debug("Error:\(error!.localizedDescription)")
            return
        }
        
        debug("Registered, awaiting connection...")
        #if arch(i386) || arch(x86_64) ||
            //Simulator
            DJISDKManager.enterDebugModeWithDebugId("192.168.1.10")
        #else
            //Device
            DJISDKManager.startConnectionToProduct()
            
        #endif
        
        //openButtonPressed(self)
    }
    
    func sdkManagerProductDidChangeFrom(oldProduct: DJIBaseProduct?, to newProduct: DJIBaseProduct?) {
        
        guard newProduct != nil else {
            debug("Product Disconnected")
            self.flightController = nil
            self.flightController = nil
            return
        }
        
        debug("Model: \((newProduct?.model)!)")
        
        newProduct?.getFirmwarePackageVersionWithCompletion({ (version:String?, error:NSError?) -> Void in
            self.debug("Firmware: \(version ?? "Unknown")")
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), {() -> Void in
                
                //     self?.captureButton.enabled = true
            })
            
        })
        
        
        ConnectedProductManager.sharedInstance.connectedProduct = newProduct
        
        self.aircraft = (newProduct as? DJIAircraft)!
        aircraft!.gimbal?.delegate = self
        
        self.debug("Product Connected")
        self.connectVideo()
        self.initMapView()
        
        let fc: DJIFlightController? = self.fetchFlightController()
        if fc != nil {
            fc!.delegate = self
            self.flightController = fc
        }
    }
    /*
    @IBAction func openButtonPressed(sender: AnyObject) {
        
        var demoView : DemoViewController = DemoViewController()
        self.navigationController?.pushViewController(demoView, animated: true)
    }*/
    
}

