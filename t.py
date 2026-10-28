import bpy
print(bpy.app.version_string, bpy.data.filepath)
sc=bpy.context.scene
print("frames", sc.frame_start, sc.frame_end, sc.frame_current)
for o in bpy.data.objects:
    a = o.animation_data.action.name if o.animation_data and o.animation_data.action else None
    print(o.name, o.type, o.parent.name if o.parent else None, [m.type for m in o.modifiers], a, len(o.data.vertices) if o.type=='MESH' else (len(o.data.bones) if o.type=='ARMATURE' else ''))
print("actions", [(a.name, tuple(a.frame_range)) for a in bpy.data.actions])
