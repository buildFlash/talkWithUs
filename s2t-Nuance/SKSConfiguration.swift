//
//  SKSConfiguration.swift
//  SpeechKitSample
//
//  All Nuance Developers configuration parameters can be set here.
//
//  Copyright (c) 2015 Nuance Communications. All rights reserved.
//

import Foundation

var SKSAppKey = "1a85d2672f94efe949ff9ee6159bbe4eae77d50edae50fc6a61a42936d3ad687bfa8eeee3cddd885dd766bf2112940bfa015cd7bfbdd41a1f7843564be0beb7d"
var SKSAppId = "NMDPTRIAL_ryn2624_icloud_com20160823055225"
var SKSServerHost = "sslsandbox.nmdp.nuancemobility.net"
var SKSServerPort = "443"

var SKSLanguage = "eng-IND"

var SKSServerUrl = String(format: "nmsps://NMDPTRIAL_ryn2624_icloud_com20160823055225@sslsandbox.nmdp.nuancemobility.net:443", SKSAppId, SKSServerHost, SKSServerPort)

// Only needed if using NLU/Bolt
var SKSNLUContextTag = "!NLU_CONTEXT_TAG!"


let LANGUAGE = SKSLanguage == "!LANGUAGE!" ? "eng-USA" : SKSLanguage