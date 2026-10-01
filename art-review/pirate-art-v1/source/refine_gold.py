import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path('/Users/jaili/projects/godot/project-pirate/art-review/pirate-art-v1')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
scene=bpy.data.scenes['01 • The Sapphire Reach'];bpy.context.window.scene=scene
r=bpy.data.objects['03 • Gilded Key'];col=r.users_collection[0]
for ob in list(r.children):
 if ob.name.startswith('Treasure • stacked gold ingot'):bpy.data.objects.remove(ob,do_unlink=True)
palms=[o for o in r.children if o.name.startswith('palm')]
for ob,xy in zip(palms,[(7,4),(5.8,-.5),(-7,4),(-7,-1),(-3,5),(2.5,5.5)]):ob.location=(xy[0],xy[1],1.2)
stalls=[o for o in r.children if o.name.startswith('structure-fence')]
for i,o in enumerate(stalls):o.location=(-5 if i<2 else 5,-2.7-(i%2)*2.0,1.25)
for row in range(3):
 for i in range(4-row):
  bpy.ops.mesh.primitive_cube_add(size=1)
  o=bpy.context.object;o.name='Treasure • stacked gold ingot'
  for c in list(o.users_collection):c.objects.unlink(o)
  col.objects.link(o);o.parent=r;o.location=(-1.2+i*.76+row*.36,-5,1.52+row*.30);o.scale=(.64,1.0,.28)
  o.data.materials.append(bpy.data.materials['Gold'])
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bevel=o.modifiers.new('Ingot bevel','BEVEL');bevel.width=.08;bevel.segments=1
  o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
def children(o):
 a=[o]
 for ch in o.children:a+=children(ch)
 return a
for o in bpy.data.objects:o.select_set(False)
for o in children(r):o.select_set(True)
bpy.context.view_layer.objects.active=r;pos=r.location.copy();r.location=(0,0,0);bpy.context.view_layer.update()
p=OUT/'models/gold.glb'
bpy.ops.export_scene.gltf(filepath=str(p),use_selection=True,use_active_scene=True,export_format='GLB',export_animations=False,export_apply=True)
r.location=pos
scene.camera=bpy.data.objects['gold'];scene.render.resolution_x=1440;scene.render.resolution_y=1080
for c in scene.collection.children:
 if c.name.startswith(('01 •','02 •','03 •','04 •','05 •','06 •','Fleet •')):c.hide_render=c!=col
scene.render.filepath=str(OUT/'renders/gold.png');bpy.ops.render.render(write_still=True)
for c in scene.collection.children:c.hide_render=False
scene.camera=bpy.data.objects['archipelago'];scene.render.resolution_x=1920;scene.render.resolution_y=1440
scene.render.filepath=str(OUT/'renders/archipelago.png');bpy.ops.render.render(write_still=True)
for o in bpy.data.objects:o.select_set(False)
bpy.context.view_layer.objects.active=None
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
m=json.loads((OUT/'manifest.json').read_text());m['assets'][p.name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(OUT/'manifest.json').write_text(json.dumps(m,indent=2));print('GOLD_REFINED')
