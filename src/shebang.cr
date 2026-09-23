module Hansa
  # Content-based shebang detection, ported from go-enry v2's
  # GetLanguagesByShebang strategy. When the interpreter maps to a
  # single language the shebang is considered decisive; when it maps
  # to several (perl -> Perl/Pod, lua -> Lua/Terra) they are handed
  # to the classifier as candidates.
  module Shebang
    SHEBANG_EXEC_HACK = /exec (\w+).+\$0.+\$@/
    PYTHON_VERSION    = /python\d\.\d+/
    ENV_OPT_ARGS      = /-[i0uCSv]*|--\S+/
    ENV_VAR_ARGS      = /\S+=\S+/

    def self.languages(content : String) : Array(String)
      LANGUAGES_BY_INTERPRETER[interpreter(content)]? || [] of String
    end

    # Returns the interpreter named by the shebang line, handling
    # /usr/bin/env indirection and the special cases documented in
    # go-enry's getInterpreter.
    def self.interpreter(content : String) : String
      line = first_line(content)
      return "" unless line.starts_with?("#!")

      line = line[2..].strip
      fields = line.split
      return "" if fields.empty?

      # Extract interpreter name from path; basename is enough
      # because even Windows shebangs use forward slashes.
      name = File.basename(fields[0])

      # #!/usr/bin/env [...], possibly with flags or VAR=value
      # assignments between env and the interpreter.
      if name == "env"
        return "" if fields.size == 1
        while fields.size > 2
          if ENV_OPT_ARGS.match(fields[1]) || ENV_VAR_ARGS.match(fields[1])
            fields.delete_at(1)
            next
          end
          break
        end
        name = File.basename(fields[1])
      end

      name = multiline_exec_interpreter(content) if name == "sh"

      # python2.7 -> python2
      name = name.split('.')[0] if PYTHON_VERSION.match(name)

      # osascript with -l could be any of several languages, so it
      # is not a reliable signal (same call as Linguist's shebang.rb)
      if name == "osascript" && line.includes?("-l")
        name = ""
      end

      name
    end

    private def self.first_line(content : String) : String
      if index = content.index('\n')
        content[0, index]
      else
        content
      end
    end

    # A #!/bin/sh script may exec another interpreter within its
    # first lines (the classic shell-wrapper trick); that
    # interpreter is a better signal than sh itself.
    private def self.multiline_exec_interpreter(content : String) : String
      content.each_line.first(5).each do |line|
        if match = SHEBANG_EXEC_HACK.match(line)
          return match[1]
        end
      end
      "sh"
    end
  end
end
