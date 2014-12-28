//
//  AppDelegate.swift
//  JookBox
//
//  Created by Andrew Barba on 12/8/14.
//  Copyright (c) 2014 Andrew Barba. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let spotify = Spotify.spotify

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.        
        return true
    }

    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        if self.spotify.handleCallbackURL(url) {
            return true
        }
        return false
    }


}

