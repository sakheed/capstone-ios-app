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
    func runClient() async throws {
        let transport: any GRPCCore.ClientTransport = try GRPCNIOTransportHTTP2.ClientTransport.using(host: "localhost", port: 50051)
        try await withGRPCClient(
            transport: .http2NIOPosix(
                target: .ipv4(host: "127.0.0.1", port: 50051),
                transportSecurity: .plaintext
            )
        ) { (client: GRPCCore.GRPCClient<GRPCCore.ClientTransport>) in
            // Explicitly specify the transport type for the client
            let detectionService = Signalq_DetectionService.Client<GRPCNIOTransportHTTP2.ClientTransport>(wrapping: client)


            try await sendDetection(using: detectionService)
        }
    }


    private func sendDetection(using detectionService: Signalq_DetectionService.Client<GRPCNIOTransportHTTP2.ClientTransport>) async throws {
        print("→ Sending Detection Message")


        // Create a request message (Replace fields as needed)
        var detectionRequest = Signalq_Detection()
        detectionRequest.id = "12345"


        // Call gRPC method
        let response = try await detectionService.sendDetection(detectionRequest)
        print("Acknowledgement received: \(response.status)")
    }
}






// Run the client
@main
struct Main {
    static func main() async {
        let client = GRPCClient()
        do {
            try await client.runClient()
        } catch {
            print("Error running client: \(error)")
        }
    }
}
