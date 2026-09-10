const assert=require('node:assert/strict');
const Selector=require('../eye_vision/static/selector.js');
function metrics(sharpness=100,x=100){return {pupil:{center_xy:[x,100],diameter_px:40},image_size_wh:[200,200],quality:{laplacian_variance:sharpness,bright_fraction:0,dark_fraction:.1}};}
const s=new Selector();
assert.equal(s.update({...metrics(),pupil:null},'absent',0).selected,undefined);
for(let i=0;i<3;i++)assert.equal(s.update(metrics(i===1?500:100),'frame'+i,i*300).selected,undefined);
assert.equal(s.update(metrics(),'last',900).selected,'frame1');
s.reset();s.update(metrics(),'a',0);s.update(metrics(),'b',300);
assert.match(s.update(metrics(100,130),'moving',600).message,/Hold still/);
assert.equal(s.update(metrics(100,130),'after',900).selected,undefined);
s.reset();assert.match(s.update(metrics(1),'blur',0).message,/detail is low/);
s.reset();s.update(metrics(),'stale',0);
assert.equal(s.update(metrics(),'fresh',3000).selected,undefined);
console.log('Selector: missing candidate, exact best frame, motion reset, stale buffer passed');
s.reset();
assert.match(s.update({...metrics(),ratio_assessment:{reason:'Boundary obscured'},pupil_to_iris_ratio:null},'rejected',0).message,/Boundary obscured/);
for(let i=0;i<3;i++)assert.equal(s.update({...metrics(),ratio_assessment:{status:'estimated'},pupil_to_iris_ratio:.3},'accepted'+i,300*i).selected,undefined);
assert.equal(s.update({...metrics(),ratio_assessment:{status:'estimated'},pupil_to_iris_ratio:.3},'accepted3',900).selected,'accepted3');
console.log('Selector: rejected iris blocks capture; accepted stable geometry permits capture');
