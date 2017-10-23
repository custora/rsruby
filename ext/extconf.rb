require 'mkmf'

# Searched after ENV['PATH']
DEFAULT_R_PATHS = %w(
  /usr/local/lib64/R
  /usr/local/lib/R
  /usr/lib64/R
  /usr/lib/R
  /Library/Frameworks/R.framework/Resources
  /usr/local/Frameworks/R.framework/Resources
)

# Searched after DEFAULT_R_PATHS/include
DEFAULT_R_INCLUDE_PATHS = %w(
  /usr/include/R
  /usr/share/R/include
)

dir_config('R')

r_paths = if $configure_args.has_key?('--with-R-dir')
  [$configure_args['--with-R-dir']]
else
  r_paths = ENV['PATH'].split(File::PATH_SEPARATOR) + DEFAULT_R_PATHS
end

r_lib_paths = if $configure_args.has_key?('--with-R-lib')
  [$configure_args['--with-R-lib']]
else
  r_paths.map { |dir| File.join(dir, 'lib') }
end

find_library('R', nil, *r_lib_paths)
unless have_library('R')
  $stderr.puts "\nERROR: Cannot find the R library, aborting."
  exit 1
end

r_include_paths = if $configure_args.has_key?('--with-R-include')
  [$configure_args['--with-R-include']]
else
  r_paths.map { |dir| File.join(dir, 'include') } + DEFAULT_R_INCLUDE_PATHS
end

find_header('R.h', nil, *r_include_paths)
unless have_header('R.h')
  $stderr.puts "\nERROR: Cannot find the R header, aborting."
  exit 1
end

File.open("config.h", "w") do |f|
  f.puts("#ifndef R_CONFIG_H")
  f.puts("#define R_CONFIG_H")
  r_home = $configure_args.has_key?('--with-R-dir') ? $configure_args['--with-R-dir'].inspect : 'NULL'
  f.puts("#define RSRUBY_R_HOME #{r_home}")
  f.puts("#endif")
end
$extconf_h = 'config.h'

create_makefile("rsruby_c")
