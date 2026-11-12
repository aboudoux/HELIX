"""Serve only the HELIX export, on loopback. Python standard library only."""
import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import webbrowser
import socket
from urllib.request import urlopen


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Helix-Local", "1")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()


class LocalServer(ThreadingHTTPServer):
    # Windows SO_REUSEADDR otherwise permits several launchers to bind the
    # same port. Keep a single server and let subsequent launchers reuse it.
    allow_reuse_address = False

    def server_bind(self):
        if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--open", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent / "exports" / "helix-web"
    if not (root / "index.html").is_file():
        parser.error("Export absent. Lancez 'Exporter HELIX Web.cmd'.")
    try:
        server = LocalServer(("127.0.0.1", args.port), functools.partial(Handler, directory=str(root)))
    except OSError as error:
        if args.open:
            try:
                with urlopen(f"http://127.0.0.1:{args.port}/", timeout=2) as response:
                    if response.headers.get("X-Helix-Local") == "1":
                        webbrowser.open(f"http://127.0.0.1:{args.port}/")
                        print("Le serveur HELIX est deja lance. Demo ouverte.")
                        return
            except OSError:
                pass
        parser.exit(1, f"Port {args.port} indisponible : {error}\n")
    url = f"http://127.0.0.1:{args.port}/"
    print(f"HELIX Web : {url}\nServeur local uniquement. Ctrl+C ou fermer cette fenetre pour arreter.", flush=True)
    if args.open:
        threading.Timer(0.3, webbrowser.open, args=(url,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
