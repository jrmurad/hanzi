# For each word, we ensure that its constituent characters are learned first,
# when those are themselves HSK words. For each character, we shall do likewise
# with components.

require 'json'
require 'set'

NUMBERS = Set.new(File.readlines('numbers.txt', chomp: true))
RADICALS = Set.new(File.readlines('radicals.txt', chomp: true))

# map character decompositions
DECOMP = {}

File.open('chise-ids.txt').each do |line|
  _, char, decomp = line.chomp.split(/\s+/)

  if not decomp.nil? and decomp.length > 1
    DECOMP[char] = decomp.split('')
  end
end

# map of word frequencies for ordering new words when learning a character
FREQ = {}

File.readlines('subtlex-ch-wf.csv', chomp: true).each_with_index do |line, i|
  word = line.split(',')[0]
  FREQ[word] ||= i.next # ||= in case word is a dupe... leave earlier index
end

@words = []

class WordData
  attr_reader :data

  def initialize(simplified, pinyin, definition, group, level)
    clean = simplified.gsub(/（[^）]+）$/, '') # 过（动）

    @data = {
      clean: clean,
      decomp: if clean.length === 1 then DECOMP[clean] else clean.split('') end,
      definition: definition,
      freq: FREQ[clean],
      group: group,
      hash: "#{clean}#{pinyin}".hash,
      levels: Set.new([level]),
      pinyin: pinyin,
      simplified: simplified,
    }
  end

  def eql?(other)
    other.is_a?(WordData) and hash == other.hash
  end

  def hash
    @data[:hash]
  end

  def to_s
    @data.to_s
  end
end

def add_hsk(group, level)
  File.readlines("hsk#{level}.txt", chomp: true).map do |line|
    simplified, pinyin, definition = line.split("\t")
    WordData.new(simplified, pinyin.downcase.gsub(/\s/, ''), definition, group, level) # TODO remove apostrophes?
  end
end

@words.push(*add_hsk(1, "2_1"))
@words.push(*add_hsk(2, "2_2"))
@words.push(*add_hsk(3, "2_3"))

@words.push(*add_hsk(4, "3_1"))
@words.push(*add_hsk(5, "3_2"))
@words.push(*add_hsk(6, "3_3"))
@words.push(*add_hsk(7, "3_4"))

@words.push(*add_hsk(8, "2_4"))
@words.push(*add_hsk(9, "2_5"))
@words.push(*add_hsk(10, "2_6"))

@words.push(*add_hsk(11, "3_5"))
@words.push(*add_hsk(12, "3_6"))

# transform into a group/frequency sorted array
@words = @words
  .sort_by do |word|
    [word.data[:group], word.data[:freq] || @words.length, word.data[:pinyin]]
  end

def add_character(word)
  char = word.data[:clean]

  throw "not a character: #{word.data[:simplified]}" unless char.length == 1

  if !RADICALS.include?(char) and DECOMP[char]
    add_components(DECOMP[char])
  end

  add_to_ordered(word)
end

def add_components(chars)
  return unless chars

  chars.each do |char|
    hsk = @words.find { |word| word.data[:clean] == char }
    add_character(hsk) if hsk
  end
end

@learned = Set.new

def add_to_ordered(word)
  if @learned.include?(word)
    existing = @ordered.find { |o| o.eql?(word) }
    existing.data[:levels].merge(word.data[:levels])
    return
  end

  @learned.add(word)
  @ordered << word
end

@ordered = []

while @words.length > 0
  word = @words.shift

  clean = word.data[:clean]
  base = clean.gsub(/[儿子了]$/, '')

  # pull forward any other words from the same group that contain this character as a component
  if base.length == 1
    same_group_words = @words.select do |queue_word| 
      queue_word.data[:group] == word.data[:group] && 
      queue_word.data[:decomp]&.include?(base)
    end

    if same_group_words.any?
      # remove same group words from their current positions
      same_group_words.each { |w| @words.delete(w) }
      # add them back at the beginning of the queue
      @words.unshift(*same_group_words)
    end
  end

  # handle like 图书馆 coming before 图书, 火车站 coming before 火车, ...
  if clean.length == 3
    if hsk = @words.find { |queue_word| queue_word.data[:clean] == clean[0..-2] }
      add_components(hsk.data[:decomp])
      add_to_ordered(hsk)
    end
  end

  add_components(word.data[:decomp])
  add_to_ordered(word)
end

# print results
@ordered.each do |word|
  level = word.data[:level]

  tags = [
    *word.data[:levels].to_a.map { |level| "hsk#{level}" }.sort,
    NUMBERS.include?(word.data[:clean]) ? "number" : nil,
    RADICALS.include?(word.data[:clean]) ? "radical" : nil,
  ].compact

  puts [
    word.data[:simplified],
    word.data[:pinyin],
    word.data[:definition],
    tags.join(" "),
  ].join("\t")
end
