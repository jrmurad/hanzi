# First, student will learn the primary digit and number characters.
# Then, student will learn the 100 most common radicals and their variants.
# From this point, student will learn the HSK vocabulary plus several "missing",
# high frequency words (as determined by Hacking Chinese from SUBTLEX).
# 
# For each word, we shall ensure that its constituent characters are learned first.
# For each character, we shall ensure that its components are learned first.
# For each character, we shall also teach the student any words they can now create,
# without delaying until they reach those positions by frequency.

require 'json'
require 'set'

# map of word frequencies for ordering new words when learning a character
@freq = {}

File.readlines('subtlex-ch-wf.csv', chomp: true).each_with_index do |line, i|
  word = line.split(',')[0]
  @freq[word] ||= i # ||= in case word is a dupe... leave earlier index
end

# map of character frequencies for ordering new characters when learning a character
# (because non-radicals are composed of other characters)
@char_freq = {}

File.readlines('char_freq.txt', chomp: true).each_with_index do |word, i|
  @char_freq[word] ||= i # ||= in case word is a dupe... leave earlier index
end

@delayed = (3..5).inject({ 3 => Set.new, 4 => Set.new, 5 => Set.new }) do |acc, level|
  File.readlines("delayed#{level}.txt", chomp: true).each { |word| acc[level].add(word) }
  acc
end

# HSK word list
@words = (1..5).inject([]) do |acc, level|
  acc.push(*File.readlines("hsk#{level}.txt", chomp: true).map { |word| [word, level] })
end

File.readlines('hacking-chinese_missing-hsk-words.csv', chomp: true).each do |line|
  three, four, five, six = line.split(',')
  @words << [three, 3] unless three.empty?
  @words << [four, 4] unless four.empty?
  @words << [five, 5] unless five.empty?
  #@words << [six, 6] unless six.empty?
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
@learned = Set.new(File.readlines('numbers.txt', chomp: true) + File.readlines('radicals.txt', chomp: true))

# the entire Set of characters which will be learned
@learning_chars = Set.new(@learned)

@words.each do |word|
  word.split('').each do |char|
    @learning_chars.add(char)
  end
end

DECOMP_IGNORE = Set.new(%w(⿰	⿱	⿲	⿳	⿴	⿵	⿶	⿷	⿸	⿹	⿺	⿻))
@decomp = {}

# map each character in the dictionary to its decomposition
File.open('dict.txt').each do |line|
  entry = JSON.parse(line)
  next unless @learning_chars.include?(entry['character'])
  @decomp[entry['character']] = entry['decomposition'].split('').reject { |char| DECOMP_IGNORE.include?(char) }
end

# override with better source
#File.open('cjk.txt').each do |line|
#  arr = line.chomp.split(/\s+/)
#
#  unless @decomp[arr[1]] and arr[2].length == 1
#    decomp = arr[2].split('').reject { |char| DECOMP_IGNORE.include?(char) }
#    next if decomp.any? { |char| char =~ /[A-Za-z]/ }
#    @decomp[arr[1]] = decomp
#  end
#end

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

# add character along with any new words or chacters which can be created with it
def add_character(char)
  return if @learned.include?(char)

  @ordered << char
  @learned.add(char)

  find_new_words()

  new_via_decomp = []

  @decomp.each do |c, decomposition|
    if !@learned.include?(c) and decomposition.include?(char) and decomposition.all? { |decomp_char| @learned.include?(decomp_char) }
      new_via_decomp << c
    end
  end

  new_via_decomp.sort_by { |c| @char_freq[c] || @char_freq.size }.each { |c| add_character(c) }
end

# initial find based on primary list (numbers, radicals)
find_new_words()

while @words.length > 0
  word = @words.shift

  next if @learned.include?(word)

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
  puts word
end
