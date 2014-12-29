//
//  SpotifySearchTableViewController.swift
//  JookBox
//
//  Created by Andrew Barba on 12/29/14.
//  Copyright (c) 2014 Andrew Barba. All rights reserved.
//

import UIKit

protocol SpotifySearchDelegate {
    func searchControllerSelectedTrack(controller: SpotifySearchTableViewController, track: SPTPartialTrack)
}

class SpotifySearchTableViewController: UITableViewController, UITextFieldDelegate {
    
    @IBOutlet var searchTextField: UITextField! {
        didSet {
            searchTextField.delegate = self
        }
    }
    
    var delegate: SpotifySearchDelegate?
    var tracks: [SPTPartialTrack] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Search"
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.searchTextField.becomeFirstResponder()
    }
    
    @IBAction func handleCloseTapped(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Search
    
    func search(query: String) {
        Spotify.spotify.search(query) {
            results, error in
            self.tracks = results as [SPTPartialTrack]
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tracks.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Track Cell", forIndexPath: indexPath) as UITableViewCell
        let track = self.tracks[indexPath.row]
        cell.textLabel?.text = track.name
        if let artist = track.artists[0] as? SPTPartialArtist {
            cell.detailTextLabel?.text = artist.name
        } else {
            cell.detailTextLabel?.text = "Unknown"
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let track = self.tracks[indexPath.row]
        self.delegate?.searchControllerSelectedTrack(self, track: track)
    }
    
    // MARK: - Text field
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.search(textField.text)
        textField.resignFirstResponder()
        return true
    }
}
