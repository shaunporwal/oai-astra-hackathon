"""Offline recording check. Produces engineering diagnostics, not accuracy metrics."""
import argparse
import json
from pathlib import Path
import time
import cv2
from eye_vision.geometry import analyze_frame

parser=argparse.ArgumentParser()
parser.add_argument('video',type=Path)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--stride',type=int,default=6)
args=parser.parse_args()
if args.stride<1:parser.error('stride must be positive')
args.output.mkdir(parents=True,exist_ok=False)
cap=cv2.VideoCapture(str(args.video))
if not cap.isOpened():parser.error('Cannot open video')
fps=cap.get(cv2.CAP_PROP_FPS)
if fps<=0:parser.error('Video requires a valid frame rate')
rows=[];index=0
while True:
    ok,frame=cap.read()
    if not ok:break
    if index%args.stride==0:
        h,w=frame.shape[:2];scale=min(1,960/max(h,w))
        frame=cv2.resize(frame,(round(w*scale),round(h*scale)))
        start=time.perf_counter();metrics=analyze_frame(frame)
        metrics['processing_ms']=(time.perf_counter()-start)*1000
        rows.append({'frame_index':index,'timestamp_ms':index/fps*1000,'metrics':metrics})
        if metrics['iris']:
            for key,color in [('pupil',(0,255,0)),('iris',(255,0,255))]:
                fit=metrics[key]
                cv2.ellipse(frame,(tuple(fit['center_xy']),tuple(fit['axes_wh']),fit['angle_degrees']),color,2)
            cv2.imwrite(str(args.output/f'frame_{index:08d}.jpg'),frame)
    index+=1
cap.release()
(args.output/'video-analysis.json').write_text(json.dumps(rows,indent=2)+'\n')
accepted=[r['frame_index'] for r in rows if r['metrics']['iris']]
print(json.dumps({'sampled_frames':len(rows),'accepted_indices':accepted,
    'mean_processing_ms':sum(r['metrics']['processing_ms'] for r in rows)/max(1,len(rows))},indent=2))
