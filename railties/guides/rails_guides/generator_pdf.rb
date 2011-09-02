#PDF: Adaptation of "generator.rb" file to transform textile2 into PDF wit gimli
#
# Changes made to "generator.rb":
#    Generator      ->  GeneratorPDF
#    Invokation order changed in "generate" method to assure asset availability
#    "output"       ->  "pdf"                   in initialize_dirs
#    ".html"        ->  ".textile"              in output_file_for(guide)
#    preproc & generate PDF file with gimli     in generate_guide(guide, output_file)


# ---------------------------------------------------------------------------
#
# This script generates the guides. It can be invoked either directly or via the
# generate_guides rake task within the railties directory.
#
# Guides are taken from the source directory, and the resulting HTML goes into the
# output directory. Assets are stored under files, and copied to output/files as
# part of the generation process.
#
# Some arguments may be passed via environment variables:
#
#   WARNINGS
#     If you are writing a guide, please work always with WARNINGS=1. Users can
#     generate the guides, and thus this flag is off by default.
#
#     Internal links (anchors) are checked. If a reference is broken levenshtein
#     distance is used to suggest an existing one. This is useful since IDs are
#     generated by Textile from headers and thus edits alter them.
#
#     Also detects duplicated IDs. They happen if there are headers with the same
#     text. Please do resolve them, if any, so guides are valid XHTML.
#
#   ALL
#    Set to "1" to force the generation of all guides.
#
#   ONLY
#     Use ONLY if you want to generate only one or a set of guides. Prefixes are
#     enough:
#
#       # generates only association_basics.html
#       ONLY=assoc ruby rails_guides.rb
#
#     Separate many using commas:
#
#       # generates only association_basics.html and migrations.html
#       ONLY=assoc,migrations ruby rails_guides.rb
#
#     Note that if you are working on a guide generation will by default process
#     only that one, so ONLY is rarely used nowadays.
#
#   GUIDES_LANGUAGE
#     Use GUIDES_LANGUAGE when you want to generate translated guides in
#     <tt>source/<GUIDES_LANGUAGE></tt> folder (such as <tt>source/es</tt>).
#     Ignore it when generating English guides.
#
#   EDGE
#     Set to "1" to indicate generated guides should be marked as edge. This
#     inserts a badge and changes the preamble of the home page.
#
# ---------------------------------------------------------------------------

require 'set'
require 'fileutils'

require 'active_support/core_ext/string/output_safety'
require 'active_support/core_ext/object/blank'
require 'action_controller'
require 'action_view'

require 'rails_guides/indexer'
require 'rails_guides/helpers'
require 'rails_guides/levenshtein'

module RailsGuides
  class GeneratorPdf
    attr_reader :guides_dir, :source_dir, :output_dir, :edge, :warnings, :all

    GUIDES_RE = /\.(?:textile|html\.erb)$/

    def initialize(output=nil)
      @lang = ENV['GUIDES_LANGUAGE']
      initialize_dirs(output)
      create_output_dir_if_needed
      set_flags_from_environment
    end

    def generate

