//
//  RabbitDocClient.swift
//  CoPilot
//
//  Created by Sven A. Schmidt on 02/11/2015.
//  Copyright © 2015 feinstruktur. All rights reserved.
//

import Foundation


class RabbitDocClient: DocNode {

    private var socket: Socket?
    private var connection: DisplayName?


    init(name: String = "DocClient", connectionId: NSUUID, document: Document) {
        super.init(name: name, document: document)

        self.connection = connectionId.UUIDString
        self.socket = RabbitSocket(connectionId: connectionId.UUIDString)
        self.configureSocket()
        self.socket?.open()
    }


    init(name: String = "DocClient", url: NSURL, document: Document) {
        super.init(name: name, document: document)

        self.connection = url.absoluteString ?? "Unknown remote document"
        self.socket = WebSocket(url: url) // TODO: rabbit socket alternative
        self.configureSocket()
        self.socket?.open()
    }


    func configureSocket() {
        self.socket?.onConnect = {
            self.socket?.send(Command(name: self.name))
        }
        self.socket?.onReceive = self.onReceive
        self.socket?.onDisconnect = { error in
            // println("### client.onDisconnect")
            self.connection = nil
            self.onDisconnect?(error)
        }
    }


    func onReceive(msg: Message) {
        guard let data = msg.data else {
            print("message does not contain data")
            return
        }

        let cmd = Command(data: data)
        // println("#### client cmd: \(cmd)")
        switch cmd {
        case .Doc(let doc):
            self.commit(doc)
        case .Update(let changes):
            let res = apply(self._document, changeSet: changes)
            if res.succeeded {
                self.commit(res.value!)
            } else {
                // attempt merge
                if let ancestor = self.revisions.objectForKey(changes.baseRev) as? String {
                    let mine = self._document.text
                    let res = apply(ancestor, patches: changes.patches)
                    if let yours = res.value,
                        let merged = merge(mine, ancestor: ancestor, yours: yours) {
                            self.commit(Document(merged))
                    } else {
                        self.requestReset()
                    }
                } else {
                    self.requestReset()
                }
            }
        case .GetDoc:
            self.socket?.send(Command(document: self._document))
        case .Cursor(let selection):
            self._onCursorUpdate?(selection)
        default:
            print("messageHandler: ignoring command: \(cmd)")
        }
    }


    func requestReset() {
        // request original document in order to re-sync
        // print("#### client: requesting reset")
        self.socket?.send(Command.GetDoc)
    }

}


extension RabbitDocClient: DocumentConnectable {

    func update(newDocument: Document) {
        if let changes = Changeset(source: self._document, target: newDocument) {
            self.docThrottle.execute {
                self._document = newDocument
                self.socket?.send(Command(update: changes))
            }
        }
    }


    func update(selection: Selection) {
        self.selThrottle.execute {
            self.socket?.send(Command(selection: selection))
        }
    }


    func disconnect() {
        self.socket?.close()
    }


    var connections: [DisplayName] {
        if let c = self.connection {
            return [c]
        } else {
            return [DisplayName]()
        }
    }
    
}

