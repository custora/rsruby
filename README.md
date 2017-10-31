# Introduction

RSRuby is a bridge library for Ruby giving Ruby developers access to the full R statistical programming environment. RSRuby embeds a full R interpreter inside the running Ruby script, allowing R methods to be called and data passed between the Ruby script and the R interpreter. Most data conversion is handled automatically, but user-definable conversion routines can also be written to handle any R or Ruby class.

RSRuby is a partial conversion of [RPy](http://rpy.sourceforge.net/), and shares the same goals of robustness, ease of use and speed. The current version is stable and passes 90% of the RPy test suite. Some conversion and method calling semantics differ between RPy and RSRuby (largely due to the differences between Python and Ruby), but they are now largely similar in functionality.

Major things to be done in the future include proper handling of OS signals, user definable I/O functions, improved DataFrame support and inevitable bug fixes.

# Installation

A working R installation is required. R must have been built with the `--enable-R-shlib` option enabled to provide the R shared library used by RSRuby.

When installing RSRuby, you may want to supply the `--with-R-dir` flag to indicate where your R installation (including the aforementioned shared libraries) is located. For example:

    gem install rsruby -- --with-R-dir=path/to/R/installation

The path to your R installation may be, for example, `/usr/local/lib/r`. (See extconf.rb for some other common locations.)

If you do not supply this flag when installing RSRuby, you will have to supply this as the `R_HOME` environment variable whenever you want to use RSRuby.

# Documentation

There are a few sources of documentation for RSRuby, though the manual should be considered the authoritative text.

- Manual: The [manual](http://web.kuicr.kyoto-u.ac.jp/~alexg/rsruby/manual.pdf) has most of the comprehensive information on calling R functions and the conversion system.
- Examples: A few example scripts are included in the distribution:
  - Using Arrayfields (files/examples/arrayfields_rb.html) instead of Hash for named lists/vectors.
  - Using the Bioconductor (files/examples/bioc_rb.html) library.
  - An example (files/examples/dataframe_rb.html) using the DataFrame class.
  - An example (files/examples/erobj_rb.html) using the ERObj class.
- Tests: The test scripts also show several usage examples.

Finally, here is a very quick and simple example:

    # Initialize R
    require 'rsruby'

    # RSRuby uses Singleton design pattern so call instance rather
    # than new
    r = RSRuby.instance
    # Call R functions on the r object
    data = r.rnorm(100)
    r.plot(data)
    sleep(2)
    # Call with named args
    r.plot({'x' => data,
           'y' => data,
           'xlab' => 'test',
           'ylab' => 'test'})
    sleep(2)

# License

LGPL. See LICENSE.txt.
