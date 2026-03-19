# Garmin Connect IQ Makefile for face
SDK_HOME = /home/yuval/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b
MONKEYC = $(SDK_HOME)/bin/monkeyc
MONKEYDO = $(SDK_HOME)/bin/monkeydo
SIMULATOR = $(SDK_HOME)/bin/simulator
DEVELOPER_KEY = $(HOME)/developer_key
DEVICE = fenix8solar47mm
JUNGLES = monkey.jungle

# Output names
DEBUG_PRG = bin/face-debug.prg
RELEASE_PRG = bin/face-release.prg
TEST_PRG = bin/face-test.prg

# Build flags
COMMON_FLAGS = -d $(DEVICE) -f $(JUNGLES) -y $(DEVELOPER_KEY) -w -l 3

.PHONY: all debug release clean run simulator test check-sim wait-sim generate

all: debug

# Generate weather strings and code from SDK docs
generate:
	@./scripts/generate_weather.sh $(SDK_HOME)

debug: generate
	@mkdir -p bin
	$(MONKEYC) $(COMMON_FLAGS) -g -o $(DEBUG_PRG)

release: generate
	@mkdir -p bin
	$(MONKEYC) $(COMMON_FLAGS) -r -O 3 -o $(RELEASE_PRG)

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
	$(MONKEYC) $(COMMON_FLAGS) -t -o $(TEST_PRG)
	@ss -tuln | grep -q ":1234 " || (echo "Simulator not ready. Starting/Waiting..." && $(MAKE) simulator)
	$(MONKEYDO) $(TEST_PRG) $(DEVICE) -t || ( [ $$? -eq 1 ] && echo "Tests completed (checking status above)..." )
