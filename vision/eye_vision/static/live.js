const $ = id => document.getElementById(id);
const video=$('video'), overlay=$('overlay'), ctx=overlay.getContext('2d');
const sample=document.createElement('canvas'), sc=sample.getContext('2d');
let token=document.querySelector('meta[name=session-token]').content;
let sessionRefresh=null;
let stream=null, epoch=0, running=false, mode=null, timer=null, fileUrl=null;
let savedCase=null, snapshotUrl=null, astra=false, reviewing=false, saving=false;
let roi=null, roiRevision=0, dragStart=null;
let autoSelecting=false; const selector=new FrameSelector();
function message(text){$('message').textContent=text;}
function sync(){ $('target').disabled=saving||reviewing;$('clear-roi').disabled=saving||reviewing; $('auto').disabled=!running||saving||reviewing; $('auto').textContent=autoSelecting?'Cancel auto-selection':'Auto-select one frame'; $('save').disabled=!running||saving||reviewing; $('file').disabled=saving||reviewing; $('review').disabled=!savedCase||!astra||reviewing||saving; }
async function refreshSession(){
  if(!sessionRefresh)sessionRefresh=(async()=>{
    const response=await fetch('/',{cache:'no-store'});
    if(!response.ok)throw new Error('Session expired. Refresh the dashboard on this Mac.');
    const html=new DOMParser().parseFromString(await response.text(),'text/html');
    const next=html.querySelector('meta[name=session-token]')?.content;
    if(!next)throw new Error('Session expired. Refresh the dashboard on this Mac.');
    token=next;
  })().finally(()=>{sessionRefresh=null;});
  return sessionRefresh;
}
async function api(path, options={}){
  const send=()=>fetch(path,{...options,headers:{'x-live-token':token,...options.headers}});
  let response=await send();
  // A rejected session has not executed the operation. Retry once with the current token.
  if(response.status===403){await refreshSession();response=await send();}
  if(!response.ok){let data;try{data=await response.json();}catch{} throw new Error(data?.detail||`Request failed (${response.status})`);}
  return response;
}
function captureStatus(text,error=false){$('saved').textContent=text;$('saved').classList.toggle('capture-error',error);}
function resetReview(){ $('saved-geometry').textContent='No saved measurement.'; $('endpoints').textContent='Send a saved frame to populate target observations.';savedCase=null;$('saved').classList.remove('capture-error');$('snapshot').hidden=true;$('review-text').textContent='';if(snapshotUrl)URL.revokeObjectURL(snapshotUrl);snapshotUrl=null;$('saved').textContent='Frames are processed locally and saved only when requested.';$('review-state').textContent=astra?'Ready for a saved frame':'API key not configured';sync();}
function stop(){epoch++;roi=null;roiRevision++;autoSelecting=false;selector.reset();$('guidance').textContent='Automatic selection is off.';$('capabilities').textContent='Camera controls: awaiting connection.';running=false;clearTimeout(timer);if(stream)stream.getTracks().forEach(t=>t.stop());stream=null;video.pause();video.srcObject=null;video.removeAttribute('src');video.load();if(fileUrl)URL.revokeObjectURL(fileUrl);fileUrl=null;ctx.clearRect(0,0,overlay.width,overlay.height);$('stop').disabled=true;$('mode').textContent='STOPPED';$('source').textContent='No input';$('tracking').textContent='Stopped';for(const id of ['vessels','ratio','sharpness','glare','latency'])$(id).textContent='—';sync();}
async function listCameras(){const devices=await navigator.mediaDevices.enumerateDevices();$('cameras').replaceChildren();for(const d of devices.filter(d=>d.kind==='videoinput')){const opt=new Option(d.label||'Camera',d.deviceId);$('cameras').add(opt);}const iphone=Array.from($('cameras').options).find(o=>/iphone|shaun camera/i.test(o.text));if(iphone)$('cameras').value=iphone.value;$('start').disabled=!$('cameras').options.length;}
$('discover').onclick=async()=>{try{const permission=await navigator.mediaDevices.getUserMedia({video:true,audio:false});permission.getTracks().forEach(t=>t.stop());await listCameras();message('Choose the iPhone camera, then Start camera. Check the macro lens is over the active rear camera.');}catch(e){message(`Camera access failed: ${e.message}`);}};
$('start').onclick=async()=>{if(reviewing||saving)return;stop();resetReview();const e=epoch;try{const incoming=await navigator.mediaDevices.getUserMedia({video:{deviceId:{exact:$('cameras').value},width:{ideal:1920},height:{ideal:1080}},audio:false});if(epoch!==e){incoming.getTracks().forEach(t=>t.stop());return;}stream=incoming;reportCapabilities(stream.getVideoTracks()[0]);video.srcObject=stream;await video.play();mode='live_camera';begin(e);message('Live camera connected. Frame analysis runs locally.');stream.getVideoTracks()[0].onended=()=>{stop();message('Camera disconnected. Reconnect and select it again.');};}catch(err){stop();message(`Could not start camera: ${err.message}`);}};
$('stop').onclick=()=>{stop();message('Input stopped. Saved review remains available.');};
$('file').onchange=async()=>{if(reviewing||saving)return;const file=$('file').files[0];if(!file)return;stop();resetReview();const e=epoch;fileUrl=URL.createObjectURL(file);video.src=fileUrl;video.loop=true;try{await video.play();mode='recorded_video';begin(e);message('Recorded-video replay. This is not a live camera feed.');}catch(err){message(`Browser cannot play this video: ${err.message}`);}};
function begin(e){if(e!==epoch)return;running=true;$('stop').disabled=false;$('mode').textContent=mode==='live_camera'?'LIVE CAMERA':'RECORDED VIDEO · REPLAY';$('source').textContent=mode==='live_camera'?($('cameras').selectedOptions[0]?.text||'Camera'):'Recorded video';sync();tick(e);}
async function capture(){if(video.readyState<2||!video.videoWidth)throw new Error('Waiting for video frames');const scale=Math.min(1,960/Math.max(video.videoWidth,video.videoHeight));sample.width=Math.round(video.videoWidth*scale);sample.height=Math.round(video.videoHeight*scale);sc.drawImage(video,0,0,sample.width,sample.height);return new Promise((resolve,reject)=>sample.toBlob(b=>b?resolve(b):reject(new Error('Frame encoding failed')),'image/jpeg',.92));}
function currentOptions(){return {target:$('target').value,roi:roi?Array.from(roi):null};}
function analysisHeaders(options){return {'content-type':'image/jpeg','x-analysis-options':JSON.stringify(options)};}
async function tick(e){
  if(!running||e!==epoch)return;
  try{
    const revision=roiRevision,options=currentOptions(),blob=await capture();
    const result=await(await api('/api/frame',{method:'POST',headers:analysisHeaders(options),body:blob})).json();
    if(e!==epoch)return;
    if(revision===roiRevision){
      draw(result);
      $('ratio').textContent=result.pupil_to_iris_ratio==null?'—':result.pupil_to_iris_ratio.toFixed(3);
      const vessel=result.redness?.measurement;
      $('vessels').textContent=vessel?.value==null?'—':`${(100*vessel.value).toFixed(1)}%`;
      const quality=options.target==='redness'?(result.redness?.quality||result.quality):result.quality;
      if(!autoSelecting)$('guidance').textContent=options.target==='redness'?vessel.reason:result.ratio_assessment.reason;
      if(autoSelecting&&!saving&&!reviewing){
        const choice=selector.update(result,{blob,options,mode},performance.now());
        $('guidance').textContent=choice.message;
        if(choice.selected){autoSelecting=false;sync();await saveFrame(choice.selected.blob,choice.selected.mode,choice.selected.options);}
      }
      $('tracking').textContent=options.target==='redness'?(vessel.value==null?'Region needs attention':'Candidate vessel coverage'):(result.pupil?'Pupil candidate':'No reliable candidate');
      $('sharpness').textContent=quality.laplacian_variance.toFixed(1);
      $('glare').textContent=`${(100*quality.bright_fraction).toFixed(2)}%`;
      $('latency').textContent=`${result.processing_ms.toFixed(0)} ms`;
    }
  }catch(err){if(e===epoch){ctx.clearRect(0,0,overlay.width,overlay.height);$('tracking').textContent='Analysis unavailable';for(const id of ['vessels','ratio','sharpness','glare','latency'])$(id).textContent='—';message(err.message);}}
  if(running&&e===epoch)timer=setTimeout(()=>tick(e),200);
}
function drawAnnotations(context,r){
  context.lineWidth=2;
  if(r.analysis_options?.target!=='redness'){
    for(const [key,color] of [['pupil','#70ed99'],['iris','#ff69ef']]){
      const fit=r[key];if(!fit)continue;context.strokeStyle=color;context.beginPath();context.ellipse(...fit.center_xy,fit.axes_wh[0]/2,fit.axes_wh[1]/2,fit.angle_degrees*Math.PI/180,0,Math.PI*2);context.stroke();
    }
  }
  const red=r.redness;
  if(red?.roi_xywh){context.strokeStyle='#67dfff';context.strokeRect(...red.roi_xywh);context.fillStyle='#ff537888';context.strokeStyle='#ff5378';
    for(const points of red.vessel_contours_xy){context.beginPath();points.forEach(([x,y],i)=>i?context.lineTo(x,y):context.moveTo(x,y));context.closePath();context.fill();context.stroke();}
  }
}
function draw(r){overlay.width=r.image_size_wh[0];overlay.height=r.image_size_wh[1];ctx.clearRect(0,0,overlay.width,overlay.height);drawAnnotations(ctx,r);}
async function saveFrame(blob,captureMode,options=currentOptions()){
  saving=true;resetReview();sync();
  // Display the captured bytes immediately. Optional annotation must never hide a capture.
  snapshotUrl=URL.createObjectURL(blob);$('snapshot').src=snapshotUrl;$('snapshot').hidden=false;
  captureStatus('Frame captured locally · saving to the Mac…');$('review-state').textContent='Saving captured frame…';
  try{
    const result=await(await api('/api/snapshot',{method:'POST',headers:{...analysisHeaders(options),'x-source-mode':captureMode},body:blob})).json();
    savedCase=result.case_id;$('saved-geometry').textContent=savedGeometryText(result.geometry);
    captureStatus(`Saved ${result.case_id} (${result.mode}) · captured image shown below`);
    $('review-state').textContent=astra?'Saved frame ready':'API key not configured';
    message(`Frame, measurements and masks saved to ${result.saved_directory}`);
    try{
      const annotated=await annotatedSnapshot(blob,result.geometry);
      const raw=snapshotUrl;snapshotUrl=annotated;$('snapshot').src=annotated;URL.revokeObjectURL(raw);
    }catch{captureStatus(`Saved ${result.case_id} · original image shown; overlay unavailable`);}
  }catch(e){captureStatus(`Save failed: ${e.message} Captured image is shown but has not been confirmed saved.`,true);$('review-state').textContent='Captured locally · save failed';message(e.message);}
  finally{saving=false;sync();}
}
$('save').onclick=async()=>{
  if(saving||reviewing)return;
  autoSelecting=false;selector.reset();saving=true;sync();captureStatus('Capturing frame…');
  const options=currentOptions(),captureMode=mode;
  try{await saveFrame(await capture(),captureMode,options);}
  catch(e){captureStatus(`Capture failed: ${e.message}`,true);message(e.message);}
  finally{saving=false;sync();}
};
$('auto').onclick=()=>{autoSelecting=!autoSelecting;selector.reset();$('guidance').textContent=autoSelecting?'Hold the eye centered and steady. No API call will be made.':'Automatic selection is off.';sync();};
$('review').onclick=async()=>{reviewing=true;sync();const caseId=savedCase;$('review-state').textContent='Astra is reviewing…';try{const result=await(await api(`/api/review/${caseId}`,{method:'POST'})).json();if(savedCase!==caseId)return;renderEndpoints(result.endpoint_assessment);if(result.saved_geometry)$('saved-geometry').textContent=savedGeometryText(result.saved_geometry);$('review-state').textContent=`Capture: ${result.prediction}`;$('review-text').textContent=result.review?[...result.review.observations,...result.review.limitations].join('\n\n'):'Astra abstained or the response was incomplete.';}catch(e){$('review-state').textContent='Review unavailable';message(e.message);}finally{reviewing=false;sync();}};
fetch('/api/status').then(r=>r.json()).then(r=>{astra=r.astra_available;$('review-state').textContent=astra?'Ready for a saved frame':'API key not configured';sync();}).catch(()=>message('Cannot reach the local analysis server.'));
window.addEventListener('beforeunload',()=>{if(stream)stream.getTracks().forEach(t=>t.stop());});

