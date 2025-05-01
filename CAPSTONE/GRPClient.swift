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

// Import transport protocol for gRPC client
import GRPCCore
import GRPCNIOTransportHTTP2

// GRPCClient encapsulates gRPC calls to the detection service
struct GRPCClient {
    /// Run the client to send detection data over gRPC
    func runClient(detections: Signalq_Detections) async throws {
        // Establish gRPC client connection using HTTP/2 transport
        try await withGRPCClient(
            transport: .http2NIOPosix(
                target: .ipv4(host: "127.0.0.1", port: 50051),
                transportSecurity: .plaintext
            )
        ) { client in
            // Wrap transport client in detection service client
            let detectionService = Signalq_DetectionService.Client(wrapping: client)

            // Send detection payload to service
            try await sendDetection(using: detectionService, detections: detections)
        }
    }

    /// Send detection message to the detection service and print acknowledgement
    private func sendDetection(
        using detectionService: Signalq_DetectionService.ClientProtocol,
        detections: Signalq_Detections
    ) async throws {
        // Indicate start of send operation
        print("→ Sending Detection Message")

        // Invoke gRPC method on detection service
        let response = try await detectionService.sendDetection(detections)

        // Log the success status from the response
        print("Acknowledgement received: \(response.success)")
    }
}
