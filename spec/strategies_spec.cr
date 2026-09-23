require "./spec_helper"

# Shebang and modeline strategies ported from go-enry v2.
describe "content strategies" do
  describe Hansa::Shebang do
    it "reads the interpreter from a direct path" do
      Hansa::Shebang.interpreter("#!/usr/bin/ruby\nputs 1").should eq("ruby")
    end

    it "reads the interpreter through /usr/bin/env" do
      Hansa::Shebang.interpreter("#!/usr/bin/env python3\nprint(1)").should eq("python3")
    end

    it "skips env flags and VAR=value arguments" do
      Hansa::Shebang.interpreter("#!/usr/bin/env -S VAR=1 node x.js").should eq("node")
    end

    it "strips python version suffixes" do
      Hansa::Shebang.interpreter("#!/usr/bin/python2.7\n").should eq("python2")
    end

    it "follows shell-wrapper exec lines for sh" do
      content = "#!/bin/sh\nexec scala -nocompdaemon \"$0\" \"$@\"\n"
      Hansa::Shebang.interpreter(content).should eq("scala")
    end

    it "ignores osascript when -l selects a language" do
      Hansa::Shebang.interpreter("#!/usr/bin/osascript -l JavaScript\n").should eq("")
    end

    it "returns no languages without a shebang" do
      Hansa::Shebang.languages("puts 1\n").should be_empty
    end

    it "maps interpreters to candidate languages" do
      Hansa::Shebang.languages("#!/bin/bash\necho hi\n").should eq(["Shell"])
      Hansa::Shebang.languages("#!/usr/bin/perl\n").should eq(["Perl", "Pod"])
    end
  end

  describe Hansa::Modeline do
    it "detects vim modelines" do
      Hansa::Modeline.languages("# comment\n# vim: set ft=ruby:\n").should eq(["Ruby"])
    end

    it "detects emacs modelines" do
      Hansa::Modeline.languages("# -*- mode: python -*-\n").should eq(["Python"])
    end

    it "finds modelines in the last lines of long files" do
      content = ("x = 1\n" * 20) + "# vim: ft=javascript:\n"
      Hansa::Modeline.languages(content).should eq(["JavaScript"])
    end

    it "rejects conflicting vim modeline settings" do
      Hansa::Modeline.languages("# vim: ft=ruby syntax=perl:\n").should be_empty
    end

    it "returns no languages without a modeline" do
      Hansa::Modeline.languages("puts 1\n").should be_empty
    end
  end

  describe ".language_by_alias" do
    it "resolves aliases to canonical names" do
      Hansa.language_by_alias("c++").should eq("C++")
      Hansa.language_by_alias("aspx").should eq("ASP.NET")
    end

    it "resolves names case-insensitively" do
      Hansa.language_by_alias("RUBY").should eq("Ruby")
    end

    it "returns nil for unknown aliases" do
      Hansa.language_by_alias("nosuchlang").should be_nil
    end
  end
end

describe Hansa do
  describe ".classify with content strategies" do
    it "classifies env-shebang files by interpreter" do
      Hansa.classify("#!/usr/bin/env python3\nprint('hello')\n").should eq("Python")
    end

    it "classifies vim modelines over content" do
      Hansa.classify("x = 1\n# vim: set ft=ruby:\n").should eq("Ruby")
    end

    it "classifies emacs modelines over content" do
      Hansa.classify("# -*- mode: python -*-\nx = 1\n").should eq("Python")
    end

    it "restricts the classifier to shebang candidates" do
      perl_code = "use strict;\nmy $greeting = 'hello';\nprint \"$greeting, world\\n\";\n"
      result = Hansa.classify("#!/usr/bin/perl\n#{perl_code}")

      ["Perl", "Pod"].should contain(result)
    end
  end

  describe "Classifier#classify with candidates" do
    classifier = Hansa.classifier

    it "scores only the candidate languages" do
      scored = classifier.classify("puts 1", ["Ruby", "Pod"])

      scored.size.should eq(2)
      scored.map(&.[0]).should contain("Ruby")
    end

    it "falls back to all known languages when candidates are unknown" do
      scored = classifier.classify("puts 1", ["No Such Language"])

      scored.size.should eq(100)
    end
  end
end
