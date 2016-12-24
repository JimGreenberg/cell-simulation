require 'chipmunk'
require 'gosu'

class Walls

  def initialize(space)
      @body = CP::Body.new(Float::INFINITY, Float::INFINITY)
      sides = [
        [CP::Vec2.new(0, 0), CP::Vec2.new(0, HEIGHT)],
        [CP::Vec2.new(0, 0), CP::Vec2.new(WIDTH , 0)],
        [CP::Vec2.new(WIDTH , 0), CP::Vec2.new(WIDTH, HEIGHT)],
        [CP::Vec2.new(WIDTH, HEIGHT), CP::Vec2.new(0, HEIGHT)]
      ]
      sides.each { |side| space.add_static_shape(wall(*side)) }
  end

  def wall(a, b)
    line = CP::Shape::Segment.new(@body, a, b, 1)
    line.e = 1
    line
  end
end
