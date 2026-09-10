"""Optional Playwright regression check; isolated server, synthetic camera, no API calls."""
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from playwright.sync_api import sync_playwright

with tempfile.TemporaryDirectory() as folder:
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    process=subprocess.Popen([sys.executable,'-c',
        'import sys,uvicorn;from eye_vision.live import create_app;uvicorn.run(create_app(sys.argv[1]),host="127.0.0.1",port=int(sys.argv[2]),access_log=False)',folder,str(port)],
        stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        origin=f'http://127.0.0.1:{port}'
        for _ in range(100):
            try:urllib.request.urlopen(origin,timeout=.2);break
            except OSError:time.sleep(.1)
        with sync_playwright() as p:
            browser=p.chromium.launch(args=['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream'])
            page=browser.new_page(viewport={'width':1280,'height':720},permissions=['camera'])
            errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
            page.goto(origin)
            page.click('#discover');page.wait_for_function("!document.getElementById('start').disabled")
            page.click('#start');page.wait_for_function("!document.getElementById('save').disabled")
            page.evaluate("token='expired-session'")
            page.click('#save')
            page.wait_for_function("document.getElementById('saved').textContent.startsWith('Saved live-') && !saving")
            page.wait_for_function("document.getElementById('snapshot').naturalWidth>0")
            assert page.evaluate("token!=='expired-session'")
            assert page.locator('#snapshot').bounding_box()['y'] > page.locator('#save').bounding_box()['y']
            assert page.evaluate('document.documentElement.scrollHeight') <= 720
            first=page.evaluate('savedCase')
            # Overlay failure must leave a saved, visible original image and usable case ID.
            page.evaluate("() => { annotatedSnapshot=async()=>{throw new Error('Injected overlay failure')}; }")
            page.click('#save');page.wait_for_function("document.getElementById('saved').textContent.includes('overlay unavailable')")
            assert page.evaluate('savedCase')!=first
            assert page.locator('#snapshot').is_visible()
            # Server error must be visible next to the button, with the local image retained.
            page.route('**/api/snapshot',lambda route:route.fulfill(status=500,content_type='application/json',body='{"detail":"Injected save failure"}'))
            page.click('#save');page.wait_for_function("document.getElementById('saved').textContent.startsWith('Save failed:')")
            assert page.locator('#snapshot').is_visible()
            assert page.evaluate('savedCase') is None
            assert page.locator('#review').is_disabled()
            page.unroute('**/api/snapshot')
            # Exercise the actual auto button/loop with deterministic eligible-frame responses.
            fixture={'image_size_wh':[960,540],'pupil':None,'iris':None,'pupil_to_iris_ratio':None,
                'ratio_assessment':{'reason':'fixture'},'redness':{'measurement':{'value':None,'reason':'fixture'},'quality':None},
                'quality':{'laplacian_variance':100,'bright_fraction':0},'processing_ms':1,
                'selection':{'eligible':True,'score':100,'motion_signature':[.5]*256,'reason':'fixture'}}
            import json
            page.route('**/api/frame',lambda route:route.fulfill(json=fixture))
            page.click('#auto')
            page.wait_for_function("savedCase!==null && !saving",timeout=10000)
            assert page.locator('#snapshot').is_visible()
            assert not errors,errors
            browser.close()
            print('Manual capture, expired session, overlay fallback, visible save failure and auto-capture passed')
    finally:
        process.terminate();process.wait(timeout=5)
