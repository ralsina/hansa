require "./spec_helper"
require "../src/cli"

def run_cli(argv : Array(String), input : String = "")
  output = IO::Memory.new
  error = IO::Memory.new
  exit_code = Hansa::CLI.run(argv, output: output, error: error,
    input: IO::Memory.new(input))

  {exit_code: exit_code, output: output.to_s, error: error.to_s}
end

describe Hansa::CLI do
  describe ".run" do
    it "prints help and exits 0 with -h" do
      result = run_cli(["-h"])

      result[:exit_code].should eq(0)
      result[:output].should contain("Usage:")
      result[:output].should contain("--help")
    end

    it "prints help and exits 0 with --help" do
      result = run_cli(["--help"])

      result[:exit_code].should eq(0)
      result[:output].should contain("Usage:")
    end

    it "prints the version and exits 0 with -V" do
      result = run_cli(["-V"])

      result[:exit_code].should eq(0)
      result[:output].should start_with("hansa ")
    end

    it "shows usage on stderr and exits 1 with no arguments" do
      result = run_cli([] of String)

      result[:exit_code].should eq(1)
      result[:error].should contain("Usage:")
      result[:output].should be_empty
    end

    it "shows usage on stderr and exits 1 for unknown options" do
      result = run_cli(["--frobnicate"])

      result[:exit_code].should eq(1)
      result[:error].should contain("Usage:")
    end

    it "classifies a file and exits 0" do
      path = File.tempname("hansa_spec", ".rb")
      File.write(path, "puts 'hello world'\n")
      begin
        result = run_cli([path])

        result[:exit_code].should eq(0)
        result[:output].should contain("#{path} Ruby")
      ensure
        File.delete(path)
      end
    end

    it "classifies standard input for a file of -" do
      result = run_cli(["-"], input: "puts 'hello world'\n")

      result[:exit_code].should eq(0)
      result[:output].should contain("- Ruby")
    end

    it "reports missing files on stderr and exits 1" do
      result = run_cli(["/no/such/file/anywhere"])

      result[:exit_code].should eq(1)
      result[:error].should contain("/no/such/file/anywhere: no such file or directory")
      result[:output].should be_empty
    end

    it "reports directories on stderr and exits 1" do
      result = run_cli([Dir.tempdir])

      result[:exit_code].should eq(1)
      result[:error].should contain("#{Dir.tempdir}: is a directory")
    end

    it "keeps classifying remaining files after an error" do
      missing = "/no/such/file/anywhere"
      path = File.tempname("hansa_spec", ".py")
      File.write(path, "import os\nimport sys\n\ndef main():\n    for i in range(10):\n        print(f\"iteration {i}\")\n")
      begin
        result = run_cli([missing, path])

        result[:exit_code].should eq(1)
        result[:error].should contain("#{missing}: no such file or directory")
        result[:output].should contain("#{path} Python")
      ensure
        File.delete(path)
      end
    end

    it "does not read past MAX_READ_BYTES" do
      # Python-only content sits beyond the 256KB prefix the CLI
      # reads, so the filler must win, exactly as if the classifier's
      # own 50K-character cutoff had been hit.
      filler = ("x" * 80 + "\n") * 4000 # ~320KB of neutral content
      path = File.tempname("hansa_spec", ".txt")
      File.write(path, filler)
      begin
        result = run_cli([path])

        result[:exit_code].should eq(0)
        result[:output].should_not contain(" Python\n")
      ensure
        File.delete(path)
      end
    end
  end
end
