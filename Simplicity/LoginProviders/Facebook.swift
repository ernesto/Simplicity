//
//  Facebook.swift
//  Simplicity
//
//  Created by Edward Jiang on 5/10/16.
//  Copyright © 2016 Stormpath. All rights reserved.
//

import Foundation

/**
 Class implementing Facebook login's mobile implicit grant flow.
 
 ## Using Facebook Login in your app.
 
 To get started, you first need to [register an 
 application](https://developers.facebook.com/?advanced_app_create=true) with 
 Facebook. After registering your app, go into your app dashboard's settings 
 page. Click "Add Platform", and fill in your Bundle ID, and turn "Single Sign 
 On" on.
 
 Finally, open up your App's Xcode project and go to the project's info tab. 
 Under "URL Types", add a new entry, and in the URL schemes form field, type in 
 `fb[APP_ID_HERE]`, replacing `[APP_ID_HERE]` with your Facebook App ID.
 
 Then, you can initiate the login screen by calling:
 
 ```
 Simplicity.login(Facebook()) { (accessToken, error) in
    // Insert code here
 }
 ```
 */
public class Facebook: OAuth2 {
    /// Facebook Auth Type
    public var authType = FacebookAuthType.None
    
    /// An array with query string parameters for the authorization URL.
    override public var authorizationURLParameters: [String : String?] {
        var result = super.authorizationURLParameters
        result["auth_type"] = authType.rawValue
        return result
    }
    
    /**
     Initializes the Facebook login object. Auto configures based on the URL 
     scheme you have in your app.
     */
    public init() {
        // Search for URL Scheme, error if not there
        
        guard let urlScheme = Helpers.registeredURLSchemes(filter: {$0.hasPrefix("fb")}).first,
            let range = urlScheme.range(of: "\\d+", options: .regularExpression) else {
                preconditionFailure("You must configure your Facebook URL Scheme to use Facebook login.")
        }
        let clientId = urlScheme.substring(with: range)
        let authorizationEndpoint = URL(string: "https://www.facebook.com/dialog/oauth")!
        let redirectEndpoint = URL(string: urlScheme + "://authorize")!
        
        super.init(clientId: clientId, authorizationEndpoint: authorizationEndpoint, redirectEndpoint: redirectEndpoint, grantType: .Implicit)
    }
    
    /**
     Handles the resulting link from the OAuth Redirect
     
     - parameters:
     - url: The OAuth redirect URL
     - callback: A callback that returns with an access token or NSError.
     */
    override public func linkHandler(_ url: URL, callback: @escaping ExternalLoginCallback) {
        switch grantType {
        case .AuthorizationCode:
            preconditionFailure("Authorization Code Grant Type Not Supported")
        case .Implicit:
            // Get the access token, and check that the state is the same
            guard let accessToken = url.fragmentDictionary["access_token"], url.fragmentAndQueryDictionary["state"] == state else {
                /**
                 Facebook's mobile implicit grant type returns errors as
                 query. Don't think it's a huge issue to be liberal in looking
                 for errors, so will check both.
                 */
                if let error = OAuth2Error.error(url.fragmentAndQueryDictionary) {
                    callback(nil, nil, nil, error)
                } else {
                    callback(nil, nil, nil, LoginError.InternalSDKError)
                }
                return
            }
            
            self.loadProfile(accessToken: accessToken, handler: { profile in
                callback(accessToken, nil, profile, nil)
            })
        case .Custom:
            preconditionFailure("Custom Grant Type Not Supported")
        }
    }
    
    private func loadProfile(accessToken: String, handler: @escaping ([String: Any]?) -> Void) {
        let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
        let url = URL(string: "https://graph.facebook.com/me?fields=email,name&access_token=" + accessToken)!
        let request = URLRequest(url: url)
        
        let task = session.dataTask(with: request) { (data, response, error) -> Void in
            guard let data = data, let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                handler(nil)
                return
            }
            handler(json)
        }
        task.resume()
        
    }
}

/**
 Facebook supports an OAuth extension that allows you to do additional things 
 with its login page.
 */
public enum FacebookAuthType: String {
    /**
     Re-requests permissions from the user. Otherwise they will login (but 
     still with declined scopes)
     */
    case Rerequest = "rerequest",
    
    /// Asks the user to type in their password again.
    Reauthenticate = "reauthenticate",
    
    /// None
    None = ""
}
