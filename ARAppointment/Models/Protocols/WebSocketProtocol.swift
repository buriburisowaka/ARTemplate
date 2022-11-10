//
//  WebSocketProtocol.swift
//  ARAppointment
//
//  Created by burisowa on 2022/11/03.
//

import Foundation

protocol WebSocketProtocol {
    func setup(url: String)
    func disconnect()
    func send(_ message: String)
    func receive()
}
