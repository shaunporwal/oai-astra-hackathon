import json
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import cv2
import numpy as np
from fastapi.testclient import TestClient
from eye_vision.live import create_app
from eye_vision.analysis import analyze_frame


class ReviewJobTests(unittest.TestCase):
    def test_single_submission_polling_cached_recovery_and_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            headers={'x-live-token':'token','content-type':'image/jpeg','x-source-mode':'imported_image'}
            _,jpeg=cv2.imencode('.jpg',np.full((200,200,3),150,dtype=np.uint8))
            entered=threading.Event();release=threading.Event()
            def slow(*args,**kwargs):
                entered.set();release.wait(3)
                return {'endpoint_assessment':{'targets':[]},'prediction':'abstain'}
            with TestClient(create_app(root,session_token='token')) as client, patch.dict('os.environ',{'OPENAI_API_KEY':'test-key'}), patch('eye_vision.astra.analyze',side_effect=slow) as model:
                case=client.post('/api/snapshot',content=jpeg.tobytes(),headers=headers).json()['case_id']
                path='/api/review-job/'+case
                self.assertEqual(client.get(path).status_code,403)
                self.assertEqual(client.get(path,headers=headers).json()['status'],'not_started')
                self.assertEqual(model.call_count,0)
                self.assertEqual(client.post(path,headers=headers).json()['status'],'running')
                self.assertTrue(entered.wait(2))
                self.assertEqual(client.post(path,headers=headers).json()['status'],'running')
                self.assertEqual(client.get(path,headers=headers).json()['status'],'running')
                self.assertEqual(model.call_count,1)
                release.set()
                for _ in range(100):
                    status=client.get(path,headers=headers).json()
                    if status['status']=='completed':break
                    time.sleep(.01)
                self.assertEqual(status['status'],'completed')
                self.assertEqual(client.post(path,headers=headers).json()['result']['prediction'],'abstain')
                self.assertEqual(model.call_count,1)
            with TestClient(create_app(root,session_token='new-token')) as restarted, patch('eye_vision.astra.analyze',side_effect=AssertionError('Polling cannot call model')):
                self.assertEqual(restarted.get(path,headers={'x-live-token':'new-token'}).json()['status'],'completed')
                (root/case/'endpoint-prediction.json').unlink()
                (root/case/'review-job.json').write_text(json.dumps({'status':'running'}))
                self.assertEqual(restarted.get(path,headers={'x-live-token':'new-token'}).json()['status'],'interrupted')
                with patch.dict('os.environ',{'OPENAI_API_KEY':'test-key'}), patch('eye_vision.astra.analyze',side_effect=RuntimeError('sensitive error details')):
                    restarted.post(path,headers={'x-live-token':'new-token'})
                    for _ in range(100):
                        status=restarted.get(path,headers={'x-live-token':'new-token'}).json()
                        if status['status']=='failed':break
                        time.sleep(.01)
                    self.assertEqual(status['status'],'failed')
                    self.assertNotIn('sensitive',json.dumps(status))

    def test_combined_runs_both_measurements(self):
        frame=np.full((200,240,3),210,dtype=np.uint8)
        cv2.line(frame,(50,60),(180,130),(100,100,190),2)
        result=analyze_frame(frame,{'target':'combined','roi':[.1,.1,.8,.8]})
        self.assertEqual({m['name'] for m in result['measurements']},{'vessel_area_fraction','pupil_to_iris_ratio'})
        self.assertIsNotNone(result['redness']['measurement']['value'])
        self.assertEqual(result['analysis_options']['target'],'combined')
