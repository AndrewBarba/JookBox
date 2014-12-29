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
public let TLMultipeerMessageRecievedNotification = "com.abarba.JookBox.multipeer.message.recieved"
public let TLMultipperNearbyPeersChangedNotification = "com.abarba.JookBox.multipeer.nearbypeers.changed"

/**
    Constants
*/
private let kJookBoxService = "jookbox-multipeer"

/**
    Private Singleton
*/
private let _Connect = Connect()

class Connect: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    var connectedPeers: [MCPeerID:MCSession] = [:]
    var nearbyPeers: [MCPeerID] = []
    
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
        if let session = self.connectedPeers[peerID] {
            if let data = NSJSONSerialization.dataWithJSONObject(message, options: nil, error: nil) {
                session.sendData(data, toPeers: [peerID], withMode: MCSessionSendDataMode.Reliable, error: nil)
            }
        }
    }
}

// MARK: - Advertising

extension Connect {
    
    func startAdvertising(name: String) {
        let peerID = MCPeerID(displayName: name)
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: kJookBoxService)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }
    
    func stopAdvertising() {
        self.advertiser?.stopAdvertisingPeer()
    }
}

// MARK: - Discover

extension Connect {
    
    func discoverPeers(name: String) {
        let peerID = MCPeerID(displayName: name)
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: kJookBoxService)
        browser.delegate = self
        self.browser = browser
    }
    
    func connectToPeer(peerID: MCPeerID) {
        if let browser = self.browser {
            let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.None)
            session.delegate = self
            browser.invitePeer(peerID, toSession: session, withContext: nil, timeout: 30)
        }
    }
    
    // Found a nearby advertising peer
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        if !contains(self.nearbyPeers, peerID) {
            self.nearbyPeers.append(peerID)
            NSNotificationCenter.defaultCenter().postNotificationName(TLMultipperNearbyPeersChangedNotification, object: self.nearbyPeers)
        }
    }

    // A nearby peer has stopped advertising
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        if let index = find(self.nearbyPeers, peerID) {
            self.nearbyPeers.removeAtIndex(index)
            NSNotificationCenter.defaultCenter().postNotificationName(TLMultipperNearbyPeersChangedNotification, object: self.nearbyPeers)
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate Delegate

extension Connect {
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.None)
        session.delegate = self
        invitationHandler(true, session)
    }
}

// MARK: - MCSessionDelegate Delegate

extension Connect {
    
    // Remote peer changed state
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        if state == .Connected {
            self.connectedPeers[peerID] = session
        } else if self.connectedPeers[peerID] != nil {
            self.connectedPeers.removeValueForKey(peerID)
        }
    }
    
    // Received data from remote peer
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        if let json: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) {
            NSNotificationCenter.defaultCenter().postNotificationName(TLMultipeerMessageRecievedNotification, object: json)
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
