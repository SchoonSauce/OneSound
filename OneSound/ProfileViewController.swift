//
//  ProfileViewController.swift
//  OneSound
//
//  Created by adam on 7/21/14.
//  Copyright (c) 2014 Adam Schoonmaker. All rights reserved.
//

import UIKit

let ProfileViewControllerNibName = "ProfileViewController"

class ProfileViewController: UIViewController {
    
    @IBOutlet weak var signOutButton: UIBarButtonItem?
    @IBOutlet weak var settingsButton: UIBarButtonItem?
    
    @IBOutlet weak var messageLabel1: UILabel?
    @IBOutlet weak var messageLabel2: UILabel?
    @IBOutlet weak var facebookSignInButton: UIButton?
    
    @IBOutlet weak var userImage: UIImageView?
    @IBOutlet weak var userNameLabel: UILabel?
    @IBOutlet weak var userUpvoteLabel: UILabel?
    @IBOutlet weak var userSongLabel: UILabel?
    @IBOutlet weak var userHotnessLabel: UILabel?
    @IBOutlet weak var userUpvoteIcon: UIImageView?
    @IBOutlet weak var userSongIcon: UIImageView?
    @IBOutlet weak var userHotnessIcon: UIImageView?
    @IBOutlet weak var spacer1: UIView?
    @IBOutlet weak var spacer2: UIView?
    @IBOutlet weak var spacer3: UIView?
    @IBOutlet weak var spacer4: UIView?
    @IBOutlet weak var messageLabel3: UILabel?
    @IBOutlet weak var messageLabel4: UILabel?
    
    @IBOutlet weak var storiesTable: UITableView?
    
    var storyTableStories: [String] = ["Much text that is here for the first story", "Such text for the second story", "Text for the third story wow", "Even more text for the fourth story"]

    var loadedFullUserInfoFromDefaults = false

    @IBAction func signIntoFacebook(sender: AnyObject) {
        let fbSession = FBSession.activeSession()
        // Only sign in if not already signed in
        
        if LocalUser.sharedUser.guest == true {
            // Make sure if a guest is clicking the button, they can try signing in
            fbSession.closeAndClearTokenInformation()
        }
        
        if (fbSession.state != FBSessionState.Open) && (fbSession.state != FBSessionState.OpenTokenExtended) {
            // was using FBSessionStateOpen and FBSessionStateOpenTokenExtended before using forked Facebook SDK version for Swift
            FBSession.openActiveSessionWithReadPermissions(facebookSessionPermissions, allowLoginUI: true, completionHandler: { session, state, error in
                let delegate = UIApplication.sharedApplication().delegate as AppDelegate
                // Call the app delegate's sessionStateChanged:state:error method to handle session state changes
                delegate.sessionStateChanged(session, state: state, error: error)
                }
            )
        }
    }
    
