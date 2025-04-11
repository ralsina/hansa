require "./hansa.cr"

ARGV.each do |arg|
  if (File.file? arg)
    result = Hansa.classify(File.read(arg))
    puts "#{arg} #{result}"
  else
    puts "File not found: #{arg}"
  end
end
