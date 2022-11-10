//
//  WebSocketRequest.swift
//  ARAppointment
//
//  Created by burisowa on 2022/11/01.
//

import Foundation

class WebSocketRequest: NSObject, WebSocketProtocol {
    
    private var webSocket: URLSessionWebSocketTask?
    
    func setup(url: String) {
        let urlSession = URLSession(configuration: .default,
                                    delegate: self,
                                    delegateQueue: .main)
        webSocket = urlSession.webSocketTask(with: URL(string: url)!)
        if let webSocket = webSocket {
            webSocket.resume()
        } else {
            print("setup error")
        }
    }
    
    func disconnect() {
        guard let webSocket = webSocket else {
            return
        }
        webSocket.cancel()
    }
    
    func send(_ message: String) {
        guard let webSocket = webSocket else {
            return
        }
        let msg = URLSessionWebSocketTask.Message.string("aaa")
        webSocket.send(msg) { error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
        
    }
    
    func receive() {
        guard let webSocket = webSocket else {
            return
        }
        webSocket.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    break
                case .string(let str):
                    break
                }
                break
            case .failure(let error):
//                let nsError = error as NSError
//                print(String(format: "Error oooooooooooo %@", nsError.localizedDescription))
                print(error.localizedDescription)
                break
            }
        }
    }
    
}

extension WebSocketRequest: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
    }

    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
    }
    
}
