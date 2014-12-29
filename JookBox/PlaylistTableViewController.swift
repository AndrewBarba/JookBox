//
//  PlaylistTableViewController.swift
//  JookBox
//
//  Created by Andrew Barba on 12/29/14.
//  Copyright (c) 2014 Andrew Barba. All rights reserved.
//

import UIKit
import MultipeerConnectivity

typealias JBTrack = [String:String]

class PlaylistTableViewController: UITableViewController, SpotifySearchDelegate {
    
    let connect = Connect.connect
    let spotify = Spotify.spotify
    
    var isHost = false
    var playlistName: String!
    
    var peerID: MCPeerID?
    var playlist: [JBTrack] = [] {
        didSet {
            dispatch_async(dispatch_get_main_queue()) {
                println(self.playlist)
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.playlistName
        
        self.spotify.player.playbackDelegate = self
        
        NSNotificationCenter
            .defaultCenter()
            .addObserver(self, selector: "handleMessageRecieved:", name: MultipeerMessageRecievedNotification, object: nil)
        
        NSNotificationCenter
            .defaultCenter()
            .addObserver(self, selector: "handleClientConnected:", name: MultipeerClientConnectedNotification, object: nil)
        
        if self.isHost {
            self.connect.startAdvertising(self.playlistName)
        }
    }
    
    deinit {
        self.spotify.player.playbackDelegate = nil
    }
    
    @IBAction func handleStopTapped(sender: AnyObject) {
        if self.isHost {
            self.connect.stopAdvertising()
            self.connect.session.disconnect()
            self.spotify.player.playbackDelegate = nil
            self.spotify.player.stop(nil)
        } else {
            self.connect.session.disconnect()
        }
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.playlist.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Track Cell", forIndexPath: indexPath) as UITableViewCell
        let track = self.playlist[indexPath.row]
        cell.textLabel?.text = track["name"]
        cell.detailTextLabel?.text = track["artist"]
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return self.isHost && indexPath.row > 0
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            self.playlist.removeAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            self.sendPlaylist()
        }
    }
    
    // MARK: - Search
    
    func searchControllerSelectedTrack(controller: SpotifySearchTableViewController, track: SPTPartialTrack) {
        let newtrack: JBTrack = [
            "name": track.name,
            "artist": (track.artists[0] as SPTPartialArtist).name,
            "id": track.identifier
        ]
        self.playlist.append(newtrack)
        self.tableView.reloadData()
        self.dismissViewControllerAnimated(true, completion: nil)
        
        if self.isHost && self.playlist.count == 1 {
            self.spotify.playTrack(track.identifier)
        }
        
        if self.isHost {
            self.sendPlaylist()
        } else {
            self.sendTrack(newtrack)
        }
    }
    
    // MARK: - Segue
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "Search Segue" {
            let nav = segue.destinationViewController as UINavigationController
            let controller = nav.viewControllers[0] as SpotifySearchTableViewController
            controller.delegate = self
        }
    }
    
    // MARK: - Multipeer
    
    func handleClientConnected(notification: NSNotification) {
        if self.isHost {
            if let peerID = notification.object as? MCPeerID {
                let data = [
                    "method": "playlist",
                    "data": self.playlist
                ]
                Connect.connect.sendMessageToPeer(peerID, message: data)
            }
        }
    }
    
    func handleMessageRecieved(notification: NSNotification) {
        let object = notification.object as [String: AnyObject]
        let message = object["message"] as [String: AnyObject]
        if message["method"] as String == "track" {
            let track = message["data"] as JBTrack
            self.playlist.append(track)
            self.tableView.reloadData()
            if self.isHost && self.playlist.count == 1 {
                let id = track["id"]
                self.spotify.playTrack(id!)
            }
            self.sendPlaylist()
        } else if message["method"] as String == "playlist" {
            if let playlist = message["data"] as? [JBTrack] {
                self.playlist = playlist
            }
        }
    }
    
    func sendTrack(track: JBTrack) {
        if let peer = self.peerID {
            Connect.connect.sendMessageToPeer(peer, message: [
                "method": "track",
                "data": track
            ])
        }
    }
    
    func sendPlaylist() {
        let data = [
            "method": "playlist",
            "data": self.playlist
        ]
        Connect.connect.broadcastMessage(data)
    }

}

extension PlaylistTableViewController: SPTAudioStreamingPlaybackDelegate {
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: NSURL!) {
        if self.playlist.count > 0 {
            self.playlist.removeAtIndex(0)
            if self.playlist.count > 0 {
                let track = self.playlist[0]
                let id = track["id"]
                self.spotify.playTrack(id!)
            }
            self.sendPlaylist()
        }
    }
}
