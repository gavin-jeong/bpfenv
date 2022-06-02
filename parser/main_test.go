package main

import (
	"testing"
)

func TestAsciiToHex(t *testing.T) {
	testCase := []struct {
		input string
		output string
	} {
		{
			`\x00\x00$\x01\x05\x00\x00\x00\x01\x82\x84\x87A\x87\x98\xe7\x9a\x82\xaeC\xd3z\x88%\xb6P\xc3\xab\xb8\xf2\xe0S\x03*/*@\x83IP\x9f\x83\x9c\xa3\x93`,
			`000024010500000001828487418798e79a82ae43d37a8825b650c3abb8f2e053032a2f2a408349509f839ca393`,
		},
		{
			`\x00\x00\x1b\x01\x05\x00\x00\x00\x01\x82\x84\x87A\x87\x98\xe7\x9a\x82\xaeC\xd3z\x88%\xb6P\xc3\xab\xb8\xf2\xe0S\x03*/*`,
			`00001b010500000001828487418798e79a82ae43d37a8825b650c3abb8f2e053032a2f2a`,
		},
		{
			`\x00\x00\x0f\x00\x01\x00\x00\x00\x01{"test":"body"}`,
			`00000f0001000000017b2274657374223a22626f6479227d`,
		},
	}

	for index, item := range testCase {
		result := AsciiToHex(item.input)
		if result != item.output {
			t.Fatalf("Failed test case #%d\nExpected: \n\t%s\nGot \n\t%s\n", index, item.output, result)
		}
	}
}
