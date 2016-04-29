//
//  DataManager.swift
//  Overwatch
//
//  Created by Andrew Trice on 3/4/16.
//  Copyright © 2016 Andrew Trice. All rights reserved.
//

import Foundation


class DataManager: NSObject, CDTReplicatorDelegate {
    static let sharedInstance = DataManager()
    
    var manager: CDTDatastoreManager? = nil
    var replicatorFactory: CDTReplicatorFactory? = nil
    var datastore: CDTDatastore? = nil
    var replicator: CDTReplicator? = nil
    var pushReplication: CDTPushReplication? = nil
    
    override init() {
        super.init()
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
            
            manager = try CDTDatastoreManager(directory: documentsPath)
            // Create and start the replicator -- -start is essential!
            replicatorFactory = CDTReplicatorFactory(datastoreManager: manager)
            
            datastore = try manager!.datastoreNamed("overwatch");
            
            ViewController.sharedInstance!.debug("Local datastore initialized")
            
            setupReplication()
            
        } catch {
            print("Encountered an error: \(error)")
        }
    }
    
    
    
    
    
    
    
    
    func setupReplication() {
        
        if let oldReplicator = replicator {
            oldReplicator.delegate = nil
            oldReplicator.stop()
        }
        
        do {
        
            let s = "https://4690f31b-c2a1-4d73-a90a-560ce540122d-bluemix:4ffb1f140acc2b7d903466a72825e607c42fc6e273cf8695c96cc88d47010649@4690f31b-c2a1-4d73-a90a-560ce540122d-bluemix.cloudant.com/overwatch"
            
            let remoteDatabaseURL = NSURL(string: s)
            
            // Replicate from the local to remote database
            pushReplication = CDTPushReplication(source: datastore, target: remoteDatabaseURL)
            replicator =  try replicatorFactory!.oneWay(pushReplication)
            replicator!.delegate = self
        
            try self.replicator!.start()
        } catch {
            print("Encountered an error: \(error)")
        }
    }
    
    
    
    
    
    
    
    
    func saveData(data:NSMutableDictionary, attachmentFile:String) {
        
        do {
            ViewController.sharedInstance!.debug("Creating document:\n\(data)")
            
            let rev = CDTDocumentRevision(docId: nil)
            rev.body = data
            
            let attachment = CDTUnsavedFileAttachment(path: attachmentFile,
                                                name: "image.jpg",
                                                type: "image/jpeg")
            rev.attachments[attachment.name] = attachment
            
            let revision = try datastore!.createDocumentFromRevision(rev)
            debug("Document created: \(revision.docId)")
            
            if !self.replicator!.isActive() {
                setupReplication()
            }
        } catch {
            debug("Encountered an error: \(error)")
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    func replicatorStateString(state:CDTReplicatorState) -> String {
        switch state {
        case CDTReplicatorState.Complete:
            return "complete"
        case CDTReplicatorState.Error:
            return "ERROR"
        case CDTReplicatorState.Pending:
            return "pending"
        case CDTReplicatorState.Started:
            return "started"
        case CDTReplicatorState.Stopped:
            return "stopped"
        case CDTReplicatorState.Stopping:
            return "stopping"
        }
    }
    
    func debug(value:String) {
        dispatch_async(dispatch_get_main_queue(),{
            ViewController.sharedInstance!.debug(value)
        })
    }
    
    @objc func replicatorDidChangeState(replicator: CDTReplicator!) {
        debug("CDT Replication: \(self.replicatorStateString(replicator.state))")
    }
    
    @objc func replicatorDidChangeProgress(replicator: CDTReplicator!) {
        debug("Replication: \(replicator.changesProcessed)/\(replicator.changesTotal)")
    }
    
    @objc func replicatorDidError(replicator: CDTReplicator!, info: NSError!) {
        debug("CDT Replication error: \(info)")
    }
    
}