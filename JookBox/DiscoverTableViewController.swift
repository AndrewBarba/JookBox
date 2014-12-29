//
//  DiscoverTableViewController.swift
//  JookBox
//
//  Created by Andrew Barba on 12/29/14.
//  Copyright (c) 2014 Andrew Barba. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class DiscoverTableViewController: UITableViewController {
    
    let connect = Connect.connect
    var nearbyPeers: [MCPeerID] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Discover"
        
        NSNotificationCenter
            .defaultCenter()
            .addObserver(self, selector: "handleNearbyPeersChangedNotification:", name: MultipperNearbyPeersChangedNotification, object: nil)
        
        NSNotificationCenter
            .defaultCenter()
            .addObserver(self, selector: "loggedIntoSpotify:", name: SpotifyLoginCompleteNotificationKey, object: nil)
        
        self.connect.discoverPeers(UIDevice.currentDevice().name)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.nearbyPeers.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Nearby Cell", forIndexPath: indexPath) as UITableViewCell
        let peerID = self.nearbyPeers[indexPath.row]
        let info = self.connect.peerInfo[peerID]
        cell.textLabel?.text = info
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60.0
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let peerID = self.nearbyPeers[indexPath.row]
        let name = self.connect.peerInfo[peerID] ?? "Unknown"
        self.connect.connectToPeer(peerID) {
            println("Connected")
        }
        let object = [
            "name": name,
            "peer": peerID,
            "host": false
        ]
        self.performSegueWithIdentifier("Playlist Segue", sender: object)
    }
    
    // MARK: - Near By Delegate
    
    func handleNearbyPeersChangedNotification(notification: NSNotification) {
        var peers: [MCPeerID] = self.connect.nearbyPeers
        peers.sort() { $0.displayName < $1.displayName }
        self.nearbyPeers = peers
        self.tableView.reloadData()
    }
    
    // MARK: - Segue
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "Playlist Segue" {
            let nav = segue.destinationViewController as UINavigationController
            let controller = nav.viewControllers[0] as PlaylistTableViewController
            let object = sender as [String:AnyObject]
            controller.playlistName = object["name"] as String
            controller.isHost = object["host"] as Bool
            controller.peerID = object["peer"] as MCPeerID?
        }
    }

}

// MARK: - Start Party

extension DiscoverTableViewController: UIAlertViewDelegate {
    
    @IBAction func handleStartPartyTapped(sender: AnyObject) {
        if Spotify.spotify.isLoggedIn() {
            self.showStartParty()
        } else {
            Spotify.spotify.login()
        }
    }
    
    func loggedIntoSpotify(notification: NSNotification) {
        self.showStartParty()
    }
    
    private func showStartParty() {
        let alert = UIAlertView(title: "Start a Party", message: "Enter a party name", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Start Party")
        alert.alertViewStyle = UIAlertViewStyle.PlainTextInput
        alert.textFieldAtIndex(0)!.autocapitalizationType = UITextAutocapitalizationType.Words
        alert.show()
    }
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex > 0 {
            let name = alertView.textFieldAtIndex(0)!.text
            let object = [ "name": name, "host": true ]
            self.performSegueWithIdentifier("Playlist Segue", sender: object)
        }
    }
}






