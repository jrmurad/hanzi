# First, student will learn the primary digit and number characters.
# Then, student will learn the radicals and their variants.
# From this point, student will learn the HSK vocabulary plus several "missing",
# high frequency words (as determined by Hacking Chinese from SUBTLEX).
# 
# For each word, we shall ensure that its constituent characters are learned first.
# For each character, we shall ensure that its components are learned first.
# For each character, we shall also teach the student any words they can now create,
# without delaying until they reach those positions by frequency.

require 'json'
require 'set'

@numbers = Set.new(File.readlines('numbers.txt', chomp: true))
@radicals = Set.new(File.readlines('radicals.txt', chomp: true))

# map of word frequencies for ordering new words when learning a character
@freq = {}

File.readlines('subtlex-ch-wf.csv', chomp: true).each_with_index do |line, i|
  word = line.split(',')[0]
  @freq[word] ||= i # ||= in case word is a dupe... leave earlier index
end

@delayed = (3..5).inject({ 3 => Set.new, 4 => Set.new, 5 => Set.new }) do |acc, level|
  File.readlines("delayed#{level}.txt", chomp: true).each { |word| acc[level].add(word) }
  acc
end

# HSK word list
@hsk_level = {}

@words = (1..6).inject([]) do |acc, level|
  words = File.readlines("hsk#{level}.txt", chomp: true).map { |word| [word, level] }
  words.each { |word| @hsk_level[word[0]] = level }
  acc.push(*words)
end

# HSK 3.0
@hsk30_level = {}

File.readlines('hsk30.csv', chomp: true).each do |line|
  id, simplified, traditional, pinyin, pos, level = line.split(',')

  level = "7" if level == "7-9"

  @hsk30_level[simplified] = level.to_i
  @words << [simplified, level.to_i] unless @hsk_level[simplified]
end

File.readlines('hacking-chinese_missing-hsk-words.csv', chomp: true).each do |line|
  three, four, five, six = line.split(',')
  @words << [three, 3] unless three.empty? or @hsk30_level[three]
  @words << [four, 4] unless four.empty? or @hsk30_level[four]
  @words << [five, 5] unless five.empty? or @hsk30_level[five]
  @words << [six, 6] unless six.empty? or @hsk30_level[six]
end

# transform into a level/frequency sorted array
@words = @words
  .sort_by do |arr|
    word, level = arr

    if @delayed[3].include?(word)
      level = 3
    elsif @delayed[4].include?(word)
      level = 4
    elsif @delayed[5].include?(word)
      level = 5
    end

    [level, @freq[word] || @words.length]
  end
  .map { |word| word[0] }

# track which words have been learned thus far, while iterating through
@learned = Set.new([*@radicals, *@numbers])

# the entire Set of characters which will be learned
@learning_chars = Set.new(@learned)

@words.each do |word|
  word.split('').each do |char|
    @learning_chars.add(char)
  end
end

@decomp = {}

# map character decompositions
File.open('chise-ids.txt').each do |line|
 _, char, decomp = line.chomp.split(/\s+/)

 if not decomp.nil? and decomp.length > 1
   @decomp[char] = decomp.split('')
 end
end

@ordered = []

# add from words list to ordered lists when word can be created from known characters
def find_new_words
  @words.each do |word|
    if !@learned.include?(word) and word.length > 1 and word.split('').all? { |char| @learned.include?(char) }
      @ordered << word
      @learned.add(word)
    end
  end
end

# add character along with any hsk words which can be created with it
def add_character(char)
  return if @learned.include?(char)

  return unless @decomp[char] or @radicals.include?(char)

  (@decomp[char] || []).each do |decomp_char|
    if !@learned.include?(decomp_char)
      add_character(decomp_char)
    end
  end

  @learned.add(char)

  @ordered << char

  find_new_words()
end

# initial find based on primary list (numbers, radicals)
find_new_words()

while @words.length > 0
  word = @words.shift

  next if @learned.include?(word)
  next if @learned.include?(word + "儿")

  if word.length == 1
    add_character(word)
  else
    word.split('').each { |char| add_character(char) }

    @ordered << word
    @learned.add(word)
  end
end

# print results
@ordered.each do |word|
  tags = [
    @hsk_level[word] ? "hsk2_"+@hsk_level[word].to_s : nil,
    @hsk30_level[word] ? "hsk3_"+@hsk30_level[word].to_s : nil,
    @numbers.include?(word) ? "number" : nil,
    @radicals.include?(word) ? "radical" : nil,
  ].compact

  puts "#{word},#{tags.join(" ")}"
end
