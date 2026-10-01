"""Read-only structural checks for the art review deliverables."""
import hashlib,json,struct,math
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
ROOT=BASE.parents[1]
manifest=json.loads((BASE/'manifest.json').read_text())
results=[]
for name,meta in manifest['assets'].items():
 p=BASE/'models'/name;b=p.read_bytes()
 assert hashlib.sha256(b).hexdigest()==meta['sha256'],name+' digest mismatch'
 magic,version,size=struct.unpack_from('<III',b,0)
 assert magic==0x46546c67 and version==2 and size==len(b),name+' invalid header'
 n,kind=struct.unpack_from('<II',b,12);d=json.loads(b[20:20+n])
 assert len(d['scenes'])==1,name+' contains unrelated scenes'
 assert len(d['scenes'][0]['nodes'])==1,name+' must have one assembly root'
 root=d['nodes'][d['scenes'][0]['nodes'][0]]
 assert all(abs(v)<.001 for v in root.get('translation',[0,0,0])),(name,root)
 assert 'animations' not in d,name+' unexpected animation'
 assert all('bufferView' in im for im in d.get('images',[])),name+' external texture dependency'
 assert all('uri' not in buffer for buffer in d.get('buffers',[])),name+' external binary dependency'
 assert not d.get('cameras'),name+' includes presentation camera'
 tris=0
 for mesh in d['meshes']:
  for prim in mesh['primitives']:
   pos=d['accessors'][prim['attributes']['POSITION']]
   assert all(math.isfinite(v) for v in pos['min']+pos['max'])
   tris+=d['accessors'][prim['indices']]['count']//3 if 'indices' in prim else pos['count']//3
 assert 0<tris<100000,(name,tris)
 results.append({'asset':name,'nodes':len(d['nodes']),'triangles':tris,'bytes':len(b),'embedded_textures':len(d.get('images',[]))})
for name,digest in json.loads((BASE/'source/source-hashes.json').read_text()).items():
 assert hashlib.sha256((ROOT/'kenney_pirate-kit/Models/GLB format'/(name+'.glb')).read_bytes()).hexdigest()==digest,'Source modified: '+name
for name in ['archipelago','food','gold','timber','metal','harbor-player','harbor-enemy','ship-lineup','ship-warship','modules']:
 b=(BASE/'renders'/(name+'.png')).read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n'
 w,h=struct.unpack_from('>II',b,16);assert w>=1440 and h>=1080
assert (BASE/'Pirate_Art_Review.blend').stat().st_size>100000
assert (BASE.parent/'.gdignore').exists()
assert 'run/main_scene' not in (ROOT/'project.godot').read_text()
print(json.dumps({'result':'PASS','assemblies':len(results),'previews':10,'source_models_unchanged':len(manifest['source_models']),'details':results},indent=2))
