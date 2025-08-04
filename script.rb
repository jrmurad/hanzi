# First, student will learn the primary digit and number characters.
# Then, student will learn the radicals and their variants.
# 
# For each word, we shall ensure that its constituent characters are learned first.
# For each character, we shall ensure that its components are learned first.

# HSK order:
# 2.0 1-3
# 3.0 1-4
# 2.0 4-6
# 3.0 5-9

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

@words = []
@hsk2_level = {}
@hsk3_level = {}
@last_group = -1

def clean_word(word)
  # take only the first characters up to whitespace, （, |, or the end of the word
  word.split(/[\s（|]/)[0]
end

def add_hsk2(level)
  @last_group += 1
  words = File.readlines("hsk#{level}.txt", chomp: true).map { |word| clean_word(word) }
  words.each { |word| @hsk2_level[word] ||= level }
  words.map { |word| [word, @last_group] }
end

def add_hsk3(level)
  @last_group += 1

  words = []
  
  File.readlines('hsk30.csv', chomp: true).each do |line|
    id, word, traditional, pinyin, pos, word_level = line.split(',')

    next unless word_level.to_i == level

    word = clean_word(word)

    @hsk3_level[word] ||= level

    words << word
  end

  words.map { |word| [word, @last_group] }
end

@words.push(*add_hsk2(1))
@words.push(*add_hsk2(2))
@words.push(*add_hsk2(3))

@words.push(*add_hsk3(1))
@words.push(*add_hsk3(2))
@words.push(*add_hsk3(3))
@words.push(*add_hsk3(4))

@words.push(*add_hsk2(4))
@words.push(*add_hsk2(5))
@words.push(*add_hsk2(6))

@words.push(*add_hsk3(5))
@words.push(*add_hsk3(6))

# transform into a group/frequency sorted array
@words = @words
  .sort_by do |arr|
    word, group = arr

    [group, @freq[word] || @words.length]
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

def add_character(char)
  return if @learned.include?(char)

  return unless @decomp[char] or @radicals.include?(char)

  (@decomp[char] || []).each do |decomp_char|
    unless @learned.include?(decomp_char)
      add_character(decomp_char)
    end
  end

  @learned.add(char)

  @ordered << char
end

while @words.length > 0
  word = @words.shift

  next if @learned.include?(word)
  next if @learned.include?(word + "儿")
  next if word.end_with?("儿") and @learned.include?(word[0..-2])

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
    @hsk2_level[word] ? "hsk2_"+@hsk2_level[word].to_s : nil,
    @hsk3_level[word] ? "hsk3_"+@hsk3_level[word].to_s : nil,
    @numbers.include?(word) ? "number" : nil,
    @radicals.include?(word) ? "radical" : nil,
  ].compact

  if word.length == 1
    char = word

    component_of = @ordered.inject(0) do |acc, word|
      if word != char and @decomp[word] and @decomp[word].include?(char)
        acc + 1
      else
        acc
      end
    end

    tags << "component_of_#{component_of}"
  end

  if @hsk2_level[word].nil? and @hsk3_level[word].nil? and word.length == 1 and (tags.include?("component_of_0") or tags.include?("component_of_1"))
    next
  end

  tags.delete("component_of_0")

  puts "#{word},#{tags.join(" ")}"
end
