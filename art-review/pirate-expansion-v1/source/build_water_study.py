import bpy, math
from pathlib import Path
from mathutils import Vector
OUT=Path('/Users/jaili/projects/godot/project-pirate/art-review/pirate-expansion-v1')
ART=OUT.parent/'pirate-art-v1'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.name='Water • Motion and Foam Study'
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=1440;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.render.fps=12;scene.frame_end=48
scene.world=bpy.data.worlds.new('Tropical atmosphere');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.48,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'

def linear(h):
 vals=[int(h[i:i+2],16)/255 for i in (0,2,4)];return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in vals)+(1,)
def material(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=linear(color);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=linear(color);return m
foam=material('Seafoam • soft ivory','C4EDE0')
water=material('Water • wave height gradient','208FA0');p=water.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.25;p.inputs['Coat Weight'].default_value=.2
nd=water.node_tree.nodes;links=water.node_tree.links
geom=nd.new('ShaderNodeNewGeometry');xyz=nd.new('ShaderNodeSeparateXYZ');mapper=nd.new('ShaderNodeMapRange');mapper.inputs['From Min'].default_value=-.37;mapper.inputs['From Max'].default_value=-.03
ramp=nd.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=linear('176E83');ramp.color_ramp.elements[1].color=linear('49ABAF')
links.new(geom.outputs['Position'],xyz.inputs[0]);links.new(xyz.outputs['Z'],mapper.inputs['Value']);links.new(mapper.outputs[0],ramp.inputs[0]);links.new(ramp.outputs[0],p.inputs['Base Color'])
noise=nd.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=2.8;noise.inputs['Detail'].default_value=2
links.new(geom.outputs['Position'],noise.inputs['Vector']);bump=nd.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.045;links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])
# Four animated sine components give a continuous, looping surface.
n=128;span=150
verts=[((i/n-.5)*span,(j/n-.5)*span,-.2) for j in range(n+1) for i in range(n+1)]
faces=[]
for j in range(n):
 for i in range(n):a=j*(n+1)+i;faces.append((a,a+1,a+n+2,a+n+1))
mesh=bpy.data.meshes.new('Ocean grid');mesh.from_pydata(verts,[],faces);mesh.materials.append(water)
ocean=bpy.data.objects.new('Animated water surface',mesh);scene.collection.objects.link(ocean)
for f in mesh.polygons:f.use_smooth=True
ocean.shape_key_add(name='Flat surface')
for name,freq,amplitude,func,driver in [('Swell A',(.52,.16),.115,math.sin,'cos'),('Swell B',(.52,.16),.115,math.cos,'sin'),('Ripple A',(-.16,.75),.045,math.sin,'cos'),('Ripple B',(-.16,.75),.045,math.cos,'sin')]:
 key=ocean.shape_key_add(name=name);key.slider_min=-1;key.slider_max=1
 for i,(x,y,z) in enumerate(verts):key.data[i].co.z=z+amplitude*func(x*freq[0]+y*freq[1])
 d=key.driver_add('value').driver;d.expression=f'{driver}((frame-1)*{math.tau/48})'

def import_asset(name,at):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ART/'models'/(name+'.glb')))
 obs=set(bpy.data.objects)-before
 r=bpy.data.objects.new(name+' motion rig',None);scene.collection.objects.link(r);r.location=at
 for ob in obs:
  if ob.parent not in obs:ob.parent=r
 return r,obs
island,island_objects=import_asset('food',(-10,6,0))
for ob in list(island_objects):
 if ob.name.startswith('Shore foam'):bpy.data.objects.remove(ob,do_unlink=True)
ship,ship_objects=import_asset('ship-warship',(7,-3,-.35))
ship.rotation_euler.z=-.12
for f,phase in [(1,0),(13,math.pi/2),(25,math.pi),(37,3*math.pi/2),(49,math.tau)]:
 ship.location.z=-.38+math.cos(phase)*.09;ship.rotation_euler.x=math.sin(phase)*.013;ship.rotation_euler.y=math.sin(phase+.5)*.018
 ship.keyframe_insert(data_path='location',frame=f);ship.keyframe_insert(data_path='rotation_euler',frame=f)

def line(name,pts,width,parent=None):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=width;cu.bevel_resolution=1
 s=cu.splines.new('POLY');s.points.add(len(pts)-1)
 for p,xyz in zip(s.points,pts):p.co=(*xyz,1)
 cu.materials.append(foam);ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob)
 if parent:ob.parent=parent
 return ob
# Three expanding shoreline foam ribbons. Their movement is purely a look reference.
shore=bpy.data.objects.new('Shoreline foam animation',None);scene.collection.objects.link(shore);shore.location=(-10,6,0)
for ring in range(3):
 pts=[];rad=1.03+ring*.065
 for i in range(129):
  a=i*math.tau/128;r=1+.045*math.sin(a*5)+.03*math.cos(a*7)
  pts.append((math.cos(a)*10.65*rad*r,math.sin(a)*8.35*rad*r,-.11))
 ob=line('Shore foam ribbon %d'%ring,pts,.037 if ring else .060,shore)
 for f in [1,13,25,37,49]:
  wave=math.sin((f-1)*math.tau/48+ring*1.0)
  ob.scale=(1+wave*.016,1+wave*.016,1);ob.location.z=wave*.015
  ob.keyframe_insert(data_path='scale',frame=f);ob.keyframe_insert(data_path='location',frame=f)
# Broken foam strands behind the stern keep the wake light rather than a solid V.
wake=bpy.data.objects.new('Wake motion reference',None);scene.collection.objects.link(wake);wake.location=(7,-3,0);wake.rotation_euler.z=-.12
for side in [-1,1]:
 for k in range(8):
  y=4.8+k*.82;x=side*(1.25+k*.18)
  ob=line('Trailing foam',[(x,y,-.08),(x+side*.12,y+.3,-.075),(x+side*.22,y+.61,-.08)],.04 if k<4 else .028,wake)
  for f in [1,13,25,37,49]:
   wave=math.sin((f-1)*math.tau/48+k*.4)
   ob.location.y=.16*wave;ob.scale.x=1+.1*wave;ob.keyframe_insert(data_path='location',frame=f);ob.keyframe_insert(data_path='scale',frame=f)
for side in [-1,1]:
 line('Bow foam',[(side*.7,-3.8,-.09),(side*1.1,-3.3,-.08),(side*1.5,-2.65,-.07),(side*1.8,-2,-.08)],.052,wake)
for name,loc,power,size in [('Sunlight',(-30,-40,65),75000,50),('Sky fill',(40,25,55),32000,50)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Water review camera');d.type='ORTHO';d.ortho_scale=46;o=bpy.data.objects.new('Water review camera',d);scene.collection.objects.link(o);o.location=(38,-57,49);target=Vector((-2,1,1.5));o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler();scene.camera=o
scene.frame_set(1)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Water_Style_Study.blend'))
scene.render.filepath=str(OUT/'renders/water-study.png');bpy.ops.render.render(write_still=True)
scene.render.resolution_x=864;scene.render.resolution_y=576;scene.cycles.samples=10
for f in range(1,49):
 scene.frame_set(f);scene.render.filepath=str(OUT/'water-frames'/('%03d.png'%f));bpy.ops.render.render(write_still=True)
 print('WATER_FRAME',f,flush=True)
print('WATER_STUDY_COMPLETE',flush=True)
