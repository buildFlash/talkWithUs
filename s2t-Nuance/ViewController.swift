//
//  ViewController.swift
//  s2t-Nuance
//
//  Created by Aryan Sharma on 23/08/16.
//  Copyright © 2016 hootyapps. All rights reserved.
//
import UIKit
import SpeechKit
import AVFoundation
import AVKit
import Alamofire

class ViewController: UIViewController, UITextFieldDelegate, SKTransactionDelegate {
    
    // to control the toggleRecogButton
    enum SKSState {
        case SKSIdle
        case SKSListening
        case SKSProcessing
    }
    
    //outlets
    @IBOutlet weak var transciptionLabel: UILabel!
    @IBOutlet weak var volumeLevelIndicator: UIProgressView!
    @IBOutlet weak var toggleRecogButton: UIButton!
    //@IBOutlet weak var transcriptionLabel: UILabel!
    @IBOutlet weak var logTextView: UITextView!
    //@IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var replayBtn: UIButton!
    
    
    // settings
    var session: SKSession!
    var transcriptionString: String!
    var transaction: SKTransaction!
    var state = SKSState.SKSIdle
    var language = "eng-IND"
    var volumePollTimer: NSTimer?
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    let recordSettings = [AVSampleRateKey : NSNumber(float: Float(44100.0)),
                          AVFormatIDKey : NSNumber(int: Int32(kAudioFormatMPEG4AAC)),
                          AVNumberOfChannelsKey : NSNumber(int: 1),
                          AVEncoderAudioQualityKey : NSNumber(int: Int32(AVAudioQuality.Medium.rawValue))]
    
    func directoryURL() -> NSURL? {
        let fileManager = NSFileManager.defaultManager()
        let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        let documentDirectory = urls[0] as NSURL
        let soundURL = documentDirectory.URLByAppendingPathComponent("sound.m4a")
        return soundURL
    }
    
    
    // translation settings
    var api_key = "AIzaSyDbjqZLRPCeCrCKPp7axxcVwNCJ9I5fGpU"
    var targetLang = "en"
    var sourceString = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initialState()
        state = .SKSIdle
        session = SKSession(URL: NSURL(string: SKSServerUrl), appToken: SKSAppKey)
        
        if (session == nil) {
            let alertView = UIAlertController(title: "SpeechKit", message: "Failed to initialize SpeechKit session.", preferredStyle: .Alert)
            let defaultAction = UIAlertAction(title: "OK", style: .Default) { (action) in }
            alertView.addAction(defaultAction)
            presentViewController(alertView, animated: true, completion: nil)
            return
        }
        loadEarcons()
        