    @IBAction func signOut(sender: AnyObject) {
        // Only proceeds if refresh leaves view controller with a valid user
        if refresh() {
            if LocalUser.sharedUser.guest == true {
                // Let the guest know that signing out a guest account doesn't really do anything
                let alert = UIAlertView(title: "Signing Out Guest", message: "Signing out of guest account deletes current guest account and signs into a new guest account. To sign into a full account, login with Facebook, and your guest account is automatically signed out.", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Ok")
                alert.tag = 101
                alert.show()
            } else {
                let alert = UIAlertView(title: "Signing Out", message: "Continue signing out to sign in with a different Facebook account, or to downgrade to a guest account. Guests can only join and use parties, and do not have social features such as stat tracking, Stories, Following, etc.", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Ok")
                alert.tag = 102
                alert.show()
            }
        }
    }
    
    @IBAction func changeSettings(sender: AnyObject) {
        let loginStoryboard = UIStoryboard(name: "Login", bundle: nil)
        let loginViewController = loginStoryboard.instantiateViewControllerWithIdentifier("LoginViewController") as LoginViewController
        loginViewController.accountAlreadyExists = true
        loginViewController.delegate = self
        let navC = UINavigationController(rootViewController: loginViewController)
        
        let delegate = UIApplication.sharedApplication().delegate as AppDelegate
        let fvc = delegate.revealViewController!.frontViewController
        fvc.presentViewController(navC, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Profile"
        
        // Setup the revealViewController to work for this view controller,
        // add its sideMenu icon to the nav bar
        let revealController = revealViewController()
        revealController.panGestureRecognizer()
        revealController.tapGestureRecognizer()
        let revealButtonItem = UIBarButtonItem(image: UIImage(named: "sideMenuToggleIcon"), style: UIBarButtonItemStyle.Plain, target: revealController, action: "revealToggle:")
        navigationItem.leftBarButtonItem = revealButtonItem
        
        disableButtons()
        hideMessages()
        setUserInfoHidden(true)
        setStoriesTableToHidden(true)
        
        userImage!.layer.cornerRadius = 5.0
        
        facebookSignInButton!.backgroundColor = UIColor.blue()
        facebookSignInButton!.layer.cornerRadius = 3.0
        
        // Make view respond to network reachability changes
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "refresh", name: AFNetworkingReachabilityDidChangeNotification, object: nil)
        // Make sure view knows the user is setup so it won't keep displaying 'Not signed into account' when there is no  internet connection when app launches and then the network comes back and LocalUser is setup
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "refresh", name: LocalUserInformationDidChangeNotification, object: nil)
        //NSNotificationCenter.defaultCenter().addObserver(self, selector: "refresh", name: FacebookSessionChangeNotification, object: nil)
        
        // Try getting saved info from UserDefaults for full users
        // Makes it so data shows up right away instead of blank screen
        loadedFullUserInfoFromDefaults = setUserProfileInfoFromUserDefaults()
        
        // Register the cell
        var nib = UINib(nibName: "StoryTableViewCell", bundle: nil)
        storiesTable!.registerNib(nib, forCellReuseIdentifier: storyCellIdentifier)
    }
    
    override func viewWillAppear(animated: Bool) {
        refresh()
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        /*
        disableButtons()
        hideMessages()
        setUserInfoHidden(true)
        setStoriesTableToHidden(true)
        */
    }
    
    func refresh() -> Bool {
        // Returns true if refreshed with a valid user variable for controller
        var validUser = false
        println("refreshing ProfileViewController")
        
        if AFNetworkReachabilityManager.sharedManager().reachable {
            let localUser = LocalUser.sharedUser
            if LocalUser.sharedUser.setup == true {
                validUser = true
                LocalUser.sharedUser.updateLocalUserInformationFromServer(
                    addToSuccess: {
                        if LocalUser.sharedUser.guest == true {
                            self.setUserInfoHidden(true)
                            self.setStoriesTableToHidden(true)
                            self.showMessages("Guests can only join and use parties", detailLine: "Please sign in with Facebook to use social features", showMessageBelowUserInfo: false)
                            self.facebookSignInButton!.hidden = false
                            self.signOutButton!.enabled = false
                            self.settingsButton!.enabled = false
                        } else {
                            // Full accounts
                            self.facebookSignInButton!.hidden = true
                            self.signOutButton!.enabled = true
                            self.settingsButton!.enabled = true
                            self.setStoriesTableToHidden(false)
                            self.hideMessages()
                            self.setUserInfoHidden(false)
                        }
                    }
                )
            } else {
                if loadedFullUserInfoFromDefaults {
                    setVisibilityOfUserInfoToHidden(false)
                    setStoriesTableToHidden(true)
                    showMessages("Could not connect to account", detailLine: "Please connect to the internet and restart One Sound", showMessageBelowUserInfo: true)
                } else {
                    setUserInfoHidden(true)
                    setStoriesTableToHidden(true)
                    showMessages("Not signed into an account", detailLine: "Please connect to the internet and restart One Sound", showMessageBelowUserInfo: false)
                }
                disableButtons()
            }
        } else {
            if loadedFullUserInfoFromDefaults {
                setVisibilityOfUserInfoToHidden(false)
                setStoriesTableToHidden(true)
                showMessages("Not connected to the internet", detailLine: "Please connect to the internet to use One Sound", showMessageBelowUserInfo: true)
            } else {
                setUserInfoHidden(true)
                setStoriesTableToHidden(true)
                showMessages("Not connected to the internet", detailLine: "Please connect to the internet to use One Sound", showMessageBelowUserInfo: false)
            }
            
            disableButtons()
        }
        
        return validUser
    }
    
    func setUserInfoHidden(hidden: Bool) {
        setVisibilityOfUserInfoToHidden(hidden)
        
        if !hidden {
            let user = LocalUser.sharedUser
            
            setUserInfoLabelsText(upvoteLabel: userUpvoteLabel, numUpvotes: user.upvoteCount, songLabel: userSongLabel, numSongs: user.songCount, hotnessLabel: userHotnessLabel, percentHotness: user.hotnessPercent, userNameLabel: userNameLabel, userName: user.name)

            
            if LocalUser.sharedUser.photo != nil {
                userImage!.image = LocalUser.sharedUser.photo
            } else {
                userImage!.backgroundColor = LocalUser.sharedUser.colorToUIColor
            }
        }
    }
    
    func setVisibilityOfUserInfoToHidden(hidden: Bool) {
        userImage!.hidden = hidden
        userNameLabel!.hidden = hidden
        userUpvoteLabel!.hidden = hidden
        userSongLabel!.hidden = hidden
        userHotnessLabel!.hidden = hidden
        userUpvoteIcon!.hidden = hidden
        userSongIcon!.hidden = hidden
        userHotnessIcon!.hidden = hidden
        spacer1!.hidden = hidden
        spacer2!.hidden = hidden
        spacer3!.hidden = hidden
        spacer4!.hidden = hidden
    }
    
    func setStoriesTableToHidden(hidden: Bool) {
        storiesTable!.hidden = hidden
    }
    
    func setUserProfileInfoFromUserDefaults() -> Bool {
        // Returns true if successfully set the info
        var gotUserProfileInfo = false
        
        let defaults = NSUserDefaults.standardUserDefaults()
        let userSavedName = defaults.objectForKey(userNameKey) as? String
        if userSavedName != nil {
            // If user information can be retreived (assumes getting ANY user info means the rest is saved)
            println("found userSavedName; assuming that means the rest of info is saved")
            let userSavedIsGuest = defaults.boolForKey(userGuestKey)
            if userSavedIsGuest == false {
                // If a full user
                println("saved user is a full user")
                if let imageData = defaults.objectForKey(userPhotoUIImageKey) as? NSData! {
                    println("image data for full user valid, use their image and set up other info")
                    let userUpvoteCount = defaults.integerForKey(userUpvoteCountKey)
                    let userSongCount = defaults.integerForKey(userSongCountKey)
                    let userHotnessPercent = defaults.integerForKey(userHotnessPercentKey)
                    
                    setUserInfoLabelsText(upvoteLabel: userUpvoteLabel, numUpvotes: userUpvoteCount, songLabel: userSongLabel, numSongs: userSongCount, hotnessLabel: userHotnessLabel, percentHotness: userHotnessPercent, userNameLabel: userNameLabel, userName: userSavedName)
                    
                    if imageData != nil {
                        userImage!.image = UIImage(data: imageData)
                    } else {
                        let userSavedColor = defaults.objectForKey(userColorKey) as? String
                        if userSavedColor != nil  {
                            userImage!.backgroundColor = LocalUser.colorToUIColor(userSavedColor!)
                        } else {
                            // In case the userSavedColor info can't be retrieved
                            userImage!.backgroundColor = UIColor.grayDark()
                        }
                    }
                    
                    setVisibilityOfUserInfoToHidden(false)
                    
                    gotUserProfileInfo = true
                }
            }
        }
        
        return gotUserProfileInfo
    }
    
    func showMessages(mainLine: String?, detailLine: String?, showMessageBelowUserInfo: Bool) {
        if showMessageBelowUserInfo {
            if mainLine != nil {
                messageLabel3!.alpha = 1
                messageLabel3!.text = mainLine
            }
            if detailLine != nil {
                messageLabel4!.alpha = 1
                messageLabel4!.text = detailLine
            }
            messageLabel1!.alpha = 0
            messageLabel1!.text = ""
            messageLabel2!.alpha = 0
            messageLabel2!.text = ""
            
        } else {
            if mainLine != nil {
                messageLabel1!.alpha = 1
                messageLabel1!.text = mainLine
            }
            if detailLine != nil {
                messageLabel2!.alpha = 1
                messageLabel2!.text = detailLine
            }
            messageLabel3!.alpha = 0
            messageLabel3!.text = ""
            messageLabel4!.alpha = 0
            messageLabel4!.text = ""
        }
    }
    
    func hideMessages() {
        messageLabel1!.alpha = 0
        messageLabel1!.text = ""
        messageLabel2!.alpha = 0
        messageLabel2!.text = ""
        messageLabel3!.alpha = 0
        messageLabel3!.text = ""
        messageLabel4!.alpha = 0
        messageLabel4!.text = ""
    }
    
    func disableButtons() {
        signOutButton!.enabled = false
        settingsButton!.enabled = false
        facebookSignInButton!.hidden = true
    }
}

extension ProfileViewController: UIAlertViewDelegate {
    func alertView(alertView: UIAlertView!, clickedButtonAtIndex buttonIndex: Int) {
        if alertView.tag == 101 {
            // If guest is trying to log out
            if buttonIndex == 1 {
                // If guest wants to sign out, delete all info and get new guest account, then refresh
                LocalUser.sharedUser.deleteAllSavedUserInformation()
                LocalUser.sharedUser.setupGuestAccount()
                refresh()
            }
        } else if alertView.tag == 102 {
            // If full user is trying to sign out, let the FB session state change handle sign out and updating to new guest account
            if buttonIndex == 1 {
                FBSession.activeSession().closeAndClearTokenInformation()
                refresh()
            }
        }
    }
}

extension ProfileViewController: LoginViewControllerDelegate {
    func loginViewControllerCancelled() {
        refresh()
    }
}

extension ProfileViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if UIScreen.mainScreen().bounds.height < 500 {
            // For iPhones w/ shorter screen show 2 cells
            return 3
        } else {
            // For iPhone w/ taller screens show 3 cells
            return 4
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // TODO: add functionality for stories
        let cell = storiesTable!.dequeueReusableCellWithIdentifier(storyCellIdentifier, forIndexPath: indexPath) as StoryTableViewCell
        cell.storyLabel.text = storyTableStories[indexPath.row]
        cell.customSeperator.hidden = true
        cell.backgroundColor = UIColor.clearColor()
        return cell
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        let tableHeight = storiesTable!.frame.height
        if UIScreen.mainScreen().bounds.height < 500 {
            // For iPhones w/ shorter screen
            return tableHeight / 3
        } else {
            // For iPhone w/ taller screens
            return tableHeight / 4
        }
    }
    
    func tableView(tableView: UITableView!, shouldHighlightRowAtIndexPath indexPath: NSIndexPath!) -> Bool {
        return false
    }
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        // TODO: add functionality for stories
    }
}
