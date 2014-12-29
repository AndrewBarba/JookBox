//
//  Spotify.swift
//  JookBox
//
//  Created by Andrew Barba on 12/20/14.
//  Copyright (c) 2014 Andrew Barba. All rights reserved.
//

import Foundation

/**
    Constants
*/
private let kSpotifyClientId = "f20136912ad74106bb70baa219b390d9"
private let kSpotifySwapUrl = "https://jookbox.herokuapp.com/swap"
private let kSpotifyCallbackUrl = "jookbox-spotify://spotify/auth"

/**
    Notifications
*/
public let SpotifyLoginCompleteNotificationKey = "com.abarba.spotify.login.complete"
public let SpotifyLoginFailedNotificationKey = "com.abarba.spotify.login.failed"

/**
    Private Singleton
*/
private let _Spotify = Spotify()

public class Spotify {
    
    /**
        Singleton
    */
    class var spotify: Spotify {
        return _Spotify
    }
    
    /**
        Spotify
    */
    private var session: SPTSession?
    private let player = SPTAudioStreamingController(clientId: kSpotifyClientId)
    
    /**
        Initialization
    */
    init() {}
}

// MARK: - Login

extension Spotify {
    
    public func login() {
        let auth = SPTAuth.defaultInstance()
        let url = auth.loginURLForClientId(kSpotifyClientId, declaredRedirectURL: NSURL(string: kSpotifyCallbackUrl), scopes: [SPTAuthStreamingScope])
        UIApplication.sharedApplication().openURL(url)
    }
    
    public func isLoggedIn() -> Bool {
        return self.session != nil
    }
}

// MARK: - Playback

extension Spotify {
    
    public func playTrack(identifier: String) {
        let uri = NSURL(string: "spotify:track:\(identifier)")
        self.player.playURI(uri, callback: nil)
    }
}

// MARK: - Search

extension Spotify {
    
    public func search(query: String, complete: ([AnyObject], NSError?)->()) {
        SPTRequest.performSearchWithQuery(query, queryType: SPTSearchQueryType.QueryTypeTrack, session: self.session) {
            _error, _page in
            if let page = _page as? SPTListPage {
                complete(page.items, nil)
            } else {
                complete([], _error)
            }
        }
    }
}

// MARK: - URL's

extension Spotify {
    
    private func canOpenURL(url: NSURL) -> Bool {
        return SPTAuth.defaultInstance().canHandleURL(url, withDeclaredRedirectURL: NSURL(string: kSpotifyCallbackUrl))
    }
    
    public func handleCallbackURL(url: NSURL) -> Bool {
        if self.canOpenURL(url) {
            SPTAuth.defaultInstance().handleAuthCallbackWithTriggeredAuthURL(url, tokenSwapServiceEndpointAtURL: NSURL(string: kSpotifySwapUrl)) {
                _error, _session in
                
                if let session = _session {
                    self.session = session
                    self.player.loginWithSession(session) {
                        _error in
                        NSNotificationCenter.defaultCenter().postNotificationName(SpotifyLoginCompleteNotificationKey, object: session)
                    }
                } else {
                    NSNotificationCenter.defaultCenter().postNotificationName(SpotifyLoginFailedNotificationKey, object: _error)
                }
            }
            return true
        } else {
            return false
        }
    }
}
