#!/usr/bin/env python3
"""
Flutter Web CORS Server
Serves Flutter web build with proper CORS headers for cross-origin access
"""
import http.server
import socketserver

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP Request Handler with CORS headers"""
    
    def end_headers(self):
        """Add CORS headers to every response"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()

PORT = 5060
HOST = '0.0.0.0'

print(f'🚀 Flutter 웹 서버 시작...')
print(f'   📍 주소: http://{HOST}:{PORT}')
print(f'   🌐 CORS: 활성화')
print(f'   📂 경로: /home/user/flutter_app/build/web')
print('')

with socketserver.TCPServer((HOST, PORT), CORSRequestHandler) as httpd:
    print(f'✅ 서버 실행 중 - Port {PORT}')
    print('   (Ctrl+C로 종료)')
    print('')
    httpd.serve_forever()
