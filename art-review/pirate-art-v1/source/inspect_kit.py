import bpy
from pathlib import Path
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
p=Path('/Users/jaili/projects/godot/project-pirate/kenney_pirate-kit/Models/GLB format')
for name in ['ship-medium','patch-sand','structure','structure-roof','tower-complete-large','castle-wall','platform','mast','cannon']:
 old=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(p/(name+'.glb')))
 obs=set(bpy.data.objects)-old
 for ob in obs:
  print('ASSET',name,ob.name,'parent',ob.parent.name if ob.parent else None,'loc',list(ob.location),'rot',list(ob.rotation_euler),'dim',list(ob.dimensions),'type',ob.type)
 for ob in obs:bpy.data.objects.remove(ob,do_unlink=True)
