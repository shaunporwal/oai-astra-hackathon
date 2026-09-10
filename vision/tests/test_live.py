import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import cv2
import numpy as np

from eye_vision.geometry import analyze_frame
try:
    from fastapi.testclient import TestClient
    from eye_vision.live import create_app
    LIVE = True
except ImportError:
    LIVE = False


class GeometryTests(unittest.TestCase):
    def test_uniform_frame_abstains(self):
        result=analyze_frame(np.full((300,400,3),120,dtype=np.uint8))
        self.assertIsNone(result['pupil'])
        self.assertIsNone(result['pupil_to_iris_ratio'])
        self.assertEqual(result['diagnosis']['status'],'not_configured')

    def test_known_dark_circle_localizes(self):
        frame=np.full((300,400,3),180,dtype=np.uint8)
        cv2.circle(frame,(200,150),30,(20,20,20),-1)
        result=analyze_frame(frame)
        self.assertIsNotNone(result['pupil'])
        np.testing.assert_allclose(result['pupil']['center_xy'],[200,150],atol=2)
        self.assertAlmostEqual(result['pupil']['diameter_px'],60,delta=5)

    def test_dark_border_is_not_a_pupil(self):
        frame=np.full((300,400,3),180,dtype=np.uint8)
        frame[:80]=0
        self.assertIsNone(analyze_frame(frame)['pupil'])


@unittest.skipUnless(LIVE,'Install .[live] to run dashboard tests')
class LiveTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.client=TestClient(create_app(self.root))
        self.addCleanup(self.client.close)
        html=self.client.get('/').text
        self.token=re.search(r'name="session-token" content="([^"]+)"',html).group(1)
        self.headers={'x-live-token':self.token,'content-type':'image/jpeg','x-source-mode':'recorded_video'}
        _, data=cv2.imencode('.jpg',np.full((120,160,3),128,dtype=np.uint8))
        self.data=data.tobytes()

    def test_frame_requires_session_and_valid_image(self):
        self.assertEqual(self.client.post('/api/frame',content=self.data).status_code,403)
        self.assertEqual(self.client.post('/api/frame',content=b'bad',headers=self.headers).status_code,422)
        self.assertEqual(self.client.post('/api/frame',content=b'x'*2_000_001,headers=self.headers).status_code,413)
        result=self.client.post('/api/frame',content=self.data,headers=self.headers)
        self.assertEqual(result.status_code,200)
        self.assertIsNone(result.json()['pupil'])
        self.assertEqual(list(self.root.iterdir()),[])

    def test_snapshot_hashes_provenance_and_no_key(self):
        response=self.client.post('/api/snapshot',content=self.data,headers=self.headers)
        self.assertEqual(response.status_code,200)
        case=response.json()['case_id']
        manifest=json.loads((self.root/case/'manifest.json').read_text())
        self.assertEqual(manifest['capture_mode'],'recorded_video')
        self.assertEqual(manifest['source_type'],'single_frame')
        self.assertEqual(manifest['source_sha256'],hashlib.sha256(self.data).hexdigest())
        with patch.dict('os.environ',{'OPENAI_API_KEY':''}):
            self.assertEqual(self.client.post(f'/api/review/{case}',headers=self.headers).status_code,503)
        self.assertFalse((self.root/case/'prediction.json').exists())
        self.assertEqual(self.client.get(f'/api/snapshot/{case}').status_code,403)
        self.assertEqual(self.client.get(f'/api/snapshot/{case}',headers=self.headers).content,self.data)

    def test_remote_hosts_rejected(self):
        self.assertEqual(self.client.get('/',headers={'host':'evil.example'}).status_code,400)

    def test_cached_review_gets_saved_geometry_without_api(self):
        image=np.full((400,500,3),210,dtype=np.uint8)
        cv2.circle(image,(250,200),100,(80,80,80),-1)
        cv2.circle(image,(250,200),30,(10,10,10),-1)
        _,encoded=cv2.imencode('.jpg',image)
        snapshot=self.client.post('/api/snapshot',content=encoded.tobytes(),headers=self.headers).json()
        self.assertIsNotNone(snapshot['geometry']['pupil_to_iris_ratio'])
        case=snapshot['case_id']
        cached={'endpoint_assessment':{'targets':[{'target_id':'pupil_iris_ratio',
            'measurements':[{'name':'pupil_to_iris_ratio','value':None}]}]}}
        (self.root/case/'endpoint-prediction.json').write_text(json.dumps(cached))
        with patch('eye_vision.astra.analyze',side_effect=AssertionError('Must not call API')):
            response=self.client.post(f'/api/review/{case}',headers=self.headers)
        self.assertEqual(response.status_code,200)
        m=response.json()['endpoint_assessment']['targets'][0]['measurements'][0]
        self.assertAlmostEqual(m['value'],.3,delta=.025)
        self.assertEqual(m['source'],'local_geometry_on_saved_jpeg')

    def test_redness_roi_persists_and_invalid_roi_rejected(self):
        headers={**self.headers,'x-analysis-options':json.dumps({'target':'redness','roi':[.1,.1,.8,.8]})}
        frame=np.full((200,240,3),210,dtype=np.uint8)
        cv2.line(frame,(50,60),(180,130),(100,100,190),2)
        _,encoded=cv2.imencode('.jpg',frame)
        response=self.client.post('/api/snapshot',content=encoded.tobytes(),headers=headers)
        self.assertEqual(response.status_code,200)
        r=response.json();folder=self.root/r['case_id']
        manifest=json.loads((folder/'manifest.json').read_text())
        self.assertEqual(manifest['analysis_options']['roi'],[.1,.1,.8,.8])
        self.assertTrue((folder/'vessel_mask.png').is_file())
        saved=json.loads((folder/'geometry.json').read_text())
        self.assertEqual(saved['redness']['measurement'],r['geometry']['redness']['measurement'])
        headers['x-analysis-options']='{"target":"redness","roi":[0,0,2,2]}'
        self.assertEqual(self.client.post('/api/frame',content=self.data,headers=headers).status_code,422)

    def test_lan_pairing_does_not_expose_session_token(self):
        app=create_app(self.root,session_token='test-pairing-secret',lan_host='lab-mac.local')
        with TestClient(app,client=('192.168.1.20',50000),base_url='http://lab-mac.local') as phone:
            response=phone.get('/')
            self.assertEqual(response.status_code,403)
            self.assertNotIn('test-pairing-secret',response.text)
            self.assertEqual(phone.post('/api/frame',content=self.data,headers={'content-type':'image/jpeg'}).status_code,403)
            headers={'content-type':'image/jpeg','x-live-token':'test-pairing-secret'}
            self.assertEqual(phone.post('/api/frame',content=self.data,headers=headers).status_code,200)
            self.assertEqual(phone.get('/',headers={'host':'attacker.example'}).status_code,400)
        with TestClient(app,client=('127.0.0.1',50000)) as local:
            self.assertIn('test-pairing-secret',local.get('/').text)
