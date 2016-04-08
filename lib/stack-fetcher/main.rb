require 'shellwords'

module StackFetcher

  class Main

    attr_reader :context, :tmp_files

    def initialize(argv)
      @context = Context.new
      @context.argv = argv.dup.freeze
    end

    def run
      @context.stack_types = StackTypes.new(context).list

      if @context.stack_types.empty?
        puts "No stack types defined - nothing to do"
        return
      end

      puts "Determining stack names"
      @context.stack_names = StackFinder.new(context).get_names
      @tmp_files = TmpFiles.new(@context)
      @tmp_files.clean!
      puts ""

      puts "Retrieving existing stacks"
      Puller.new(context, tmp_files).get_all
      puts ""

      puts "Generating target stacks"
      Generator.new(context, tmp_files).generate_all
      puts ""

      NormaliserRunner.new(context, tmp_files).normalise_all
      tmp_files.copy_current_to_next

      comparison = StackComparer.new(context, tmp_files).compare
      puts ""
      comparison.print
      puts ""

      show_instructions

      context.save
      p @context
    end

    def show_instructions
      cmd = [ "spud", "update" ] + context.argv
      update_command = Shellwords.join cmd

      puts <<EOF
You should now edit the "next" files to suit, for example using the following
commands:

EOF

      context.stack_types.each do |t|
        puts <<EOF
  vimdiff #{Shellwords.join [ "vimdiff", tmp_files.current_template(t), tmp_files.generated_template(t), tmp_files.next_template(t) ]} ; vim #{Shellwords.shellescape tmp_files.next_description(t)}
EOF
      end

      puts <<EOF

then run the following command to review and apply your changes:

  #{update_command}

EOF
    end

  end

end