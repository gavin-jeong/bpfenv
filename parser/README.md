# Parser
Currently bpftrace has some limitation with processing binary data.
Only method to pass its data to other progrem is using the function "buf()".

But the default behaviour of the function is like the below
- if data is ascii, print ascii character
- Other, print hex string with "\x" prefix

For Example, `PRI * HTTP/2.0\x0d\x0a\x0d\x0aSM\x0d\x0a\x0d\x0a`
It is quite good for reducing string size, 
cause bpftrace has tight limitation of string length.

But bad to see what is the meaning of the message.
This parser is for processing well known protocol stream.
Currently supports only HTTP/2
