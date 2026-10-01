import bpy,json,hashlib,sys
from pathlib import Path
OUT=Path('/Users/jaili/projects/godot/project-pirate/art-review/pirate-art-v1')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
world=bpy.data.scenes['01 • The Sapphire Reach'];ships=bpy.data.scenes['02 • Modular Ship Workshop'];modules=bpy.data.scenes['03 • Outfitting Modules']
names={'food':'01 • Provision Cay','timber':'02 • Palmwood Isle','gold':'03 • Gilded Key','metal':'04 • Ironwake Mine','harbor-player':'05 • Tidewatch Harbor','harbor-enemy':'06 • Redwake Stronghold','ship-corsair':'Ship • corsair','ship-scout':'Ship • scout.001','ship-warship':'Ship • warship.001','ship-trader':'Ship • trader.001','module-cannons':'Module • Cannons','module-rigging':'Module • Rigging','module-armor':'Module • Armor','module-cargo':'Module • Cargo'}
def children(r):
    a=[r]
    for ch in r.children:a+=children(ch)
    return a
for name,obname in names.items():
    sc=ships if name.startswith('ship-') and name!='ship-corsair' else modules if name.startswith('module-') else world
    bpy.context.window.scene=sc
    r=bpy.data.objects[obname]
    for ob in bpy.data.objects:ob.select_set(False)
    for ob in children(r):ob.select_set(True)
    bpy.context.view_layer.objects.active=r
    loc=r.location.copy();action=r.animation_data.action if r.animation_data else None
    if action:r.animation_data.action=None
    r.location=(0,0,0);bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(OUT/'models'/(name+'.glb')),use_selection=True,export_format='GLB',export_animations=False,export_apply=True,use_active_scene=True)
    r.location=loc
    if action:r.animation_data.action=action
for sc in [world,ships,modules]:sc.frame_set(1)
bpy.context.window.scene=world
world.camera=bpy.data.objects['archipelago']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
m=json.loads((OUT/'manifest.json').read_text())
for p in (OUT/'models').glob('*.glb'):m['assets'][p.name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(OUT/'manifest.json').write_text(json.dumps(m,indent=2))
for scene,cameras in [(world,['archipelago','food','timber','gold','metal','harbor-player','harbor-enemy']),(ships,['ship-lineup','ship-warship']),(modules,['modules'])]:
    bpy.context.window.scene=scene
    scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.cycles.samples=24
    for name in cameras:
        scene.camera=bpy.data.objects[name]
        for c in scene.collection.children:
            if scene==world and c.name in list(names.values())+['Fleet • visual mockups']:
                c.hide_render=name!='archipelago' and c.name!=names.get(name)
        if scene==ships:
            for ob in bpy.data.objects['Ship loadouts'].children:
                for child in children(ob):child.hide_render=name=='ship-warship' and ob.name!='Ship • warship.001'
        scene.render.resolution_x=1920 if name=='archipelago' else 1440
        scene.render.resolution_y=1440 if name=='archipelago' else 1080
        scene.render.filepath=str(OUT/'renders'/(name+'.png'))
        bpy.ops.render.render(write_still=True)
        print('RENDER_COMPLETE',name,flush=True)
for c in world.collection.children:c.hide_render=False
for ob in children(bpy.data.objects['Ship loadouts']):ob.hide_render=False
bpy.context.window.scene=world
world.camera=bpy.data.objects['archipelago']
ships.camera=bpy.data.objects['ship-lineup']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
print('REVIEW_RENDERS_COMPLETE',flush=True)
