require 'chipmunk'
require 'gosu'

require_relative 'template.rb'
require 'byebug'




class Cell
	attr_accessor :genes, :head, :action, :joints, :shapes, :bodies, :headshape, :health, :mated, :dead
	def initialize(window, spawnpoint, parent1 = Template.new, parent2 = Template.new)
		@genes = {
			:type => parent1.genes[:type], #for now, cells will not be able to mate outside of their type
			:size => mean([parent1.genes[:size], parent2.genes[:size]]), #number of segments
			:speed => mean([parent1.genes[:speed], parent2.genes[:speed]]),
			:scale => mean([parent1.genes[:scale], parent2.genes[:scale]]), #how big the cells segments are
			:health => mean([parent1.genes[:health], parent2.genes[:health]]),
			:damage => mean([parent1.genes[:damage], parent2.genes[:damage]]),
			:lifespan => mean([parent1.genes[:lifespan], parent2.genes[:lifespan]]),
			:clutchsize => mean([parent1.genes[:clutchsize], parent2.genes[:clutchsize]]),
			:branches => mean([parent1.genes[:branches], parent2.genes[:branches]]),
			:hueshift => mean([parent1.genes[:hueshift], parent2.genes[:hueshift]]) #number of branches or "tails/tentacles"
		}

		#initialize the instance variables for the cell from its genes
		@health = @genes[:health] #when the cell runs out of health, it dies
		@hunger = 50 #lower is more hungry, 0 is death
		@dead = false
		@birthday = Time.now.to_i #keep track of how old the cell is in seconds
		@action = ''
		@timeofdeath = 2000000000
		@mated = false
		@mature = false
		@sleep = 0
		self.colorpicker
		@genes[:speed] += 1.5 if @genes[:type] == "carnivore"

    #body creation
		@health = @genes[:health]
		@head = CP::Body.new(5, 100)
		@head.p = spawnpoint
		@head.w = rand(-50..50)
		@head.v = CP::Vec2.new(rand(-200..200), rand(-200..200)) #starting velocity must be nonzero due to bug in physics?
		@headshape = CP::Shape::Circle.new(@head, 1, CP::Vec2.new(0,0))
		@headshape.u = 0 #friction
		@headshape.e = 0 #elasticity
		@headshape.collision_type = @genes[:type].to_sym
		@sensor = CP::Shape::Circle.new(@head, 25, CP::Vec2.new(0,0))
		@sensor.sensor = true
		@sensor.collision_type = :sensor
		@bodies = Array.new << @head
		@shapes = Array.new + [@headshape, @sensor]
		@joints = Array.new
		@tails = Array.new
		@tris = Hash.new #drawn triangle vertices (2/3)
		@skeleton = skeleton(@genes[:size], @genes[:branches])
		@skeleton.each { |bone| tail(@head, bone) }
		@tails.each { |t| @tris[t] = [@bodies.sample, @bodies.sample]}
		#add all the bits of the cell to the space
		@bodies.each { |b| window.space.add_body(b) }
		@shapes.each do |s|
			window.space.add_shape(s)
			s.object = self
		end

		@joints.each { |j| window.space.add_constraint(j) }
	end

	def colorpicker
		if @genes[:type] == 'herbivore'
			@color = Gosu::Color.new(0xff0000ff)
			@color.hue += @genes[:hueshift] - 70
		elsif @genes[:type] == 'carnivore'
			@color = Gosu::Color.new(0xffff0000)
			@color.hue += @genes[:hueshift] - 20
		end
		@color.value = rand(50..80) / 100.0
		@color2 = Gosu::Color.new(0xff00ff00)
		@color2.hue = @color.hue
		@color2.value = @color.value + 0.2
	end

	#recursively build a tail of length n onto the head
	def tail(head, n)
		if n == 0
			@joints << CP::Constraint::DampedSpring.new(
				head, @head,
				CP::Vec2.new(0, 0),
				CP::Vec2.new(0, 0),
				100, 1, 0)
				@tails << head
		else
			stub = CP::Body.new(1, 100)
			stub.p = head.p
			@joints << CP::Constraint::DampedSpring.new(
				head, stub,
				CP::Vec2.new(0, 0),
				CP::Vec2.new(0, 0),
				2, 100, 20)
			@shapes << CP::Shape::Circle.new(
				stub, @genes[:scale],
				CP::Vec2.new(0, 0))
			@shapes.last.e = 1.2
			@shapes.last.collision_type = :tail
			@shapes.last.e = 1 if head == @head
			@bodies << stub
			tail(stub, n - 1)
		end
	end


	def skeleton(size, branches)
		#build the skeleton "plan" by initializing the branches, and then randomly adding
		#onto them until size has been depleteed
		#e.g. [5] would look like a snake whereas [1,1,1,1,1] would look like a starfish
		arr = Array.new
		branches.times {arr << 1}
		while size > branches
			arr[rand(arr.length)] += 1
			size -= 1
		end
		arr << 1 until arr.length >= 4
		arr.shuffle
	end

	def update(window, tick = false)
		#this method calls on all of the behavior submethods and makes a decision which action to pursue
		#compares hunger, sex drive, as well as proximity to other objects
		#decision heirarchy:
			#skip if already dead
			#if too old OR health depleted OR hunger depleted: die
			#if predator closeby: flee
			#findfood -> eat
			#if old enough AND not hungry: findmate -> mate

		if @sleep > 0
			@bodies.each{ |body| body.reset_forces }
			@sleep -= 1 if tick
			return
		end

		window.cells.delete(self) if @dead && @sleep <= 0
		window.deads << self if @dead


		die(window) if dead?
		@hunger -= 3 if tick
		window.birthrequest(self) if @action == "mate" && !@mated

		if !safe?(window)
			flee(nearest(@head, predlist(window)))
		elsif readymate?(window)
			@mature = true
			@action = "findmate"
			hunt(nearest(@head, matelist(window)))
		else
			@action = "hunt"
			hunt(nearest(@head, foodlist(window)))
		end

	end

	def interact(target, window)
		return if target == self
		if @genes[:type] == "herbivore"
			if target.class == Food
				eat(target) if readyeat?(window)
			elsif target.class == Cell
				if target.genes[:type] == @genes[:type]
					mate(target, window) if @action == "findmate"
				else
					flee(target)
				end
			end
		elsif @genes[:type] == "carnivore"
			if target.class == Cell
				if target.genes[:type] == @genes[:type]
					mate(target, window) if @action == "findmate"
				else
					eat(target) if readyeat?(window)
				end
			end
		end
	end


	def move(target)
		#applies an impulse to the head in the direction of the target
		return if target.nil?
		vector = target.head.p - @head.p
		vector /= vector.length
		@head.apply_impulse(vector * @genes[:speed], CP::Vec2.new(0, 0))
	end

	def hunt(target)
		move(target)
	end

	def foodlist(window)
		if @genes[:type] == 'herbivore'
			window.foods
		else
			preylist(window)
		end
	end

	def readyeat?(window)
		@hunger <= 100 &&
		(@action == "eat" || @action == "hunt")
	end

	def eat(target)
		@action = "eat"
		@head.reset_forces
		target.head.reset_forces
		target.eaten(@genes[:damage])
		@hunger += @genes[:damage]
		@hunger += @genes[:damage] if @genes[:type] == "carnivore"
	end

	def eaten(amount)
		@health -= amount
	end

	def safe?(window)
		return true if @genes[:type] == "carnivore"
		return true if predlist(window).empty?
		!@head.p.near?(nearest(@head, predlist(window)).head.p, 60)
	end

	def readymate?(window)
		safe?(window) &&
		@hunger >= 75 &&
		@mated == false &&
		!matelist(window).empty?
	end

	def mate(target, window)
		return if @mated || target.mated || target.dead
		@action = "mate"
		@sleep = 5
	end

	def matelist(window)
		window.cells.reject { |cell| cell.genes[:type] != @genes[:type] }.to_a
	end

	def predlist(window)
		window.cells.reject { |cell| cell.genes[:type] != "carnivore" }.to_a
	end

	def preylist(window)
		window.cells.reject { |cell| cell.genes[:type] != "herbivore" }.to_a
	end

	def flee(target)
		#same as move, but moves AWAY from the target
		vector = @head.p - target.head.p
		vector /= vector.length
		@head.apply_impulse(vector * @genes[:speed], CP::Vec2.new(0, 0))
	end

	def age
		Time.now.to_i - @birthday
	end

	def die(window)
		@joints.each { |j| window.space.remove_constraint(j) }
		@bodies.each do |body| #exploding corpses, for fun
			body.apply_impulse(
			CP::Vec2.new(rand(-100..100), rand(-100..100)),
			CP::Vec2.new(0, 0))
		end
		@timeofdeath = Time.now.to_i + 7
		@sleep = 7
		@dead = true
	end

	def dead?
	#	age >= @genes[:lifespan] ||
		@health <= 0 ||
		@hunger <= 0
	end

	def nearest(start, points)
		#nearest neighbor search from 'start' point to array of 'points'
		#'start' and every element of 'points' being chipmunk objects
		#returns the object pointer of the closest point
		points.delete(self)
		return if points.empty?
		arr = []
		points.each { |point| arr << start.p.distsq(point.head.p).to_i }
		points[arr.index(arr.min)]
	end

	def mean(a)
		a.inject { |b, c| b + c } / a.length
	end

	def draw(window)
		@color2.value -= 0.0001 if @dead

		window.draw_quad(
			@bodies[0].p.x - @genes[:scale], @bodies[0].p.y - @genes[:scale], @color2,
      @bodies[0].p.x + @genes[:scale], @bodies[0].p.y - @genes[:scale], @color2,
      @bodies[0].p.x - @genes[:scale], @bodies[0].p.y + @genes[:scale], @color2,
      @bodies[0].p.x + @genes[:scale], @bodies[0].p.y + @genes[:scale], @color2, 3)

		unless @dead
			@tails.each do |t|
				10.times do
					b = @bodies.sample
					next if @tails.include?(b)
					window.draw_triangle(
						t.p.x, t.p.y, @color,
						b.p.x, b.p.y, @color,
						@head.p.x, @head.p.y, @color, 1)
				end
			end
		end

		@genes[:scale] *= 0.5
		@bodies[1..-1].each do |b|
			window.draw_quad(
				b.p.x - @genes[:scale], b.p.y - @genes[:scale], @color2,
      	b.p.x + @genes[:scale], b.p.y - @genes[:scale], @color2,
        b.p.x - @genes[:scale], b.p.y + @genes[:scale], @color2,
        b.p.x + @genes[:scale], b.p.y + @genes[:scale], @color2, 3)
		end
		@genes[:scale] *= 2

	end

end
