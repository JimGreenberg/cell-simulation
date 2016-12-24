require 'chipmunk'
require 'gosu'
require 'rubygems'

require_relative 'walls.rb'
require_relative 'cell.rb'
require_relative 'template.rb'
require_relative 'food.rb'

WIDTH = 1440
HEIGHT = 900

Images = {

}

Sounds = {

}

class GameWindow < Gosu::Window
	attr_accessor :space, :cells, :foods, :deads
	def initialize
		super WIDTH, HEIGHT
		self.caption = 'Cells in a Dish'
		#Physics variables
		@space = CP::Space.new
		@space.damping = 0.75
		@lastsec = Time.now.to_i
		@dt = 1.0/60.0

		#Game Variables
		@oxygen = 100
		@carbon = 100
		@cells = Array.new
		@foods = Array.new
		@deads = Array.new
		@parents = Array.new
		Walls.new(@space)
		10.times {
			@cells.push(Cell.new(self, CP::Vec2.new(rand(WIDTH), rand(HEIGHT))))
			@foods.push(Food.new(self, CP::Vec2.new(rand(WIDTH), rand(HEIGHT))))
		}

		@space.add_collision_handler(:sensor, :food) { |a, b| a.object.interact(b.object, self) }
		@space.add_collision_handler(:sensor, :herbivore) { |a, b| a.object.interact(b.object, self) }
		@space.add_collision_handler(:sensor, :carnivore) { |a, b| a.object.interact(b.object, self) }

	end

	def birthrequest(cell)
		cell.mated = true
		@parents << cell
	end

	def babyspawnpoint(point)
		while @cells.any? { |cell| point.near?(cell.head.p, 20) }
			point = @parents.sample.head.p + CP::Vec2.new(rand(-40..40), rand(-40..40))
		end
		return point
	end

	def button_down(key)
		if key == Gosu::KbSpace
			@cells = Array.new
			@foods = Array.new
			10.times {
				@cells.push(Cell.new(self, CP::Vec2.new(rand(WIDTH), rand(HEIGHT))))
				@foods.push(Food.new(self, CP::Vec2.new(rand(WIDTH), rand(HEIGHT))))
			}
		end
		if key == Gosu::KbM
			debugger
		end
		if key == Gosu::KbK
			@cells.sample.die(self)
		end
	end

	def update
		@space.step(@dt)

		unless @parents.empty?
			@parents.sample.genes[:clutchsize].times do
				@cells.push(Cell.new(self, babyspawnpoint(@parents.sample.head.p), @parents.first, @parents.last))
			end
			@parents = Array.new
		end

		if @lastsec != Time.now.to_i
			@cells.each { |cell| cell.update(self, true) }
			@foods.each { |food| food.update(self, true) }

			@foods.push(Food.new(self, CP::Vec2.new(rand(WIDTH), rand(HEIGHT)))) if rand(4) == 1
			@cells.push(Cell.new(self, CP::Vec2.new(rand(WIDTH), rand(HEIGHT)))) if rand(8) == 1
		else
			@cells.each { |cell| cell.update(self) }
			@foods.each { |food| food.update(self) }

		end
		@lastsec = Time.now.to_i

		@deads.each do |dead|
			@space.add_post_step_callback(dead) do |space, key|
				key.shapes.each { |s| space.remove_shape(s) } if dead.is_a?(Cell)
				key.bodies.each { |b| space.remove_body(b) }	if dead.is_a?(Cell)
				space.remove_shape(key.shape) if dead.is_a?(Food)
				space.remove_body(key.head) if dead.is_a?(Food)
			end
			@deads.delete(dead)
		end
	end

	def draw
		@cells.each { |cell| cell.draw(self) }
		@foods.each { |food| food.draw(self) }

	end

end

window = GameWindow.new
window.show
