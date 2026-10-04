#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给 App「打开链接」做对照用的本机 HTTP 服务：支持 Range + 记录请求（含 UA）。

  python srv.py <目录> [端口]

日志（同目录 srv.log）每行：时间 | 客户端 | 方法 | 路径 | Range | UA | 状态 | 字节
"""
import os
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8099
LOG = os.path.join(ROOT, "srv.log")


def log(line: str) -> None:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "ProbeSrv/1.0"

    def _resolve(self):
        rel = self.path.split("?", 1)[0].lstrip("/")
        full = os.path.abspath(os.path.join(ROOT, rel))
        if not full.startswith(ROOT) or not os.path.isfile(full):
            return None
        return full

    def _serve(self, with_body: bool):
        target = self._resolve()
        rng = self.headers.get("Range")
        ua = self.headers.get("User-Agent", "")
        if target is None:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            log("%s | %s | %s | %s | Range=%s | UA=%s | 404 | -" % (
                time.strftime("%H:%M:%S"), self.client_address[0], self.command, self.path, rng, ua))
            return
        size = os.path.getsize(target)
        start, end = 0, size - 1
        status = 200
        if rng:
            m = re.match(r"bytes=(\d*)-(\d*)", rng)
            if m:
                if m.group(1):
                    start = int(m.group(1))
                if m.group(2):
                    end = int(m.group(2))
                end = min(end, size - 1)
                if start >= size:
                    self.send_response(416)
                    self.send_header("Content-Range", "bytes */%d" % size)
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    log("%s | %s | %s | %s | Range=%s | UA=%s | 416 | -" % (
                        time.strftime("%H:%M:%S"), self.client_address[0], self.command, self.path, rng, ua))
                    return
                status = 206
        length = end - start + 1
        ctype = "video/mp4" if target.endswith(".mp4") else (
            "application/vnd.apple.mpegurl" if target.endswith(".m3u8") else "application/octet-stream")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        if status == 206:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
        self.end_headers()
        sent = 0
        if with_body:
            with open(target, "rb") as f:
                f.seek(start)
                remain = length
                while remain > 0:
                    chunk = f.read(min(65536, remain))
                    if not chunk:
                        break
                    try:
                        self.wfile.write(chunk)
                    except Exception as e:
                        log("%s | 写失败: %s" % (time.strftime("%H:%M:%S"), e))
                        break
                    sent += len(chunk)
                    remain -= len(chunk)
        log("%s | %s | %s | %s | Range=%s | UA=%s | %d | %d/%d" % (
            time.strftime("%H:%M:%S"), self.client_address[0], self.command, self.path,
            rng, ua, status, sent, size))

    def do_GET(self):
        self._serve(True)

    def do_HEAD(self):
        self._serve(False)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print("serving %s on 0.0.0.0:%d" % (ROOT, PORT), flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
