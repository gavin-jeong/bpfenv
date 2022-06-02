#!/usr/bin/python

from scapy.all import IP, ICMP, sr1, TCP, srloop
import sys
import binascii

def main():
	destination = '192.30.253.112'
	ttl = 5

	payload = "ABCDEFGHIJKLMNOPQRSTUVWXYZ01"

	def prn(echo_response):
		rpl = echo_response[1].payload.payload.payload.payload
		ret = payload.startswith(str(rpl))
		return "%s %s" % (ret, binascii.hexlify(bytes(rpl)))

	echo_request = IP(dst=destination, ttl=ttl)/TCP(flags='PA', dport=443)/payload
	echo_responses, _ = srloop(echo_request, inter=0.01, timeout=1, count=5000, prn=prn)

	print("Got response from remote server:")
	for echo_req, echo_response in echo_responses:
#		print(echo_response.summary())

		# IP/ICMP/IP/TCP
		rp = echo_response.payload.payload.payload.payload
		if not payload.startswith(str(rp)):
			print(rp)
			print(echo_req)
			print(echo_response)

if __name__ == '__main__':
	main()
