require 'rsruby/robj'
require 'rsruby/rarray'
require 'rsruby_c'
require 'singleton'

require 'complex'

#== Synopsis
#
#This class represents the embedded R interpreter. The Singleton module is
#mixed in to ensure that only one R interpreter is running in a script at
#any one time and that the interpreter can always be easily accessed without
#using a global variable.
#
#The R interpreter is started by calling RSRuby.instance. The returned
#object represents the R interpreter and R functions are called by
#calling methods on this object:
#
#  r = RSRuby.instance
#  r.sum(1,2,3)
#  puts r.t_test(1,2,3)['p-value']
#
#See the manual[http://web.kuicr.kyoto-u.ac.jp/~alexg/rsruby/manual.pdf] for
#more details on calling functions and the conversion system for passing data
#between Ruby and R. If no suitable conversion from R to Ruby is found, an RObj
#is returned (all R functions are returned as instances of RObj).
#--
#== Copyright
#Copyright (C) 2006 Alex Gutteridge
#
#The Original Code is the RPy python module.
#
#The Initial Developer of the Original Code is Walter Moreira.
#Portions created by the Initial Developer are Copyright (C) 2002
#the Initial Developer. All Rights Reserved.
#
#Contributor(s):
#Gregory R. Warnes <greg@warnes.net> (RPy Maintainer)
#
#This library is free software; you can redistribute it and/or
#modify it under the terms of the GNU Lesser General Public
#License as published by the Free Software Foundation; either
#version 2.1 of the License, or (at your option) any later version.
#
#This library is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#Lesser General Public License for more details.
#
#You should have received a copy of the GNU Lesser General Public
#License along with this library; if not, write to the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#++

