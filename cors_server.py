#!/usr/bin/env python3
import http.server
import socketserver

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()

with socketserver.TCPServer(('0.0.0.0', 5060), CORSRequestHandler) as httpd:
    print('Flutter web server with CORS started on port 5060')
    httpd.serve_forever()
