# Position camera for view to contain points, selection or custom entities.
module Zoom
  # REVIEW: Either make a few methods private, or change description of class
  # to include all view related things.

  # Get the transformation defining the placement of the active camera. Used for
  # converting between model space and camera space.
  #
  # @return [Geom::Transformation]
  def self.camera_transformation
    camera = Sketchup.active_model.active_view.camera

    Geom::Transformation.axes(camera.eye, camera.xaxis, camera.yaxis, camera.zaxis)
  end

  # Get horizontal field of view angle for active view. Angle in radians.
  #
  # @return [Float]
  def self.horizontal_fov
    view = Sketchup.active_model.active_view
    return 0 unless view.camera.perspective?
    return view.camera.fov.degrees unless view.camera.fov_is_height?

    Math.atan(Math.tan(vertical_fov / 2) * view.vpwidth.to_f / view.vpheight) * 2
  end

  # Get vertical field of view angle for active view. Angle in radians.
  #
  # @return [Float]
  def self.vertical_fov
    view = Sketchup.active_model.active_view
    return 0 unless view.camera.perspective?
    return view.camera.fov.degrees if view.camera.fov_is_height?

    Math.atan(Math.tan(horizontal_fov / 2) * view.vpheight.to_f / view.vpwidth) * 2
  end

  # Place camera for view to contain active drawing context.
  #
  # @param horizontal_fov [Float]
  # @param vertical_fov [Float]
  #
  # @return [Void]
  def self.zoom_active(horizontal_fov = self.horizontal_fov, vertical_fov = self.vertical_fov)
    zoom_entities(Sketchup.active_model.active_entities, horizontal_fov, vertical_fov)
  end

  # Place camera for view to contain entities (assumed to be in active drawing
  # context).
  #
  # @param entities [Array<Sketchup::DrawingElement>, Sketchup::Entities, Sketchup::Selection]
  # @param horizontal_fov [Float]
  # @param vertical_fov [Float]
  #
  # @return [Void]
  def self.zoom_entities(entities, horizontal_fov = self.horizontal_fov, vertical_fov = self.vertical_fov)
    points = entities.flat_map { |e| points(e) }
    zoom_points(points, horizontal_fov, vertical_fov)
  end

  # Place camera for view to contain points. Coordinates in model space.
  #
  # @param points [Array<Geom::Point3d>]
  # @param horizontal_fov [Float]
  # @param vertical_fov [Float]
  #
  # @return [Void]
  def self.zoom_points(points, horizontal_fov = self.horizontal_fov, vertical_fov = self.vertical_fov)
    transformation = camera_transformation.inverse
    points = points.map { |pt| pt.transform(transformation) }

    if Sketchup.active_model.active_view.camera.perspective?
      zoom_perspective(points, horizontal_fov, vertical_fov)
    else
      zoom_parallel(points)
    end

    nil
  end

  # Place camera for view to contain selection.
  #
  # @param horizontal_fov [Float]
  # @param vertical_fov [Float]
  #
  # @return [Void]
  def self.zoom_selection(horizontal_fov = self.horizontal_fov, vertical_fov = self.vertical_fov)
    zoom_entities(Sketchup.active_model.selection, horizontal_fov, vertical_fov)
  end

  #-------------------------------------------------------------------------------

  # Recursively find all points in entity.
  #
  # @param entity [Sketchup::DrawingElement]
  # @param transformation [Geom::Transformation]
  #
  # @return [Array<Geom::Point3d>]
  def self.points(entity, transformation = IDENTITY)
    case entity
    when Sketchup::ComponentInstance, Sketchup::Group
      entity.definition.entities.flat_map { |e| points(e, transformation * entity.transformation) }
    when Sketchup::Edge, Sketchup::Face
      entity.vertices.map { |v| v.position.transform(transformation) }
    else
      []
    end.uniq
  end
  private_class_method :points

  def self.zoom_perspective(points, horizontal_fov, vertical_fov)
    place_camera(perspective_camera_coords(points, horizontal_fov, vertical_fov))
  end

  def self.zoom_parallel(points)
    bb = Geom::BoundingBox.new.add(points)
    eye = bb.center
    # Move camera back a little extra to avoid clipping.
    eye.z = bb.min.z - bb.height / 10

    view = Sketchup.active_model.active_view
    place_camera(eye, view.camera)
    view.camera.height = [bb.height, bb.width / view.vpwidth.to_f * view.vpheight].max
  end

  # Place camera at position. Coordinates in camera space.
  #
  # @param position [Geom::Point3d]
  # @param camera [Sketchup::Camera]
  #
  # @return [Void]
  def self.place_camera(position, camera = Sketchup.active_model.active_view.camera)
    eye = position.transform(camera_transformation)
    offset = eye - camera.eye
    camera.set(eye, camera.target.offset(offset), camera.up)
  end
  private_class_method :place_camera

  # Find left, right, top and bottom extreme points. All coordinates in camera
  # space.
  #
  # @param points [Array<Geom::Point3d>]
  # @param horizontal_fov [Float]
  # @param vertical_fov [Float]
  #
  # @return [Array<(Geom::Point3d, Geom::Point3d, Geom::Point3d, Geom::Point3d)>]
  def self.frustrum_extremes(points, horizontal_fov, vertical_fov)
    [
      points.max_by { |pt| pt.x - pt.z * Math.tan(horizontal_fov / 2) },
      points.min_by { |pt| pt.x + pt.z * Math.tan(horizontal_fov / 2) },
      points.max_by { |pt| pt.y - pt.z * Math.tan(vertical_fov / 2) },
      points.min_by { |pt| pt.y + pt.z * Math.tan(vertical_fov / 2) }
    ]
  end
  private_class_method :frustrum_extremes

  # Find 3D coordinates for perspective camera. All coordinates in camera space.
  #
  # @param points [Array<Geom::Point3d>]
  # @param horizontal_fov [Float]
  # @param vertical_fov [Float]
  #
  # @return [Geom::Point3d]
  def self.perspective_camera_coords(points, horizontal_fov, vertical_fov)
    extremes = frustrum_extremes(points, horizontal_fov, vertical_fov)

    c0 = camera_2d_coords(extremes[0..1], horizontal_fov, 0)
    c1 = camera_2d_coords(extremes[2..3], vertical_fov, 1)

    Geom::Point3d.new(c0[0], c1[0], [c0[1], c1[1]].min)
  end
  private_class_method :perspective_camera_coords

  def parallel_camera_coords(points)
    bb = Geom::BoundingBox.new.add(points)
    eye = bb.center
    # Move camera back a little extra to void clipping.
    eye.z = bb.min.z - bb.height / 10

    eye
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
  def self.camera_2d_coords(extremes, fov, dimension_index)
    k = Math.tan(fov / 2)
    m0 = extremes[0].to_a[dimension_index] - k * extremes[0].z
    m1 = extremes[1].to_a[dimension_index] + k * extremes[1].z
    z = (m1 - m0) / (2 * k)

    [k * z + m0, z]
  end
  private_class_method :camera_2d_coords

end
