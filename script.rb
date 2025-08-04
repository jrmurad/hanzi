# Assume student has already the radicals, their variants, digits, and other numeric characters.
# 
# For each word, we shall ensure that its constituent characters are learned first.
# For each character, we shall ensure that its components are learned first.

require 'json'
require 'set'

@numbers = Set.new(File.readlines('numbers.txt', chomp: true))
@radicals = Set.new(File.readlines('radicals.txt', chomp: true))

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
HSK2_LEVEL = {}
HSK3_LEVEL = {}

class WordData
  attr_reader :data

  def initialize(simplified, pinyin, definition, group, level)
    clean = simplified.gsub(/（[^）]+）$/, '') # 过（动）
    clean = clean.gsub(/(.)\1\｜(\1)/, '\1') # 爸爸｜爸
    clean = clean.split('｜').first # 有时候｜有时

    @data = {
      clean: clean,
      decomp: if clean.length === 1 then DECOMP[clean] else clean.split('') end,
      definition: definition,
      freq: FREQ[clean],
      group: group,
      hash: "#{simplified}#{pinyin}#{definition}".hash,
      pinyin: pinyin,
      simplified: simplified,
    }

    if level =~ /^2_(\d)/
      HSK2_LEVEL[simplified] ||= $1
    elsif level =~ /^3_(\d)/
      HSK3_LEVEL[simplified] ||= $1
    end
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
    WordData.new(simplified, pinyin, definition, group, level)
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

@learned = Set.new

def add_character(word)
  char = word.data[:clean]

  throw "not a character: #{word.data[:simplified]}" unless char.length == 1

  return if @learned.include?(word)

  @learned.add(word)

  if !@radicals.include?(char) and DECOMP[char]
    add_components(DECOMP[char])
  end

  @ordered << word
end

def add_components(chars)
  return unless chars

  chars.each do |char|
    hsk = @words.find { |word| word.data[:clean] == char }
    add_character(hsk) if hsk
  end
end

@ordered = []
@words_queue = @words.dup

while @words_queue.length > 0
  word = @words_queue.shift
  @learned.add(word)

  add_components(word.data[:decomp])

  @ordered << word
end

def get_freq(word)
  if level = (HSK2_LEVEL[word.data[:simplified]] || HSK3_LEVEL[word.data[:simplified]])
    if level.to_i < 4
      return "Elementary"
    elsif level.to_i < 7
      return "Intermediate"
    end
  elsif freq = word.data[:freq]
    if freq < 2250
      return "Elementary"
    elsif freq < 5500
      return "Intermediate"
    end
  end

  "Advanced"
end

# print results
@ordered.each do |word|
  simplified = word.data[:simplified]
  clean = word.data[:clean]

  tags = [
    HSK2_LEVEL[simplified] ? "hsk2_"+HSK2_LEVEL[simplified] : nil,
    HSK3_LEVEL[simplified] ? "hsk3_"+HSK3_LEVEL[simplified] : nil,
    @numbers.include?(clean) ? "number" : nil,
    @radicals.include?(clean) ? "radical" : nil,
  ].compact

  line = [
    word.data[:simplified],
    word.data[:pinyin],
    word.data[:definition],
    tags.join(" "),
    get_freq(word)
  ].join("\t")

  puts line
end
