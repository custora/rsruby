require 'mkmf'

dir_config('R')

if $configure_args.has_key?('--with-R-lib')
  find_library('R', nil, $configure_args['--with-R-lib'])
  unless have_library('R')
    $stderr.puts "\nERROR: Cannot find the R library, aborting."
    exit 1
  end
else
  if RUBY_PLATFORM =~ /darwin/
    # Temporary changes due to new Xcode problems as of 2018-10-20.
    # Some incorrect warnings get promoted to failures and cause bad installs.
    append_ldflags(`R CMD config --ldflags`.shellsplit, {:werror => false})
  else
    append_ldflags(`R CMD config --ldflags`.shellsplit)
  end
end

if $configure_args.has_key?('--with-R-include')
  find_header('R.h', nil, $configure_args['--with-R-include'])
  unless have_header('R.h')
    $stderr.puts "\nERROR: Cannot find the R header, aborting."
    exit 1
  end
else
  append_cppflags(`R CMD config --cppflags`.shellsplit)
end

File.open("r_config.h", "w") do |f|
  f.puts("#ifndef R_CONFIG_H")
  f.puts("#define R_CONFIG_H")
  r_home = $configure_args['--with-R-dir'] || `R RHOME | grep -v ^WARNING:`.chomp
  f.puts("#define RSRUBY_R_HOME \"#{r_home}\"")
  f.puts("#endif")
end
$extconf_h = 'r_config.h'

create_makefile("rsruby_c")
