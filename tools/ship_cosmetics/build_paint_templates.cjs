// Rebuild the approved canvas artwork as runtime SVG templates (no browser dependency).
const fs=require('fs'),vm=require('vm');
class CanvasSVG {
 constructor(){this.items=[];this.stack=[];this.transforms=[];this.globalAlpha=1;this.lineWidth=1;this.fillStyle='';this.strokeStyle='';this.path='';}
 save(){this.stack.push({transforms:[...this.transforms],fillStyle:this.fillStyle,strokeStyle:this.strokeStyle,lineWidth:this.lineWidth,globalAlpha:this.globalAlpha});}
 restore(){Object.assign(this,this.stack.pop());}
 translate(x,y){this.transforms.push(`translate(${x} ${y})`);}
 scale(x,y){this.transforms.push(`scale(${x} ${y})`);}
 rotate(a){this.transforms.push(`rotate(${a*180/Math.PI})`);}
 add(tag,attrs,fill,stroke){this.items.push(`<${tag} ${attrs} fill="${fill||'none'}" stroke="${stroke||'none'}" stroke-width="${this.lineWidth}" stroke-linecap="round" stroke-linejoin="round" opacity="${this.globalAlpha}" transform="${this.transforms.join(' ')}"/>`);}
 fillRect(x,y,w,h){this.add('rect',`x="${x}" y="${y}" width="${w}" height="${h}"`,this.fillStyle);}
 strokeRect(x,y,w,h){this.add('rect',`x="${x}" y="${y}" width="${w}" height="${h}"`,null,this.strokeStyle);}
 beginPath(){this.path='';}
 moveTo(x,y){this.path+=`M ${x} ${y} `;}
 lineTo(x,y){this.path+=`L ${x} ${y} `;}
 bezierCurveTo(...p){this.path+=`C ${p.join(' ')} `;}
 closePath(){this.path+='Z ';}
 arc(x,y,r){this.ellipse(x,y,r,r);}
 ellipse(x,y,rx,ry){this.path+=`M ${x-rx} ${y} a ${rx} ${ry} 0 1 0 ${rx*2} 0 a ${rx} ${ry} 0 1 0 ${-rx*2} 0 Z `;}
 fill(){this.add('path',`d="${this.path}"`,this.fillStyle);}
 stroke(){this.add('path',`d="${this.path}"`,null,this.strokeStyle);}
}
let ctx;
const sandbox={document:{createElement:()=>({getContext:()=>ctx})},THREE:{CanvasTexture:class{},SRGBColorSpace:0},Math};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(__dirname+'/sail-paint-source.js','utf8').replace(/import .*?;\n/,'').replace('export function','function')+';this.paint=paintSail;',sandbox);
const templates={};
for(const format of ['sail','flag'])for(const pattern of ['plain','border','stripes','quarters','chevron','diamonds','hem','split'])for(const emblem of ['none','skull','compass','kraken','gull','sun','waves','moon']){
 ctx=new CanvasSVG();sandbox.paint({cloth:'@CLOTH@',ink:'@INK@',pattern,emblem,format,aspect:1});
 let body=ctx.items.join('');
 if(format==='flag'){
  body=body.replaceAll('scale(0.92 0.92)','scale(@EMBLEM_SCALE@ 0.92)');
  // The medallion's horizontal radius is compensated for a long flag.
  body=body.replace('M 30 510 a 290 290 0 1 0 580 0 a 290 290 0 1 0 -580 0 Z ','M @DISC_LEFT@ 510 a @DISC_RADIUS@ 290 0 1 0 @DISC_DIAMETER@ 0 a @DISC_RADIUS@ 290 0 1 0 -@DISC_DIAMETER@ 0 Z ');
 }
 templates[`${format}/${pattern}/${emblem}`]=`<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 1024 1024">${body}</svg>`;
}
fs.writeFileSync(__dirname+'/../../scripts/ships/cosmetics/paint_templates.gd','extends RefCounted\n# Generated from the approved artwork by tools/ship_cosmetics/build_paint_templates.cjs.\nconst SVG := '+JSON.stringify(templates,null,'\t')+'\n');
