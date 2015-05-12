//
//  ConnectionManager.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 12/05/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Foundation


class ConnectionManager {
    
    static var published = [ConnectedEditor]()
    static var subscribed = [ConnectedEditor]()
    
    
    static func isPublished(editor: Editor) -> Bool {
        return self.published.filter({ $0.editor == editor }).count > 0
    }
    
    
    static func isSubscribed(editor: Editor) -> Bool {
        return self.subscribed.filter({ $0.editor == editor }).count > 0
    }
    
    
    static func isConnected(editor: Editor) -> Bool {
        return self.isPublished(editor) || self.isSubscribed(editor)
    }
 
    
    static func publish(editor: Editor) -> ConnectedEditor {
        let name = "\(editor.document.displayName) @ \(NSHost.currentHost().localizedName!)"
        let doc = { Document(editor.textStorage.string) }
        let docServer = DocServer(name: name, document: doc())
        let connectedEditor = ConnectedEditor(editor: editor, document: docServer)
        self.published.append(connectedEditor)
        return connectedEditor
    }
    
    
    static func unpublish(editor: Editor) {
        let publishedConnection = { editor in
            self.published.filter({ $0.editor == editor }).first
        }
        if let conn = publishedConnection(editor) {
            conn.document.disconnect()
            self.published = self.published.filter({ $0.editor != editor })
        }
    }
    
    
    static func subscribe(service: NSNetService, editor: Editor) -> ConnectedEditor {
        let client = DocClient(service: service, document: Document(editor.textStorage.string))
        let connectedEditor = ConnectedEditor(editor: editor, document: client)
        self.subscribed.append(connectedEditor)
        return connectedEditor
    }
    
}
