class_name WorldBuilder
extends RefCounted


static func build_reservations(parent: Node3D, layout: WorldLayout) -> void:
    var plots := Node3D.new()
    plots.name = "ReservedPlots"
    plots.visible = false
    parent.add_child(plots)
    for plot_id: String in layout.plots:
        var plot: Dictionary = layout.plots[plot_id]
        var color: Color = layout.districts[plot.district].color
        slab(plots, plot_id, layout.meters(plot.rect).grow(-0.40), -0.009, 0.02, Color("86996f").lerp(color, 0.32))
    var plaza := layout.meters(layout.plaza)
    slab(parent, "Plaza", plaza, 0.16, 0.18, Color("bcaf95"))
    slab(parent, "PlazaPaving", plaza.grow(-1.5), 0.165, 0.015, Color("d4bd91"))


static func build_roads(parent: Node3D, layout: WorldLayout) -> bool:
    for cell: Vector2i in layout.roads:
        var tile: Dictionary = layout.roads[cell]
        var road := KenneyAssets.instance(tile.asset_id)
        if road == null:
            return false
        road.name = "Road_%02d_%02d" % [cell.x, cell.y]
        road.position = at(layout.cell_center(cell), 0.0)
        road.rotation.y = float(tile.turns) * PI / 2.0
        road.set_meta("asset_id", tile.asset_id)
        parent.add_child(road)
    return true


static func at(xz: Vector2, y: float) -> Vector3:
    return Vector3(xz.x, y, xz.y)


static func slab(parent: Node3D, id: String, rect: Rect2, top: float, depth: float, color: Color) -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    var mesh := BoxMesh.new()
    mesh.size = Vector3(rect.size.x, depth, rect.size.y)
    mesh.material = material
    var slab := MeshInstance3D.new()
    slab.name = id
    slab.mesh = mesh
    slab.position = at(rect.get_center(), top - depth / 2.0)
    slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(slab)
