require "json"
require "baked_file_system"
require "./interpreter_table"
require "./alias_table"
require "./shebang"
require "./modeline"

# Hansa is a port of go-enry's language classification algorithm
# It uses a naive bayes classifier to classify the language of a
# given text based on the corpus from Linguist
#
# The most surprising bit is that ... it mostly works?
module Hansa
  extend self

  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

  # The `BakedData` class embeds the languages probabilities
  # in the actual binary so we don't have to carry it around.
  # baked_file_system gzips the data at compile time and
  # decompresses it transparently when read.
  class BakedData
    extend BakedFileSystem
    bake_folder "data"
  end

  alias ScoredLanguage = {String, Float64}

  # Empty token table used as the fetch default for languages the
  # corpus has no token probabilities for
  DEFAULT_TOKEN_PROBABILITIES = {} of String => Float64

  struct Classifier
    include JSON::Serializable
    @[JSON::Field(key: "LanguagesLogProbabilities")]
    property languages_log_probabilities : Hash(String, Float64)
    @[JSON::Field(key: "TokensLogProbabilities")]
    property tokens_log_probabilities : Hash(String, Hash(String, Float64))
    @[JSON::Field(key: "TokensTotal")]
    property tokens_total : Float64

    @known_languages : Array(String)? = nil

    # Despite the name this only reports the 100 most
    # common languages in the corpus, to avoid super
    # unilely false positives for obscure languages
    def known_languages : Array(String)
      @known_languages ||= languages_log_probabilities.keys.sort_by! { |language| languages_log_probabilities[language] }[-100..]
    end

    # Scores the content over the candidate languages (go-enry v2
    # "hints" semantics): with no candidates every known language
    # competes, with candidates only those do.
    def classify(content : String, candidates : Array(String) = [] of String)
      tokens = tokenize(content)
      scored_languages = [] of ScoredLanguage

      scoring_languages(candidates).each do |language|
        score = languages_log_probabilities[language]
        score += tokens_log_probability(tokens, language)
        scored_languages << {language, score}
      end

      scored_languages.sort_by { |language| language[1] }
    end

    def tokens_log_probability(tokens : Array(String), language : String) : Float64
      log_probability = 0.0
      language_tokens = tokens_log_probabilities.fetch(language, DEFAULT_TOKEN_PROBABILITIES)
      default_probability = default_token_probability

      tokens.each do |token|
        log_probability += language_tokens.fetch(token, default_probability)
      end

      log_probability
    end

    # Probability for tokens not present in a language's token
    # table, derived from the corpus like go-enry v2 does
    def default_token_probability : Float64
      Math.log(1 / tokens_total)
    end

    private def scoring_languages(candidates : Array(String)) : Array(String)
      return known_languages if candidates.empty?

      resolved = candidates.map { |candidate| Hansa.language_by_alias(candidate) || candidate }
        .select { |language| languages_log_probabilities.has_key?(language) }
        .uniq!
      resolved.empty? ? known_languages : resolved
    end

    def tokenize(content : String) : Array(String)
      # No need to look at more than 50K characters
      content = content[..50000]
      tokens = [] of String
      extracted, content = extract_and_replace_shebang(content)
      tokens += extracted
      extracted, content = extract_and_replace_sgml(content)
      tokens += extracted
      extracted, content = skip_comments_and_literals(content)
      tokens += extracted
      extracted, content = extract_and_replace_punctuation(content)
      tokens += extracted
      extracted, content = extract_and_replace_regular(content)
      tokens += extracted
      extracted, content = extract_and_replace_operator(content)
      tokens += extracted
      extracted, _ = extract_remainders(content)
      tokens += extracted
      tokens
    end

    def common_extract_and_replace(content : String, re : Regex) : {Array(String), String}
      tokens = content.scan(re).map { |match| match[0] }
      content.gsub(re, ' ')
      {tokens, content}
    end

    def extract_and_replace_punctuation(content : String) : {Array(String), String}
      common_extract_and_replace(content, /;|\{|\}|\(|\)|\[|\]/)
    end

    def extract_and_replace_regular(content : String) : {Array(String), String}
      common_extract_and_replace(content, /[0-9A-Za-z_\.@#\/\*]+/)
    end

    def extract_and_replace_operator(content : String) : {Array(String), String}
      common_extract_and_replace(content, /<<?|\+|\-|\*|\/|%|&&?|\|\|?/)
    end

    def extract_and_replace_shebang(content : String) : {Array(String), String}
      re_shebang = /(?m)^#!(?:\/[0-9A-Za-z_]+)*\/(?:([0-9A-Za-z_]+)|[0-9A-Za-z_]+(?:\s*[0-9A-Za-z_]+=[0-9A-Za-z_]+\s*)*\s*([0-9A-Za-z_]+))(?:\s*-[0-9A-Za-z_]+\s*)*$/
      shebang_tokens = [] of String
      content.scan(re_shebang).each do |match|
        # Env-style shebangs (#!/usr/bin/env ruby) match through the
        # second capture group, so group 1 is nil and no SHEBANG token
        # is emitted, mirroring go-enry.
        if interpreter = match[1]?
          if !interpreter.empty?
            shebang_tokens << "SHEBANG#!" + interpreter
            break
          end
        end
      end
      content = content.gsub(re_shebang, ' ')
      {shebang_tokens, content}
    end

    def extract_and_replace_sgml(content : String) : {Array(String), String}
      re_sgml = /(<\/?[^\s<>=\d"']+)(?:\s(.|\n)*?\/?>|>)/
      re_sgml_comment = /(<!--(.|\n)*?-->)/
      sgml_tokens = [] of String
      matches = content.scan(re_sgml)

      if matches
        sgml_tokens = [] of String
        matches.each do |match|
          if re_sgml_comment.match(match[0])
            next
          end

          token = match[1] + ">"

          sgml_tokens << token
          attributes = get_sgml_attributes(match[0])
          sgml_tokens += attributes
        end

        content = content.gsub(re_sgml, ' ')
      end

      {sgml_tokens, content}
    end

    def get_sgml_attributes(sgml_tag : String) : Array(String)
      re_sgml_attributes = /\s+([0-9A-Za-z_]+=)|\s+([^\s>]+)/
      re_sgml_lone_attribute = /([0-9A-Za-z_]+)/

      attributes = [] of String
      matches = sgml_tag.scan(re_sgml_attributes)

      if matches
        attributes = [] of String
        matches.each do |match|
          if match[1]?
            attributes << match[1]
          end

          if match[2]?
            lone_attributes = match[2].scan(re_sgml_lone_attribute)
            attributes += lone_attributes.map(&.[0])
          end
        end
      end

      attributes
    end

    def skip_comments_and_literals(content : String) : {Array(String), String}
      regex_to_skip = [
        /("(.|\n)*?"|'(.|\n)*?')/,                                                                          # string literals
        /(\/\*(.|\n)*?\*\/|<!--(.|\n)*?-->|\{-(.|\n)*?-\}|\(\*(.|\n)*?\*\)|"""(.|\n)*?"""|'''(.|\n)*?''')/, # multiline comment
        /(?m)(\/\/|--|#|%|")\s([^\n]*$)/,                                                                   # single line comment
        /(0x[0-9A-Fa-f]([0-9A-Fa-f]|\.)*|\d(\d|\.)*)([uU][lL]{0,2}|([eE][-+]\d*)?[fFlL]*)/,                 # literal number
      ]

      regex_to_skip.each do |skip|
        content = content.gsub(skip, ' ')
      rescue
        # Sometimes regexes run into JIT limits
      end

      {[] of String, content}
    end

    def extract_remainders(content : String) : {Array(String), String}
      splitted = content.split

      {splitted, content}
    end
  end

  @@classifier : Classifier?

  # Resolves a language name or alias (vim ft=..., emacs mode:...)
  # to a canonical language name; keys are lower case with
  # whitespace replaced by underscores.
  def self.language_by_alias(alias_name : String) : String?
    key = alias_name.split(',')[0].gsub(' ', '_').downcase
    LANGUAGE_BY_ALIAS[key]?
  end

  # The classifier is built from ~8.5MB of baked JSON, so it is
  # parsed on first use instead of at require time: programs that
  # never classify don't pay for it.
  def self.classifier : Classifier
    @@classifier ||= Classifier.from_json(BakedData.get("/frequencies.json").gets_to_end)
  end

  def self.classify(code : String) : String
    if code.empty?
      "Python" # whatever
    else
      code = scrub(code)

      # Same strategy order as go-enry v2's content-only subset:
      # modelines first, then shebangs; a strategy that resolves to
      # a single language is decisive, several candidates restrict
      # the classifier, none fall through to full classification.
      candidates = Modeline.languages(code)
      candidates = Shebang.languages(code) if candidates.empty?
      return candidates.first if candidates.size == 1

      classifier.classify(code, candidates).last[0]
    end
  end

  # Regexes fail on invalid UTF-8, so replace broken
  # byte sequences with the unicode replacement character
  private def self.scrub(code : String) : String
    code.scrub
  end
end
