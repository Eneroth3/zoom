# Recursively find all points in entity.
#
# @param entity [Sketchup::DrawingElement]
# @param transformation [Geom::Transformation]
#
# @return [Array<Geom::Point3d>]
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

# Get the transformation defining the placement of the active camera. Used for
# converting between model space and camera space.
#
# @return [Geom::Transformation]
def camera_transformation
  camera = Sketchup.active_model.active_view.camera

  Geom::Transformation.axes(camera.eye, camera.xaxis, camera.yaxis, camera.zaxis)
end

# Get vertical field of view angle for active view. Angle in radians.
#
# @return [Float]
def vertical_fov
  view = Sketchup.active_model.active_view
  if view.camera.fov_is_height?
    view.camera.fov.degrees
  else
    Math.atan(Math.tan(horizontal_fov / 2 ) * view.vpheight.to_f / view.vpwidth) * 2
  end
end

# Get horizontal field of view angle for active view. Angle in radians.
#
# @return [Float]
def horizontal_fov
  view = Sketchup.active_model.active_view
  if view.camera.fov_is_height?
    Math.atan(Math.tan(vertical_fov / 2 ) * view.vpwidth.to_f / view.vpheight) * 2
  else
    view.camera.fov.degrees
  end
end

# Find left, right, top and bottom extreme points. All coordinates in camera
# space.
#
# @para points [Array<Geom::Point3d>]
# @param horizontal_fov [Float]
# @param vertical_fov [Float]
#
# @return [Array<(Geom::Point3d, Geom::Point3d, Geom::Point3d, Geom::Point3d)>]
def frustrum_extremes(points, horizontal_fov = horizontal_fov(), vertical_fov = vertical_fov())
  [
    points.max_by { |pt| pt.x - pt.z * Math.tan(horizontal_fov / 2) },
    points.min_by { |pt| pt.x + pt.z * Math.tan(horizontal_fov / 2) },
    points.max_by { |pt| pt.y - pt.z * Math.tan(vertical_fov / 2) },
    points.min_by { |pt| pt.y + pt.z * Math.tan(vertical_fov / 2) }
  ]
end

# Find 2D coordinates for possible camera position. First coordinate is for the
# dimension given by `dimension_index`, second is Z. All coordinates in camera
# space.
#
# @param extremes [Array<(Geom::Point3d, Geom::Point3d)>]
# @param fov [Float] Field of view in radians.
# @param dimension_index [Integer] 0 for X, 1 for Y.
#
# @return [Array<(Float, Float)>]
def camera_2d_coords(extremes, fov, dimension_index)
  k = Math.tan(fov / 2)
  m0 = extremes[0].to_a[dimension_index] - k * extremes[0].z
  m1 = extremes[1].to_a[dimension_index] + k * extremes[1].z
  z = (m1 - m0) / (2 * k)

  [k * z + m0, z]
end

# Find 3D coordinates for zoom entities camera. All coordinates in camera space.
#
# @param extremes [Array<(Geom::Point3d, Geom::Point3d, Geom::Point3d, Geom::Point3d)>]
# @param horizontal_fov [Float]
# @param vertical_fov [Float]
#
# @return [Geom::Point3d]
def camera_coords(extremes, horizontal_fov = horizontal_fov(), vertical_fov = vertical_fov())
  c0 = camera_2d_coords(extremes[0..1], horizontal_fov, 0)
  c1 = camera_2d_coords(extremes[2..3], vertical_fov, 1)

  Geom::Point3d.new(c0[0], c1[0], [c0[1], c1[1]].min)
end

# Place camera at position. Coordinates in camera space.
#
# @param position [Geom::Point3d]
# @param camera [Sketchup::Camera]
#
# @return [Void]
def place_camera(position, camera = Sketchup.active_model.active_view.camera)
  eye = position.transform(camera_transformation)
  offset = eye - camera.eye
  camera.set(eye, camera.target.offset(offset), camera.up)
end

# Place camera for view to contain points. Coordinates in model space.
#
# @param points [Array<Geom::Point3d>]
#
# @return [Void]
def zoom_points(points)
  transformation = camera_transformation.inverse
  points = points.map { |pt| pt.transform(transformation) }
  extremes = frustrum_extremes(points)
  place_camera(camera_coords(extremes))
end

# Place camera for view to contain selection.
#
# @return [Void]
def zoom_selection
  zoom_points(Sketchup.active_model.selection.flat_map { |e| points(e) })
end
