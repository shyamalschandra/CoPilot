//
//  DocServer.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 05/05/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Cocoa
import FeinstrukturUtils


typealias MessageDocumentHandler = ((Message, Document) -> Void)


func messageHandler(documentProvider: DocumentProvider, update: MessageDocumentHandler) -> MessageHandler {
    return { msg in
        let cmd = Command(data: msg.data!)
        switch cmd {
        case .Doc(let doc):
            update(msg, doc)
        case .Update(let changes):
            let res = apply(documentProvider(), changes)
            if res.succeeded {
                update(msg, res.value!)
            } else {
                println("messageHandler: applying patch failed: \(res.error!.localizedDescription)")
            }
        default:
            println("messageHandler: ignoring command: \(cmd)")
        }
    }
}


class DocServer {
    
    private var server: Server! = nil
    private var _document: Document
    private var _onUpdate: UpdateHandler?
    private var timer: Timer!
    private var docProvider: DocumentProvider!

    var document: Document { return self._document }

    init(name: String, service: BonjourService = CoPilotService, document: Document) {
        self._document = document
        self.server = {
            let s = Server(name: name, service: service)
            s.onConnect = { ws in
                // initialize client on connect
                let cmd = Command(document: self._document)
                ws.send(cmd.serialize())
                
                ws.onReceive = messageHandler({ self._document }, { msg, doc in
                    self._document = doc
                    self.server.broadcast(msg.data!, exclude: ws)
                    self.onUpdate?(doc)
                })
            }
            s.start()
            return s
            }()
    }
    
    // TODO: do we really need polling? - remove
    func poll(interval: NSTimeInterval = 0.5, docProvider: DocumentProvider) {
        self.docProvider = docProvider
        self.timer = Timer(interval: interval) {
            self.update(self.docProvider())
        }
    }


    func stop() {
        self.server.stop()
    }

}


extension DocServer: ConnectedDocument {

    var onUpdate: UpdateHandler? {
        get { return self._onUpdate }
        set { self._onUpdate = newValue }
    }
    
    
    func update(newDocument: Document) {
        if let changes = Changeset(source: self._document, target: newDocument) {
            if let changes = Changeset(source: self._document, target: newDocument) {
                self.server.broadcast(Command(update: changes).serialize())
                self._document = newDocument
            }
        }
    }

    
    func disconnect() {
        self.server.stop()
    }
    
}