function reportCapabilities(track){
  const caps=track.getCapabilities?.()||{};
  const settings=track.getSettings?.()||{};
  const controls=['focusMode','focusDistance','exposureMode','exposureCompensation','zoom'].filter(k=>k in caps);
  $('capabilities').textContent=`Camera controls reported: ${controls.join(', ')||'no focus/exposure/zoom controls exposed'}. Stream: ${settings.width||'?'} × ${settings.height||'?'}. No settings changed.`;
}

function renderEndpoints(assessment){
  const container=$('endpoints');container.replaceChildren();
  if(!assessment?.targets?.length){container.textContent='No endpoint assessment returned; model abstained or response was incomplete.';return;}
  for(const target of assessment.targets){
    const section=document.createElement('details');
    const title=document.createElement('summary');
    const name=document.createElement('strong');name.textContent=target.name;
    const status=document.createElement('span');status.className='endpoint-status';
    const measured=target.measurements.find(m=>m.value!=null);
    status.textContent=measured?`${Number(measured.value).toFixed(3)} · estimate`:target.status.replaceAll('_',' ');
    title.append(name,status);
    const body=document.createElement('p');body.textContent=`${target.status}: ${target.observation}`;
    const limits=document.createElement('p');limits.textContent=target.limitations.join(' ');
    const values=document.createElement('p');values.textContent=target.measurements.map(m=>`${m.name}: ${m.value??'—'} (${m.status})`).join('; ');
    section.append(title,body,limits,values);container.append(section);
  }
}

