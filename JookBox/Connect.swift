//
//  Connect.swift
//  JookBox
//
//  Created by Andrew Barba on 12/20/14.
//  Copyright (c) 2014 Andrew Barba. All rights reserved.
//

import Foundation
import MultipeerConnectivity

/**
    Notifications
*/
public let MultipeerMessageRecievedNotification = "com.abarba.JookBox.multipeer.message.recieved"
public let MultipeerClientConnectedNotification = "com.abarba.JookBox.multipeer.client.connected"
public let MultipperNearbyPeersChangedNotification = "com.abarba.JookBox.multipeer.nearbypeers.changed"

/**
    Constants
*/
private let kJookBoxService = "jookbox-audio"

/**
    Private Singleton
*/
private let _Connect = Connect()

class Connect: NSObject {
    
    let localPeerID = MCPeerID(displayName: UIDevice.currentDevice().name)
    
    var session: MCSession! {
        willSet {
            if let session = self.session {
                session.delegate = nil
            }
        }
        didSet {
            session.delegate = self
        }
    }
    
    private var advertiser: MCNearbyServiceAdvertiser! {
        didSet {
            advertiser.delegate = self
        }
    }
    
    private var browser: MCNearbyServiceBrowser! {
        didSet {
            browser.delegate = self
        }
    }
    
    private var callbacks: [MCPeerID:()->()] = [:]
    
    var nearbyPeers: [MCPeerID] = []
    var peerInfo: [MCPeerID:String] = [:]
    
    /**
        Singleton
    */
    class var connect: Connect {
        return _Connect
    }
}

// MARK: - Messaging

extension Connect {
    
    func sendMessageToPeer(peerID: MCPeerID, message: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {
            if let data = NSJSONSerialization.dataWithJSONObject(message, options: nil, error: nil) {
                var error: NSError? = nil
                self.session.sendData(data, toPeers: [peerID], withMode: MCSessionSendDataMode.Reliable, error: &error)
                if let error = error {
                    println(error)
                }
            }
        }
    }
    
    func broadcastMessage(message: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {
            if let data = NSJSONSerialization.dataWithJSONObject(message, options: nil, error: nil) {
                var error: NSError? = nil
                self.session.sendData(data, toPeers: self.session.connectedPeers, withMode: MCSessionSendDataMode.Reliable, error: nil)
                if let error = error {
                    println(error)
                }
            }
        }
    }
}

// MARK: - Advertising

extension Connect {
    
    func startAdvertising(name: String) {
        self.session = MCSession(peer: self.localPeerID)
        self.advertiser = MCNearbyServiceAdvertiser(peer: self.localPeerID, discoveryInfo: ["name": name], serviceType: kJookBoxService)
        self.advertiser.startAdvertisingPeer()
    }
    
    func stopAdvertising() {
        self.advertiser?.stopAdvertisingPeer()
    }
}

// MARK: - Discover

extension Connect: MCNearbyServiceBrowserDelegate {
    
    func discoverPeers(name: String) {
        self.browser = MCNearbyServiceBrowser(peer: self.localPeerID, serviceType: kJookBoxService)
        self.browser.startBrowsingForPeers()
    }
    
    func connectToPeer(peerID: MCPeerID) {
        self.session = MCSession(peer: self.localPeerID)
        dispatch_async(dispatch_get_main_queue()) {
            self.browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 30)
        }
    }
    
    func connectToPeer(peerID: MCPeerID, completion: ()->()) {
        self.callbacks[peerID] = completion
        self.connectToPeer(peerID)
    }
    
    // Found a nearby advertising peer
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        dispatch_async(dispatch_get_main_queue()) {
            if self.localPeerID.displayName != peerID.displayName && !contains(self.nearbyPeers, peerID) {
                self.nearbyPeers.append(peerID)
                self.peerInfo[peerID] = info["name"] as? String
                NSNotificationCenter.defaultCenter().postNotificationName(MultipperNearbyPeersChangedNotification, object: self.nearbyPeers)
            }
        }
    }

    // A nearby peer has stopped advertising
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        dispatch_async(dispatch_get_main_queue()) {
            if let index = find(self.nearbyPeers, peerID) {
                self.nearbyPeers.removeAtIndex(index)
                NSNotificationCenter.defaultCenter().postNotificationName(MultipperNearbyPeersChangedNotification, object: self.nearbyPeers)
            }
        }
    }
    
    // Browsing did not start due to an error
    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        println(error)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate Delegate

extension Connect: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        dispatch_async(dispatch_get_main_queue()) {
            invitationHandler(true, self.session)
        }
    }
}

// MARK: - MCSessionDelegate Delegate

extension Connect: MCSessionDelegate {
    
    // Remote peer changed state
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        dispatch_async(dispatch_get_main_queue()) {
            println("\(self.localPeerID.displayName) <-\(state.rawValue)-> \(peerID.displayName)")
            if state == MCSessionState.Connected {
                self.callbacks[peerID]?()
                NSNotificationCenter
                    .defaultCenter()
                    .postNotificationName(MultipeerClientConnectedNotification, object: peerID)
            }
        }
    }
    
    // Received data from remote peer
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        dispatch_async(dispatch_get_main_queue()) {
            if let json: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) {
                let object = [ "peer": peerID, "message": json ]
                NSNotificationCenter.defaultCenter().postNotificationName(MultipeerMessageRecievedNotification, object: object)
            }
        }
    }
    
    // Received a byte stream from remote peer
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {
        // no op
    }
    
    // Start receiving a resource from remote peer
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {
        // no op
    }
    
    // Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
        // no op
    }
}
