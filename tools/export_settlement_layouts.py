"""Extract the approved Blender placements and scenery without presentation water."""
import bpy
import json
from pathlib import Path
from mathutils import Matrix

PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT / 'assets/models/settlements/layouts'
bpy.ops.wm.open_mainfile(filepath=str(PROJECT / 'art-review/island-settlements-v1/Island_Settlements_Review.blend'))
conversion = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
layouts = {}
for kind in ['food', 'timber', 'gold', 'metal', 'harbor-player', 'harbor-enemy']:
    collection = bpy.data.collections['Island • ' + kind]
    scene = next(s for s in bpy.data.scenes if collection in list(s.collection.children))
    bpy.context.window.scene = scene
    instances = []
    scenery = []
    for obj in collection.objects:
        if obj.instance_type == 'COLLECTION' and 'asset_id' in obj:
            matrix = conversion @ obj.matrix_world @ conversion.inverted()
            instances.append({'asset': obj['asset_id'], 'transform': [matrix[r][c] for c in range(4) for r in range(3)]})
        elif obj.name.lower().startswith(('palm', 'rocks-sand-a', 'village paths', 'castle banners')):
            scenery.extend([obj, *obj.children_recursive])
    bpy.ops.object.select_all(action='DESELECT')
    for obj in scenery:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = scenery[0]
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (kind.replace('-', '_') + '_scenery.glb')), use_selection=True, use_active_scene=True, export_format='GLB', export_animations=False, export_apply=True)
    layouts[kind] = instances
(OUTPUT / 'placements.json').write_text(json.dumps(layouts, indent=2) + '\n')
print('EXPORTED', {k: len(v) for k, v in layouts.items()})
