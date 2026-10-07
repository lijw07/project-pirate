import * as THREE from 'three';
export function paintSail({cloth,ink,pattern,emblem,format='sail',aspect=1}){
 const canvas=document.createElement('canvas');canvas.width=format==='flag'?Math.round(1024*aspect):1024;canvas.height=1024;const c=canvas.getContext('2d');if(format==='flag')c.scale(aspect,1);
 c.fillStyle=cloth;c.fillRect(0,0,1024,1024);c.fillStyle=ink;c.strokeStyle=ink;c.lineWidth=28;c.lineJoin='round';c.lineCap='round';
 if(pattern==='border'){c.strokeRect(48,48,928,928);c.lineWidth=6;c.strokeRect(83,83,858,858);}
 if(pattern==='stripes')for(let x=0;x<1024;x+=256)c.fillRect(x,0,95,1024);
 if(pattern==='quarters'){c.fillRect(0,0,512,512);c.fillRect(512,512,512,512);}
 if(pattern==='chevron'){for(let y=-500;y<1300;y+=270){c.beginPath();c.moveTo(-30,y);c.lineTo(512,y+245);c.lineTo(1054,y);c.lineWidth=70;c.stroke();}}
 if(pattern==='diamonds')for(let y=0;y<1024;y+=256)for(let x=0;x<1024;x+=256){c.beginPath();c.moveTo(x+128,y+30);c.lineTo(x+218,y+128);c.lineTo(x+128,y+226);c.lineTo(x+38,y+128);c.closePath();c.fill();}
 if(pattern==='hem'){if(format==='flag'){c.fillRect(835,0,100,1024);c.fillRect(785,0,17,1024);}else{c.fillRect(0,835,1024,100);c.fillRect(0,785,1024,17);}}
 if(pattern==='split')c.fillRect(0,0,512,1024);
 if(emblem!=='none'){
  // A cloth medallion keeps every emblem legible over every pattern.
  if(!['plain','border','hem'].includes(pattern)){c.fillStyle=cloth;c.beginPath();c.ellipse(format==='flag'?320:512,510,format==='flag'?290/aspect:290,290,0,0,Math.PI*2);c.fill();}
  c.save();c.translate(format==='flag'?320:512,500);c.scale(format==='flag'?.92/aspect:.92,.92);c.fillStyle=ink;c.strokeStyle=ink;c.lineWidth=25;
  const line=(pts,w=25)=>{c.lineWidth=w;c.beginPath();pts.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.stroke();};
  const disc=(x,y,r)=>{c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();};
  if(emblem==='skull'){
   line([[-165,165],[165,-135]],33);line([[165,165],[-165,-135]],33);for(const x of [-165,165])for(const y of [-135,165])disc(x,y,24);
   c.beginPath();c.ellipse(0,-35,122,130,0,0,Math.PI*2);c.fill();c.fillRect(-77,40,154,105);c.fillStyle=cloth;disc(-48,-49,32);disc(48,-49,32);c.beginPath();c.moveTo(0,-5);c.lineTo(-22,30);c.lineTo(22,30);c.fill();for(let x=-43;x<55;x+=28)c.fillRect(x,96,12,54);
  }
  if(emblem==='compass'){
   c.lineWidth=8;c.beginPath();c.arc(0,0,155,0,Math.PI*2);c.stroke();
   for(let i=0;i<8;i++){c.save();c.rotate(i*Math.PI/4);c.beginPath();c.moveTo(0,i%2? -140:-235);c.lineTo(38,0);c.lineTo(0,35);c.lineTo(-38,0);c.closePath();c.fill();c.restore();}c.fillStyle=cloth;disc(0,0,23);
  }
  if(emblem==='kraken'){
   c.beginPath();c.ellipse(0,-85,85,115,0,0,Math.PI*2);c.fill();for(let s of [-1,1])for(let i=0;i<4;i++){c.lineWidth=23;c.beginPath();c.moveTo(s*30,-10);c.bezierCurveTo(s*(65+i*35),40,s*(90+i*36),150-i*20,s*(40+i*41),165-i*25);c.bezierCurveTo(s*(10+i*41),175-i*25,s*(15+i*41),120-i*20,s*(35+i*41),130-i*20);c.stroke();}c.fillStyle=cloth;disc(-30,-68,13);disc(30,-68,13);
  }
  if(emblem==='gull'){
   c.beginPath();c.moveTo(0,55);c.lineTo(-230,-85);c.lineTo(-125,-55);c.lineTo(-150,-145);c.lineTo(-42,-55);c.lineTo(0,-80);c.lineTo(42,-55);c.lineTo(150,-145);c.lineTo(125,-55);c.lineTo(230,-85);c.closePath();c.fill();c.beginPath();c.moveTo(-25,35);c.lineTo(0,150);c.lineTo(25,35);c.fill();
  }
  if(emblem==='sun'){
   for(let i=0;i<12;i++){c.save();c.rotate(i*Math.PI/6);line([[0,-155],[0,-220]],19);c.restore();}disc(0,0,117);c.fillStyle=cloth;disc(0,0,79);
  }
  if(emblem==='waves')for(let y=-110;y<=110;y+=110){c.lineWidth=31;c.beginPath();c.moveTo(-220,y);for(let i=0;i<4;i++)c.bezierCurveTo(-200+i*110,y-70,-150+i*110,y+70,-110+i*110,y);c.stroke();}
  if(emblem==='moon'){
   disc(0,0,185);c.fillStyle=cloth;disc(78,-56,166);c.fillStyle=ink;for(const [x,y,r] of [[145,-100,30],[170,40,18],[65,-180,18]]){c.beginPath();c.moveTo(x,y-r);c.lineTo(x+r*.4,y);c.lineTo(x,y+r);c.lineTo(x-r*.4,y);c.closePath();c.fill();}
  }
  c.restore();
 }
 // Subtle panel stitching follows the sail rather than introducing surface noise.
 c.strokeStyle=ink;c.globalAlpha=.13;c.lineWidth=2;for(let x=128;x<1024;x+=128){c.beginPath();c.moveTo(x,0);c.lineTo(x,1024);c.stroke();}c.globalAlpha=1;
 const texture=new THREE.CanvasTexture(canvas);texture.flipY=false;texture.colorSpace=THREE.SRGBColorSpace;texture.anisotropy=8;return texture;
}
