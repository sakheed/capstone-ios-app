# ==== File Paths ====
PROTO_REPO = ../proto-repo
PROTO_DIR = ../proto-repo/proto
PROTO_FILE = detection.proto
PY_OUT_DIR = ../proto-repo/generated
SWIFT_OUT_DIR = ./
SERVER_DIR = ./proto-repo/server


all: swift-proto python-proto start-server

reset: kill-server clean

swift-proto:
	protoc --swift_out=$(SWIFT_OUT_DIR) --grpc-swift_out=$(SWIFT_OUT_DIR) --proto_path=$(PROTO_DIR) $(PROTO_DIR)/$(PROTO_FILE)
	
python-proto:
	@source $(PROTO_REPO)/venv/bin/activate && \
	python3 -m grpc_tools.protoc -I$(PROTO_DIR) --python_out=$(PY_OUT_DIR) --grpc_python_out=$(PY_OUT_DIR) $(PROTO_DIR)/$(PROTO_FILE)
	
start-server:
	@source $(PROTO_REPO)/venv/bin/activate && \
	PYTHONPATH=$(PROTO_REPO) python3 -m server.server
	
kill-server:
	-lsof -ti tcp:50051 | xargs kill -9
	
clean:
	rm ./detection.grpc.swift ./detection.pb.swift
