module Hansa
  # Content-based modeline detection, ported from go-enry v2's
  # GetLanguagesByModeline strategy. Emacs modelines are checked
  # first, then Vim ones, over the first and last 5 lines.
  module Modeline
    SEARCH_SCOPE = 5

    EMACS_MODELINE = /-\*-\s*(.+?)\s*-\*-/
    EMACS_LANG     = /(?i:mode)\s*:\s*([^\s;]+)/
    VIM_MODELINE   = /(?:(?:\s|^)vi(?:m[<=>]?\d+|m)?|[\t ]*ex)\s*:\s*(.*)$/
    VIM_LANG       = /(?i:filetype|ft|syntax)\s*=(\w+)(?:\s|:|$)/

    def self.languages(content : String) : Array(String)
      head_and_footer = header_and_footer(content)

      emacs = emacs_languages(head_and_footer)
      return emacs unless emacs.empty?

      vim_languages(head_and_footer)
    end

    private def self.header_and_footer(content : String) : String
      return content if content.count('\n') < SEARCH_SCOPE * 2

      lines = content.lines
      (lines.first(SEARCH_SCOPE) + lines.last(SEARCH_SCOPE)).join('\n')
    end

    private def self.emacs_languages(text : String) : Array(String)
      last_match = nil
      text.each_line do |line|
        if match = line.match(EMACS_MODELINE)
          last_match = match[1]
        end
      end
      return [] of String unless captured = last_match

      alias_name =
        if mode = EMACS_LANG.match(captured)
          mode[1]
        else
          captured
        end

      if language = Hansa.language_by_alias(alias_name)
        [language]
      else
        [] of String
      end
    end

    private def self.vim_languages(text : String) : Array(String)
      last_match = nil
      text.each_line do |line|
        if match = line.match(VIM_MODELINE)
          last_match = match[1]
        end
      end
      return [] of String unless captured = last_match

      matches = captured.scan(VIM_LANG).map(&.[1])
      return [] of String if matches.empty?

      # ft=, syntax= and filetype= must agree when several appear,
      # otherwise the modeline is not a reliable signal.
      return [] of String unless matches.uniq.size == 1

      if language = Hansa.language_by_alias(matches.first)
        [language]
      else
        [] of String
      end
    end
  end
end
