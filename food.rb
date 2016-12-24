require 'chipmunk'
require 'gosu'


class Food
  attr_accessor :head, :shape
  def initialize(window, spawnpoint)
    @health = rand(30..100)
    @health += 0.1
    @head = CP::Body.new(@health / 4, 10)
    @head.p = spawnpoint
    @head.w = rand(-3..3)
    window.space.add_body(@head)
    makeshape(window)
    @color = Gosu::Color.new(0xff00ff00)
    @color.hue += rand(-70..40)
    @color.value = rand(50..80) / 100.0
  end

  def corners
    corners = [
      CP::Vec2.new(-@health / 10, @health / 10),
      CP::Vec2.new(@health / 10, @health / 10),
      CP::Vec2.new(@health / 10, -@health / 10),
      CP::Vec2.new(-@health / 10, -@health / 10)
    ]
    corners.each { |c| c + CP::Vec2.new(20, 20) }
  end

  def makeshape(window)
    @shape = CP::Shape::Poly.new(@head, corners, CP::Vec2.new(0, 0))
    @shape.collision_type = :food
    @shape.object = self
    window.space.add_shape(@shape)
  end

  def eaten(amount)
    @health -= amount
  end

  def update(window, tick = false)
    if @health <= 0
      window.foods.delete(self)
      window.deads << self
    end
  end

  def rotate
    diag = Math.sqrt(2) * (@health / 10)
    [-45, +45, -135, +135].collect do |angle|
      xrot = @head.p.x + Gosu::offset_x(@head.a.radians_to_gosu + angle, diag)
      yrot = @head.p.y + Gosu::offset_y(@head.a.radians_to_gosu + angle, diag)
      CP::Vec2.new(xrot, yrot)
    end
  end

  def draw(window)
    window.space.remove_shape(@shape)
    makeshape(window)
    top_left, top_right, bottom_left, bottom_right = rotate

    window.draw_quad(
      top_left.x, top_left.y, @color,
      top_right.x, top_right.y, @color,
      bottom_left.x, bottom_left.y, @color,
      bottom_right.x, bottom_right.y, @color, 1)
  end

end
