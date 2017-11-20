.DEFAULT: build/fix_wave_header

build/fix_wave_header:
	swiftc -static-stdlib fix_wave_header.swift -o build/fix_wave_header

