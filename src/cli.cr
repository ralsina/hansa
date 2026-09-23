require "docopt"
require "./hansa"

module Hansa
  module CLI
    # The classifier only ever looks at the first 50K characters, so
    # reading more than this from disk is wasted work. 256KB covers
    # 50K four-byte UTF-8 characters with room to spare; a read that
    # cuts a multibyte character in half is cleaned up by the scrub
    # in Hansa.classify.
    MAX_READ_BYTES = 256 * 1024

    DOC = <<-DOC
      Hansa, detect the programming language of files by content only.

      Usage:
        hansa [options] <file>...
        hansa -h | --help
        hansa -V | --version

      Options:
        -h, --help     Show this help.
        -V, --version  Show version.

      A <file> of "-" reads standard input.
      DOC

    def self.run(argv : Array(String), output : IO = STDOUT, error : IO = STDERR,
                 input : IO = STDIN) : Int32
      options = parse_options(argv, error)
      return 1 if options.nil?

      if options["--help"]?
        output << DOC
        return 0
      end

      if options["--version"]?
        output << "hansa #{VERSION}\n"
        return 0
      end

      files = options["<file>"].as(Array(String))
      exit_code = 0
      files.each do |file|
        exit_code |= 1 unless report_language(file, output, error, input)
      end
      exit_code
    end

    private def self.parse_options(argv : Array(String), error : IO)
      Docopt.docopt(DOC, argv: argv, help: false, version: false, exit: false)
    rescue exception : Docopt::DocoptException
      message = exception.message
      error << message << "\n" if message && !message.empty?
      error << Docopt::DocoptExit.usage << "\n"
      nil
    end

    private def self.report_language(file : String, output : IO, error : IO,
                                     input : IO) : Bool
      content =
        if file == "-"
          input.gets_to_end
        else
          return false unless check_file(file, error)
          read_file_prefix(file)
        end

      output << file << ' ' << Hansa.classify(content) << "\n"
      true
    rescue File::AccessDeniedError
      error << "hansa: " << file << ": permission denied\n"
      false
    end

    private def self.check_file(file : String, error : IO) : Bool
      unless File.exists?(file)
        error << "hansa: " << file << ": no such file or directory\n"
        return false
      end

      if Dir.exists?(file)
        error << "hansa: " << file << ": is a directory\n"
        return false
      end

      unless File.file?(file)
        error << "hansa: " << file << ": not a regular file\n"
        return false
      end

      true
    end

    private def self.read_file_prefix(path : String) : String
      File.open(path) do |file|
        buffer = Bytes.new(MAX_READ_BYTES)
        total_bytes = 0
        while total_bytes < buffer.size
          read_bytes = file.read(buffer + total_bytes)
          break if read_bytes == 0
          total_bytes += read_bytes
        end
        String.new(buffer[0, total_bytes])
      end
    end
  end
end
