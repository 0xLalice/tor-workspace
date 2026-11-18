#!/usr/bin/env python3
"""Exercise visitor pages with real OnionShare and headless Chromium, without Tor.

Development only: needs Playwright and its Chromium, or --chromium PATH.
Fails (never skips) when dependencies or the installed adapter are incompatible.
No user services, files, onion addresses or browser profiles are used.
"""
import argparse
import contextlib
import importlib.metadata
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit
from urllib.request import urlopen

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


@contextlib.contextmanager
def server(mode, fixture, root):
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    log = root / (mode + '.log')
    with log.open('w') as output:
        process = subprocess.Popen(
            [sys.executable, '-B', str(ROOT / 'tests/browser/server.py'), mode, str(port), str(fixture)],
            stdout=output, stderr=subprocess.STDOUT,
            env=dict(os.environ, PYTHONUNBUFFERED='1', TMPDIR=str(root)))
        try:
            url = 'http://127.0.0.1:' + str(port)
            deadline = time.monotonic() + 20
            while True:
                if process.poll() is not None:
                    raise AssertionError(log.read_text())
                try:
                    with urlopen(url, timeout=1) as response:
                        assert response.status == 200
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise AssertionError('Server did not become ready: ' + log.read_text())
                    time.sleep(.1)
            if 'WORKSPACE_STYLE_UNAVAILABLE' in log.read_text():
                raise AssertionError('Installed OnionShare is not supported by our custom UI')
            yield url, log
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def wait_count(log, count):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        values = re.findall(r'WORKSPACE_ROOM_COUNT (\d+)', log.read_text())
        if values and int(values[-1]) == count:
            return
        time.sleep(.1)
    raise AssertionError('Participant count did not become ' + str(count))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chromium', help='Use this installed Chromium executable')
    args = parser.parse_args()
    from playwright.sync_api import sync_playwright, expect
    print('OnionShare ' + importlib.metadata.version('onionshare_cli'), flush=True)
    with tempfile.TemporaryDirectory(prefix='tor-web-test-') as temporary, sync_playwright() as pw:
        root = Path(temporary)
        browser = pw.chromium.launch(headless=True, **({'executable_path': args.chromium} if args.chromium else {}))
        errors = []
        failures = []
        external = []

        def page():
            tab = browser.new_page()
            tab.on('pageerror', lambda error: errors.append(str(error)))
            tab.on('response', lambda response: failures.append(response.status) if response.status >= 400 else None)
            def route(request):
                if urlsplit(request.request.url).hostname != '127.0.0.1':
                    external.append(request.request.url)
                    request.abort()
                else:
                    request.continue_()
            tab.route('**/*', route)
            return tab

        try:
            with server('chat', '', root) as (url, log):
                first, second = page(), page()
                for tab in (first, second):
                    tab.goto(url)
                    expect(tab.locator('#new-message')).to_be_visible()
                    expect(tab.locator('#chat-loading')).to_be_hidden()
                wait_count(log, 2)
                for sender, receiver in ((first, second), (second, first)):
                    message = 'Hello <img src=x onerror="window.injected=true"> ' + str(sender == first)
                    sender.locator('#new-message').fill(message)
                    sender.locator('#new-message').press('Enter')
                    expect(receiver.locator('#chat')).to_contain_text(message)
                    assert receiver.evaluate('window.injected === undefined')
                second.close()
                wait_count(log, 1)
                first.close()
                wait_count(log, 0)
                # Deliberate dependency failure must leave visible feedback.
                broken = browser.new_page()
                broken.route('**/js/jquery*.js', lambda route: route.abort())
                broken.goto(url)
                expect(broken.locator('#chat-loading')).to_be_visible()
                expect(broken.locator('#new-message')).to_be_hidden()
                broken.close()
                print('PASS chat: visible, bidirectional messages, escaped text, counts 2/1/0, missing-script feedback', flush=True)

            fixture = root / 'File ü 100% <tag>.txt'
            content = b'Tor Workspace browser download verification.\n'
            fixture.write_bytes(content)
            with server('share', fixture, root) as (url, _):
                tab = page()
                tab.goto(url)
                expect(tab.locator('h1')).to_have_text(fixture.name)
                with tab.expect_download() as download:
                    tab.get_by_role('link', name='Download', exact=True).click()
                # Browsers sanitize filename characters that are invalid on Windows.
                assert download.value.suggested_filename == fixture.name.replace('<', '_').replace('>', '_'), download.value.suggested_filename
                assert Path(download.value.path()).read_bytes() == content
                tab.close()
                print('PASS file: visible filename, encoded link, downloaded bytes match original', flush=True)

            site = root / 'site'
            site.mkdir()
            (site / 'index.html').write_text('<!doctype html><title>Test site</title><h1>Hosted site</h1><img src="pixel.svg"><a href="next.html">Next</a>')
            (site / 'pixel.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"><rect width="2" height="2"/></svg>')
            (site / 'next.html').write_text('<!doctype html><h1>Second page</h1>')
            with server('website', site, root) as (url, _):
                tab = page()
                tab.goto(url)
                expect(tab.get_by_role('heading', name='Hosted site')).to_be_visible()
                assert tab.locator('img').evaluate('(image) => image.complete && image.naturalWidth > 0')
                tab.get_by_role('link', name='Next').click()
                expect(tab.get_by_role('heading', name='Second page')).to_be_visible()
                tab.close()
                print('PASS website: root index, relative assets and navigation', flush=True)
            assert not errors, errors
            assert not failures, failures
            assert not external, external
        finally:
            browser.close()
    print('PASS visitor pages; onion transport and desktop wiring require separate VM acceptance')


if __name__ == '__main__':
    main()
