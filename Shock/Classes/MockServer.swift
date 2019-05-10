//
//  MockAPI.swift
//  Shock
//
//  Created by Jack Newcombe on 27/06/2018.
//  Copyright © 2018 Just Eat. All rights reserved.
//

// Force tries are bad in the app but in a test-case it's good to have a crash
// if server unavailable
// swiftlint:disable force_try

import Foundation
import NIO
import NIOHTTP1

public class MockServer {
    
    private let host = "localhost"

	private let port: UInt16
    
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
    private let bundle: Bundle
	
    private var mockRoutes = [MockHTTPRoute]()
	
	public init(port: UInt16 = 9000, bundle: Bundle = Bundle.main) {
		self.port = port
        self.bundle = bundle
	}
	
	// MARK: Server managements
	
	public func start(priority: DispatchQoS.QoSClass = .default) {
        DispatchQueue.global().async {
            let bootStrap = ServerBootstrap(group: self.group)
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline().then {_ in
                        channel.pipeline.add(handler: MockHTTPHandler(bundle: self.bundle, routes: self.mockRoutes))
                    }
                }
                // I'm sure these are incredibly important, must work out why
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_IP), TCP_NODELAY), value: 1)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .serverChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            let channel = try! bootStrap.bind(host: self.host, port: Int(self.port)).wait()
            guard let localAddress = channel.localAddress else {
                fatalError("Unable to bind port \(self.port)")
            }
            print("Starting listening on \(localAddress)")
            try! channel.closeFuture.wait()
            print("Server shut down")
        }
	}
	
	public func stop() {
		try! group.syncShutdownGracefully()
        print("Server closed")
	}
	
	public var hostURL: String {
		return "http://\(host):\(port)"
	}
	
	// MARK: Mock setup
	
	public func setup(route: MockHTTPRoute) {
		self.mockRoutes.append(route)
	}
	
}
