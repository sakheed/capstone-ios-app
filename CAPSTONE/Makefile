all: proto

proto:
	protoc --swift_out=./ --grpc-swift_out=./ --proto_path=../proto-repo/proto ../proto-repo/proto/detection.proto
	
clean:
	rm ./detection.grpc.swift ./detection.pb.swift
