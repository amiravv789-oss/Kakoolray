#!/usr/bin/env python3
# .devcontainer/panel.py
import sys, json, os, subprocess, uuid as uuid_mod, html
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs

USERS_FILE = sys.argv[1]
RELOAD_FLAG = sys.argv[2]
PORT = int(sys.argv[3])

def load_users():
    with open(USERS_FILE, 'r') as f:
        return json.load(f)

def save_users(data):
    with open(USERS_FILE, 'w') as f:
        json.dump(data, f, indent=2)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            users = load_users()['users']
            rows = ""
            for u in users:
                rows += f"<tr><td>{html.escape(u['uuid'])}</td><td>{u['limit_gb']}</td><td>{html.escape(u.get('comment',''))}</td></tr>"
            html_page = f"""<!DOCTYPE html>
<html dir="rtl">
<head><meta charset="utf-8"><title>Kakoolray Panel</title></head>
<body>
<h2>کاربران</h2>
<table border="1">
<tr><th>UUID</th><th>حجم (GB)</th><th>توضیح</th></tr>
{rows}
</table>
<h3>افزودن کاربر</h3>
<form method="POST" action="/add">
  UUID: <input name="uuid" placeholder="خالی = تصادفی"><br>
  حجم (GB): <input name="limit" value="-1"><br>
  توضیح: <input name="comment"><br>
  <input type="submit" value="افزودن">
</form>
</body></html>"""
            self.wfile.write(html_page.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == '/add':
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length).decode('utf-8')
            params = parse_qs(body)
            new_uuid = params.get('uuid', [None])[0]
            limit_str = params.get('limit', ['-1'])[0]
            comment = params.get('comment', [''])[0]

            if not new_uuid or new_uuid.strip() == '':
                new_uuid = str(uuid_mod.uuid4())
            try:
                limit = int(limit_str)
            except:
                limit = -1

            data = load_users()
            # check duplicate
            if any(u['uuid'] == new_uuid for u in data['users']):
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'UUID already exists')
                return
            data['users'].append({
                "uuid": new_uuid,
                "limit_gb": limit,
                "comment": comment
            })
            save_users(data)
            # trigger reload
            with open(RELOAD_FLAG, 'w') as f:
                f.write('add')
            self.send_response(302)
            self.send_header('Location', '/')
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), Handler)
    print(f'Panel running on port {PORT}')
    server.serve_forever()