function savedGeometryText(g){
  if(g.analysis_options?.target==='redness'){
    const m=g.redness.measurement;
    return m.value==null?`Saved region: ${m.reason}`:`Saved candidate vessel coverage: ${(100*m.value).toFixed(1)}% · user-selected tissue, unvalidated.`;
  }
  return g.pupil_to_iris_ratio==null?`Saved frame ratio unavailable: ${g.ratio_assessment.reason}`:`Saved frame ratio: ${g.pupil_to_iris_ratio.toFixed(3)} · local experimental estimate.`;
}
async function annotatedSnapshot(blob,g){
  const image=new Image();const url=URL.createObjectURL(blob);
  try{
    await new Promise((resolve,reject)=>{image.onload=resolve;image.onerror=()=>reject(new Error('Image decoding failed'));image.src=url;});
    const c=document.createElement('canvas');c.width=image.naturalWidth;c.height=image.naturalHeight;
    const context=c.getContext('2d');context.drawImage(image,0,0);drawAnnotations(context,g);
    return await new Promise((resolve,reject)=>c.toBlob(b=>b?resolve(URL.createObjectURL(b)):reject(new Error('Overlay encoding failed')),'image/jpeg',.92));
  }finally{URL.revokeObjectURL(url);}
}
function changeRegion(){roiRevision++;selector.reset();autoSelecting=false;sync();$('guidance').textContent=$('target').value==='redness'?'Drag inside exposed white-eye tissue. Keep iris, skin and lids outside the rectangle.':'Center the pupil and show the outer iris boundary.';}
$('target').onchange=()=>{roi=null;changeRegion();};
$('clear-roi').onclick=()=>{roi=null;changeRegion();};
function imagePoint(event){
  if(!video.videoWidth)return null;
  const box=video.getBoundingClientRect(),scale=Math.min(box.width/video.videoWidth,box.height/video.videoHeight);
  const width=video.videoWidth*scale,height=video.videoHeight*scale;
  const x=(event.clientX-box.left-(box.width-width)/2)/width,y=(event.clientY-box.top-(box.height-height)/2)/height;
  return x>=0&&x<=1&&y>=0&&y<=1?[x,y]:null;
}
const screen=document.querySelector('.screen');
screen.addEventListener('pointerdown',event=>{
  if(!running||saving||reviewing||$('target').value!=='redness')return;
  dragStart=imagePoint(event);if(dragStart){screen.setPointerCapture(event.pointerId);screen.classList.add('selecting');roiRevision++;selector.reset();autoSelecting=false;sync();}
});
screen.addEventListener('pointerup',event=>{
  const end=imagePoint(event);if(dragStart&&end){const x=Math.min(dragStart[0],end[0]),y=Math.min(dragStart[1],end[1]);const w=Math.abs(dragStart[0]-end[0]),h=Math.abs(dragStart[1]-end[1]);if(w>.01&&h>.01)roi=[x,y,w,h];}
  dragStart=null;screen.classList.remove('selecting');changeRegion();
});
screen.addEventListener('pointercancel',()=>{dragStart=null;changeRegion();});
