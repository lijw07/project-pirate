"""Review-only pirate art assembly. Blender 5.1; originals remain untouched."""
import bpy, math, random, json, hashlib, shutil, sys
from pathlib import Path
from mathutils import Vector
ROOT = Path('/Users/jaili/projects/godot/project-pirate')
OUT = ROOT/'art-review/pirate-art-v1'
KIT = ROOT/'kenney_pirate-kit/Models/GLB format'
random.seed(47)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if not c.objects and c.name != 'Collection': bpy.data.collections.remove(c)
world = bpy.context.scene
world.name = '01 • The Sapphire Reach'
cache = {}; used = set(); prefabs = {}; review_cameras = {}
lib = bpy.data.collections.new('SOURCE • Kenney Pirate Kit 2.1')
# Library is deliberately unlinked from all scenes; instances are real, editable objects.
def material(name, hexval, roughness=.7, metal=0):
    srgb = tuple(int(hexval[i:i+2],16)/255 for i in (0,2,4))
    rgb = tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in srgb)
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=roughness; p.inputs['Metallic'].default_value=metal
    return m
M={k:material(k,*v) for k,v in {
    'Deep sea':('237D8F',.35), 'Lagoon':('288F98',.4), 'Foam':('A4E0CF',.8),
    'Ivory':('F5E4B8',.85),'Sand':('E9AE76',.9),'Wet sand':('CA996A',.9),
    'Soil':('795041',1),'Timber':('99512F',.9),'Cut timber':('D99A59',.9),
    'Teal':('168F86',.8),'Red':('B64F48',.8),'Dark iron':('414E64',.6,.2),
    'Steel':('8495A4',.55,.15),'Ore':('B1C0CE',.5,.15),'Gold':('F2BA42',.5,.2),
    'Leaf':('559B62',.9),'Crop':('8DBD61',.9),'Orange':('D88740',.8),
    'Rock':('6A7287',.9),'Black':('263543',.95),'Board':('123447',.85)
}.items()}

def group(name,scene=world):
    c=bpy.data.collections.new(name); scene.collection.children.link(c); return c

def root(name,col,at=(0,0,0)):
    ob=bpy.data.objects.new(name,None); col.objects.link(ob); ob.location=at; return ob

def place(ob,col,parent=None):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    col.objects.link(ob)
    if parent: ob.parent=parent
    return ob

def source(name):
    if name in cache:return cache[name]
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(KIT/(name+'.glb')))
    obs=list(set(bpy.data.objects)-before)
    for o in obs:place(o,lib)
    cache[name]=obs; used.add(name)
    return obs

