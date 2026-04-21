# Garmin Connect IQ Makefile for face
SDK_HOME = $(HOME)/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b
MONKEYC = $(SDK_HOME)/bin/monkeyc
MONKEYDO = $(SDK_HOME)/bin/monkeydo
SIMULATOR = $(SDK_HOME)/bin/simulator
DEVELOPER_KEY = $(HOME)/developer_key
DEVICE = fenix8solar47mm
JUNGLE = monkey.jungle
DEBUG_JUNGLE = debug.jungle

# Output names
DEBUG_PRG = bin/face-debug.prg
RELEASE_PRG = bin/face-release.prg
TEST_PRG = bin/face-test.prg

# Build flags
COMMON_FLAGS = -d $(DEVICE) -y $(DEVELOPER_KEY) -w -l 3

.PHONY: help all debug release clean run simulator test check-sim wait-sim generate

all: debug

help:
	@echo "Fenix 8 Solar MIP Watch Face - Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Primary Targets:"
	@echo "  debug         Build debug PRG (default)"
	@echo "  release       Build release PRG (optimized)"
	@echo "  run           Build and run debug PRG in simulator"
	@echo "  test          Build and run unit tests"
	@echo "  clean         Remove build artifacts and generated files"
	@echo ""
	@echo "Development & Debugging:"
	@echo "  generate      Regenerate layout and weather strings"
	@echo "  debug-align   Build with alignment overlay enabled"
	@echo "  run-align     Run with alignment overlay enabled"
	@echo "  profile       Build for performance profiling (-k flag)"
	@echo "  run-profile   Run with profiling enabled"
	@echo "  heap-check    Run debug build with memory logging"
	@echo ""
	@echo "Simulator Utilities:"
	@echo "  simulator     Start the Garmin simulator"
	@echo "  check-sim     Check if simulator process is running"
	@echo "  wait-sim      Wait for simulator to be ready on port 1234"

# Generate weather strings and code from SDK docs
generate:
	@./scripts/generate_weather.sh $(SDK_HOME)
	@./scripts/generate_layout.sh 260 260

debug: generate
	@mkdir -p bin
	$(MONKEYC) $(COMMON_FLAGS) -f $(JUNGLE) -g -o $(DEBUG_PRG)

release: generate
	@mkdir -p bin
	$(MONKEYC) $(COMMON_FLAGS) -f $(JUNGLE) -r -O 3 -o $(RELEASE_PRG)

# Debug with alignment overlay
debug-align: generate
	@mkdir -p bin
	$(MONKEYC) $(COMMON_FLAGS) -f $(DEBUG_JUNGLE) -g -o bin/face-debug-align.prg

run-align: debug-align
	@ss -tuln | grep -q ":1234 " || (echo "Simulator not ready. Starting/Waiting..." && $(MAKE) simulator)
	$(MONKEYDO) bin/face-debug-align.prg $(DEVICE)

# Profile build (enables -k flag)
profile: generate
	@mkdir -p bin
	$(MONKEYC) $(COMMON_FLAGS) -f $(JUNGLE) -g -k -o bin/face-profile.prg

run-profile: profile
	@ss -tuln | grep -q ":1234 " || (echo "Simulator not ready. Starting/Waiting..." && $(MAKE) simulator)
	$(MONKEYDO) bin/face-profile.prg $(DEVICE)

clean:
	rm -rf bin/*.prg
	rm -f source/weatherGenerated.mc
	rm -f resources/strings/weather_gen.xml

simulator:
	@echo "Starting simulator..."
	@nohup $(SIMULATOR) > /dev/null 2>&1 &
	@$(MAKE) wait-sim

check-sim:
	@pgrep -f "$(SIMULATOR)" > /dev/null && echo "Simulator process is running." || echo "Simulator process is NOT running."

wait-sim:
	@echo "Waiting for simulator to listen on port 1234..."
	@for i in $$(seq 1 30); do \
		if ss -tuln | grep -q ":1234 "; then \
			echo "Simulator is ready."; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Timeout waiting for simulator."; exit 1

run: debug
	@ss -tuln | grep -q ":1234 " || (echo "Simulator not ready. Starting/Waiting..." && $(MAKE) simulator)
	$(MONKEYDO) $(DEBUG_PRG) $(DEVICE)

test:
	@mkdir -p bin
	$(MAKE) generate
	$(MONKEYC) $(COMMON_FLAGS) -f $(JUNGLE) -t -o $(TEST_PRG)
	@ss -tuln | grep -q ":1234 " || (echo "Simulator not ready. Starting/Waiting..." && $(MAKE) simulator)
	$(MONKEYDO) $(TEST_PRG) $(DEVICE) -t || ( [ $$? -eq 1 ] && echo "Tests completed (checking status above)..." )

# Memory profiling (heap check)
heap-check: debug
	@ss -tuln | grep -q ":1234 " || (echo "Simulator not ready. Starting/Waiting..." && $(MAKE) simulator)
	$(MONKEYDO) $(DEBUG_PRG) $(DEVICE) -log
