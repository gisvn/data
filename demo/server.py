#!/usr/bin/env python3
# WebGIS Local Server (Python) - co proxy /api/s2token, /api/s2process
import http.server, json, os, socketserver, sys, threading, webbrowser
import urllib.request, urllib.error

PORT = 8080
ROOT = os.path.dirname(os.path.abspath(__file__))
MIME = {'.html':'text/html; charset=utf-8','.js':'application/javascript; charset=utf-8',
        '.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8',
        '.geojson':'application/json; charset=utf-8','.png':'image/png','.jpg':'image/jpeg',
        '.jpeg':'image/jpeg','.ico':'image/x-icon','.svg':'image/svg+xml',
        '.woff2':'font/woff2','.woff':'font/woff'}
TOKEN_URL   = 'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token'
PROCESS_URL = 'https://sh.dataspace.copernicus.eu/api/v1/process'

class Handler(http.server.BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type,Authorization')

    def do_OPTIONS(self):
        self.send_response(204); self._cors(); self.end_headers()

    def _proxy(self, url, content_type, extra_headers=None, response_ct='application/json; charset=utf-8'):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b''
        req = urllib.request.Request(url, data=body, method='POST')
        req.add_header('Content-Type', content_type)
        if extra_headers:
            for k, v in extra_headers.items():
                req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                self.send_response(resp.status); self._cors()
                self.send_header('Content-Type', response_ct)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers(); self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code); self._cors()
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers(); self.wfile.write(data)
        except Exception as e:
            msg = json.dumps({'error':'proxy_error','error_description':str(e)}).encode('utf-8')
            self.send_response(502); self._cors()
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(msg)))
            self.end_headers(); self.wfile.write(msg)

    def do_POST(self):
        if self.path == '/api/s2token':
            self._proxy(TOKEN_URL, 'application/x-www-form-urlencoded'); return
        if self.path == '/api/s2process':
            auth = self.headers.get('Authorization')
            extra = {'Authorization': auth} if auth else None
            self._proxy(PROCESS_URL, 'application/json', extra_headers=extra, response_ct='image/tiff'); return
        self.send_response(404); self._cors(); self.end_headers()

    def do_GET(self):
        path = self.path.split('?', 1)[0]
        if path == '/': path = '/index.html'
        file_path = os.path.normpath(os.path.join(ROOT, path.lstrip('/')))
        if not file_path.startswith(ROOT):
            self.send_response(403); self._cors(); self.end_headers(); return
        if os.path.isfile(file_path):
            ext = os.path.splitext(file_path)[1].lower()
            mime = MIME.get(ext, 'application/octet-stream')
            with open(file_path, 'rb') as f: data = f.read()
            self.send_response(200); self._cors()
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers(); self.wfile.write(data)
        else:
            self.send_response(404); self._cors()
            msg = b'404 Not Found'
            self.send_header('Content-Length', str(len(msg)))
            self.end_headers(); self.wfile.write(msg)

    def log_message(self, fmt, *args):
        pass

def main():
    print('==========================================')
    print('   WebGIS Local Server (Python)')
    print('==========================================')
    print()
    try:
        server = socketserver.ThreadingTCPServer(('localhost', PORT), Handler)
    except OSError:
        print(f'[LOI] Khong the mo port {PORT}. Co the port dang duoc dung boi chuong trinh khac.')
        print(f'Thu doi port hoac dong chuong trinh dang dung port {PORT}.')
        input('Nhan Enter de thoat: ')
        sys.exit(1)
    server.allow_reuse_address = True
    print(f'[OK] Server dang chay tai: http://localhost:{PORT}')
    print('Nhan Ctrl+C de dung server.')
    threading.Timer(1.0, lambda: webbrowser.open(f'http://localhost:{PORT}')).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == '__main__':
    main()