        // intialize the recorder
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try audioRecorder = AVAudioRecorder(URL: self.directoryURL()!,
                                                settings: recordSettings)
            audioRecorder.prepareToRecord()
        } catch {
            
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initialState() {
        logTextView.text = ""
        replayBtn.hidden = true
    }
    
    // working is self explanatory
    @IBAction func toggleRecogButton(sender: UIButton) {
        switch state {
        case .SKSIdle:
            initialState()
            recognize()
        case .SKSListening:
            stopRecording()
        case .SKSProcessing:
            initialState()
            cancel()
        }
    }
    
    // function that recognizes the speech by creating a transaction
    // this is extremely important as this is the only way of starting a transaction
    func recognize(){
        stopPlayback()
        logTextView.text = ""
        toggleRecogButton?.setTitle("Listening..", forState: .Normal)
        transaction = session.recognizeWithType(SKTransactionSpeechTypeDictation, detection: .Long, language: language, delegate: self)
        
    }
    
    // this segmented control helps the user select the language
    @IBAction func selectRecognitionType(sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        if(index == 0){
            language = "eng-IND"
        } else if (index == 1){
            language = "hin-IND"
        }
    }
    
    
    func stopRecording(){
        stopPlayback()
        transaction.stopRecording()
        toggleRecogButton?.setTitle("Click to Record", forState: .Normal)
        
        audioRecorder.stop()
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false)
        } catch {
        }
        
        
    }
    
    func cancel(){
        stopPlayback()
        transaction.cancel()
        toggleRecogButton?.setTitle("Click to Restart", forState: .Normal)
    }
    
    // transaction delegate functions which are needed to complete a transaction
    // names and strings logged explain what is being done in each phase of transaction
    
    func transactionDidBeginRecording(transaction: SKTransaction!) {
        recordAudio()
        state = .SKSListening
        log("Recording Began")
        startPollingVolume()
        toggleRecogButton?.setTitle("Listening..", forState: .Normal)
    }
    
    func transactionDidFinishRecording(transaction: SKTransaction!) {
        state = .SKSProcessing
        stopPollingVolume()
        log("transactionDidFinishRecording")
        toggleRecogButton?.setTitle("Processing..", forState: .Normal)
    }
    
    func transaction(transaction: SKTransaction!, didReceiveRecognition recognition: SKRecognition!) {
        state = .SKSIdle
        transcriptionString = recognition.text
        if language == "hin-IND" {
                translateRequest(transcriptionString)
        }
        
        transciptionLabel.text = recognition.text
        log(String(format: "didReceiveRecognition: %@", arguments: [recognition.text]))
        log(transcriptionString)
        parseString(transcriptionString)
        //playAudio()
        //  playVideo(transcriptionString.lowercaseString)
    }
    
    func transaction(transaction: SKTransaction!, didReceiveServiceResponse response: [NSObject : AnyObject]!) {
        log(String(format: "didReceiveServiceResponse: %@", arguments: [response]))
    }
    
    func transaction(transaction: SKTransaction!, didFinishWithSuggestion suggestion: String) {
        log("didFinishWithSuggestion")
        state = .SKSIdle
        resetTransaction()
    }
    
    func transaction(transaction: SKTransaction!, didFailWithError error: NSError!, suggestion: String) {
        log(String(format: "didFailWithError: %@. %@", arguments: [error.description, suggestion]))
        
        // Something went wrong. Ensure that your credentials are correct.
        // The user could also be offline, so be sure to handle this case appropriately.
        state = .SKSIdle
        resetTransaction()
    }
    
    // Helpers
    func log(message: String) {
        logTextView!.text = logTextView!.text.stringByAppendingFormat("%@\n", message)
    }
    
    func resetTransaction() {
        NSOperationQueue.mainQueue().addOperationWithBlock({
            self.transaction = nil
            self.toggleRecogButton?.setTitle("Click to record", forState: .Normal)
            self.toggleRecogButton?.enabled = true
        })
    }
    
    // for recording and playing audio
    func recordAudio(){
        if !audioRecorder.recording {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setActive(true)
                audioRecorder.record()
            } catch {
            }
        }
    }
    
    func playAudio(){
        if (!audioRecorder.recording){
            do {
                try audioPlayer = AVAudioPlayer(contentsOfURL: audioRecorder.url)
                audioPlayer.volume = 1.0
                audioPlayer.play()
                //       audioPlayer.volume = 1.0
                
            } catch {
            }
        }
    }
    
    func stopPlayback(){
        if let _ = audioPlayer{
            if audioPlayer.playing{
                audioPlayer.stop()
            }
        }
    }
    
    // manages volume level indicator
    func startPollingVolume() {
        // Every 50 milliseconds we should update the volume meter in our UI.
        volumePollTimer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self, selector: #selector(ViewController.pollVolume), userInfo: nil, repeats: true)
    }
    
    func pollVolume() {
        let volumeLevel = transaction!.audioLevel
        volumeLevelIndicator!.setProgress(volumeLevel / Float(100), animated: true)
    }
    
    func stopPollingVolume() {
        volumePollTimer!.invalidate()
        volumePollTimer = nil
        volumeLevelIndicator!.setProgress(Float(0), animated: true)
    }
    
    // used to play the voice when transaction begins, ends and fails
    func loadEarcons() {
        let startEarconPath = NSBundle.mainBundle().pathForResource("sk_start", ofType: "pcm")
        let stopEarconPath = NSBundle.mainBundle().pathForResource("sk_stop", ofType: "pcm")
        let errorEarconPath = NSBundle.mainBundle().pathForResource("sk_error", ofType: "pcm")
        let audioFormat = SKPCMFormat()
        audioFormat.sampleFormat = .SignedLinear16
        audioFormat.sampleRate = 16000
        audioFormat.channels = 1
        
        session!.startEarcon = SKAudioFile(URL: NSURL(fileURLWithPath: startEarconPath!), pcmFormat: audioFormat)
        session!.endEarcon = SKAudioFile(URL: NSURL(fileURLWithPath: stopEarconPath!), pcmFormat: audioFormat)
        session!.errorEarcon = SKAudioFile(URL: NSURL(fileURLWithPath: errorEarconPath!), pcmFormat: audioFormat)
        
    }
    
    // used to resign first responders
    func textFieldDidEndEditing(textField: UITextField) {
        textField.resignFirstResponder()
    }
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = event?.allTouches()?.first
        if (logTextView!.isFirstResponder() && touch!.view != logTextView) {
            logTextView!.resignFirstResponder()
        }
        super.touchesBegan(touches, withEvent: event)
    }
    
    // parsing function
    var stringArray: [String]!
    var i=0
    func parseString(string: String){
        i=0
        stringArray = string.componentsSeparatedByString(" ")
        logTextView.text = ""
        playVideo(stringArray[i].lowercaseString)
    }

    // video player
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer!
    
    private func playVideo(name: String) {
        guard let path = NSBundle.mainBundle().pathForResource(name, ofType:"mp4") else {
            log("\(name.uppercaseString) : not found in our dictionary")
            i+=1
            if (i != stringArray.count){
                playVideo(stringArray[i].lowercaseString)
            }
            return
        }
        player = AVPlayer(URL: NSURL(fileURLWithPath: path))
        playerLayer = AVPlayerLayer(player: player)
        self.playerLayer.frame = self.logTextView.bounds
        self.logTextView!.layer.addSublayer(self.playerLayer)
        self.player!.play()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.playerDidFinishPlaying(_:)),name: AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem)
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        i += 1
        print("Video Finished")
        self.playerLayer.removeFromSuperlayer()
        if (i < stringArray.count){
            playVideo(stringArray[i].lowercaseString)
        }
        if(i == stringArray.count){
            replayBtn.hidden = false
        }
    }
    
    
    @IBAction func replayBtnPressed(sender: UIButton) {
        logTextView.text = ""
        i=0
        playVideo(stringArray[i].lowercaseString)
    }
    
    func translateRequest(sourceString: String) {
        let getUrl = "https://translation.googleapis.com/language/translate/v2?key=\(api_key)&source=hi&target=en&q=\(transcriptionString)"
        print(getUrl)
        let urlString = getUrl.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        //let parameters: [String: AnyObject] = ["foo": "bar"]

        Alamofire.request(.GET, urlString, parameters: nil).responseJSON { response in
            let result  = response.result
            if let dict = result.value as? [String: AnyObject]{
                if let data = dict["data"] as? [String: AnyObject] {
                    if let translations = data["translations"] as? [[String: AnyObject]]{
                        if let translatedText = translations[0]["translatedText"] as? String {
                            self.transcriptionString = translatedText
                            print(translatedText)
                            self.parseString(translatedText)
                            self.log("translated to \(translatedText)")
                        }
                    }
                }
            }
            
            if let JSON = response.result.value {
                    print("JSON: \(JSON)")
                }
        }
    }
    
}
