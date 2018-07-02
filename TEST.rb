# Get My Number Game
# Written By: Dusan Munizaba

puts "Welcome to 'Get My Number!'"

# Get the player's name, and greet them.
print "What's your name? "
name = gets.chomp
puts "Welcome, #{name}"

# Store a random number for hte player to guess.
puts "I've got a random number between 1 100."
puts "Can you guess it?"
target = rand(100) +1

num_guesses = 0
puts "You've got #{10 - num_guesses} +  guesses left."