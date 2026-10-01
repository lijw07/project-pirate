import bpy, math, json, shutil, hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
BASE=Path('/Users/jaili/projects/godot/project-pirate/art-review/pirate-art-v1')
BACK=BASE/'revisions/before-ship-fix'
for p in [BASE/'Pirate_Art_Review.blend']+list((BASE/'models').glob('ship-*.glb')):
 if not (BACK/p.name).exists():shutil.copy2(p,BACK/p.name)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'Pirate_Art_Review.blend'))
world=bpy.data.scenes['01 • The Sapphire Reach'];workshop=bpy.data.scenes['02 • Modular Ship Workshop']
# Load one intact cannon template; copy its hierarchy for each deck mount.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath='/Users/jaili/projects/godot/project-pirate/kenney_pirate-kit/Models/GLB format/cannon.glb')
templates=list(set(bpy.data.objects)-before)
for o in templates:
 for c in list(o.users_collection):c.objects.unlink(o)

def children(o):
 a=[o]
 for ch in o.children:a+=children(ch)
 return a

def cube(name,root,at,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1)
 o=bpy.context.object
 for c in list(o.users_collection):c.objects.unlink(o)
 root.users_collection[0].objects.link(o);o.parent=root;o.name=name;o.location=at;o.scale=size;o.data.materials.append(bpy.data.materials[mat]);return o

def cannon(root,at,side):
 copies={o:o.copy() for o in templates}
 for o,n in copies.items():
  root.users_collection[0].objects.link(n)
  n.parent=copies.get(o.parent,root)
  if o.parent not in copies:
   n.name='Fitted cannon';n.location=at;n.rotation_mode='XYZ';n.rotation_euler.z=side*math.pi/2;n.scale=(.5,)*3
 return next(n for o,n in copies.items() if o.parent not in copies)

def hull_bvh(r):
 h=next(o for o in r.children if o.name.startswith('Hull'))
 bpy.context.view_layer.update()
 mat=h.matrix_basis
 return BVHTree.FromPolygons([mat@v.co for v in h.data.vertices],[list(p.vertices) for p in h.data.polygons])

def top(bvh,x,y):
 p,*_=bvh.ray_cast(Vector((x,y,12)),Vector((0,0,-1)),20)
 return p.z if p else None

def side_x(bvh,side,y,z):
 p,*_=bvh.ray_cast(Vector((side*5,y,z)),Vector((-side,0,0)),10)
 assert p is not None,(side,y,z)
 return p.x

