//
//  GRPClient.swift
//  CAPSTONE
//
//  Created by admin on 3/19/25.
//

import GRPCCore
import GRPCProtobuf
import GRPCCodeGen
import protoc_gen_grpc_swift
import GRPCProtobufCodeGen
import GRPCNIOTransportHTTP2
import NIO
import SwiftProtobuf

import GRPCCore
import GRPCNIOTransportHTTP2


struct GRPCClient {
    func runClient(detectionRequest: Signalq_Detection) async throws {
        try await withGRPCClient(
            transport: .http2NIOPosix(
                target: .ipv4(host: "127.0.0.1", port: 50051),
                transportSecurity: .plaintext
            )
        ) { client in
            // Explicitly specify the transport type for the client
            let detectionService = Signalq_DetectionService.Client(wrapping: client)


            try await sendDetection(using: detectionService, detectionRequest: detectionRequest)
        }
    }


    private func sendDetection(using detectionService: Signalq_DetectionService.ClientProtocol, detectionRequest: Signalq_Detection) async throws {
        print("→ Sending Detection Message")



        // Call gRPC method
        let response = try await detectionService.sendDetection(detectionRequest)
        print("Acknowledgement received: \(response.success)")
    }
}


