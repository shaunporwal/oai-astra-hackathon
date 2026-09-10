/* Local heuristic selection only: this does not establish that an eye is present. */
(function(root){
class FrameSelector {
  constructor(){this.reset();}
  reset(){this.frames=[];this.previous=null;}
  update(metrics, frame, now){
    if(metrics.selection){
      const selection=metrics.selection;
      if(!selection.eligible){this.reset();return {message:selection.reason};}
      const signature=selection.motion_signature;
      const motion=this.previous?signature.reduce((sum,v,i)=>sum+Math.abs(v-this.previous[i]),0)/signature.length:0;
      this.previous=signature;
      if(motion>.025){this.frames=[];return {message:'Hold the selected tissue steady; image content is changing.'};}
      return this.retain(frame,now,selection.score);
    }
    const p=metrics.pupil, q=metrics.quality;
    if(!p){this.reset();return {message:'Center the eye; no pupil candidate found.'};}
    if(metrics.ratio_assessment && metrics.pupil_to_iris_ratio==null){this.reset();return {message:metrics.ratio_assessment.reason+'; show more of the outer iris boundary.'};}
    const [w,h]=metrics.image_size_wh;
    const position=[p.center_xy[0]/w,p.center_xy[1]/h,p.diameter_px/Math.min(w,h)];
    if(Math.abs(position[0]-.5)>.25||Math.abs(position[1]-.5)>.25){this.reset();return {message:'Move the eye toward the center.'};}
    if(q.bright_fraction>.15||q.dark_fraction>.65){this.reset();return {message:'Adjust the angle or lighting; exposure is limiting capture.'};}
    if(q.laplacian_variance<40){this.reset();return {message:'Image detail is low; adjust distance and hold still.'};}
    const motion=this.previous?Math.max(...position.map((v,i)=>Math.abs(v-this.previous[i]))):0;
    this.previous=position;
    if(motion>.035){this.frames=[];return {message:'Hold still while the image settles.'};}
    return this.retain(frame,now,q.laplacian_variance*(1-q.bright_fraction));
  }
  retain(frame,now,score){
    this.frames=this.frames.filter(f=>now-f.time<=2500);
    this.frames.push({frame,time:now,score});
    if(this.frames.length<4||now-this.frames[0].time<800)return {message:'Hold still; collecting a stable window.'};
    const best=this.frames.reduce((a,b)=>a.score>b.score?a:b);
    this.reset();
    return {message:'Stable candidate selected for review.',selected:best.frame,score:best.score};
  }
}
root.FrameSelector=FrameSelector;
if(typeof module!=='undefined')module.exports=FrameSelector;
})(globalThis);
