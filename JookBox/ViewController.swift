//
//  ViewController.swift
//  JookBox
//
//  Created by Andrew Barba on 12/8/14.
//  Copyright (c) 2014 Andrew Barba. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let spotify = Spotify.spotify
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "ready:", name: SpotifyLoginCompleteNotificationKey, object: nil)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.spotify.login()
    }
    
    func ready(notification: NSNotification) {
        println("Ready!")
        
        self.spotify.search("rather be") {
            results, error in
            let track = results[0] as SPTPartialTrack
            self.spotify.playTrack(track.identifier)
        }
    }
}

