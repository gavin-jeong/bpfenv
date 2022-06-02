package main

import (
	"bufio"
	"bytes"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"strings"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/hpack"
)

// Convert ascii mixed hex string to hex string only
func AsciiToHex(input string) string {
	var sb strings.Builder
	for index, char := range input {
		flag := 0
		recentIndex := strings.LastIndex(input[:index], `\x`)

		// hex string body
		if recentIndex >= 0 && (index-recentIndex == 2 || index-recentIndex == 3) {
			flag = 1
		}

		// normal ascii
		if recentIndex >= 0 && index-recentIndex >= 4 && (  char != '\\' && char != 'x' ) {
			flag = -1
		}

		//fmt.Printf("%d %d %x %s\n", index, flag, char, string(char))

		switch flag {
		case -1:
			sb.WriteString(fmt.Sprintf("%x", char))
		case 1:
			sb.WriteRune(char)
		default:
		}
	}
	return sb.String()
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := scanner.Text()
		hexed := AsciiToHex(line)

		data := make([]byte, len(hexed))
		_, err := hex.Decode(data, []byte(hexed))
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed decode hex, %v: %s\n", err, line)
			continue
		}

		buffer := bytes.NewBuffer(data)
		framer := http2.NewFramer(bufio.NewWriter(buffer), bufio.NewReader(buffer))
		frame, err := framer.ReadFrame()
		if err != nil {
			fmt.Println(line)
			//fmt.Fprintf(os.Stderr, "Failed read Frame, %v: %s\n", err, hexed)
			continue
		}

		fmt.Println("-----START HTTP2 FRAME-----")
		fmt.Println(frame)
		if frame.Header().Type == http2.FrameHeaders {
			frameheader := frame.(*http2.HeadersFrame)
			decoder := hpack.NewDecoder(2048, nil)
			hf, err := decoder.DecodeFull(frameheader.HeaderBlockFragment())
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed decode header fragment, %v: %s\n", err, hexed)
				continue
			}
			for _, h := range hf {
				fmt.Printf("%s\n", h.Name+":"+h.Value)
			}
		}
		fmt.Println("-----END HTTP2 FRAME-----")
	}

	if err := scanner.Err(); err != nil {
		log.Println(err)
	}
}
