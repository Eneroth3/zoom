def points(entity, transformation = IDENTITY)
  case entity
  when Sketchup::ComponentInstance, Sketchup::Group
    entity.definition.entities.flat_map { |e| points(e, transformation * entity.transformation) }
  when Sketchup::Edge, Sketchup::Face
    entity.vertices.map { |v| v.position.transform(transformation) }
  else
    []
  end.uniq
end

# @example:
#   draw_points(points(model.selection.first))
def draw_points(points)
  model = Sketchup.active_model
  model.start_operation("Test", true)
  pts = points.map { |pt| model.entities.add_cpoint(pt) }
  model.commit_operation

  pts
end

def camera_transformation
  camera = Sketchup.active_model.active_view.camera

  Geom::Transformation.axes(camera.eye, camera.xaxis, camera.yaxis, camera.zaxis)
end

def frustrum_extremes(points)
  view = Sketchup.active_model.active_view
  vertical_fov = view.camera.fov / 2
  horisontal_tan = horizontal_fov * view.vpheight / view.vpwidth
p Math.atan(horisontal_tan).radians

  [
    points.max_by { |pt| pt.x - pt.z * vertical_fov }, # Correctly adjust for actual fov.
    points.max_by { |pt| pt.x + pt.z * vertical_fov },
    points.max_by { |pt| pt.y - pt.z * horisontal_tan },
    points.max_by { |pt| pt.y + pt.z * horisontal_tan }
  ]
end

transformation = camera_transformation.inverse
points = points(model.selection.first).map { |pt| pt.transform(transformation) }
extremes = frustrum_extremes(points)
# Place camera between these points somehow.

# Testing
draw_points(points - extremes)
Sketchup.active_model.selection.add(draw_points(extremes))