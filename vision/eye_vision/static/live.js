const $ = id => document.getElementById(id);
const video=$('video'), overlay=$('overlay'), ctx=overlay.getContext('2d');
const sample=document.createElement('canvas'), sc=sample.getContext('2d');
const token=document.querySelector('meta[name=session-token]').content;
let stream=null, epoch=0, running=false, mode=null, timer=null, fileUrl=null;
let savedCase=null, snapshotUrl=null, astra=false, reviewing=false, saving=false;
let autoSelecting=false; const selector=new FrameSelector();
function message(text){$('message').textContent=text;}
function sync(){ $('auto').disabled=!running||saving||reviewing; $('auto').textContent=autoSelecting?'Cancel auto-selection':'Auto-select one frame'; $('save').disabled=!running||saving||reviewing; $('file').disabled=saving||reviewing; $('review').disabled=!savedCase||!astra||reviewing||saving; }
async function api(path, options={}){
  const response=await fetch(path,{...options,headers:{'x-live-token':token,...options.headers}});
  if(!response.ok){let data;try{data=await response.json();}catch{} throw new Error(data?.detail||`Request failed (${response.status})`);}
  return response;
}
function resetReview(){ $('saved-geometry').textContent='No saved measurement.'; $('endpoints').textContent='Send a saved frame to populate target observations.';savedCase=null;$('snapshot').hidden=true;$('review-text').textContent='';if(snapshotUrl)URL.revokeObjectURL(snapshotUrl);snapshotUrl=null;$('saved').textContent='Frames are processed locally and saved only when requested.';$('review-state').textContent=astra?'Ready for a saved frame':'API key not configured';sync();}
function stop(){epoch++;autoSelecting=false;selector.reset();$('guidance').textContent='Automatic selection is off.';$('capabilities').textContent='Camera controls: awaiting connection.';running=false;clearTimeout(timer);if(stream)stream.getTracks().forEach(t=>t.stop());stream=null;video.pause();video.srcObject=null;video.removeAttribute('src');video.load();if(fileUrl)URL.revokeObjectURL(fileUrl);fileUrl=null;ctx.clearRect(0,0,overlay.width,overlay.height);$('stop').disabled=true;$('mode').textContent='STOPPED';$('source').textContent='No input';$('tracking').textContent='Stopped';for(const id of ['diameter','ratio','sharpness','glare','latency'])$(id).textContent='—';sync();}
async function listCameras(){const devices=await navigator.mediaDevices.enumerateDevices();$('cameras').replaceChildren();for(const d of devices.filter(d=>d.kind==='videoinput')){const opt=new Option(d.label||'Camera',d.deviceId);$('cameras').add(opt);}const iphone=Array.from($('cameras').options).find(o=>/iphone|shaun camera/i.test(o.text));if(iphone)$('cameras').value=iphone.value;$('start').disabled=!$('cameras').options.length;}
$('discover').onclick=async()=>{try{const permission=await navigator.mediaDevices.getUserMedia({video:true,audio:false});permission.getTracks().forEach(t=>t.stop());await listCameras();message('Choose the iPhone camera, then Start camera. Check the macro lens is over the active rear camera.');}catch(e){message(`Camera access failed: ${e.message}`);}};
$('start').onclick=async()=>{if(reviewing||saving)return;stop();resetReview();const e=epoch;try{const incoming=await navigator.mediaDevices.getUserMedia({video:{deviceId:{exact:$('cameras').value},width:{ideal:1920},height:{ideal:1080}},audio:false});if(epoch!==e){incoming.getTracks().forEach(t=>t.stop());return;}stream=incoming;reportCapabilities(stream.getVideoTracks()[0]);video.srcObject=stream;await video.play();mode='live_camera';begin(e);message('Live camera connected. Frame analysis runs locally.');stream.getVideoTracks()[0].onended=()=>{stop();message('Camera disconnected. Reconnect and select it again.');};}catch(err){stop();message(`Could not start camera: ${err.message}`);}};
$('stop').onclick=()=>{stop();message('Input stopped. Saved review remains available.');};
$('file').onchange=async()=>{if(reviewing||saving)return;const file=$('file').files[0];if(!file)return;stop();resetReview();const e=epoch;fileUrl=URL.createObjectURL(file);video.src=fileUrl;video.loop=true;try{await video.play();mode='recorded_video';begin(e);message('Recorded-video replay. This is not a live camera feed.');}catch(err){message(`Browser cannot play this video: ${err.message}`);}};
function begin(e){if(e!==epoch)return;running=true;$('stop').disabled=false;$('mode').textContent=mode==='live_camera'?'LIVE CAMERA':'RECORDED VIDEO · REPLAY';$('source').textContent=mode==='live_camera'?($('cameras').selectedOptions[0]?.text||'Camera'):'Recorded video';sync();tick(e);}
async function capture(){if(video.readyState<2||!video.videoWidth)throw new Error('Waiting for video frames');const scale=Math.min(1,960/Math.max(video.videoWidth,video.videoHeight));sample.width=Math.round(video.videoWidth*scale);sample.height=Math.round(video.videoHeight*scale);sc.drawImage(video,0,0,sample.width,sample.height);return new Promise((resolve,reject)=>sample.toBlob(b=>b?resolve(b):reject(new Error('Frame encoding failed')),'image/jpeg',.92));}
async function tick(e){if(!running||e!==epoch)return;try{const blob=await capture();const result=await (await api('/api/frame',{method:'POST',headers:{'content-type':'image/jpeg'},body:blob})).json();if(e!==epoch)return;draw(result);$('ratio').textContent=result.pupil_to_iris_ratio==null?'—':result.pupil_to_iris_ratio.toFixed(3);if(!autoSelecting)$('guidance').textContent=result.ratio_assessment.reason;if(autoSelecting&&!saving&&!reviewing){const choice=selector.update(result,blob,performance.now());$('guidance').textContent=choice.message;if(choice.selected){autoSelecting=false;sync();await saveFrame(choice.selected,mode);}}$('tracking').textContent=result.pupil?'Pupil candidate':'No reliable candidate';$('diameter').textContent=result.pupil?`${result.pupil.diameter_px.toFixed(1)} px`:'—';$('sharpness').textContent=result.quality.laplacian_variance.toFixed(1);$('glare').textContent=`${(100*result.quality.bright_fraction).toFixed(2)}%`;$('latency').textContent=`${result.processing_ms.toFixed(0)} ms`;}catch(err){if(e===epoch){ctx.clearRect(0,0,overlay.width,overlay.height);$('tracking').textContent='Analysis unavailable';for(const id of ['diameter','ratio','sharpness','glare','latency'])$(id).textContent='—';message(err.message);}}if(running&&e===epoch)timer=setTimeout(()=>tick(e),200);}
function draw(r){overlay.width=r.image_size_wh[0];overlay.height=r.image_size_wh[1];ctx.clearRect(0,0,overlay.width,overlay.height);if(!r.pupil)return;const p=r.pupil;ctx.lineWidth=2;ctx.strokeStyle='#70ed99';ctx.beginPath();p.contour_xy.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();ctx.stroke();ctx.strokeStyle='#67dfff';ctx.beginPath();ctx.ellipse(...p.center_xy,p.axes_wh[0]/2,p.axes_wh[1]/2,p.angle_degrees*Math.PI/180,0,Math.PI*2);ctx.stroke();if(r.iris){const i=r.iris;ctx.strokeStyle='#ff69ef';ctx.beginPath();ctx.ellipse(...i.center_xy,i.axes_wh[0]/2,i.axes_wh[1]/2,i.angle_degrees*Math.PI/180,0,Math.PI*2);ctx.stroke();}}
async function saveFrame(blob,captureMode){saving=true;sync();try{const result=await(await api('/api/snapshot',{method:'POST',headers:{'content-type':'image/jpeg','x-source-mode':captureMode},body:blob})).json();resetReview();savedCase=result.case_id;snapshotUrl=await annotatedSnapshot(blob,result.geometry);$('saved-geometry').textContent=savedGeometryText(result.geometry);$('snapshot').src=snapshotUrl;$('snapshot').hidden=false;$('saved').textContent=`Saved ${result.case_id} (${result.mode})`;$('review-state').textContent=astra?'Saved frame ready':'API key not configured';message(`Frame and measurements saved to ${result.saved_directory}`);}catch(e){message(e.message);}finally{saving=false;sync();}}
$('save').onclick=async()=>{autoSelecting=false;selector.reset();try{await saveFrame(await capture(),mode);}catch(e){message(e.message);}};
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

function savedGeometryText(g){return g.pupil_to_iris_ratio==null?`Saved frame ratio unavailable: ${g.ratio_assessment.reason}`:`Saved frame ratio: ${g.pupil_to_iris_ratio.toFixed(3)} · local experimental estimate, not Astra-inferred.`;}
async function annotatedSnapshot(blob,g){
  const bitmap=await createImageBitmap(blob);const c=document.createElement('canvas');c.width=bitmap.width;c.height=bitmap.height;
  const context=c.getContext('2d');context.drawImage(bitmap,0,0);bitmap.close();
  for(const [key,color] of [['pupil','#70ed99'],['iris','#ff69ef']]){
    const fit=g[key];if(!fit)continue;context.strokeStyle=color;context.lineWidth=2;context.beginPath();context.ellipse(...fit.center_xy,fit.axes_wh[0]/2,fit.axes_wh[1]/2,fit.angle_degrees*Math.PI/180,0,Math.PI*2);context.stroke();
  }
  return new Promise(resolve=>c.toBlob(b=>resolve(URL.createObjectURL(b||blob)),'image/jpeg',.92));
}
