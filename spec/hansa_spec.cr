require "./spec_helper"

# Expected values below were verified against the current classifier output.
# Known confusions (Crystal -> Ruby, Go -> Golo) are documented in the README.
describe Hansa do
  describe ".classify" do
    it "detects Ruby" do
      ruby_code = <<-'CODE'
        require 'sinatra'

        get '/hello' do
          @name = "world"
          erb :hello
        end

        class Greeter
          def initialize(name)
            @name = name
          end

          def greet
            puts "Hello, #{@name}!"
          end
        end
      CODE

      Hansa.classify(ruby_code).should eq("Ruby")
    end

    it "detects JavaScript" do
      js_code = <<-'CODE'
        const express = require('express');
        const app = express();

        function add(a, b) {
          return a + b;
        }

        app.listen(3000, () => {
          console.log("Server running on port 3000");
        });
      CODE

      Hansa.classify(js_code).should eq("JavaScript")
    end

    it "detects Python" do
      python_code = <<-'CODE'
        import os
        import sys

        def main():
            for i in range(10):
                print(f"iteration {i}")

        if __name__ == "__main__":
            main()
      CODE

      Hansa.classify(python_code).should eq("Python")
    end

    it "detects HTML" do
      html_code = <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <title>Test Page</title>
          <meta charset="utf-8">
        </head>
        <body>
          <div id="root" class="container">Hello</div>
        </body>
        </html>
      HTML

      Hansa.classify(html_code).should eq("HTML")
    end

    it "detects Shell from a shebang" do
      shell_code = <<-SHELL
        #!/bin/bash
        echo "hello"
        ls -la
      SHELL

      Hansa.classify(shell_code).should eq("Shell")
    end

    # Crystal code is frequently classified as Ruby, its closest relative
    # in the corpus. This documents the current behavior.
    it "detects Crystal code as Ruby or Crystal" do
      crystal_code = <<-CRYSTAL
        class Greeter
          def initialize(@name : String)
          end

          def greet
            puts "Hello, \#{@name}!"
          end
        end

        Greeter.new("world").greet
      CRYSTAL

      ["Crystal", "Ruby"].should contain(Hansa.classify(crystal_code))
    end

    # Go is often confused with Golo. This documents the current behavior.
    it "detects Go code as Go or Golo" do
      go_code = <<-GO
        package main

        import "fmt"

        func main() {
            fmt.Println("Hello")
        }
      GO

      ["Go", "Golo"].should contain(Hansa.classify(go_code))
    end

    it "returns Python for empty content" do
      Hansa.classify("").should eq("Python")
    end

    it "only classifies based on the first 50K characters" do
      filler = ("a" * 60 + "\n") * 900 # ~55K of neutral lines
      python_code = "import os\nfrom flask import Flask\napp = Flask(__name__)\n"

      # Python-only content is past the cutoff, so it must not win.
      Hansa.classify(filler + python_code).should_not eq("Python")
    end

    it "handles binary content" do
      # Currently raises ArgumentError (Regex UTF-8 error) on invalid UTF-8.
      binary = String.new(Bytes[0x89, 0x50, 0x4e, 0x47, 0xff, 0xfe, 0x00, 0x01])
      Hansa.classify(binary).should be_a(String)
    end
  end

  describe "Classifier" do
    classifier = Hansa::CLASSIFIER

    it "knows exactly 100 languages" do
      classifier.known_languages.size.should eq(100)
    end

    it "sorts known languages by log probability" do
      languages = classifier.known_languages
      probabilities = languages.map { |language| classifier.languages_log_probabilities[language] }

      probabilities.should eq(probabilities.sort)
    end

    it "classifies with token scores contributing to the result" do
      scored = classifier.classify("puts 'hello'")

      scored.size.should eq(100)
      scored.last[0].should eq("Ruby")
    end

    it "tokenizes shebang lines" do
      tokens = classifier.tokenize("#!/usr/bin/ruby\nputs 1")

      tokens.should contain("SHEBANG#!ruby")
    end

    it "tokenizes SGML tags and attributes" do
      tokens = classifier.tokenize("<div id=\"root\" class=\"box\">x</div>")

      tokens.should contain("<div>")
      tokens.should contain("id=")
      tokens.should contain("class=")
    end

    it "strips comments and string literals from content" do
      tokens = classifier.tokenize("x = 1 # this is a comment")

      tokens.should contain("x")
      tokens.should_not contain("comment")
    end

    it "extracts punctuation tokens" do
      tokens = classifier.tokenize("foo(a, b) { c }")

      ["(", ")", "{", "}"].each do |punctuation|
        tokens.should contain(punctuation)
      end
    end

    it "does not tokenize beyond 50K characters" do
      # The keyword only appears past the 50K cutoff, so it must not
      # show up as a token.
      filler = "a " * 30000
      tokens = classifier.tokenize(filler + " puts ")

      tokens.should_not contain("puts")
    end
  end
end
