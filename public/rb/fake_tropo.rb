def answer
  puts "ANSWERING"
end

def say(message)
  puts "SAY: #{message}"
end

def ask(message, options)
  puts "ASKING: #{message} WITH OPTIONS #{options.inspect}"
end

def log(message)
  puts "LOG: #{message}"
end

def hangup
  puts "HANGING UP"
end
