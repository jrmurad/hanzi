# Assume student has already the radicals, their variants, digits, and other numeric characters.
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

# map character decompositions
@decomp = {}

File.open('chise-ids.txt').each do |line|
  _, char, decomp = line.chomp.split(/\s+/)

  if not decomp.nil? and decomp.length > 1
    @decomp[char] = decomp.split('')
  end
end

# map of word frequencies for ordering new words when learning a character
@freq = {}

File.readlines('subtlex-ch-wf.csv', chomp: true).each_with_index do |line, i|
  word = line.split(',')[0]
  @freq[word] ||= i.next # ||= in case word is a dupe... leave earlier index
end

@words = []
@hsk2_level = {}
@hsk3_level = {}

def add_hsk(group, level)
  File.readlines("hsk#{level}.txt", chomp: true).map do |line|
    simplified, pinyin, definition = line.split("\t")

    if level =~ /^2_(\d)/
      @hsk2_level[simplified] ||= $1
    elsif level =~ /^3_(\d)/
      @hsk3_level[simplified] ||= $1
    end

    {
      chars: simplified.split(''),
      definition: definition,
      freq: @freq[simplified],
      group: group,
      hsk_level: level,
      pinyin: pinyin,
      simplified: simplified,
    }
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
    [word[:group], word[:freq] || @words.length]
  end

# track which words have been learned thus far, while iterating through
@learned_words = Set.new([*@radicals, *@numbers])

# the entire Set of characters which will be learned
@learning_chars = Set.new(@learned_words)

@words.each do |word|
  word[:chars].each do |char|
    @learning_chars.add(char)
  end
end

@ordered = []

def add_character(char)
  return if @learned_words.include?(char)

  return unless @decomp[char] or @radicals.include?(char)

  (@decomp[char] || []).each do |decomp_char|
    unless @learned_words.include?(decomp_char)
      add_character(decomp_char)
    end
  end

  @learned_words.add(char)

  hsk = @words.find { |word| word[:simplified] == char }

  @ordered << (hsk || {
    chars: [char],
    definition: "",
    freq: @freq[char],
    pinyin: "",
    simplified: char,
  })
end

@words_queue = @words.dup

while @words_queue.length > 0
  word_data = @words_queue.shift
  word = word_data[:simplified]

  next if @learned_words.include?(word)
  next if @learned_words.include?(word + "儿")
  next if word.end_with?("儿") and @learned_words.include?(word[0..-2])

  if word.length == 1
    add_character(word)
  else
    word.split('').each { |char| add_character(char) }

    @ordered << word_data
    @learned_words.add(word)
  end
end

def get_freq(word_data)
  if level = (@hsk3_level[word_data[:simplified]] || @hsk2_level[word_data[:simplified]])
    if level.to_i < 4
      return "Elementary"
    elsif level.to_i < 7
      return "Intermediate"
    end
  elsif freq = word_data[:freq]
    if freq < 2250
      return "Elementary"
    elsif freq < 5500
      return "Intermediate"
    end
  end

  "Advanced"
end

# print results
@ordered.each do |word_data|
  word = word_data[:simplified]

  tags = [
    @hsk2_level[word] ? "hsk2_"+@hsk2_level[word] : nil,
    @hsk3_level[word] ? "hsk3_"+@hsk3_level[word] : nil,
    @numbers.include?(word) ? "number" : nil,
    @radicals.include?(word) ? "radical" : nil,
  ].compact

  # if word is a character, determine how many other learning characters it is a component of
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

  # don't bother with non-HSK chars found via decomposition if not found in multiple HSK words
  if @hsk2_level[word].nil? and @hsk3_level[word].nil? and word.length == 1 and (tags.include?("component_of_0") or tags.include?("component_of_1"))
    next
  end

  tags.delete("component_of_0")

  puts [
    word_data[:simplified],
    word_data[:pinyin],
    word_data[:definition],
    tags.join(" "),
    get_freq(word_data)
  ].join("\t")
end