class RSRuby

  VERSION = '0.5.5'

  include Singleton

  #Constants for conversion modes
  TOP_CONVERSION = 4
  PROC_CONVERSION = 4
  CLASS_CONVERSION = 3
  BASIC_CONVERSION = 2
  VECTOR_CONVERSION = 1
  NO_CONVERSION = 0
  NO_DEFAULT = -1

  VALID_CONVERSION_MODES = [-1, 0, 1, 2, 3, 4]

  attr_accessor :proc_table, :class_table, :default_mode, :caching

  @@r_flags = ["--quiet", "--vanilla"]
  def self.r_flags
    @@r_flags
  end
  def self.r_flags= r_flags
    @@r_flags = r_flags
  end

  @@underscore_translation = true
  def self.underscore_translation
    @@underscore_translation
  end
  def self.underscore_translation=(tf)
    @@underscore_translation = !!tf
  end

  def underscore_translation
    self.class.underscore_translation
  end
  def underscore_translation=(tf)
    self.class.underscore_translation = tf
  end

  #Create a new RSRuby interpreter instance. The Singleton design pattern
  #ensures that only one instance can be running in a script. Further
  #calls to RSRuby.instance will return the original instance.
  def initialize

    #Initialize R
    r_init(@@r_flags)

    @default_mode = NO_DEFAULT

    @class_table = {}
    @proc_table  = {}

    @caching = true
    reset_cache

    #Catch errors
    self.__init_eval_R__("options(error=expression(NULL))")
    #disable errors
    self.__init_eval_R__("options(show.error.messages=F)")

  end

  def reset_cache
    #Setup R object cache
    @cache = {}
    @cache['get'] = self.get_fun('get')

    #Get constants
    @cache['TRUE']  = self.__getitem__('T',true)
    @cache['FALSE'] = self.__getitem__('F',true)

    @cache['parse'] = self.__getitem__('parse',true)
    @cache['eval']  = self.__getitem__('eval',true)

    @cache['NA']    = self.__init_eval_R__('NA')
    @cache['NaN']   = self.__init_eval_R__('NaN')
    # @cache['NAN']   = self.eval_R('as.double(NA)')

    #help!
    @cache['helpfun'] = self.with_mode(NO_CONVERSION, self.__getitem__('help',true))
  end

  #Delete an R object from the cache. Use R-style function naming, not ruby style.
  def delete_from_cache(x)
    @cache.delete(x)
  end

  def self.img(filename,args={})
    format = File.extname(filename).gsub(".","").to_sym
    r = RSRuby.instance
    raise ArgumentError, "Format #{format.to_s} is not supported" unless [:pdf].include? format
    r.pdf(filename,args)
    yield(r)
    r.dev_off.call
  end

  #Handles method name conversion and calling of R functions
  #If called without args the R function/varialbe is returned rather
  #than called.
  def method_missing(r_id,*args)

    #Translate Ruby method call to R
    robj_name = RSRuby.convert_method_name(r_id.to_s)

    robj = robj_name =~ /(.+)::(.+)/ ? self.send('::',$1,$2) : self.__getitem__(robj_name)

    #TODO perhaps this is not neccessary - always call these methods
    #use the [] syntax for variables etc...
    if args.length > 0

      #convert arguments to lcall format
      lcall_args = RSRuby.convert_args_to_lcall(args)

      #Return result of calling object with lcall
      #formatted args
      return robj.lcall(lcall_args)

    end

    return robj

  end

  #The same as  method_missing, but only returns the R function/object,
  #does not call it.
  def [](r_id)

    #Translate Ruby method call to R
    robj_name = RSRuby.convert_method_name(r_id.to_s)

    #Retrieve it
    robj = self.__getitem__(robj_name)

    #And return it
    return robj

  end

  #Takes an #RObj representing an R function and sets the 'wrapping'
  #mode for that function. Implemented for compatibility with RPy.
  def with_mode(mode,func)
    func.wrap = mode
    return func
  end

  #Converts a String representing a 'Ruby-style' R function name into a
  #String with the real R name according to the rules given in the manual.
  def RSRuby.convert_method_name(name)

    return name if !@@underscore_translation   # must access class var, else you get a Singleton-related recursive error

    if name.length > 1 and name[-1].chr == '_' and name[-2].chr != '_'
      name = name[0..-2]
    end
    # newname = name.gsub(/([^\\])__/,'\1<-')  this doesn't appear to have been used anyway
    name = name.gsub(/([^\\])_/, '\1.')
    name = name.gsub(/^_/, '.')
    name = name.gsub(/\\_/, '_')
    name

  end

  #Converts an Array of function arguments into lcall format. If the last
  #element of the array is a Hash then the contents of the Hash are
  #interpreted as named arguments.
  #
  #The returned value is an Array of tuples (Arrays of length two). Each
  #tupple corresponds to a name/argument pair.
  #
  #For example:
  #  convert_args_to_lcall([1,2,3,{:a=>4,:b=>5})
  #  => [['',1],['',2],['',3],['a',4],['b',5]]
  def RSRuby.convert_args_to_lcall(args)

    lcall_args = []

    args.each_with_index do |arg,i|
      unless arg.kind_of?(Hash) and i == args.length-1
        lcall_args.push(['',arg])
      else
        arg.each do |k,v|
          lcall_args.push([k.to_s,v])
        end
      end
    end

    return lcall_args

  end

  # Sets the default conversion mode for RSRuby.

  def RSRuby.set_default_mode(mode)
    raise ArgumentError, "Invalid mode requested" if !VALID_CONVERSION_MODES.include?(mode)
    RSRuby.instance.default_mode = mode
  end

  def RSRuby.get_default_mode
    RSRuby.instance.default_mode
  end

  def RSRuby.with_default_mode(mode)
    original_mode = get_default_mode
    begin
      RSRuby.set_default_mode(mode)
      yield
    ensure
      RSRuby.set_default_mode(original_mode)
    end
  end


  #TODO - not implemented
  def RSRuby.set_rsruby_input(m)
    @@rsruby_input = m
  end

  #TODO - not implemented
  def RSRuby.get_rsruby_input
    @@rsruby_input
  end

  #TODO - not implemented
  def RSRuby.set_rsruby_output(m)
    @@rsruby_output = m
  end

  #TODO - not implemented
  def RSRuby.get_rsruby_output
    @@rsruby_output
  end

  #TODO - not implemented
  def RSRuby.set_rsruby_showfiles(m)
    @@rsruby_showfiles = m
  end

  #TODO - not implemented
  def RSRuby.get_rsruby_showfiles
    @@rsruby_showfiles
  end

  #Evaluates the given string in R. Returns the result of the evaluation.
  def eval_R(s)
    self.eval(self.parse(:text => s))
  end


  #Wraps the R help function.
  def help(*args)
    helpobj = @cache['helpfun'].call(args)
    self.print(helpobj)
  end


  def __init_eval_R__(s)
    parsed = self.parse.__init_lcall__([['text',s]])
    self.eval.__init_lcall__([['',parsed]])
  end

  def __getitem__(name,init=false)

    #Find the identifier and cache (unless already cached)
    unless @cache.has_key?(name) && @caching
      if init
        robj = @cache['get'].__init_lcall__([['',name]])
      else
        robj = @cache['get'].lcall([['',name]])
      end
      @cache[name] = robj if @caching
    end

    #Retrieve object from cache
    robj ||= @cache[name]

    return robj

  end

end

class RException < RuntimeError
  MAX_BACKTRACE_LINES = 100

  def initialize(msg)
    begin
      RSRuby.instance.send('sink', 'file' => '/dev/null')
      r_full_traceback = RSRuby.with_default_mode(RSRuby::VECTOR_CONVERSION) do
        RSRuby.instance.send("traceback", {})
      end
    ensure
      RSRuby.instance.send('sink', {})
    end
    @r_traceback = if r_full_traceback
      r_full_traceback.map do |traceback_item|
        if traceback_item.length > MAX_BACKTRACE_LINES
          traceback_item.first(MAX_BACKTRACE_LINES) + ["  ... (#{traceback_item.length - MAX_BACKTRACE_LINES} more lines) ..."]
        else
          traceback_item
        end
      end.flatten
    else
      ["No traceback available"]
    end
    # Force UTF-8 - would be better to read R settings but UTF-8 is a nicer
    # default than ASCII-8BIT
    super(msg.dup.force_encoding("UTF-8"))
  end
  def backtrace
    x = super
    return x if x.nil?
    @r_traceback + x
  end
end
