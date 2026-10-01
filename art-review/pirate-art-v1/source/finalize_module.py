import bpy, math, json, hashlib
from pathlib import Path
OUT=Path('/Users/jaili/projects/godot/project-pirate/art-review/pirate-art-v1')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
scene=bpy.data.scenes['03 • Outfitting Modules'];bpy.context.window.scene=scene
r=bpy.data.objects['Module • Rigging']
verts=[];faces=[]
for j in range(6):
    v=j/5
    for i in range(7):
        u=i/6
        verts.append(((u-.5)*2.65,-.15-math.sin(v*math.pi)*.35,1.90+v*2.0))
for j in range(5):
    for i in range(6):
        a=j*7+i;faces.append((a,a+1,a+8,a+7))
mesh=bpy.data.meshes.new('Sail cloth • bowed panels');mesh.from_pydata(verts,[],faces);mesh.materials.append(bpy.data.materials['Teal'])
ob=bpy.data.objects.new('Sail cloth • removable',mesh);r.users_collection[0].objects.link(ob);ob.parent=r
for p in mesh.polygons:p.use_smooth=True
for o in bpy.data.objects:o.select_set(False)
def children(o):
    a=[o]
    for c in o.children:a+=children(c)
    return a
for o in children(r):o.select_set(True)
bpy.context.view_layer.objects.active=r
pos=r.location.copy();r.location=(0,0,0);bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(OUT/'models/module-rigging.glb'),use_selection=True,use_active_scene=True,export_format='GLB',export_animations=False,export_apply=True)
r.location=pos
scene.camera=bpy.data.objects['modules'];scene.render.filepath=str(OUT/'renders/modules.png')
bpy.ops.render.render(write_still=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.region_3d.view_camera_zoom=0
bpy.context.window.scene=bpy.data.scenes['01 • The Sapphire Reach']
for o in bpy.data.objects:o.select_set(False)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
m=json.loads((OUT/'manifest.json').read_text());p=OUT/'models/module-rigging.glb'
m['assets'][p.name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(OUT/'manifest.json').write_text(json.dumps(m,indent=2))
print('ART_FINALIZED',flush=True)