def model(name,parent,at=(0,0,0),scale=1,angle=0,label=None,sail=None):
    orig=source(name); copies={}
    col=parent.users_collection[0]
    for o in orig:
        n=o.copy(); col.objects.link(n); copies[o]=n
    for o,n in copies.items():
        n.parent=copies[o.parent] if o.parent in copies else parent
        if o.parent not in copies:
            n.location=at; n.rotation_euler.z=math.radians(angle)
            n.scale=(scale,)*3 if isinstance(scale,(float,int)) else scale
            n.name=label or name
        if sail and ('sail' in o.name or 'flag' in o.name):
            n.data=o.data.copy(); n.data.materials.append(M[sail])
            # Preserve the original wood spars and fittings; tint only pale cloth faces.
            uv=n.data.uv_layers.active
            image=next((node.image for node in n.data.materials[0].node_tree.nodes if node.type=='TEX_IMAGE'),None)
            if image and uv:
                px=list(image.pixels); w,h=image.size
                for face in n.data.polygons:
                    coord=sum((uv.data[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
                    u,v=int(coord.x*w)%w,int(coord.y*h)%h
                    rgb=px[(v*w+u)*4:(v*w+u)*4+3]
                    if min(rgb)>.60 and max(rgb)-min(rgb)<.22:face.material_index=len(n.data.materials)-1
    return next(n for o,n in copies.items() if o.parent not in copies)

def cube(name,parent,at,size,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o=place(bpy.context.object,parent.users_collection[0],parent); o.name=name;o.location=at;o.scale=size
    o.data.materials.append(M[mat])
    if bevel:
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        mod=o.modifiers.new('Soft cut edges','BEVEL'); mod.width=bevel;mod.segments=1
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o

def ico(name,parent,at,size,mat,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1)
    o=place(bpy.context.object,parent.users_collection[0],parent);o.name=name;o.location=at
    o.scale=(size,)*3 if isinstance(size,(int,float)) else size;o.data.materials.append(M[mat]);return o

def cylinder(name,parent,at,radius,depth,mat,vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth)
    o=place(bpy.context.object,parent.users_collection[0],parent);o.name=name;o.location=at;o.data.materials.append(M[mat]);return o

def beam(name,parent,a,b,width,mat):
    a,b=Vector(a),Vector(b)
    o=cube(name,parent,(a+b)/2,(width,width,(a-b).length),mat)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def curve(name,parent,pts,width,mat,closed=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=width;cu.bevel_resolution=0
    sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
    for p,xyz in zip(sp.points,pts):p.co=(*xyz,1)
    sp.use_cyclic_u=closed
    o=bpy.data.objects.new(name,cu);parent.users_collection[0].objects.link(o);o.parent=parent;cu.materials.append(M[mat]);return o

def text(name,parent,body,at,size=.65,mat='Ivory',rotation=(0,0,0)):
    cu=bpy.data.curves.new(name,'FONT');cu.body=body;cu.align_x='CENTER';cu.size=size;cu.extrude=0
    ob=bpy.data.objects.new(name,cu);parent.users_collection[0].objects.link(ob);ob.parent=parent;ob.location=at;ob.rotation_euler=rotation;cu.materials.append(M[mat]);return ob

def flag(parent,at,color='Teal',height=4):
    x,y,z=at
    cylinder('Capture mast',parent,(x,y,z+height/2),.065,height,'Timber')
    verts=[(x,y,z+height),(x+1.5,y+.1,z+height-.1),(x+1.12,y-.1,z+height-.65),(x,y,z+height-.6)]
    mesh=bpy.data.meshes.new('Flag cloth');mesh.from_pydata(verts,[],[(0,1,2,3)]);mesh.materials.append(M[color])
    ob=bpy.data.objects.new('Faction pennant',mesh);parent.users_collection[0].objects.link(ob);ob.parent=parent

def terrain(parent,large=False,rocky=False):
    s=1.18 if large else 1
    model('patch-sand',parent,(0,0,-.02),(2.7*s,2.8*s,4.6),label='Beach • sandy silhouette')
    model('patch-grass',parent,(-.4,.3,1.0),(3.0*s,3.15*s,1.3),label='Island ground cover')
    # Low shelves follow the source's irregular outline and give the waterline depth.
    model('patch-sand',parent,(0,0,-.20),(2.93*s,3.05*s,1.8),label='Wet sand shelf')
    for j in range(3):
        a=j*2.1+.6
        model('rocks-sand-a',parent,(math.cos(a)*8*s,math.sin(a)*6*s,.25),(.7,.8,.5),angle=j*73)
    for radius,w in [(1.10,.065),(1.22,.038)]:
        pts=[]
        for i in range(90):
            a=i*math.tau/90;r=1+0.045*math.sin(a*5)+.03*math.cos(a*7)
            pts.append((math.cos(a)*10.6*s*radius*r,math.sin(a)*8.3*s*radius*r,-.09))
        curve('Shore foam',parent,pts,w,'Foam',True)
    for i in range(4 if rocky else 6):
        a=0.3+i*.89
        model('palm-detailed-bend' if i%2==0 else 'palm-straight',parent,(math.cos(a)*7*s,math.sin(a)*5*s,1.2),.9+random.random()*.25,angle=i*65)

def dock(parent,x=0,y=-9,wide=False):
    for j in range(3):
        model('structure-platform-dock',parent,(x,y-j*2.2,.1),(1.15,1.05,1),label='Dock • pier %d'%j)
    if wide:
        for i in [-1,1]:
            model('structure-platform-dock',parent,(x+i*2.7,y-4.4,.1),(1.1,1.05,1))
    for xx in [-1.4,1.4]:
        for yy in [0,-4.5]:
            cylinder('Mooring bollard',parent,(x+xx,y+yy,.85),.15,1.4,'Timber')
            curve('Mooring rope',parent,[(x+xx,y+yy,1.25),(x+xx+.07,y+yy-.8,1.0),(x+xx,y+yy-1.4,1.25)],.06,'Ivory')

def house(parent,at,scale=1,roof=True):
    model('structure-roof' if roof else 'structure',parent,at,scale)

def props(parent,at=(0,0,1.3),kind='barrel',n=3):
    for i in range(n):model(kind,parent,(at[0]+(i%3)*.8,at[1]+(i//3)*.8,at[2]),.65,angle=i*17)

def log(parent,at,length=3,axis='X'):
    o=cylinder('Timber • bark',parent,at,.27,length,'Timber',9)
    o.rotation_euler[1 if axis=='X' else 0]=math.pi/2
    for side in [-1,1]:
        pos=list(at);pos[0 if axis=='X' else 1]+=side*length/2
        cap=cylinder('Timber • cut end',parent,pos,.24,.025,'Cut timber',9);cap.rotation_euler=o.rotation_euler

def food(parent):
    terrain(parent);dock(parent,x=-1)
    house(parent,(-4,1,1.35),1.15)
    # Terraced market garden; silhouette reads as cultivation even from overhead.
    for y in [-3,-1,1]:
        cube('Raised garden bed',parent,(2.2,y,1.4),(4.5,1.35,.18),'Soil',.1)
        for x in [.5,1.5,2.5,3.5]:
            ico('Cabbage',parent,(x,y,1.8),(.32,.32,.3),'Crop',1)
            for dx in [-.22,.22]:ico('Cabbage leaf',parent,(x+dx,y,1.65),(.25,.38,.1),'Leaf')
    for x in [-.2,4.7]:
        for y in [-3.8,1.8]:cube('Garden fence post',parent,(x,y,1.85),(.12,.12,1.3),'Timber')
    beam('Garden rail',parent,(-.2,1.8,2.1),(4.7,1.8,2.1),.10,'Cut timber')
    for i in range(5):ico('Pumpkin',parent,(-4+i*.7,-2.5,1.65),(.3,.28,.27),'Orange',2)
    # Fish-drying rack beside the pier.
    for x in [-5.0,-2.0]:beam('Drying-rack support',parent,(x,-5,1.1),(x,-5,3.1),.13,'Timber')
    beam('Drying-rack top',parent,(-5,-5,3.0),(-2,-5,3.0),.12,'Timber')
    for i in range(5):
        x=-4.7+i*.52
        curve('Fish tie',parent,[(x,-5,3),(x,-5,2.5)],.025,'Ivory')
        ico('Dried fish',parent,(x,-5,2.17),(.13,.11,.37),'Steel')
    props(parent,(-6,-1,1.3),'barrel',4);props(parent,(-1,-7,1.15),'crate-bottles',2)
    flag(parent,(-.5,4,1.3),'Teal')

def timber(parent):
    terrain(parent);dock(parent,x=1)
    for i,(x,y) in enumerate([(-3,2),(-1,3.8),(1.5,3),(4,2.6),(3.3,5),(-4.5,4.2)]):
        model('palm-detailed-straight',parent,(x,y,1.3),1.05+(i%3)*.12,angle=i*42)
    house(parent,(-4,-1.2,1.3),1.2)
    for j in range(3):
        for i in range(3-j):log(parent,(1.0,-3+i*.65+j*.30,1.65+j*.48),4)
    for i in range(4):
        cube('Sawn plank stack',parent,(4.7,-.8,1.5+i*.16),(2.7,.95,.12),'Cut timber',.025)
    for x in [-2.5,2.8]:
        cylinder('Tree stump',parent,(x,-5,1.55),.45,.5,'Timber',9)
        cylinder('Tree rings',parent,(x,-5,1.81),.4,.02,'Cut timber',9)
    cube('Saw bench',parent,(1.3,-.3,2),(3.7,.7,.2),'Timber')
    for x in [-.1,2.7]:cube('Saw bench legs',parent,(x,-.3,1.6),(.2,.5,.8),'Timber')
    beam('Saw blade',parent,(-.4,-.3,2.3),(2.8,-.3,2.3),.12,'Steel')
    props(parent,(-1,-7,1.15),'crate',3);flag(parent,(-5,2,1.3),'Teal')

def gold(parent):
    terrain(parent);dock(parent,x=-1,wide=True)
    house(parent,(-3,1.7,1.3),1.5)
    model('tower-base-door',parent,(3,2,1.3),.8)
    for x,y,s in [(4.7,4.0,1.1),(6,1,1),(-5.8,3.3,.8)]:
        model('rocks-sand-b',parent,(x,y,1.2),s)
        for j in range(4):ico('Exposed gold vein',parent,(x+random.uniform(-.6,.6),y+random.uniform(-.6,.6),2+j*.25),(.27,.23,.32),'Gold')
    for i in range(3):
        model('chest',parent,(-2+i*1.5,-2,1.3),.95,angle=-12+i*12)
        for j in range(3):cube('Gold ingot',parent,(-2+i*1.5+j*.26,-3,1.5),(.22,.48,.16),'Gold',.04)
    props(parent,(3,-2,1.3),'crate',4)
    for i in range(4):model('structure-fence',parent,(-4+i*2.3,-4.5,1.25),.8)
    flag(parent,(0,2,1.3),'Gold')

def metal(parent):
    terrain(parent,rocky=True);dock(parent,x=0,wide=True)
    for x,y,s in [(-3,2.5,1.3),(0,3.7,1.6),(3.8,2.5,1.2)]:
        model('rocks-a',parent,(x,y,1.2),s,angle=x*10)
        for j in range(4):ico('Silver ore seam',parent,(x+random.uniform(-1,1),y-.9,2.1+j*.36),(.36,.27,.45),'Ore')
    cube('Mine entrance • dark recess',parent,(-.4,-.9,2.5),(2.8,.35,2.7),'Black',.2)
    for x in [-1.8,1]:beam('Mine timber upright',parent,(x,-1.15,1.3),(x,-1.15,4.2),.3,'Timber')
    beam('Mine lintel',parent,(-2,-1.15,4.2),(1.2,-1.15,4.2),.36,'Cut timber')
    for x in [-.9,.5]:beam('Mine rail',parent,(x,-4,1.37),(x,1.5,1.37),.09,'Dark iron')
    for y in [-3.8,-2.8,-1.8,-.8,.2,1.2]:cube('Rail sleeper',parent,(-.2,y,1.3),(1.9,.19,.12),'Timber')
    cube('Ore cart',parent,(-.2,-1.9,1.95),(1.1,1.45,.65),'Dark iron',.12)
    for x in [-.85,.45]:
        for y in [-2.4,-1.4]:
            wheel=cylinder('Ore-cart wheel',parent,(x,y,1.6),.24,.13,'Steel');wheel.rotation_euler.y=math.pi/2
    for i in range(5):ico('Cart ore',parent,(-.5+(i%2)*.55,-2.4+(i//2)*.42,2.35),.31,'Ore')
    # Timber crane, suspended metal load, and a small forge distinguish industry.
    beam('Crane upright',parent,(4,-3,1.3),(4,-3,6),.3,'Timber')
    beam('Crane jib',parent,(4,-3,5.8),(1,-4.5,5.8),.27,'Timber')
    beam('Crane brace',parent,(4,-3,3.8),(2.2,-3.9,5.8),.2,'Cut timber')
    curve('Crane rope',parent,[(1,-4.5,5.8),(1,-4.5,2.2)],.045,'Ivory')
    for i in range(3):cube('Iron ingot bundle',parent,(1+i*.25,-4.5,1.8),(.24,.8,.22),'Steel',.03)
    model('tower-base',parent,(-5,-1,1.3),(.6,.6,.45),label='Stone forge')
    cube('Forge chimney',parent,(-5,.1,3.4),(.85,.85,2.7),'Rock',.1)
    flag(parent,(5,1,1.3),'Steel')

def harbor(parent,enemy=False):
    terrain(parent,large=True);dock(parent,x=-3,wide=True);dock(parent,x=3,wide=True)
    color='Red' if enemy else 'Teal'
    for x in [-5.2,5.2]:
        model('tower-complete-large',parent,(x,1.8,1.3),.7,label='Harbor bastion')
        flag(parent,(x,1.8,8.35),color,2.7)
        cube('Faction banner',parent,(x,.50,5.9),(1.15,.045,2.1),color)
        ico('Banner crest',parent,(x,.455,6.0),(.24,.035,.34),'Ivory')
        model('cannon',parent,(x,-2,1.3),.95,angle=180)
    model('castle-gate',parent,(0,1.8,1.3),1.1,angle=90,label='Harbor keep gate')
    for x in [-3.3,3.3]:model('castle-wall',parent,(x,1.8,1.3),(.7,.85,.7),angle=90)
    house(parent,(-4,-3.5,1.3),1.1);house(parent,(4,-3.5,1.3),1.1)
    for x in [-8,8]:
        model('tower-watch',parent,(x,0,1.2),.65)
    props(parent,(-6,-6.5,1.2),'barrel',5);props(parent,(4,-7,1.2),'crate',6)
    model('chest',parent,(1,-4,1.3),.8)
    # Shipyard stock visually connects the harbor with modular outfitting.
    model('mast',parent,(7,4,1.3),.55,sail=color)
    for j in range(3):log(parent,(-3+j*.1,5,1.6+j*.45),3.5)
    flag(parent,(0,-1,1.3),color,5)

def ship(parent,kind='scout',at=(0,0,0),angle=0):
    col=parent.users_collection[0]
    rig=root('Ship • '+kind,col,at);rig.parent=parent;rig.rotation_euler.z=math.radians(angle)
    asset='ship-small' if kind=='scout' else ('ship-pirate-medium' if kind=='corsair' else 'ship-medium')
    hull=model(asset,rig,scale=.95 if kind=='scout' else 1,sail='Teal' if kind!='corsair' else None,label='Hull + rigging')
    for side in [-1,1]:
        for j in range(1 if kind=='scout' else (3 if kind in ['warship','corsair'] else 2)):
            model('cannon',rig,(side*2.0,-1.6+j*1.4,2.0),.65,angle=side*90,label='Cannon slot %s %s'%(side,j))
    if kind in ['warship','corsair']:
        for side in [-1,1]:
            for j in range(4):
                o=cube('Armor • removable plate',rig,(side*2.22,-2.2+j*1.2,1.25),(.18,1.03,.85),'Dark iron',.07)
                for yy in [-.32,.32]:ico('Armor rivet',rig,(side*2.33,-2.2+j*1.2+yy,1.37),.075,'Gold')
    if kind=='trader':
        for x in [-.8,0,.8]:
            for y in [-2.0,-1.2]:model('crate',rig,(x,y,2.3),.65)
        for x in [-.7,.1,.9]:model('barrel',rig,(x,2.7,2.3),.65)
    # Presentation-only animation is authored in the .blend, not gameplay code.
    for f,z,tilt in [(1,0,-.012),(31,.10,.018),(61,0,-.012)]:
        rig.location.z=at[2]+z;rig.rotation_euler.y=tilt
        rig.keyframe_insert(data_path='location',frame=f);rig.keyframe_insert(data_path='rotation_euler',frame=f)
    return rig

def setup(scene):
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.world=bpy.data.worlds.new(scene.name+' • atmosphere');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.27,.43,.52,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.fps=24;scene.frame_end=60
    col=group('Lighting & cameras',scene)
    for name,loc,power,size in [('Warm key',(-40,-55,95),110000,65),('Cool fill',(45,30,75),60000,80)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        ob=bpy.data.objects.new(name,data);col.objects.link(ob);ob.location=loc;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
    data=bpy.data.lights.new('Soft sun','SUN');data.energy=1.5;data.angle=.25
    ob=bpy.data.objects.new('Soft sun',data);col.objects.link(ob);ob.rotation_euler=(.35,-.45,-.5)
    return col

def camera(scene,col,name,target,distance=50,scale=30,azimuth=-55,elevation=48):
    a,e=math.radians(azimuth),math.radians(elevation)
    ob=bpy.data.objects.new(name,bpy.data.cameras.new(name));col.objects.link(ob)
    ob.location=Vector(target)+Vector((math.cos(a)*math.cos(e),math.sin(a)*math.cos(e),math.sin(e)))*distance
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    ob.data.type='ORTHO';ob.data.ortho_scale=scale;ob.data.lens=50;ob.data.clip_end=1500
    scene.camera=ob;review_cameras[name]=ob;return ob

def sea(scene,size=300):
    col=group('Water • stylized lagoon',scene);r=root('Ocean',col)
    o=cube('Water surface',r,(0,0,-.32),(size,size,.1),'Deep sea')
    mat=M['Deep sea'];nd=mat.node_tree.nodes;ln=mat.node_tree.links;p=nd.get('Principled BSDF')
    noise=nd.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=.9;noise.inputs['Detail'].default_value=2
    tex=nd.new('ShaderNodeTexCoord');ln.new(tex.outputs['Object'],noise.inputs['Vector'])
    bump=nd.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.08
    ln.new(noise.outputs['Fac'],bump.inputs['Height']);ln.new(bump.outputs['Normal'],p.inputs['Normal'])
    return r

lights=setup(world);water=sea(world)
locations={'food':(-25,-5,0),'timber':(-29,31,0),'gold':(13,33,0),'metal':(29,-6,0),'harbor-player':(-41,-42,0),'harbor-enemy':(47,47,0)}
labels={'food':'01 • Provision Cay','timber':'02 • Palmwood Isle','gold':'03 • Gilded Key','metal':'04 • Ironwake Mine','harbor-player':'05 • Tidewatch Harbor','harbor-enemy':'06 • Redwake Stronghold'}
for kind,at in locations.items():
    col=group(labels[kind]);r=root(labels[kind],col,at);prefabs[kind]=r
    if kind.startswith('harbor'):harbor(r,kind.endswith('enemy'))
    else:globals()[kind](r)
    target=Vector(at)+Vector((0,-1,2))
    camera(world,lights,kind,target,60,36 if kind.startswith('harbor') else 32)
ships=group('Fleet • visual mockups');fleet=root('Fleet',ships)
ship(fleet,'warship',(-24,-35,0),-15)
ship(fleet,'trader',(1,-1,0),-28)
prefabs['ship-corsair']=ship(fleet,'corsair',(49,24,0),165)
ship(fleet,'scout',(-13,17,0),35)
# Light foam dashes keep the sea graphic, quiet, and readable.
for i in range(140):
    x,y=random.uniform(-75,75),random.uniform(-65,75)
    if any((x-a[0])**2+(y-a[1])**2<210 for a in locations.values()):continue
    curve('Sea glint',water,[(x,y,-.20),(x+.6,y+.08,-.20),(x+1.4,y,-.20)],.022,'Foam')
cam=camera(world,lights,'archipelago',(1,3,0),200,157,-67,55)
world.camera=cam
world.frame_set(1)

# Dedicated ship design scene: three outfitting variants, plus detached module study.
shipscene=bpy.data.scenes.new('02 • Modular Ship Workshop');sl=setup(shipscene);sea(shipscene,200)
sc=group('Three ship loadouts',shipscene);sr=root('Ship loadouts',sc)
for name,pos,ang in [('scout',(-12,0,0),-18),('warship',(0,0,0),-18),('trader',(13,0,0),-18)]:
    rig=ship(sr,name,pos,ang);prefabs['ship-'+name]=rig
camera(shipscene,sl,'ship-lineup',(0,0,3),65,42,-68,32)
for name,pos in [('scout',(-12,0,3)),('warship',(0,0,3)),('trader',(13,0,3))]:
    camera(shipscene,sl,'ship-'+name,Vector(pos)+Vector((0,0,1)),45,22,-60,32)
shipscene.camera=review_cameras['ship-lineup']

modules=bpy.data.scenes.new('03 • Outfitting Modules');ml=setup(modules)
mc=group('Module library',modules);mr=root('Removable fittings',mc)
cube('Backdrop',mr,(0,0,-.3),(200,200,.2),'Board')
for i,name in enumerate(['Cannons','Rigging','Armor','Cargo']):
    r=root('Module • '+name,mc,(-9+i*6,0,0));r.parent=mr;prefabs['module-'+name.lower()]=r
    cylinder('Display plinth',mr,(-9+i*6,0,-.05),2.5,.28,'Black',48)
    if i==0:
        model('cannon',r,(-.6,-.4,.15),1.0,angle=-25)
        for j in range(4):ico('Cannonball',r,(.8+(j%2)*.45,.3+(j//2)*.45,.35),.2,'Dark iron',2)
    elif i==1:model('mast',r,(0,0,.1),.67,sail='Teal')
    elif i==2:
        for j in range(3):
            cube('Armor plate',r,(-1.1+j*.75,0,1.0),(.65,.3,1.8),'Dark iron',.08)
            for z in [.4,1.6]:ico('Armor bolt',r,(-1.1+j*.75,-.2,z),.09,'Gold')
    else:
        for x in [-.65,.1]:model('crate',r,(x,0,.1),.7)
        model('barrel',r,(.8,.3,.1),.9)
    text(name+' label',mr,name.upper(),(-9+i*6,-3.0,.02),.55,'Ivory')
camera(modules,ml,'modules',(0,0,1.2),55,30,-75,35)

# Export clean visual assemblies, without cameras, water, lights, or gameplay.
def descendants(r):
    out=[r]
    for ch in r.children:out+=descendants(ch)
    return out
for name,r in prefabs.items():
    scene=shipscene if name.startswith('ship-') and name!='ship-corsair' else modules if name.startswith('module-') else world
    bpy.context.window.scene=scene
    bpy.ops.object.select_all(action='DESELECT')
    obs=descendants(r)
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=r
    # Root origin is reset only during export; source placement is restored.
    loc=r.location.copy();r.location=(0,0,0)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'models'/(name+'.glb')),use_selection=True,export_format='GLB',export_animations=False,export_apply=True,use_active_scene=True)
    r.location=loc
bpy.context.window.scene=world
world.camera=review_cameras['archipelago']
for scene in [world,shipscene,modules]:
    scene.frame_set(1)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pirate_Art_Review.blend'))
manifest={'status':'Art review only; not approved for gameplay integration','source':'Kenney Pirate Kit 2.1','source_license':'CC0-1.0; see License-Kenney.txt','custom_geometry':'Original farm, timber, mining, armor, foam and presentation additions created for this project','units':'meters; Blender Z-up; GLB Y-up','assets':{},'source_models':sorted(used),'scenes':[s.name for s in [world,shipscene,modules]],'animation':'Presentation-only ship bob/roll, frames 1–60 at 24 fps, in Blender; GLBs are static'}
for p in sorted((OUT/'models').glob('*.glb')):
    manifest['assets'][p.name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
shutil.copyfile(ROOT/'kenney_pirate-kit/License.txt',OUT/'License-Kenney.txt')
(OUT/'source/source-hashes.json').write_text(json.dumps({n:hashlib.sha256((KIT/(n+'.glb')).read_bytes()).hexdigest() for n in sorted(used)},indent=2))
# Render the overview first; the saved source can render remaining views independently.
world.render.resolution_x=1920;world.render.resolution_y=1440
world.render.filepath=str(OUT/'renders/archipelago.png')
bpy.ops.render.render(write_still=True)
print('ART_BUILD_COMPLETE',str(OUT),flush=True)
