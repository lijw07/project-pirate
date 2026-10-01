import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
P='/Users/jaili/projects/godot/project-pirate/art-review/pirate-art-v1/Pirate_Art_Review.blend'
bpy.ops.wm.open_mainfile(filepath=P)
for name in ['Ship • warship.001','Ship • scout.001','Ship • trader.001']:
 r=bpy.data.objects[name];h=next(c for c in r.children if c.name.startswith('Hull'))
 verts=[h.matrix_local@v.co for v in h.data.vertices]
 bvh=BVHTree.FromPolygons(verts,[list(p.vertices) for p in h.data.polygons])
 print('\nSHIP',name,flush=True)
 for y in [-3,-2.2,-1.6,-.8,0,.8,1.6,2.4,3.0]:
  vals=[]
  for x in [1,1.3,1.5,1.7,1.9,2.1,2.3]:
   loc,n,idx,dist=bvh.ray_cast(Vector((x,y,11)),Vector((0,0,-1)),20)
   vals.append(round(loc.z,3) if loc else None)
  sides=[]
  for z in [.7,1.0,1.3,1.6,1.9,2.2,2.5,2.8]:
   loc,n,idx,dist=bvh.ray_cast(Vector((4,y,z)),Vector((-1,0,0)),8)
   sides.append(round(loc.x,3) if loc else None)
  print('Y',y,'TOP(x1..2.3)',vals,'SIDE(z.7..2.8)',sides,flush=True)
