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

# Find left, right, top and bottom extreme points.
def frustrum_extremes(points, horizontal_fov = horizontal_fov(), vertical_fov = vertical_fov())
  [
    points.max_by { |pt| pt.x - pt.z * Math.tan(horizontal_fov / 2) },
    points.min_by { |pt| pt.x + pt.z * Math.tan(horizontal_fov / 2) },
    points.max_by { |pt| pt.y - pt.z * Math.tan(vertical_fov / 2) },
    points.min_by { |pt| pt.y + pt.z * Math.tan(vertical_fov / 2) }
  ]
end

# Find 2D coordinates for possible camera position. First coordinate is for the
# dimension given by `dimension_index`, second is Z.
#
# @param extremes [Array<(Geom::Point3d, Geom::Point3d)>]
# @param fov [Float] Field of view in radians.
# @param dimension_index [Integer] Dimension to check. 0 for X, 1 for Y.
#
# @return [Array<(Float, Float)>]
def camera_2d_coords(extremes, fov, dimension_index)
  k = Math.tan(fov / 2)
  m0 = extremes[0].to_a[dimension_index] - k * extremes[0].z
  m1 = extremes[1].to_a[dimension_index] + k * extremes[1].z
  z = (m1 - m0) / (2 * k)

  [k * z + m0, z]
end

def camera_coords(extremes, horizontal_fov = horizontal_fov(), vertical_fov = vertical_fov())
  c0 = camera_2d_coords(extremes[0..1], horizontal_fov, 0)
  c1 = camera_2d_coords(extremes[2..3], vertical_fov, 1)

  Geom::Point3d.new(c0[0], c1[0], [c0[1], c1[1]].min)
end

model = Sketchup.active_model
transformation = camera_transformation.inverse
points = model.selection.flat_map { |e| points(e) }.map { |pt| pt.transform(transformation) }
extremes = frustrum_extremes(points)
p camera_coords(extremes)

# Testing
model.selection.add(draw_points(extremes.map { |pt| pt.transform(transformation.inverse) } ))