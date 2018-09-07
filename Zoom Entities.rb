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

def vertical_fov
  view = Sketchup.active_model.active_view
  if view.camera.fov_is_height?
    view.camera.fov.degrees
  else
    Math.atan(Math.tan(horizontal_fov / 2 ) * view.vpheight.to_f / view.vpwidth) * 2
  end
end

def horizontal_fov
  view = Sketchup.active_model.active_view
  if view.camera.fov_is_height?
    Math.atan(Math.tan(vertical_fov / 2 ) * view.vpwidth.to_f / view.vpheight) * 2
  else
    view.camera.fov.degrees
  end
end

def frustrum_extremes(points, horizontal_fov = horizontal_fov(), vertical_fov = vertical_fov())
  [
    points.max_by { |pt| pt.x - pt.z * Math.tan(horizontal_fov / 2) },
    points.min_by { |pt| pt.x + pt.z * Math.tan(horizontal_fov / 2) },
    points.max_by { |pt| pt.y - pt.z * Math.tan(vertical_fov / 2) },
    points.min_by { |pt| pt.y + pt.z * Math.tan(vertical_fov / 2) }
  ]
end

def place_camera(extremes, horizontal_fov = horizontal_fov(), vertical_fov = vertical_fov())
  k = Math.tan(horizontal_fov / 2)
  m0 = extremes[0].x - k * extremes[0].z
  m1 = extremes[1].x + k * extremes[1].z
  z = (m1 - m0) / (2 * k)

  # DEBUG: To start with, just find the z offset needed for zoom extents.
  # Should be 0 when already in horizontally confided zoom extents.
  #
  # Nope, should not be 0 for native zoom extents as that adds some margin on
  # the sides!
  p z
end

model = Sketchup.active_model
transformation = camera_transformation.inverse
points = model.selection.flat_map { |e| points(e) }.map { |pt| pt.transform(transformation) }
extremes = frustrum_extremes(points)
place_camera(extremes)

# Testing
model.selection.add(draw_points(extremes.map { |pt| pt.transform(transformation.inverse) } ))