#PDF: Order changed for gimli to find assets
      copy_assets
      generate_guides
    end

    private
    def initialize_dirs(output)
      @guides_dir = File.join(File.dirname(__FILE__), '..')
      @source_dir = File.join(@guides_dir, "source", @lang.to_s)
      @output_dir = output || File.join(@guides_dir, "pdf", @lang.to_s)  #PDF
    end

    def create_output_dir_if_needed
      FileUtils.mkdir_p(output_dir)
    end

    def set_flags_from_environment
      @edge     = ENV['EDGE']     == '1'
      @warnings = ENV['WARNINGS'] == '1'
      @all      = ENV['ALL']      == '1'
    end

    def generate_guides
      guides_to_generate.each do |guide|
        output_file = output_file_for(guide)
        generate_guide(guide, output_file) if generate?(guide, output_file)
      end
    end

    def guides_to_generate
      guides = Dir.entries(source_dir).grep(GUIDES_RE)
      ENV.key?('ONLY') ? select_only(guides) : guides
    end

    def select_only(guides)
      prefixes = ENV['ONLY'].split(",").map(&:strip)
      guides.select do |guide|
        prefixes.any? {|p| guide.start_with?(p)}
      end
    end

    def copy_assets
      FileUtils.cp_r(Dir.glob("#{guides_dir}/assets/*"), output_dir)
    end

    def output_file_for(guide)
      guide.sub(GUIDES_RE, '.textile')  #PDF
    end

    def generate?(source_file, output_file)
      fin  = File.join(source_dir, source_file)
      fout = File.join(output_dir, output_file)
      all || !File.exists?(fout) || File.mtime(fout) < File.mtime(fin)
    end

    def generate_guide(guide, output_file)

      puts "Preparing Textile for #{output_file}"

      File.open(File.join(output_dir, output_file), 'w') do |f|


 		body = File.read(File.join(source_dir, guide))

		index =  %x{grep "^h[3-4].*$" #{File.join(source_dir, guide)}}


#		index = body.gsub(/([^h][^3-4][^.].*$)/, '')

#		index = index.gsub(/^(h3\.[ ]*)(.*)$/, "<span class='h3'>\\2</span>")
#		index = index.gsub(/^(h4\.[ ]*)(.*)$/, "<span class='h4'>\\2</span>")

#		index = index.gsub(/^(h3\.[ ]*)(.*)$/, "\# *\"\\2\":(\#" + (("\\2").gsub(/a/, '-')) + ")*")

		index = index.gsub(/^(h3\.[ ]*)(.*)$/, "\# *\\2*")
		index = index.gsub(/^(h4\.[ ]*)(.*)$/, " ** \\2")


		body = body.gsub(/h2\.(.*)$/, "<div class='guide'>\n\nh2. \\1 \n\n<div class='prologue'>")
		body = body.gsub(/endprologue./, '</div>' + "\n\nh3. INDEX\n\n" + index)

#        puts "step 1"


#        body = body.gsub(%r{([a-zA-Z0-9.,:;!?<>'"'_*+\^\~%-\(\)])(\n\r|\r\n|\r|\n)([a-zA-Z0-9.,:;!?<>'"'_*+\^\~%-\(\)])}, '\1 \3')

		body = body.gsub(%r{<pre>}, "<pre class='pre'>")

#	    puts "step 2"


		body = body.gsub(%r{<ruby>}, "```ruby")
		body = body.gsub(%r{</ruby>}, "```")

		body = body.gsub(%r{<shell>}, "```sh")
		body = body.gsub(%r{</shell>}, "```")

		body = body.gsub(%r{<yaml>}, "```yaml")
		body = body.gsub(%r{</yaml>}, "```")

		body = body.gsub(%r{<html>}, "```html")
		body = body.gsub(%r{</html>}, "```")

		body = body.gsub(%r{<erb>}, "```erb")
		body = body.gsub(%r{</erb>}, "```")

		body = body.gsub(%r{<plain>}, "```text")
		body = body.gsub(%r{</plain>}, "```")

		body = body.gsub(%r{<tt>}, "<tt class='tt'>")

#        puts "step 3"

		body = body.gsub(%r{TIP:|TIP.}, 'div(tip). ')
		body = body.gsub(%r{NOTE:|NOTE.}, 'div(note). ')
		body = body.gsub(%r{INFO:|INFO.}, 'div(info). ')
		body = body.gsub(%r{WARNING.|WARNING.}, 'div(warning). ')
		body = body + '</div>'

#        puts "step 4"

    # Rewrite headers to include id for internal linking in pdf
    body = body.gsub /(h\d)\. (.+)/ do
      "#{$1}(##{$2.parameterize}). #{$2}"
    end

        f.write body
      end

      puts "Generating #{output_file}"

      #PDF: generate PDF using gimli
	  %x{gimli -f #{File.join(output_dir, output_file)} -s 'guides/assets/stylesheets/pdf.css' -o #{output_dir}}

    end
  end
end
