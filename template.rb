require 'chipmunk'
require 'gosu'


class Template
	attr_accessor :genes
	def initialize
		@genes = {
			:type => ['herbivore', 'herbivore', 'carnivore'].sample, #for now, cells will not be able to mate outside of their type
			:size => rand(10..20), #number of segments
			:speed => rand(20..90) / 10.0,
			:scale => rand(25..50) / 10.0, #how big the cells segments are
			:health => rand(40..90),
			:damage => 1,
			:lifespan => rand(90..180), #units = seconds
			:clutchsize => rand(1..4),
			:branches => rand(3..6), #number of branches or "tails/tentacles"
			:hueshift => rand(90)
		}
	end
end
