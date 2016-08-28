//
//  ViewController.swift
//  s2t-Nuance
//
//  Created by Aryan Sharma on 23/08/16.
//  Copyright © 2016 hootyapps. All rights reserved.
//

import UIKit
import SpeechKit

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
    
    
    // settings
    var session: SKSession!
    var transaction:SKTransaction!
    var state = SKSState.SKSIdle
    var language = "eng-IND"
    var volumePollTimer: NSTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    }
    
 

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // working is self explanatory
    @IBAction func toggleRecogButton(sender: UIButton) {
        switch state {
        case .SKSIdle:
            recognize()
        case .SKSListening:
            stopRecording()
        case .SKSProcessing:
            cancel()
        }
    }
    
    // function that recognizes the speech by creating a transaction
    // this is extremely important as this is the only way of starting a transaction
    func recognize(){
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
        transaction.stopRecording()
        toggleRecogButton?.setTitle("Click to Record", forState: .Normal)
    }
    
    func cancel(){
        transaction.cancel()
        toggleRecogButton?.setTitle("Click to Restart", forState: .Normal)
    }
 
    // transaction delegate functions which are needed to complete a transaction
    // names and strings logged explain what is being done in each phase of transaction
    
    func transactionDidBeginRecording(transaction: SKTransaction!) {
        state = .SKSListening
        log("Recording Began")
        startPollingVolume()
        toggleRecogButton?.setTitle("Listening..", forState: .Normal)
        state = .SKSListening
    }
    
    func transactionDidFinishRecording(transaction: SKTransaction!) {
        state = .SKSProcessing
        stopPollingVolume()
        log("transactionDidFinishRecording")
        toggleRecogButton?.setTitle("Processing..", forState: .Normal)
    }
    
    func transaction(transaction: SKTransaction!, didReceiveRecognition recognition: SKRecognition!) {
        state = .SKSIdle
        transciptionLabel.text = recognition.text
        log(String(format: "didReceiveRecognition: %@", arguments: [recognition.text]))
        
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
}