report=[]
for scene in [world,workshop]:
 bpy.context.window.scene=scene
 for r in [o for o in scene.objects if o.type=='EMPTY' and o.name.startswith('Ship •')]:
  kind=r.name.split('• ')[1].split('.')[0]
  bvh=hull_bvh(r)
  # Remove only fittings authored in this art pass; source hull and rigging stay intact.
  for ob in list(r.children):
   if ob.name.startswith(('Cannon slot','Armor •','Armor rivet','Fitted cannon','Gun platform','Gun support','Fitted armor','Hull rivet')):
    for ch in reversed(children(ob)):bpy.data.objects.remove(ch,do_unlink=True)
  rows=[-.30] if kind=='scout' else ([-1.55,.12,1.16] if kind in ['warship','corsair'] else [-1.45,.8])
  checks=[]
  for side in [-1,1]:
   for y in rows:
    cx=1.55 if y < -1.0 else 1.91
    # The full gun footprint, not its center, must clear the raised bulwark.
    heights=[top(bvh,side*x,y+dy) for x in [cx-.6,cx-.4,cx-.2,cx,cx+.2,cx+.4,cx+.6] for dy in [-.37,-.18,0,.18,.37]]
    z=max(v for v in heights if v is not None)+.105
    pad=cube('Gun platform • timber saddle',r,(side*cx,y,z-.065),(1.00,.77,.13),'Timber')
    for dy in [-.24,.24]:
     floor=top(bvh,side*(cx-.4),y+dy)
     if floor is None:floor=2.1
     height=max(.08,z-.13-floor)
     cube('Gun support • deck foot',r,(side*(cx-.4),y+dy,floor+height/2),(.17,.16,height),'Timber')
    gun=cannon(r,(side*cx,y,z),side)
    checks.append({'row':y,'side':side,'gun_base':round(z,3),'max_bulwark':round(z-.105,3)})
  if kind in ['warship','corsair']:
   for side in [-1,1]:
    for panel in range(4):
     ya=-1.60+panel*.76;yb=ya+.68;za=.88;zb=1.54
     verts=[];faces=[];ny=8;nz=5
     for offset in [.012,.080]:
      for iz in range(nz+1):
       z=za+(zb-za)*iz/nz
       for iy in range(ny+1):
        y=ya+(yb-ya)*iy/ny;verts.append((side_x(bvh,side,y,z)+side*offset,y,z))
     count=(ny+1)*(nz+1)
     for iz in range(nz):
      for iy in range(ny):
       a=iz*(ny+1)+iy;f=(a,a+1,a+ny+2,a+ny+1)
       faces.append(tuple(reversed(f)));faces.append(tuple(v+count for v in f))
     boundary=list(range(ny+1))+[i*(ny+1)+ny for i in range(1,nz+1)]+[nz*(ny+1)+i for i in range(ny-1,-1,-1)]+[i*(ny+1) for i in range(nz-1,0,-1)]
     for i,a in enumerate(boundary):
      b=boundary[(i+1)%len(boundary)];faces.append((a,b,b+count,a+count))
     mesh=bpy.data.meshes.new('Hull fitted armor');mesh.from_pydata(verts,[],faces);mesh.materials.append(bpy.data.materials['Dark iron'])
     ob=bpy.data.objects.new('Fitted armor • %s %s'%(side,panel),mesh);r.users_collection[0].objects.link(ob);ob.parent=r
     # Recalculate shell normals so both sides render correctly after export.
     bpy.context.view_layer.objects.active=ob;ob.select_set(True)
     bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');ob.select_set(False)
     for y in [ya+.13,yb-.13]:
      z=1.35;x=side_x(bvh,side,y,z)+side*.090
      bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.054)
      bolt=bpy.context.object
      for c in list(bolt.users_collection):c.objects.unlink(bolt)
      r.users_collection[0].objects.link(bolt);bolt.parent=r;bolt.location=(x,y,z);bolt.name='Hull rivet';bolt.data.materials.append(bpy.data.materials['Gold'])
  if kind=='trader':
   crates=[o for o in r.children if o.name.startswith('crate')]
   barrels=[o for o in r.children if o.name.startswith('barrel')]
   for i,o in enumerate(crates):
    o.scale=(.52,)*3;o.location=((-1 if i%2==0 else 1)*.7,-2.0+(i//2)*.55,2.1)
   for i,o in enumerate(barrels):
    o.scale=(.48,)*3;o.location=((-1 if i%2==0 else 1)*1.0,.68+(i//2)*.55,2.1)
  report.append({'ship':r.name,'mounts':checks,'armor_offset_inner_m':.012,'armor_thickness_m':.068})
for o in templates:bpy.data.objects.remove(o,do_unlink=True)
# Export corrected ship variants, leaving island exports untouched.
for name,scene in [('scout',workshop),('warship',workshop),('trader',workshop),('corsair',world)]:
 bpy.context.window.scene=scene
 r=next(o for o in scene.objects if o.type=='EMPTY' and o.name.startswith('Ship • '+name))
 for o in bpy.data.objects:o.select_set(False)
 for o in children(r):o.select_set(True)
 bpy.context.view_layer.objects.active=r
 loc=r.location.copy();act=r.animation_data.action;r.animation_data.action=None;r.location=(0,0,0);bpy.context.view_layer.update()
 bpy.ops.export_scene.gltf(filepath=str(BASE/'models'/('ship-'+name+'.glb')),use_selection=True,use_active_scene=True,export_format='GLB',export_animations=False,export_apply=True)
 r.location=loc;r.animation_data.action=act;scene.frame_set(1)

def new_camera(name,root,az,el,scale):
 
 if name in bpy.data.objects:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
 d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale
 ob=bpy.data.objects.new(name,d);workshop.collection.objects.link(ob)
 target=root.location+Vector((0,0,3.3));az=math.radians(az);el=math.radians(el)
 ob.location=target+Vector((math.cos(az)*math.cos(el),math.sin(az)*math.cos(el),math.sin(el)))*40
 ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler();return ob
bpy.context.window.scene=workshop
war=next(o for o in workshop.objects if o.name.startswith('Ship • warship'))
for name,az,el in [('bow-clearance',-108,13),('starboard-clearance',-26,14),('port-clearance',-153,16),('deck-clearance',-65,65)]:
 new_camera(name,war,az,el,16.7)
for scene in [world,workshop]:
 bpy.context.window.scene=scene
 scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.cycles.samples=24
 shots=['archipelago'] if scene==world else ['ship-lineup','ship-warship','bow-clearance','starboard-clearance','port-clearance','deck-clearance']
 for name in shots:
  if scene==workshop:
   for r in bpy.data.objects['Ship loadouts'].children:
    for o in children(r):o.hide_render=name!='ship-lineup' and r!=war
  scene.camera=bpy.data.objects[name]
  scene.render.filepath=str(BASE/'renders'/('ship-fit/'+name+'.png' if 'clearance' in name else name+'.png'))
  bpy.ops.render.render(write_still=True);print('SHIP_RENDER',name,flush=True)
for o in children(bpy.data.objects['Ship loadouts']):o.hide_render=False
workshop.camera=bpy.data.objects['ship-lineup'];world.camera=bpy.data.objects['archipelago']
bpy.context.window.scene=world
for o in bpy.data.objects:o.select_set(False)
bpy.context.view_layer.objects.active=None
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'Pirate_Art_Review.blend'))
m=json.loads((BASE/'manifest.json').read_text())
for p in (BASE/'models').glob('ship-*.glb'):m['assets'][p.name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(BASE/'manifest.json').write_text(json.dumps(m,indent=2))
(BASE/'ship-fit-report.json').write_text(json.dumps(report,indent=2))
print('SHIP_FITTINGS_CORRECTED',flush=True)
