import bpy,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
BASE=Path('/Users/jaili/projects/godot/project-pirate/art-review/pirate-art-v1')
bpy.ops.wm.open_mainfile(filepath=str(BASE/'Pirate_Art_Review.blend'))
def children(r):
 a=[r]
 for c in r.children:a+=children(c)
 return a

def tris(objects,rig):
 vs=[];ts=[];names=[];inv=rig.matrix_world.inverted()
 for ob in objects:
  if ob.type!='MESH':continue
  ob.data.calc_loop_triangles();m=inv@ob.matrix_world;n=len(vs);vs += [m@v.co for v in ob.data.vertices]
  for tri in ob.data.loop_triangles:ts.append(tuple(n+i for i in tri.vertices));names.append(ob.name)
 return vs,ts,names

def cuts(a,b):
 for t1,t2 in [(a,b),(b,a)]:
  for i in range(3):
   p=t1[i];q=t1[(i+1)%3];d=q-p
   if d.length<1e-6:continue
   hit=intersect_ray_tri(*t2,d.normalized(),p,True)
   if hit is not None and 0.0001<(hit-p).dot(d.normalized())<d.length-.0001:return True
 return False
report=[]
for scene in [bpy.data.scenes['01 • The Sapphire Reach'],bpy.data.scenes['02 • Modular Ship Workshop']]:
 bpy.context.window.scene=scene;scene.frame_set(1);bpy.context.view_layer.update()
 for r in [o for o in scene.objects if o.type=='EMPTY' and o.name.startswith('Ship •')]:
  hull=next(c for c in r.children if c.name.startswith('Hull'))
  hv,ht,hn=tris(children(hull),r);h_bvh=BVHTree.FromPolygons(hv,ht,all_triangles=True)
  errors=[];guns=[o for o in r.children if o.name.startswith('Fitted cannon')]
  for gun in guns:
   gv,gt,gn=tris(children(gun),r);g_bvh=BVHTree.FromPolygons(gv,gt,all_triangles=True)
   actual=0;hit_names=set()
   for a,b in g_bvh.overlap(h_bvh):
    if cuts([gv[i] for i in gt[a]],[hv[i] for i in ht[b]]):actual+=1;hit_names.add(hn[b])
   if actual:errors.append({'gun':gun.name,'intersections':actual,'source_parts':sorted(hit_names)})
  report.append({'ship':r.name,'cannons':len(guns),'source_geometry_intersections':errors})
(BASE/'ship-clearance-validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2),flush=True)
assert not any(row['source_geometry_intersections'] for row in report),'Unresolved fitting intersection'
print('SHIP_CLEARANCE_PASS',flush=True)
