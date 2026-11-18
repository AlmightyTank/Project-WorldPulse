"""Converts the Kenney Animated Characters Protagonists FBX set to GLB.

Blender imports the character model once per skin, imports idle/run/jump FBX
clips, keeps only those three actions, applies the skin texture, and exports
one GLB per skin. Run through tools/assets/import-kenney.ps1.
"""
import bpy
import json
import os
import sys

jobs_path = sys.argv[sys.argv.index("--") + 1]
with open(jobs_path, encoding="utf-8-sig") as fh:
    jobs = json.load(fh)

for job in jobs:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.fbx(filepath=job["model"])
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    armature.animation_data_create()

    # Each clip FBX brings its own armature copy and a static "Targeting Pose"
    # action. Keep the action with the longest frame range (the real clip) and
    # discard the rest.
    for clip in ("idle", "run", "jump"):
        existing_objects = set(bpy.context.scene.objects)
        existing_actions = set(bpy.data.actions)
        bpy.ops.import_scene.fbx(filepath=os.path.join(job["animations"], clip + ".fbx"))
        imported = [a for a in bpy.data.actions if a not in existing_actions]
        for obj in [o for o in bpy.context.scene.objects if o not in existing_objects and o.type == "ARMATURE"]:
            bpy.data.objects.remove(obj, do_unlink=True)
        if not imported:
            raise RuntimeError("No action imported for clip " + clip)
        action = max(imported, key=lambda a: a.frame_range[1] - a.frame_range[0])
        for other in imported:
            if other is not action:
                bpy.data.actions.remove(other)
        action.name = clip.capitalize()
        action.use_fake_user = True
        # Actions export through NLA tracks; a plain assigned action exports a
        # bind-pose sample with one key per track, so push each clip to a track.
        track = armature.animation_data.nla_tracks.new()
        track.name = action.name
        strip = track.strips.new(action.name, int(action.frame_range[0]), action)
        if action.slots:
            strip.action_slot = action.slots[0]

    for action in list(bpy.data.actions):
        if action.name not in ("Idle", "Run", "Jump"):
            bpy.data.actions.remove(action)

    material = bpy.data.materials.get("skin")
    if material and material.node_tree:
        nodes = material.node_tree.nodes
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        skin = bpy.data.images.load(job["skin"], check_existing=True)
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = skin
        tex.location = (-420, 260)
        if bsdf:
            material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            # The FBX material arrives with a zero alpha; glTF then exports
            # alphaMode MASK with factor 0 and the character renders invisible.
            bsdf.inputs["Alpha"].default_value = 1.0
            material.diffuse_color = (1.0, 1.0, 1.0, 1.0)
    else:
        print("WARN: no skin material for", job["out"])

    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    height = round(mesh.dimensions.z, 4)
    # Source stays authored size; Godot applies the manifest scale so joints
    # and animation translations scale together (glTF ignores node scale on
    # skinned meshes anyway).

    bpy.ops.export_scene.gltf(
        filepath=job["out"],
        export_format="GLB",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_anim_single_armature=True,
        export_yup=True,
    )
    print("CONVERTED", os.path.basename(job["out"]), "height_units", height,
          "actions", sorted(a.name for a in bpy.data.actions))
